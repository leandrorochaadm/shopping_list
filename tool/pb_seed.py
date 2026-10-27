# /// script
# requires-python = ">=3.12"
# dependencies = ["httpx"]
# ///
"""Fills the LOCAL PocketBase with the seed catalog and four months of purchases.

    uv run tool/pb_seed.py                     # anchors on today (Brasília)
    uv run tool/pb_seed.py --anchor 2026-11-01
    uv run tool/pb_seed.py --dry-run           # builds and checks, no network

Everything is written through the API as the user `dev@local.test`, so each
batch goes through the same API Rules as the app. The superuser only creates
or fixes the `dev` account. Each run wipes ONLY the records of `dev` (in
reverse creation order) and writes them again with deterministic ids.

**Never against production**: any URL that is not local is refused.

Money and quantity are INTEGERS in the smallest unit (cents, grams,
millilitres). Nothing here is ever a float.
"""

from __future__ import annotations

import argparse
import hashlib
import re
import secrets
import subprocess
import sys
import unicodedata
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta
from enum import IntEnum
from pathlib import Path
from urllib.parse import urlparse
from zoneinfo import ZoneInfo

import httpx

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "tool" / "data" / "seed_catalog.md"
DEFAULT_URL = "http://127.0.0.1:8095"
DEFAULT_PB_BIN = ROOT / "pocketbase" / "pocketbase"
DEFAULT_PB_DIR = ROOT / "pocketbase" / "pb_data"

DEV_EMAIL = "dev@local.test"
DEV_PASSWORD = "dev-local-pass"
SEED_SUPERUSER_EMAIL = "seed@local.test"

BATCH_SIZE = 50
BUYERS = ["Leandro", "Esposa"]
STORES = ["Supermercado Central", "Feira do Bairro"]
LOCAL_HOSTS = ("127.0.0.1", "localhost")
RECORD_ID_PATTERN = re.compile(r"^[a-z0-9]{15}$")
BASE36 = "0123456789abcdefghijklmnopqrstuvwxyz"

# Parents first: this is also the order the records are written in.
COLLECTION_ORDER: tuple[str, ...] = (
    "category",
    "brand",
    "store",
    "product_type",
    "product_registration",
    "product",
    "product_barcode",
    "shopping_list_item",
    "purchase",
    "purchase_item",
    "list_write_off",
    "spending_cap",
    "spending_cap_alert",
)

# collection -> {relation field: target collection}, as in the schema migration.
RELATIONS: dict[str, dict[str, str]] = {
    "product_type": {"category_id": "category"},
    "product_registration": {
        "product_type_id": "product_type",
        "brand_id": "brand",
    },
    "product": {"product_registration_id": "product_registration"},
    "shopping_list_item": {
        "product_type_id": "product_type",
        "preferred_registration_id": "product_registration",
    },
    "purchase": {"store_id": "store"},
    "purchase_item": {"purchase_id": "purchase", "product_id": "product"},
    "list_write_off": {
        "purchase_item_id": "purchase_item",
        "shopping_list_item_id": "shopping_list_item",
    },
}
OPTIONAL_RELATIONS = {"brand_id", "preferred_registration_id"}

# The unit written after a type in the catalog, and the base unit it stands for.
CATALOG_UNITS = {"g": "gram", "ml": "milliliter", "un": "unit", "cm": "centimeter"}
BASE_UNITS = frozenset(CATALOG_UNITS.values())
SELLING_MODES = frozenset({"by_piece", "by_weight"})


class ExitCode(IntEnum):
    OK = 0
    BAD_DATA = 2
    BAD_TARGET = 3
    BINARY_MISSING = 4
    SERVER_UNREACHABLE = 5
    SUPERUSER_FAILED = 6
    DEV_LOGIN_FAILED = 7
    WRITE_FAILED = 8


class SeedWriteError(Exception):
    """A batch the server refused."""


@dataclass(frozen=True)
class Packaging:
    """One leaf. `piece_size` and `total_content` are in the smallest unit."""

    piece_count: int
    piece_size: int
    piece_size_unit: str

    @property
    def total_content(self) -> int:
        return self.piece_count * self.piece_size


