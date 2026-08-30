# /// script
# requires-python = ">=3.12"
# dependencies = []
# ///
"""Generates `supabase/seed.sql`: four months of synthetic purchases for `dev`.

    uv run tool/make_seed.py            # anchors on today
    uv run tool/make_seed.py 2026-11-01 # anchors on a chosen day

**Why this is generated and not written by hand.** The dates inside the .sql
stay literal — "no current_date in SQL" (decision 7) does not bend for a seed.
But H15, H17 and H18 measure three-month windows against the phone's "today":
seed data anchored on August 2026 falls out of every window by November, and
those screens go back to having nothing to show — the exact problem the seed
exists to solve. Re-anchoring is one command, and reapplying it is one psql.

**Never against `prod`.** This writes catalog rows and purchases that never
happened. It belongs to the `dev` project only (decision 17).

Money and quantity are INTEGERS in the smallest unit — cents, grams,
millilitres (decision B5). Nothing here is ever a float.
"""

from __future__ import annotations

import sys
from dataclasses import dataclass, field
from datetime import date, timedelta
from pathlib import Path
from uuid import UUID, uuid5

SEED_NAMESPACE = UUID("5b1a4f6e-8f2a-4c1e-9d3b-7a6c2e0f9d41")
OUTPUT = Path(__file__).resolve().parent.parent / "supabase" / "seed.sql"

# The two device labels of H1, copied onto each purchase as text.
BUYERS = ["Leandro", "Esposa"]


def uid(kind: str, *parts: object) -> str:
    """A stable uuid per logical row, so rerunning replaces instead of piling up."""
    return str(uuid5(SEED_NAMESPACE, f"{kind}:{'|'.join(str(p) for p in parts)}"))


def sql_text(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def sql_optional(value: str | None) -> str:
    return "null" if value is None else sql_text(value)


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
    # Cents added to every price of this registration from `bump_after` on —
    # this is what gives H15 an increase above its threshold to find.
    bump: int = 0
    bump_after_months: int = 2
    leaf_ids: list[str] = field(default_factory=list)


CATEGORIES = {
    "Bebidas": ["Refrigerante", "Leite"],
    "Carnes": ["Acém"],
    "Limpeza": ["Sabão em pó"],
    "Hortifrúti": ["Banana"],
}

TYPE_BASE_UNIT = {
    "Refrigerante": "liter",
    "Leite": "liter",
    "Acém": "kilogram",
    "Sabão em pó": "kilogram",
    "Banana": "kilogram",
}

STORES = ["Supermercado Central", "Feira do Bairro"]

REGISTRATIONS = [
    # The four-packaging registration of the requirements' own example.
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
            # Same product, two stores, different prices — that is H16.
            "Supermercado Central": [349, 1890, 899, 1090],
            "Feira do Bairro": [399, 2090, 799, 1190],
        },
        # A jump big enough for the price-increase alert of H15 to fire.
        bump=180,
    ),
    # Sold by weight, no brand: the leaf exists with null packaging (B1), and
    # the missing brand is a value in the unique index (B2).
    Registration(
        key="acem",
        type_name="Acém",
        brand=None,
        description="moído",
        selling_mode="by_weight",
        packagings=[None],
        prices={
            "Supermercado Central": [3290],
            "Feira do Bairro": [2990],
        },
    ),
    Registration(
        key="leite",
        type_name="Leite",
        brand="Italac",
        description="integral",
        selling_mode="by_piece",
        packagings=[Packaging(1, 1000, "milliliter")],
        prices={
            "Supermercado Central": [529],
            "Feira do Bairro": [559],
        },
    ),
    Registration(
        key="sabao",
        type_name="Sabão em pó",
        brand="Omo",
        description="",
        selling_mode="by_piece",
        packagings=[Packaging(1, 800, "gram")],
        prices={
            "Supermercado Central": [1890],
            "Feira do Bairro": [1990],
        },
    ),
    Registration(
        key="banana",
        type_name="Banana",
        brand=None,
        description="prata",
        selling_mode="by_weight",
        packagings=[None],
        prices={
            "Supermercado Central": [749],
            "Feira do Bairro": [599],
        },
    ),
]


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
            # Never write a purchase in the future: a month-to-date total that
            # includes tomorrow is a bug nobody would suspect the seed of.
            if day <= anchor:
                days.append(day)
    return days