@dataclass
class Registration:
    """A registration plus its leaves — `type + brand + description`."""

    key: str
    type_name: str
    brand: str | None
    description: str
    selling_mode: str
    packagings: list[Packaging | None]
    # Price in CENTS per leaf, per store: prices[store][leaf index].
    prices: dict[str, list[int]]
    # Cents added to every price from `first_day(anchor, 1)` on: gives the
    # price-increase alert something to find.
    bump: int = 0


@dataclass
class CatalogType:
    """A `### Type (unit)` heading of the catalog and the lines under it."""

    name: str
    base_unit: str
    descriptions: list[str] = field(default_factory=list)


@dataclass(frozen=True)
class SeedRecord:
    """A record without `id` and `user` in the body."""

    collection: str
    id: str
    body: dict[str, object]


REGISTRATIONS = [
    Registration(
        key="refri",
        type_name="Refrigerante",
        brand="Coca-Cola",
        description="",
        selling_mode="by_piece",
        packagings=[
            Packaging(1, 350, "milliliter"),
            Packaging(6, 350, "milliliter"),
            Packaging(1, 2000, "milliliter"),
            Packaging(1, 2500, "milliliter"),
        ],
        prices={
            "Supermercado Central": [349, 1890, 899, 1090],
            "Feira do Bairro": [399, 2090, 799, 1190],
        },
        bump=180,
    ),
    Registration(
        key="acem",
        type_name="Acém",
        brand=None,
        description="moído",
        selling_mode="by_weight",
        packagings=[None],
        prices={"Supermercado Central": [3290], "Feira do Bairro": [2990]},
    ),
    Registration(
        key="leite",
        type_name="Leite",
        brand="Italac",
        description="integral",
        selling_mode="by_piece",
        packagings=[Packaging(1, 1000, "milliliter")],
        prices={"Supermercado Central": [529], "Feira do Bairro": [559]},
    ),
    Registration(
        key="sabao",
        type_name="Sabão em pó",
        brand="Omo",
        description="",
        selling_mode="by_piece",
        packagings=[Packaging(1, 800, "gram")],
        prices={"Supermercado Central": [1890], "Feira do Bairro": [1990]},
    ),
    Registration(
        key="aluminio",
        type_name="Papel alumínio",
        brand=None,
        description="",
        selling_mode="by_piece",
        # 30 m in centimetres.
        packagings=[Packaging(1, 3000, "centimeter")],
        prices={"Supermercado Central": [1290], "Feira do Bairro": [1390]},
    ),
    Registration(
        key="banana",
        type_name="Banana",
        brand=None,
        description="prata",
        selling_mode="by_weight",
        packagings=[None],
        prices={"Supermercado Central": [749], "Feira do Bairro": [599]},
    ),
]


def record_id(kind: str, *parts: object) -> str:
    """A stable 15-character id per logical row, so rerunning replaces."""
    digest = hashlib.sha256(
        f"{kind}:{'|'.join(str(p) for p in parts)}".encode()
    ).digest()
    number = int.from_bytes(digest, "big")
    digits: list[str] = []
    while number:
        number, rest = divmod(number, 36)
        digits.append(BASE36[rest])
    return "".join(reversed(digits))[:15]


def stored_day(day: date) -> str:
    return f"{day.isoformat()} 00:00:00.000Z"


def stored_instant(day: date, hour_utc: int) -> str:
    return f"{day.isoformat()} {hour_utc:02d}:00:00.000Z"


def normalized(name: str) -> str:
    stripped = unicodedata.normalize("NFKD", name)
    return "".join(c for c in stripped if not unicodedata.combining(c)).strip().lower()


def read_catalog(path: Path) -> dict[str, list[CatalogType]]:
    """Parses `seed_catalog.md`: `## Category`, `### Type (unit)`, `- description`.

    Everything after the second `---` is commentary and is not read.
    """
    catalog: dict[str, list[CatalogType]] = {}
    category: str | None = None
    rulers = 0
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if line == "---":
            rulers += 1
            if rulers == 2:
                break
            continue
        if rulers == 0:
            continue
        if line.startswith("### "):
            match = re.fullmatch(r"### (.+?) \((\w+)\)", line)
            if match is None or category is None:
                raise ValueError(f"Cabeçalho de tipo fora do padrão: {line!r}")
            name, unit = match.groups()
            if unit not in CATALOG_UNITS:
                raise ValueError(f"Unidade desconhecida no catálogo: {line!r}")
            catalog[category].append(CatalogType(name.strip(), CATALOG_UNITS[unit]))
        elif line.startswith("## "):
            category = line[3:].strip()
            catalog[category] = []
        elif line.startswith("- "):
            if category is None or not catalog[category]:
                raise ValueError(f"Descrição fora de um tipo: {line!r}")
            catalog[category][-1].descriptions.append(line[2:].strip())
    return catalog


def first_day(anchor: date, months_back: int) -> date:
    """First day of the month `months_back` months before `anchor`."""
    month = anchor.month - months_back
    year = anchor.year
    while month <= 0:
        month += 12
        year -= 1
    return date(year, month, 1)


def purchase_days(anchor: date) -> list[date]:
    """Two shopping days per month, over four months ending in the anchor's."""
    days: list[date] = []
    for months_back in range(3, -1, -1):
        start = first_day(anchor, months_back)
        for offset in (4, 18):
            day = start + timedelta(days=offset)
            # Never write a purchase in the future.
            if day <= anchor:
                days.append(day)
    return days


def build_records(anchor: date) -> list[SeedRecord]:
    catalog = read_catalog(CATALOG)
    records: list[SeedRecord] = []

    def add(collection: str, rid: str, body: dict[str, object]) -> None:
        records.append(SeedRecord(collection, rid, body))

    # ── Catalog ──────────────────────────────────────────────────────────
    for category, types in catalog.items():
        category_id = record_id("category", category)
        add("category", category_id, {"name": category, "active": True})
        for catalog_type in types:
            add(
                "product_type",
                record_id("type", catalog_type.name),
                {
                    "name": catalog_type.name,
                    "category_id": category_id,
                    "base_unit": catalog_type.base_unit,
                    "active": True,
                },
            )

    for brand in sorted({r.brand for r in REGISTRATIONS if r.brand}):
        add("brand", record_id("brand", brand), {"name": brand, "active": True})
    for store in STORES:
        add("store", record_id("store", store), {"name": store, "active": True})

    leaf_ids: dict[str, list[str]] = {}
    for registration in REGISTRATIONS:
        registration_id = record_id("registration", registration.key)
        add(
            "product_registration",
            registration_id,
            {
                "product_type_id": record_id("type", registration.type_name),
                "brand_id": record_id("brand", registration.brand)
                if registration.brand
                else "",
                "description": registration.description,
                "selling_mode": registration.selling_mode,
                "active": True,
            },
        )
        leaf_ids[registration.key] = []
        for index, packaging in enumerate(registration.packagings):
            leaf_id = record_id("product", registration.key, index)
            leaf_ids[registration.key].append(leaf_id)
            body: dict[str, object] = {
                "product_registration_id": registration_id,
                "active": True,
            }
            if packaging is not None:
                body.update(
                    piece_count=packaging.piece_count,
                    piece_size=packaging.piece_size,
                    piece_size_unit=packaging.piece_size_unit,
                    total_content=packaging.total_content,
                )
            add("product", leaf_id, body)

    # Generic brandless registrations of the catalog, one leaf each.
    purchased = {
        (r.type_name, normalized(r.description))
        for r in REGISTRATIONS
        if r.brand is None
    }
    for types in catalog.values():
        for catalog_type in types:
            for description in catalog_type.descriptions or [""]:
                if (catalog_type.name, normalized(description)) in purchased:
                    continue
                registration_id = record_id(
                    "registration", "catalog", catalog_type.name, description
                )
                by_piece = catalog_type.base_unit == "unit"
                add(
                    "product_registration",
                    registration_id,
                    {
                        "product_type_id": record_id("type", catalog_type.name),
                        "brand_id": "",
                        "description": description,
                        "selling_mode": "by_piece" if by_piece else "by_weight",
                        "active": True,
                    },
                )
                leaf: dict[str, object] = {
                    "product_registration_id": registration_id,
                    "active": True,
                }
                if by_piece:
                    leaf.update(
                        piece_count=1,
                        piece_size=1,
                        piece_size_unit="unit",
                        total_content=1,
                    )
                add(
                    "product",
                    record_id("product", "catalog", catalog_type.name, description),
                    leaf,
                )

    # ── Purchases ────────────────────────────────────────────────────────
    days = purchase_days(anchor)
    bump_from = first_day(anchor, 1)
    # The last purchase, remembered so the H9 trail points at REAL items.
    last_items: dict[str, tuple[str, int]] = {}
    last_day: date | None = None
    for order, day in enumerate(days):
        store = STORES[order % len(STORES)]
        buyer = BUYERS[order % len(BUYERS)]
        purchase_id = record_id("purchase", day.isoformat(), store)
        add(
            "purchase",
            purchase_id,
            {
                "purchase_date": stored_day(day),
                "store_id": record_id("store", store),
                "registered_by": buyer,
                "created_at": stored_instant(day, 15),
            },
        )
        for registration in REGISTRATIONS:
            for index, packaging in enumerate(registration.packagings):
                if (order + index) % max(len(registration.packagings), 1) != 0:
                    continue
                price = registration.prices[store][index]
                if registration.bump and day >= bump_from:
                    price += registration.bump
                if packaging is None:
                    # By weight: quantity IS the weight, in grams.
                    quantity = 1000 + 200 * (order % 3)
                    in_base_unit = quantity
                    paid = price * quantity // 1000
                else:
                    quantity = 1 + (order % 2)
                    in_base_unit = quantity * packaging.total_content
                    paid = price * quantity
                item_id = record_id("item", purchase_id, registration.key, index)
                add(
                    "purchase_item",
                    item_id,
                    {
                        "purchase_id": purchase_id,
                        "product_id": leaf_ids[registration.key][index],
                        "quantity": quantity,
                        "quantity_in_base_unit": in_base_unit,
                        "total_paid": paid,
                    },
                )
                if index == 0:
                    last_items[registration.key] = (item_id, in_base_unit)
        last_day = day

    # ── The list ─────────────────────────────────────────────────────────
    for offset, (type_name, quantity, registration_key) in enumerate(
        [
            ("Leite", 6000, "leite"),
            ("Refrigerante", 3000, "refri"),
            ("Banana", 1500, None),
            ("Sabão em pó", None, None),
        ]
    ):
        body = {
            "product_type_id": record_id("type", type_name),
            "preferred_registration_id": record_id("registration", registration_key)
            if registration_key
            else "",
            "entered_on": stored_day(anchor - timedelta(days=offset)),
            "picked": False,
            "not_found": False,
        }
        if quantity is not None:
            body["quantity"] = quantity
        add("shopping_list_item", record_id("list", type_name), body)

    # ── H9: a closed item with its trail, and a partial write-off ────────
    if last_day is not None:
        entered_before = stored_day(first_day(anchor, 3))
        closed_id = record_id("list", "fechado")
        add(
            "shopping_list_item",
            closed_id,
            {
                "product_type_id": record_id("type", "Acém"),
                "preferred_registration_id": "",
                "quantity": 1000,
                "entered_on": entered_before,
                "fulfilled_on": stored_day(last_day),
                "picked": False,
                "not_found": False,
            },
        )
        beef_item, _ = last_items["acem"]
        add(
            "list_write_off",
            record_id("write-off", "fechado"),
            {
                "purchase_item_id": beef_item,
                "shopping_list_item_id": closed_id,
                "quantity_written_off": 1000,
                "cleared_not_found": True,
            },
        )
        partial_id = record_id("list", "parcial")
        add(
            "shopping_list_item",
            partial_id,
            {
                "product_type_id": record_id("type", "Leite"),
                "preferred_registration_id": "",
                "quantity": 6000,
                "entered_on": entered_before,
                "picked": False,
                "not_found": False,
            },
        )
        milk_item, milk_amount = last_items["leite"]
        add(
            "list_write_off",
            record_id("write-off", "parcial"),
            {
                "purchase_item_id": milk_item,
                "shopping_list_item_id": partial_id,
                "quantity_written_off": milk_amount,
                "cleared_not_found": False,
            },
        )

    # ── H10: one deactivated row of each of the six catalogs ─────────────
    add("category", record_id("category", "Bazar"), {"name": "Bazar", "active": False})
    add(
        "product_type",
        record_id("type", "Cerveja"),
        {
            "name": "Cerveja",
            "category_id": record_id("category", "Bebidas"),
            "base_unit": "milliliter",
            "active": False,
        },
    )
    add(
        "brand",
        record_id("brand", "Marca Antiga"),
        {"name": "Marca Antiga", "active": False},
    )
    skim_id = record_id("registration", "leite-desnatado")
    add(
        "product_registration",
        skim_id,
        {
            "product_type_id": record_id("type", "Leite"),
            "brand_id": "",
            "description": "desnatado",
            "selling_mode": "by_piece",
            "active": False,
        },
    )
    add(
        "product",
        record_id("product", "leite-desnatado", 0),
        {
            "product_registration_id": skim_id,
            "piece_count": 1,
            "piece_size": 1000,
            "piece_size_unit": "milliliter",
            "total_content": 1000,
            "active": True,
        },
    )
    # A leaf deactivated on its own, under an ACTIVE registration.
    add(
        "product",
        record_id("product", "refri", 99),
        {
            "product_registration_id": record_id("registration", "refri"),
            "piece_count": 1,
            "piece_size": 1500,
            "piece_size_unit": "milliliter",
            "total_content": 1500,
            "active": False,
        },
    )
    add(
        "store",
        record_id("store", "Mercearia do Zé"),
        {"name": "Mercearia do Zé", "active": False},
    )

    # ── H13: a cap in force and the 80% of this month already given ──────
    cap_from = first_day(anchor, 3)
    current_month = first_day(anchor, 0)
    add(
        "spending_cap",
        record_id("cap", cap_from.isoformat()),
        {"amount": 150000, "effective_from": stored_day(cap_from)},
    )
    add(
        "spending_cap_alert",
        record_id("cap-alert", current_month.isoformat()),
        {
            "month": stored_day(current_month),
            "warned_80_at": stored_instant(current_month, 0),
        },
    )

    position = {name: i for i, name in enumerate(COLLECTION_ORDER)}
    return sorted(records, key=lambda r: position[r.collection])