def build(anchor: date) -> str:
    lines: list[str] = [
        "-- GENERATED BY tool/make_seed.py — do not edit by hand.",
        f"-- Anchor: {anchor.isoformat()} (four months ending in this one).",
        "--",
        "-- Synthetic data for the `dev` project ONLY (decision 17). It exists",
        "-- so the three-month windows of H15, H17 and H18 and the reports of",
        "-- H11 and H16 have something to show before four months of real use.",
        "--",
        "-- The dates below are literal on purpose: no current_date in SQL",
        "-- (decision 7). They age, and re-anchoring is one command:",
        "--     uv run tool/make_seed.py",
        "--",
        "-- Money is in CENTS and quantity in the smallest unit (decision B5).",
        "",
        "begin;",
        "",
        "-- Idempotent: rerunning replaces the same rows instead of piling up.",
        "-- Purchases go first, because the catalog is what they reference.",
        "delete from public.list_write_off;",
        "delete from public.purchase_item;",
        "delete from public.purchase;",
        "delete from public.shopping_list_item;",
        "delete from public.product;",
        "delete from public.product_registration;",
        "delete from public.product_type;",
        "delete from public.brand;",
        "delete from public.category;",
        "delete from public.store;",
        "",
    ]

    # ── Catalog ──────────────────────────────────────────────────────────
    lines.append("-- Categories and types")
    for category, types in CATEGORIES.items():
        category_id = uid("category", category)
        lines.append(
            "insert into public.category (id, name) values "
            f"({sql_text(category_id)}, {sql_text(category)});"
        )
        for type_name in types:
            lines.append(
                "insert into public.product_type "
                "(id, name, category_id, base_unit) values ("
                f"{sql_text(uid('type', type_name))}, {sql_text(type_name)}, "
                f"{sql_text(category_id)}, {sql_text(TYPE_BASE_UNIT[type_name])});"
            )
    lines.append("")

    brands = sorted({r.brand for r in REGISTRATIONS if r.brand})
    lines.append("-- Brands (a product with no brand keeps brand_id null — B2)")
    for brand in brands:
        lines.append(
            "insert into public.brand (id, name) values "
            f"({sql_text(uid('brand', brand))}, {sql_text(brand)});"
        )
    lines.append("")

    lines.append("-- Stores")
    for store in STORES:
        lines.append(
            "insert into public.store (id, name) values "
            f"({sql_text(uid('store', store))}, {sql_text(store)});"
        )
    lines.append("")

    lines.append("-- Registrations and their leaves")
    for registration in REGISTRATIONS:
        registration_id = uid("registration", registration.key)
        brand_id = uid("brand", registration.brand) if registration.brand else None
        lines.append(
            "insert into public.product_registration (id, product_type_id, "
            "brand_id, description, selling_mode) values ("
            f"{sql_text(registration_id)}, "
            f"{sql_text(uid('type', registration.type_name))}, "
            f"{sql_optional(brand_id)}, "
            f"{sql_text(registration.description)}, "
            f"{sql_text(registration.selling_mode)});"
        )
        for index, packaging in enumerate(registration.packagings):
            leaf_id = uid("product", registration.key, index)
            registration.leaf_ids.append(leaf_id)
            if packaging is None:
                # Sold by weight: the leaf exists with no packaging (B1).
                lines.append(
                    "insert into public.product (id, product_registration_id) "
                    f"values ({sql_text(leaf_id)}, {sql_text(registration_id)});"
                )
            else:
                lines.append(
                    "insert into public.product (id, product_registration_id, "
                    "piece_count, piece_size, piece_size_unit, total_content) "
                    f"values ({sql_text(leaf_id)}, {sql_text(registration_id)}, "
                    f"{packaging.piece_count}, {packaging.piece_size}, "
                    f"{sql_text(packaging.piece_size_unit)}, "
                    f"{packaging.total_content});"
                )
    lines.append("")

    # ── Purchases ────────────────────────────────────────────────────────
    days = purchase_days(anchor)
    bump_from = first_day(anchor, 1)
    lines.append(
        f"-- {len(days)} purchases over four months, alternating store and buyer."
    )
    lines.append(
        f"-- Prices rise from {bump_from.isoformat()} on, so H15 has an increase to find."
    )
    # The last purchase, remembered so the trail of H9 can point at REAL
    # purchase items: a write-off whose `purchase_item_id` does not exist
    # would be refused by the foreign key, and one that points at a purchase
    # of another day would make the undo give back the wrong amount.
    last_purchase: dict[str, object] = {}

    for order, day in enumerate(days):
        store = STORES[order % len(STORES)]
        buyer = BUYERS[order % len(BUYERS)]
        purchase_id = uid("purchase", day.isoformat(), store)
        lines.append(
            "insert into public.purchase (id, purchase_date, store_id, "
            f"registered_by) values ({sql_text(purchase_id)}, "
            f"{sql_text(day.isoformat())}, {sql_text(uid('store', store))}, "
            f"{sql_text(buyer)});"
        )
        for registration in REGISTRATIONS:
            # Two leaves per registration per purchase at most, so the four
            # packagings of the soft drink all get a history.
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
                item_id = uid("item", purchase_id, registration.key, index)
                lines.append(
                    "insert into public.purchase_item (id, purchase_id, "
                    "product_id, quantity, quantity_in_base_unit, total_paid) "
                    f"values ({sql_text(item_id)}, "
                    f"{sql_text(purchase_id)}, "
                    f"{sql_text(registration.leaf_ids[index])}, "
                    f"{quantity}, {in_base_unit}, {paid});"
                )
                if index == 0:
                    last_purchase[registration.key] = (item_id, in_base_unit)
        last_purchase["day"] = day
        lines.append("")

    # ── The list, as it would be found in the aisle ──────────────────────
    #
    # The four shapes screen 1 has to draw, so none of them has to be typed by
    # hand on `dev`: the full line of the wireframe ("Leite Italac 1 L — 6 L"),
    # an item that only prefers a brand, a plain one, and — the common path of
    # the `#1a` panel — one with NO QUANTITY at all, which is what the base
    # migration was corrected to accept.
    lines.append("-- A shopping list with something already on it")
    for offset, (type_name, quantity, brand, leaf) in enumerate(
        [
            ("Leite", 6000, "Italac", ("leite", 0)),
            ("Refrigerante", 3000, "Coca-Cola", None),
            ("Banana", 1500, None, None),
            # No quantity: "acabou o sabão em pó" has none to state, and the
            # item leaves the list on the first purchase of the type.
            ("Sabão em pó", None, None, None),
        ]
    ):
        entered_on = anchor - timedelta(days=offset)
        lines.append(
            "insert into public.shopping_list_item (id, product_type_id, "
            "preferred_brand_id, preferred_product_id, quantity, entered_on) "
            f"values ({sql_text(uid('list', type_name))}, "
            f"{sql_text(uid('type', type_name))}, "
            f"{sql_optional(uid('brand', brand) if brand else None)}, "
            f"{sql_optional(uid('product', *leaf) if leaf else None)}, "
            f"{'null' if quantity is None else quantity}, "
            f"{sql_text(entered_on.isoformat())});"
        )

    # ── What H9 undoes, and what H10 has to be able to show ─────────────
    #
    # Three situations the four lines above do not cover, and without which
    # the two screens of delivery 4 open on `dev` with nothing to work on.
    lines.append("")
    lines.append("-- H9: a list item CLOSED by a purchase, with its trail")

    last_day = last_purchase["day"]
    assert isinstance(last_day, date)
    # Entered well before the purchase: an item that entered AFTER it is
    # precisely the one decision 25 says the purchase must not touch.
    entered_before = first_day(anchor, 3)

    beef_item, _ = last_purchase["acem"]  # type: ignore[misc]
    lines.append(
        "insert into public.shopping_list_item (id, product_type_id, "
        "quantity, entered_on, fulfilled_on) values ("
        f"{sql_text(uid('list', 'fechado'))}, {sql_text(uid('type', 'Acém'))}, "
        f"1000, {sql_text(entered_before.isoformat())}, "
        f"{sql_text(last_day.isoformat())});"
    )
    lines.append(
        "insert into public.list_write_off (purchase_item_id, "
        "shopping_list_item_id, quantity_written_off, cleared_not_found) "
        f"values ({sql_text(beef_item)}, {sql_text(uid('list', 'fechado'))}, "
        "1000, true);"
    )
    lines.append("")

    lines.append(
        "-- H9: a PARTIAL write-off — 6 L asked, part bought, still on the list"
    )
    milk_item, milk_amount = last_purchase["leite"]  # type: ignore[misc]
    lines.append(
        "insert into public.shopping_list_item (id, product_type_id, "
        "quantity, entered_on) values ("
        f"{sql_text(uid('list', 'parcial'))}, {sql_text(uid('type', 'Leite'))}, "
        f"6000, {sql_text(entered_before.isoformat())});"
    )
    lines.append(
        "insert into public.list_write_off (purchase_item_id, "
        "shopping_list_item_id, quantity_written_off, cleared_not_found) "
        f"values ({sql_text(milk_item)}, {sql_text(uid('list', 'parcial'))}, "
        f"{milk_amount}, false);"
    )
    lines.append("")

    # ── H10: one deactivated row of each of the six catalogs ─────────────
    #
    # Nothing is ever deleted (decision 19), so "mostrar desativados" is a
    # filter over rows that have to EXIST for it to have anything to show.
    lines.append("-- H10: one deactivated row of each of the six catalogs")
    lines.append(
        "insert into public.category (id, name, active) values "
        f"({sql_text(uid('category', 'Padaria'))}, 'Padaria', false);"
    )
    lines.append(
        "insert into public.product_type (id, name, category_id, base_unit, "
        f"active) values ({sql_text(uid('type', 'Iogurte'))}, 'Iogurte', "
        f"{sql_text(uid('category', 'Bebidas'))}, 'liter', false);"
    )
    lines.append(
        "insert into public.brand (id, name, active) values "
        f"({sql_text(uid('brand', 'Marca Antiga'))}, 'Marca Antiga', false);"
    )
    lines.append(
        "insert into public.product_registration (id, product_type_id, "
        "brand_id, description, selling_mode, active) values ("
        f"{sql_text(uid('registration', 'leite-desnatado'))}, "
        f"{sql_text(uid('type', 'Leite'))}, null, 'desnatado', "
        "'by_piece', false);"
    )
    lines.append(
        "insert into public.product (id, product_registration_id, piece_count, "
        "piece_size, piece_size_unit, total_content) values ("
        f"{sql_text(uid('product', 'leite-desnatado', 0))}, "
        f"{sql_text(uid('registration', 'leite-desnatado'))}, "
        "1, 1000, 'milliliter', 1000);"
    )
    lines.append(
        "-- A leaf deactivated on its own, under an ACTIVE registration "
        "(decision 23):"
    )
    lines.append(
        "insert into public.product (id, product_registration_id, piece_count, "
        "piece_size, piece_size_unit, total_content, active) values ("
        f"{sql_text(uid('product', 'refri', 99))}, "
        f"{sql_text(uid('registration', 'refri'))}, "
        "1, 1500, 'milliliter', 1500, false);"
    )
    lines.append(
        "insert into public.store (id, name, active) values "
        f"({sql_text(uid('store', 'Mercearia do Zé'))}, "
        "'Mercearia do Zé', false);"
    )

    lines += ["", "commit;", ""]
    return "\n".join(lines)


def main() -> None:
    anchor = date.fromisoformat(sys.argv[1]) if len(sys.argv) > 1 else date.today()
    OUTPUT.write_text(build(anchor), encoding="utf-8")
    print(f"wrote {OUTPUT.relative_to(Path.cwd())} anchored on {anchor.isoformat()}")


if __name__ == "__main__":
    main()