def check_catalog(catalog: dict[str, list[CatalogType]]) -> None:
    categories = list(catalog) + ["Bazar"]
    types = [t.name for ts in catalog.values() for t in ts] + ["Cerveja"]
    for kind, names in (("categoria", categories), ("tipo", types)):
        keys = [normalized(n) for n in names]
        repeated = sorted({k for k in keys if keys.count(k) > 1})
        if repeated:
            raise ValueError(f"Nome de {kind} repetido no catálogo: {repeated}")
    missing = sorted({r.type_name for r in REGISTRATIONS} - set(types))
    if missing:
        raise ValueError(f"Tipos que faltam em {CATALOG.name}: {missing}")


def check_records(records: list[SeedRecord]) -> None:
    check_catalog(read_catalog(CATALOG))
    position = {name: i for i, name in enumerate(COLLECTION_ORDER)}
    seen: dict[str, dict[str, int]] = {name: {} for name in COLLECTION_ORDER}
    for record in records:
        if not RECORD_ID_PATTERN.fullmatch(record.id):
            raise ValueError(f"Id inválido em {record.collection}: {record.id!r}")
        if record.id in seen[record.collection]:
            raise ValueError(f"Id repetido em {record.collection}: {record.id}")
        seen[record.collection][record.id] = len(seen[record.collection])
        for rel_field, target in RELATIONS.get(record.collection, {}).items():
            value = record.body.get(rel_field)
            if value == "" and rel_field in OPTIONAL_RELATIONS:
                continue
            if position[target] >= position[record.collection] or value not in seen[target]:
                raise ValueError(
                    f"{record.collection}.{rel_field} aponta para um registro "
                    f"que não existe antes dele: {value!r}"
                )
        body = record.body
        for unit_field in ("base_unit", "piece_size_unit"):
            if unit_field in body and body[unit_field] not in BASE_UNITS:
                raise ValueError(f"{unit_field} inválido em {record.id}")
        if "selling_mode" in body and body["selling_mode"] not in SELLING_MODES:
            raise ValueError(f"selling_mode inválido em {record.id}")
        for positive in ("quantity", "quantity_in_base_unit", "total_content"):
            value = body.get(positive)
            if isinstance(value, int) and value <= 0:
                raise ValueError(f"{positive} deve ser maior que zero em {record.id}")
        paid = body.get("total_paid")
        if isinstance(paid, int) and paid < 0:
            raise ValueError(f"total_paid negativo em {record.id}")


def ensure_superuser(pb_bin: Path, pb_dir: Path) -> str:
    """Creates or updates the seed superuser; returns the generated password."""
    if not pb_bin.is_file() or not pb_bin.stat().st_mode & 0o111:
        raise FileNotFoundError(str(pb_bin))
    password = secrets.token_urlsafe(18)
    result = subprocess.run(
        [str(pb_bin), "superuser", "upsert", SEED_SUPERUSER_EMAIL, password,
         f"--dir={pb_dir}"],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip())
    return password


class Api:
    def __init__(self, base_url: str) -> None:
        self._client = httpx.Client(base_url=base_url, timeout=30)

    def health(self) -> bool:
        try:
            return self._client.get("/api/health").status_code == 200
        except httpx.TransportError:
            return False

    def auth(
        self, collection: str, email: str, password: str
    ) -> tuple[str, str] | None:
        response = self._client.post(
            f"/api/collections/{collection}/auth-with-password",
            json={"identity": email, "password": password},
        )
        if response.status_code == 400:
            return None
        response.raise_for_status()
        data = response.json()
        return data["token"], data["record"]["id"]

    def find_user(self, superuser_token: str, email: str) -> str | None:
        response = self._client.get(
            "/api/collections/users/records",
            params={"filter": f'email = "{email}"', "fields": "id"},
            headers={"Authorization": superuser_token},
        )
        response.raise_for_status()
        items = response.json()["items"]
        return items[0]["id"] if items else None

    def create_user(self, superuser_token: str, email: str, password: str) -> str:
        response = self._client.post(
            "/api/collections/users/records",
            json={
                "email": email,
                "password": password,
                "passwordConfirm": password,
                "verified": True,
            },
            headers={"Authorization": superuser_token},
        )
        response.raise_for_status()
        return response.json()["id"]

    def set_password(self, superuser_token: str, user_id: str, password: str) -> None:
        response = self._client.patch(
            f"/api/collections/users/records/{user_id}",
            json={"password": password, "passwordConfirm": password},
            headers={"Authorization": superuser_token},
        )
        response.raise_for_status()

    def list_ids(self, token: str, collection: str) -> list[str]:
        ids: list[str] = []
        page = 1
        while True:
            response = self._client.get(
                f"/api/collections/{collection}/records",
                params={"fields": "id", "perPage": 500, "page": page,
                        "skipTotal": 1},
                headers={"Authorization": token},
            )
            response.raise_for_status()
            items = response.json()["items"]
            ids.extend(item["id"] for item in items)
            if len(items) < 500:
                return ids
            page += 1

    def batch(self, token: str, requests: list[dict[str, object]]) -> None:
        response = self._client.post(
            "/api/batch",
            json={"requests": requests},
            headers={"Authorization": token},
        )
        if response.status_code != 200:
            raise SeedWriteError(f"{response.status_code}: {_batch_message(response)}")


def _batch_message(response: httpx.Response) -> str:
    try:
        data = response.json()
    except ValueError:
        return "resposta sem corpo"
    nested = data.get("data", {}).get("requests", {})
    for _, item in sorted(nested.items()):
        inner = item.get("response", item)
        message = inner.get("message")
        if message:
            return str(message)
    return str(data.get("message", "sem detalhe"))


def wipe(api: Api, token: str) -> dict[str, int]:
    removed: dict[str, int] = {}
    for collection in reversed(COLLECTION_ORDER):
        ids = api.list_ids(token, collection)
        removed[collection] = len(ids)
        for start in range(0, len(ids), BATCH_SIZE):
            api.batch(
                token,
                [
                    {"method": "DELETE",
                     "url": f"/api/collections/{collection}/records/{rid}"}
                    for rid in ids[start : start + BATCH_SIZE]
                ],
            )
    return removed


def write(api: Api, token: str, user_id: str, records: list[SeedRecord]) -> None:
    for start in range(0, len(records), BATCH_SIZE):
        chunk = records[start : start + BATCH_SIZE]
        try:
            api.batch(
                token,
                [
                    {
                        "method": "POST",
                        "url": f"/api/collections/{r.collection}/records",
                        "body": {"id": r.id, "user": user_id, **r.body},
                    }
                    for r in chunk
                ],
            )
        except SeedWriteError as error:
            collections = sorted({r.collection for r in chunk})
            raise SeedWriteError(f"{error} (coleções: {', '.join(collections)})")


def _counts(records: list[SeedRecord]) -> dict[str, int]:
    return {c: sum(1 for r in records if r.collection == c) for c in COLLECTION_ORDER}


def _fail(code: ExitCode, *lines: str) -> int:
    for line in lines:
        print(line, file=sys.stderr)
    return int(code)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--anchor", type=date.fromisoformat)
    parser.add_argument("--url", default=DEFAULT_URL)
    parser.add_argument("--pb-bin", type=Path, default=DEFAULT_PB_BIN)
    parser.add_argument("--pb-dir", type=Path, default=DEFAULT_PB_DIR)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)

    anchor = args.anchor or datetime.now(ZoneInfo("America/Sao_Paulo")).date()
    try:
        records = build_records(anchor)
        check_records(records)
    except (ValueError, OSError) as error:
        return _fail(ExitCode.BAD_DATA, str(error))
    counts = _counts(records)

    if args.dry_run:
        for collection, count in counts.items():
            print(f"{collection}: {count}")
        print(f"Âncora: {anchor.isoformat()}")
        return int(ExitCode.OK)

    parsed = urlparse(args.url)
    if parsed.scheme != "http" or parsed.hostname not in LOCAL_HOSTS:
        return _fail(
            ExitCode.BAD_TARGET,
            "O seed só roda no PocketBase local (http://127.0.0.1:<porta>).",
        )

    unreachable = (
        f"O PocketBase local não respondeu em {args.url}. "
        "Rode `make pb-serve` em outro terminal."
    )
    api = Api(args.url)
    if not api.health():
        return _fail(ExitCode.SERVER_UNREACHABLE, unreachable)

    try:
        try:
            superuser_password = ensure_superuser(args.pb_bin, args.pb_dir)
        except FileNotFoundError:
            return _fail(
                ExitCode.BINARY_MISSING, "Rode `make setup` primeiro.", str(args.pb_bin)
            )
        except RuntimeError as error:
            return _fail(ExitCode.SUPERUSER_FAILED, str(error))

        superuser = api.auth("_superusers", SEED_SUPERUSER_EMAIL, superuser_password)
        if superuser is None:
            return _fail(
                ExitCode.SUPERUSER_FAILED,
                "O superusuário do seed não entrou. Confira se o "
                f"`make pb-serve` usa --dir={args.pb_dir}.",
            )
        superuser_token = superuser[0]

        if api.find_user(superuser_token, DEV_EMAIL) is None:
            api.create_user(superuser_token, DEV_EMAIL, DEV_PASSWORD)
        dev = api.auth("users", DEV_EMAIL, DEV_PASSWORD)
        if dev is None:
            user_id = api.find_user(superuser_token, DEV_EMAIL)
            assert user_id is not None
            api.set_password(superuser_token, user_id, DEV_PASSWORD)
            dev = api.auth("users", DEV_EMAIL, DEV_PASSWORD)
        if dev is None:
            return _fail(
                ExitCode.DEV_LOGIN_FAILED, "A conta dev@local.test não entrou."
            )
        token, user_id = dev

        wipe(api, token)
        write(api, token, user_id, records)

        for collection, expected in counts.items():
            if len(api.list_ids(token, collection)) != expected:
                return _fail(
                    ExitCode.WRITE_FAILED,
                    f"A contagem de {collection} no servidor não bate com o seed.",
                )
    except SeedWriteError as error:
        return _fail(ExitCode.WRITE_FAILED, f"Não foi possível gravar: {error}")
    except httpx.TransportError:
        return _fail(ExitCode.SERVER_UNREACHABLE, unreachable)
    except httpx.HTTPStatusError as error:
        return _fail(
            ExitCode.WRITE_FAILED,
            f"O servidor recusou o pedido ({error.response.status_code}) "
            f"em {error.request.url.path}.",
        )

    for collection, count in counts.items():
        print(f"{collection}: {count}")
    print(f"Âncora: {anchor.isoformat()}")
    print(f"Entre no app com {DEV_EMAIL} / {DEV_PASSWORD}.")
    return int(ExitCode.OK)


if __name__ == "__main__":
    sys.exit(main())
