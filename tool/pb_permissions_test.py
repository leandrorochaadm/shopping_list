# /// script
# requires-python = ">=3.12"
# dependencies = ["httpx>=0.27"]
# ///
"""Permission test and Phase 0 proofs for the PocketBase backend.

Usage (from anywhere): `uv run tool/pb_permissions_test.py [--pb-bin PATH] [--verbose]`

Starts a throwaway PocketBase (free port, temporary `pb_data`, the project
migrations), creates users A and B, seeds a full chain of the 13 collections
for each, and checks collection x operation, the `users` collection, the
`purchase_item_totals` view and the proofs 0.1 to 0.5. Only talks to 127.0.0.1.

Exit codes:
  0  everything passed
  3  PocketBase binary missing (run `make setup`)
  4  the throwaway server did not start
  10 proof 0.1: batch does not chain records created in it, or is not atomic
  11 proof 0.2: rate limit hit a logged-in user in normal use
  12 proof 0.3: optional relation rule
  13 proof 0.4: duplicated id does not return validation_not_unique
  14 proof 0.5: realtime delivery or reconnection
  20 permission matrix, `users` or view failure
When several families fail, the lowest code is returned.
"""

from __future__ import annotations

import argparse
import json
import queue
import random
import secrets
import socket
import string
import subprocess
import tempfile
import threading
import time
from collections.abc import Callable
from dataclasses import dataclass, field
from enum import IntEnum
from pathlib import Path
from typing import Any

import httpx

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_PB_BIN = ROOT / "pocketbase" / "pocketbase"  # PB_BIN of the Makefile
MIGRATIONS_DIR = ROOT / "pocketbase" / "pb_migrations"
GUEST_RETRY_WAIT_S = 3.5  # the `*:auth` rule is 2 requests per 3 s
HEALTH_TIMEOUT_S = 15.0
REFUSED = {400, 403, 404}
DIR_PREFIX = "shop-pb-perm-"


class ExitCode(IntEnum):
    OK = 0
    BINARY_MISSING = 3
    SERVER_FAILED = 4
    BATCH_CHAIN = 10
    RATE_LIMIT = 11
    OPTIONAL_RELATION = 12
    DUPLICATE_ID = 13
    REALTIME = 14
    PERMISSIONS = 20


@dataclass(frozen=True)
class Relation:
    field: str
    target: str
    required: bool


@dataclass(frozen=True)
class CollectionSpec:
    name: str
    relations: tuple[Relation, ...]
    update_body: dict[str, object]


def _spec(name: str, update_body: dict[str, object], *relations: tuple[str, str, bool]) -> CollectionSpec:
    return CollectionSpec(name, tuple(Relation(*r) for r in relations), update_body)


# The 13 collections, in creation order (1792800000_schema.js).
COLLECTIONS: tuple[CollectionSpec, ...] = (
    _spec("category", {"name": "category 2"}),
    _spec("brand", {"name": "brand 2"}),
    _spec("store", {"name": "store 2"}),
    _spec("product_type", {"name": "type 2"}, ("category_id", "category", True)),
    _spec(
        "product_registration",
        {"description": "integral"},
        ("product_type_id", "product_type", True),
        ("brand_id", "brand", False),
    ),
    _spec("product", {"active": False}, ("product_registration_id", "product_registration", True)),
    _spec(
        "product_barcode",
        {"code": "07891234567896"},
        ("product_id", "product", True),
        ("store_id", "store", False),
    ),
    _spec(
        "shopping_list_item",
        {"picked": True},
        ("product_type_id", "product_type", True),
        ("preferred_registration_id", "product_registration", False),
    ),
    _spec("purchase", {"registered_by": "Bia"}, ("store_id", "store", True)),
    _spec(
        "purchase_item",
        {"total_paid": 2600},
        ("purchase_id", "purchase", True),
        ("product_id", "product", True),
    ),
    _spec(
        "list_write_off",
        {"cleared_not_found": True},
        ("purchase_item_id", "purchase_item", True),
        ("shopping_list_item_id", "shopping_list_item", True),
    ),
    _spec("spending_cap", {"amount": 160000}),
    _spec("spending_cap_alert", {"warned_80_at": "2026-10-20 12:00:00.000Z"}),
)
SPEC_BY_NAME = {spec.name: spec for spec in COLLECTIONS}
OPTIONAL_RELATIONS = ("brand_id", "store_id", "preferred_registration_id")


def calendar_day(text: str) -> str:
    return f"{text} 00:00:00.000Z"


def _extra(name: str, variant: int) -> dict[str, object]:
    """Fields besides `user` and the relations; `variant` keeps unique keys apart."""
    day = calendar_day(f"{2026 + variant}-10-01")
    table: dict[str, dict[str, object]] = {
        "category": {"name": f"category {variant}", "active": True},
        "brand": {"name": f"brand {variant}", "active": True},
        "store": {"name": f"store {variant}", "active": True},
        "product_type": {"name": f"type {variant}", "base_unit": "gram", "active": True},
        "product_registration": {"description": "", "selling_mode": "by_piece", "active": True},
        "product": {
            "piece_count": 1,
            "piece_size": 1000,
            "piece_size_unit": "gram",
            "total_content": 1000,
            "active": True,
        },
        "product_barcode": {"code": "07891234567895"},
        "shopping_list_item": {
            "quantity": 1000,
            "entered_on": calendar_day("2026-10-01"),
            "picked": False,
            "not_found": False,
        },
        "purchase": {
            "purchase_date": calendar_day("2026-10-02"),
            "registered_by": "Ana",
            "created_at": "2026-10-02 12:00:00.000Z",
        },
        "purchase_item": {"quantity": 1, "quantity_in_base_unit": 1000, "total_paid": 2599},
        "list_write_off": {"quantity_written_off": 1000, "cleared_not_found": False},
        "spending_cap": {"amount": 150000, "effective_from": day},
        "spending_cap_alert": {"month": day, "warned_80_at": "", "warned_100_at": ""},
    }
    return table[name]


@dataclass(frozen=True)
class Session:
    user_id: str
    token: str


@dataclass
class Failures:
    by_code: dict[ExitCode, list[str]] = field(default_factory=dict)
    observed: dict[str, int] = field(default_factory=dict)

    def add(self, code: ExitCode, message: str) -> None:
        self.by_code.setdefault(code, []).append(message)
        print(f"FALHA [{code.value}] {message}")

    def observe(self, label: str, status: int) -> None:
        self.observed.setdefault(label, status)

    def first_code(self) -> ExitCode:
        return min(self.by_code, default=ExitCode.OK)


class ServerFailed(Exception):
    pass


def free_port() -> int:
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


def new_record_id() -> str:
    return "".join(random.choices(string.ascii_lowercase + string.digits, k=15))


class PbServer:
    """Throwaway PocketBase: migrate up, superuser upsert, serve, health, stop."""

    def __init__(self, pb_bin: Path, data_dir: Path, port: int) -> None:
        self.pb_bin = pb_bin
        self.data_dir = data_dir
        self.port = port
        self.superuser_email = "root@perm.test"
        self.superuser_password = secrets.token_urlsafe(16)
        self._process: subprocess.Popen[bytes] | None = None
        self._log = None

    @property
    def base_url(self) -> str:
        return f"http://127.0.0.1:{self.port}"

    def _run(self, *args: str) -> None:
        result = subprocess.run([str(self.pb_bin), *args], capture_output=True, text=True)
        if result.returncode != 0:
            raise ServerFailed(result.stderr or result.stdout)

    def __enter__(self) -> PbServer:
        data = str(self.data_dir)
        migrations = f"--migrationsDir={MIGRATIONS_DIR}"
        try:
            self._run("migrate", "up", f"--dir={data}", migrations)
            self._run(
                "superuser", "upsert", self.superuser_email, self.superuser_password, f"--dir={data}"
            )
            self._log = (self.data_dir.parent / "serve.log").open("wb")
            self._process = subprocess.Popen(
                [
                    str(self.pb_bin),
                    "serve",
                    f"--http=127.0.0.1:{self.port}",
                    f"--dir={data}",
                    migrations,
                ],
                stdout=self._log,
                stderr=subprocess.STDOUT,
            )
            deadline = time.monotonic() + HEALTH_TIMEOUT_S
            while time.monotonic() < deadline:
                if self._process.poll() is not None:
                    break
                try:
                    if httpx.get(f"{self.base_url}/api/health", timeout=1).status_code == 200:
                        return self
                except httpx.HTTPError:
                    pass
                time.sleep(0.2)
            raise ServerFailed(self._read_log() or "sem resposta em /api/health")
        except BaseException:
            self.__exit__(None, None, None)
            raise

    def _read_log(self) -> str:
        if self._log is None:
            return ""
        self._log.flush()
        return (self.data_dir.parent / "serve.log").read_text(errors="replace")

    def __exit__(self, *_: object) -> None:
        process = self._process
        if process is not None and process.poll() is None:
            process.terminate()
            try:
                process.wait(5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
        if self._log is not None:
            self._log.close()


class Api:
    """Thin httpx client; never raises on status."""

    def __init__(self, base_url: str, verbose: bool = False) -> None:
        self.base_url = base_url
        self.verbose = verbose
        self.client = httpx.Client(base_url=base_url, timeout=30)

    def request(
        self,
        method: str,
        path: str,
        token: str | None = None,
        body: dict[str, Any] | None = None,
        params: dict[str, Any] | None = None,
    ) -> httpx.Response:
        headers = {"Authorization": token} if token else {}
        retryable = token is None or "/auth-" in path
        for attempt in range(2):
            response = self.client.request(method, path, headers=headers, json=body, params=params)
            if self.verbose:
                print(f"  {method} {path} -> {response.status_code}")
            if response.status_code == 429 and retryable and attempt == 0:
                time.sleep(GUEST_RETRY_WAIT_S)
                continue
            break
        return response

    def auth(self, collection: str, email: str, password: str) -> Session:
        response = self.request(
            "POST",
            f"/api/collections/{collection}/auth-with-password",
            body={"identity": email, "password": password},
        )
        if response.status_code != 200:
            raise ServerFailed(f"login de {email} falhou: {response.status_code} {response.text}")
        data = response.json()
        return Session(data["record"]["id"], data["token"])


class RealtimeStream:
    """SSE stream read in a thread; events land in a queue as (event, data)."""

    def __init__(self, base_url: str) -> None:
        self._events: queue.Queue[tuple[str, dict[str, Any]]] = queue.Queue()
        self._response: httpx.Response | None = None
        self._base_url = base_url
        self._client = httpx.Client(base_url=base_url, timeout=httpx.Timeout(10, read=None))
        self._thread = threading.Thread(target=self._run, daemon=True)
        self._thread.start()

    def _run(self) -> None:
        try:
            with self._client.stream(
                "GET", "/api/realtime", headers={"Accept": "text/event-stream"}
            ) as response:
                self._response = response
                event: str | None = None
                data: list[str] = []
                for line in response.iter_lines():
                    if line == "":
                        if data:
                            payload = json.loads("\n".join(data))
                            self._events.put((event or "message", payload))
                        event, data = None, []
                    elif line.startswith("event:"):
                        event = line[6:].strip()
                    elif line.startswith("data:"):
                        data.append(line[5:].strip())
        except Exception:  # closed by close() or by the server going away
            pass

    def client_id(self, timeout: float) -> str:
        deadline = time.monotonic() + timeout
        while (remaining := deadline - time.monotonic()) > 0:
            item = self.next_event(remaining)
            if item is not None and item[0] == "PB_CONNECT":
                return str(item[1]["clientId"])
        raise TimeoutError("PB_CONNECT não chegou")

    def subscribe(self, api: Api, token: str | None, topics: list[str]) -> int:
        client_id = self.client_id(5) if not hasattr(self, "_client_id") else self._client_id
        self._client_id = client_id
        response = api.request(
            "POST",
            "/api/realtime",
            token=token,
            body={"clientId": client_id, "subscriptions": topics},
        )
        return response.status_code

    def next_event(self, timeout: float) -> tuple[str, dict[str, Any]] | None:
        try:
            return self._events.get(timeout=timeout)
        except queue.Empty:
            return None

    def close(self) -> None:
        try:
            if self._response is not None:
                self._response.close()
            self._client.close()
        except Exception:
            pass


# ---------------------------------------------------------------- helpers


def su_get(api: Api, su: str, collection: str, record_id: str) -> dict[str, Any] | None:
    response = api.request("GET", f"/api/collections/{collection}/records/{record_id}", token=su)
    return response.json() if response.status_code == 200 else None


def refused(response: httpx.Response) -> bool:
    return response.status_code in REFUSED


def list_ids(response: httpx.Response) -> set[str] | None:
    """Ids of a list response; 403 counts as empty; anything else is None."""
    if response.status_code == 403:
        return set()
    if response.status_code != 200:
        return None
    return {item["id"] for item in response.json().get("items", [])}


def body_for(
    spec: CollectionSpec,
    owner: Session,
    ids: dict[str, str],
    variant: int = 0,
    overrides: dict[str, object] | None = None,
) -> dict[str, object]:
    body: dict[str, object] = {"user": owner.user_id, **_extra(spec.name, variant)}
    for relation in spec.relations:
        body[relation.field] = ids[relation.target]
    body.update(overrides or {})
    return body


def seed_chain(api: Api, owner: Session, variant: int = 0, ids: dict[str, str] | None = None) -> dict[str, str]:
    """One valid record per collection, relations pointing to the owner's own records."""
    own = dict(ids or {})
    created: dict[str, str] = {}
    for spec in COLLECTIONS:
        body = body_for(spec, owner, own if ids else created, variant)
        if variant == 0 and spec.name in ("product_registration", "shopping_list_item"):
            pass  # optional relations are already filled by body_for
        response = api.request("POST", f"/api/collections/{spec.name}/records", owner.token, body)
        if response.status_code != 200:
            raise ServerFailed(f"seed de {spec.name} falhou: {response.status_code} {response.text}")
        created[spec.name] = response.json()["id"]
    return created


def batch_sub_error(response: httpx.Response) -> tuple[int, dict[str, Any]] | None:
    """(index, {status, data}) of the first failed sub-request, or None if the shape is unknown."""
    try:
        requests = response.json()["data"]["requests"]
    except (KeyError, ValueError, TypeError):
        return None
    items = (
        sorted(requests.items(), key=lambda kv: int(kv[0]))
        if isinstance(requests, dict)
        else list(enumerate(requests))
    )
    for key, entry in items:
        if isinstance(entry, dict) and isinstance(entry.get("response"), dict):
            inner = entry["response"]
            return int(key), {"status": inner.get("status"), "data": inner.get("data", {})}
    return None


def batch(api: Api, token: str | None, requests: list[dict[str, Any]]) -> httpx.Response:
    return api.request("POST", "/api/batch", token, {"requests": requests})


def op_create(collection: str, body: dict[str, object]) -> dict[str, Any]:
    return {"method": "POST", "url": f"/api/collections/{collection}/records", "body": body}


def op_delete(collection: str, record_id: str) -> dict[str, Any]:
    return {"method": "DELETE", "url": f"/api/collections/{collection}/records/{record_id}"}


def has_code(data: Any, code: str) -> bool:
    return isinstance(data, dict) and any(
        isinstance(v, dict) and v.get("code") == code for v in data.values()
    )


# ---------------------------------------------------------------- matrix


def check_matrix(
    api: Api,
    superuser: str,
    a: Session,
    b: Session,
    ids_a: dict[str, str],
    ids_b: dict[str, str],
    failures: Failures,
    spares_a: dict[str, str],
    spares_b: dict[str, str],
) -> None:
    def fail(message: str) -> None:
        failures.add(ExitCode.PERMISSIONS, message)

    first = COLLECTIONS[0].name

    def attack(spec: CollectionSpec, token: str | None, who: str) -> None:
        name = spec.name
        base = f"/api/collections/{name}/records"
        ida = ids_a[name]

        def msg(op: str) -> str:
            return f"sem login: {name} {op}" if token is None else f"B acessou {name} de A ({op})"

        tag = "sem login" if token is None else "B"
        listing = api.request("GET", base, token)
        if name == first:
            failures.observe(f"{tag}: list", listing.status_code)
        ids = list_ids(listing)
        if ids is None or (token is None and ids) or ida in (ids or set()):
            fail(msg("list"))

        view = api.request("GET", f"{base}/{ida}", token)
        if name == first:
            failures.observe(f"{tag}: view de outro dono", view.status_code)
        if not refused(view):
            fail(msg("view"))

        update = api.request("PATCH", f"{base}/{ida}", token, spec.update_body)
        if name == first:
            failures.observe(f"{tag}: update de outro dono", update.status_code)
        record = su_get(api, superuser, name, ida) or {}
        key, value = next(iter(spec.update_body.items()))
        if not refused(update) or record.get(key) == value:
            fail(msg("update"))

        delete = api.request("DELETE", f"{base}/{ida}", token)
        if name == first:
            failures.observe(f"{tag}: delete de outro dono", delete.status_code)
        if not refused(delete) or su_get(api, superuser, name, ida) is None:
            fail(msg("delete"))

        new_id = new_record_id()
        create_body = body_for(spec, a, ids_a, overrides={"id": new_id})
        create = api.request("POST", base, token, create_body)
        if name == first:
            failures.observe(f"{tag}: create com user de A", create.status_code)
        if not refused(create) or su_get(api, superuser, name, new_id) is not None:
            fail(msg("create") if token is None else f"B criou {name} com user de A")

    for spec in COLLECTIONS:
        name = spec.name
        base = f"/api/collections/{name}/records"
        ida, idb = ids_a[name], ids_b[name]
        attack(spec, None, "guest")
        attack(spec, b.token, "B")

        # A, the owner, works normally.
        ids = list_ids(api.request("GET", base, a.token))
        if ids is None or ida not in ids or idb in ids:
            fail(f"A não conseguiu list em {name}")
        if api.request("GET", f"{base}/{ida}", a.token).status_code != 200:
            fail(f"A não conseguiu view em {name}")
        key, value = next(iter(spec.update_body.items()))
        update = api.request("PATCH", f"{base}/{ida}", a.token, spec.update_body)
        record = su_get(api, superuser, name, ida) or {}
        if update.status_code != 200 or record.get(key) != value:
            fail(f"A não conseguiu update em {name}")
        for owner_id, label in ((b.user_id, "para B"), (a.user_id, "para o mesmo dono")):
            swap = api.request("PATCH", f"{base}/{ida}", a.token, {"user": owner_id})
            now = su_get(api, superuser, name, ida) or {}
            if not refused(swap) or now.get("user") != a.user_id:
                fail(f"update trocou o dono de {name} ({label})")
        spare = spares_a[name]
        gone = api.request("DELETE", f"{base}/{spare}", a.token)
        if gone.status_code != 204 or su_get(api, superuser, name, spare) is not None:
            fail(f"A não conseguiu delete em {name}")

        # Relations: B cannot point to A's records; pairs with own records pass.
        for relation in spec.relations:
            field_name, target = relation.field, relation.target
            where = f"{name}.{field_name}"
            new_id = new_record_id()
            bad = api.request(
                "POST", base, b.token,
                body_for(spec, b, ids_b, overrides={"id": new_id, field_name: ids_a[target]}),
            )
            if not refused(bad) or su_get(api, superuser, name, new_id) is not None:
                fail(f"{where} aceitou registro de A (create)")
            good_id = new_record_id()
            good = api.request(
                "POST", base, b.token, body_for(spec, b, ids_b, variant=2, overrides={"id": good_id})
            )
            if good.status_code != 200:
                fail(f"B não conseguiu create em {name} com relação própria ({where})")
            before = (su_get(api, superuser, name, idb) or {}).get(field_name)
            bad_up = api.request("PATCH", f"{base}/{idb}", b.token, {field_name: ids_a[target]})
            after = (su_get(api, superuser, name, idb) or {}).get(field_name)
            if not refused(bad_up) or after != before:
                fail(f"{where} aceitou registro de A (update)")
            good_up = api.request("PATCH", f"{base}/{idb}", b.token, {field_name: spares_b[target]})
            after = (su_get(api, superuser, name, idb) or {}).get(field_name)
            if good_up.status_code != 200 or after != spares_b[target]:
                fail(f"B não conseguiu update em {name} com relação própria ({where})")
        plain = api.request("PATCH", f"{base}/{idb}", b.token, spec.update_body)
        if plain.status_code != 200:
            fail(f"B não conseguiu update em {name} sem mandar a relação")

    # The unique index of cap and alert is per user, not global.
    for name in ("spending_cap", "spending_cap_alert"):
        spec = SPEC_BY_NAME[name]
        if not (ids_a.get(name) and ids_b.get(name)):
            fail(f"único de {name} não é por usuário")
        again = api.request(
            "POST", f"/api/collections/{name}/records", a.token, body_for(spec, a, ids_a)
        )
        data = again.json().get("data", {}) if again.status_code == 400 else {}
        if not has_code(data, "validation_not_unique"):
            fail(f"único de {name} não barrou o mesmo mês do mesmo usuário ({again.status_code})")


def check_users(api: Api, superuser: str, a: Session, b: Session, failures: Failures) -> None:
    def fail(message: str) -> None:
        failures.add(ExitCode.PERMISSIONS, message)

    base = "/api/collections/users/records"
    ids = list_ids(api.request("GET", base, a.token))
    if ids != {a.user_id}:
        fail("users vazou ou aceitou cadastro (list de A)")
    guest = list_ids(api.request("GET", base))
    if guest != set():
        fail("users vazou ou aceitou cadastro (list sem login)")
    if api.request("GET", f"{base}/{b.user_id}", a.token).status_code not in REFUSED:
        fail("users vazou ou aceitou cadastro (view de B por A)")
    patch = api.request("PATCH", f"{base}/{b.user_id}", a.token, {"name": "hacked"})
    delete = api.request("DELETE", f"{base}/{b.user_id}", a.token)
    record_b = su_get(api, superuser, "users", b.user_id)
    if patch.status_code not in REFUSED or delete.status_code not in REFUSED or not record_b or record_b.get("name") == "hacked":
        fail("users vazou ou aceitou cadastro (alterar ou apagar B)")
    new_user = {"email": "c@perm.test", "password": "senha-longa-123", "passwordConfirm": "senha-longa-123"}
    for token in (None, a.token):
        created = api.request("POST", base, token, new_user)
        failures.observe("users: create", created.status_code)
        if created.status_code != 403:
            fail(f"users vazou ou aceitou cadastro (create {created.status_code})")
    found = api.request("GET", base, superuser, params={"filter": 'email = "c@perm.test"'})
    if found.json().get("totalItems", 0) != 0:
        fail("users vazou ou aceitou cadastro (usuário criado)")
    own = api.request("PATCH", f"{base}/{a.user_id}", a.token, {"name": "Ana"})
    if own.status_code != 200:
        fail("A não conseguiu update em users")

    wrong = api.request(
        "POST", "/api/collections/users/auth-with-password",
        body={"identity": "a@perm.test", "password": "senha-errada-xyz"},
    )
    failures.observe("login com senha errada", wrong.status_code)
    refresh = api.request("POST", "/api/collections/users/auth-refresh", token="token.invalido.x")
    failures.observe("auth-refresh com token inválido", refresh.status_code)
    invalid = api.request("GET", "/api/collections/store/records", token="token.invalido.x")
    failures.observe("token inválido em list", invalid.status_code)


def check_totals_view(
    api: Api, a: Session, b: Session, ids_a: dict[str, str], failures: Failures, superuser: str
) -> None:
    def fail() -> None:
        failures.add(ExitCode.PERMISSIONS, "view mostrou linha de outro dono")

    spec = SPEC_BY_NAME["purchase_item"]
    created = api.request(
        "POST", "/api/collections/purchase_item/records", a.token, body_for(spec, a, ids_a, variant=3)
    )
    if created.status_code != 200:
        raise ServerFailed(f"segundo purchase_item falhou: {created.status_code} {created.text}")
    product = ids_a["product"]
    owned = api.request(
        "GET", "/api/collections/purchase_item/records", superuser,
        params={"filter": f'user = "{a.user_id}" && product_id = "{product}"', "perPage": 1},
    ).json()["totalItems"]
    base = "/api/collections/purchase_item_totals/records"
    rows = api.request("GET", base, a.token).json().get("items", [])
    if any(row["user"] != a.user_id for row in rows):
        fail()
    mine = [row for row in rows if row["product_id"] == product]
    if len(mine) != 1 or mine[0]["purchase_count"] != owned or owned < 2:
        failures.add(ExitCode.PERMISSIONS, f"view com contagem errada ({mine}, esperado {owned})")
    row_id = f"{a.user_id}_{product}"
    if any(row["user"] == a.user_id for row in api.request("GET", base, b.token).json().get("items", [])):
        fail()
    if api.request("GET", base).json().get("items"):
        fail()
    if api.request("GET", f"{base}/{row_id}", b.token).status_code != 404:
        fail()


# ---------------------------------------------------------------- proofs


def prove_batch_chain(api: Api, a: Session, b: Session, ids_a: dict[str, str], ids_b: dict[str, str], su: str, failures: Failures) -> None:
    code = ExitCode.BATCH_CHAIN
    message = "Prova 0.1 falhou: o lote não encadeia registros criados nele, ou não é atômico."
    ok = True

    def exists(collection: str, record_id: str) -> bool:
        return su_get(api, su, collection, record_id) is not None

    purchase_id, item_id = new_record_id(), new_record_id()
    purchase = SPEC_BY_NAME["purchase"]
    item = SPEC_BY_NAME["purchase_item"]
    write_off = SPEC_BY_NAME["list_write_off"]
    chain = [
        op_create("purchase", body_for(purchase, a, ids_a, overrides={"id": purchase_id})),
        op_create(
            "purchase_item",
            body_for(item, a, ids_a, overrides={"id": item_id, "purchase_id": purchase_id}),
        ),
        op_create(
            "list_write_off",
            body_for(write_off, a, ids_a, overrides={"purchase_item_id": item_id}),
        ),
    ]
    response = batch(api, a.token, chain)
    if response.status_code != 200 or not (exists("purchase", purchase_id) and exists("purchase_item", item_id)):
        ok = False
        print(f"  lote encadeado: {response.status_code} {response.text}")

    other = new_record_id()
    atomic = batch(api, a.token, [
        op_create("purchase", body_for(purchase, a, ids_a, overrides={"id": other})),
        op_create("purchase_item", body_for(item, a, ids_a, overrides={
            "purchase_id": other, "product_id": ids_b["product"]})),
    ])
    if atomic.status_code == 200 or exists("purchase", other):
        ok = False
        print(f"  lote atômico: {atomic.status_code} {atomic.text}")

    stolen = new_record_id()
    theft = batch(api, b.token, [
        op_create("purchase_item", body_for(item, b, ids_b, overrides={"id": stolen, "purchase_id": purchase_id})),
    ])
    if theft.status_code == 200 or exists("purchase_item", stolen):
        ok = False
        print(f"  lote de B com compra de A: {theft.status_code} {theft.text}")

    write_off_id = (api.request(
        "GET", "/api/collections/list_write_off/records", su,
        params={"filter": f'purchase_item_id = "{item_id}"'},
    ).json().get("items") or [{}])[0].get("id", "")
    removal = batch(api, a.token, [
        op_delete("list_write_off", write_off_id),
        op_delete("purchase_item", item_id),
        op_delete("purchase", purchase_id),
    ])
    if removal.status_code != 200 or exists("purchase", purchase_id) or exists("purchase_item", item_id):
        ok = False
        print(f"  lote de exclusão: {removal.status_code} {removal.text}")
    if not ok:
        failures.add(code, message)


def prove_rate_limit(api: Api, a: Session, ids_a: dict[str, str], failures: Failures) -> None:
    code = ExitCode.RATE_LIMIT
    message = "Prova 0.2 falhou: o usuário comum levou limite de pedidos em uso normal."
    purchase = SPEC_BY_NAME["purchase"]
    item = SPEC_BY_NAME["purchase_item"]

    def small_batch(count: int) -> list[dict[str, Any]]:
        purchase_id = new_record_id()
        ops = [op_create("purchase", body_for(purchase, a, ids_a, overrides={"id": purchase_id}))]
        for _ in range(count - 1):
            ops.append(op_create("purchase_item", body_for(item, a, ids_a, overrides={"purchase_id": purchase_id})))
        return ops

    big = batch(api, a.token, small_batch(60))
    if big.status_code != 200:
        failures.add(code, f"{message} (lote de 60: {big.status_code} {big.text[:200]})")
        return
    started = time.monotonic()
    statuses = [batch(api, a.token, small_batch(3)).status_code for _ in range(4)]
    elapsed = time.monotonic() - started
    if any(s != 200 for s in statuses):
        failures.add(code, f"{message} (4 lotes: {statuses})")
    elif elapsed >= 1:
        failures.add(code, f"{message} A prova não vale: 4 lotes levaram {elapsed:.2f} s (>= 1 s).")
    reads = [
        api.request("GET", "/api/collections/purchase/records", a.token, params={"perPage": 1}).status_code
        for _ in range(40)
    ]
    if any(s != 200 for s in reads):
        failures.add(code, f"{message} (40 leituras: {sorted(set(reads))})")


def prove_optional_relation(api: Api, a: Session, b: Session, ids_a: dict[str, str], ids_b: dict[str, str], failures: Failures) -> None:
    code = ExitCode.OPTIONAL_RELATION
    message = "Prova 0.3 falhou: relação opcional vazia foi recusada, ou aceitou registro de outro dono."
    cases = (
        ("product_registration", "brand_id", "brand"),
        ("product_barcode", "store_id", "store"),
        ("shopping_list_item", "preferred_registration_id", "product_registration"),
    )
    for collection, field_name, target in cases:
        spec = SPEC_BY_NAME[collection]
        base = f"/api/collections/{collection}/records"
        empty = api.request("POST", base, a.token, body_for(spec, a, ids_a, overrides={field_name: ""}))
        if empty.status_code != 200 or empty.json().get(field_name) != "":
            failures.add(code, f"{message} ({collection}.{field_name} vazio: {empty.status_code})")
        new_id = new_record_id()
        stolen = api.request(
            "POST", base, b.token,
            body_for(spec, b, ids_b, overrides={"id": new_id, field_name: ids_a[target]}),
        )
        if not refused(stolen) or su_get(api, su_token(api), collection, new_id):
            failures.add(code, f"{message} ({collection}.{field_name} create com registro de A)")
        mine = ids_b[collection]
        steal_up = api.request("PATCH", f"{base}/{mine}", b.token, {field_name: ids_a[target]})
        if not refused(steal_up):
            failures.add(code, f"{message} ({collection}.{field_name} update com registro de A)")
        clear = api.request("PATCH", f"{base}/{mine}", b.token, {field_name: ""})
        if clear.status_code != 200 or clear.json().get(field_name) != "":
            failures.add(code, f"{message} ({collection}.{field_name} limpar: {clear.status_code})")
        plain = api.request("PATCH", f"{base}/{mine}", b.token, spec.update_body)
        if plain.status_code != 200:
            failures.add(code, f"{message} ({collection} sem mandar a opcional: {plain.status_code})")


_SUPERUSER_TOKEN: dict[str, str] = {}


def su_token(api: Api) -> str:
    return _SUPERUSER_TOKEN[api.base_url]


def prove_duplicate_id(api: Api, a: Session, ids_a: dict[str, str], su: str, failures: Failures, verbose: bool) -> None:
    code = ExitCode.DUPLICATE_ID
    message = "Prova 0.4 falhou: id repetido não devolveu validation_not_unique (fora ou dentro do lote)."
    spec = SPEC_BY_NAME["category"]
    base = "/api/collections/category/records"
    dup_id, other = new_record_id(), new_record_id()
    first = api.request("POST", base, a.token, body_for(spec, a, ids_a, overrides={"id": dup_id}))
    again = api.request("POST", base, a.token, body_for(spec, a, ids_a, overrides={"id": dup_id}))
    if first.status_code != 200 or again.status_code != 400 or not has_code(again.json().get("data"), "validation_not_unique"):
        failures.add(code, f"{message} (fora: {again.status_code} {again.text})")
    inside = batch(api, a.token, [
        op_create("category", body_for(spec, a, ids_a, overrides={"id": other})),
        op_create("category", body_for(spec, a, ids_a, overrides={"id": dup_id})),
    ])
    if verbose:
        print(f"  erro de lote cru: {inside.text}")
    sub = batch_sub_error(inside)
    if sub is None:
        failures.add(code, f"{message} formato de lote desconhecido: {inside.text}")
    else:
        index, response = sub
        failures.observe("id repetido dentro do lote", inside.status_code)
        if inside.status_code == 200 or index != 1 or not has_code(response["data"], "validation_not_unique"):
            failures.add(code, f"{message} (dentro: {inside.status_code} {inside.text})")
    if su_get(api, su, "category", other) is not None:
        failures.add(code, f"{message} (o lote gravou {other})")
    failures.observe("id repetido fora do lote", again.status_code)


def prove_realtime(api: Api, a: Session, b: Session, ids_a: dict[str, str], ids_b: dict[str, str], failures: Failures) -> None:
    code = ExitCode.REALTIME
    message = "Prova 0.5 falhou: o tempo real não entregou ao dono, entregou a outro usuário, ou não mandou PB_CONNECT na reconexão."
    spec = SPEC_BY_NAME["shopping_list_item"]
    base = "/api/collections/shopping_list_item/records"
    topic = "shopping_list_item"
    streams: list[RealtimeStream] = []

    def open_stream() -> RealtimeStream:
        stream = RealtimeStream(api.base_url)
        streams.append(stream)
        return stream

    def drain(stream: RealtimeStream, wanted: int, timeout: float) -> list[tuple[str, dict[str, Any]]]:
        got: list[tuple[str, dict[str, Any]]] = []
        deadline = time.monotonic() + timeout
        while len(got) < wanted and (remaining := deadline - time.monotonic()) > 0:
            item = stream.next_event(remaining)
            if item is not None and item[0] != "PB_CONNECT":
                got.append(item)
        return got

    try:
        stream_a, stream_b, stream_guest = open_stream(), open_stream(), open_stream()
        statuses = [
            stream_a.subscribe(api, a.token, [topic]),
            stream_b.subscribe(api, b.token, [topic, f"{topic}/{ids_a[topic]}"]),
            stream_guest.subscribe(api, None, [topic]),
        ]
        if any(s != 204 for s in statuses):
            failures.add(code, f"{message} (assinatura: {statuses})")
            return
        created = api.request("POST", base, a.token, body_for(spec, a, ids_a))
        item_id = created.json()["id"]
        api.request("PATCH", f"{base}/{item_id}", a.token, {"picked": True})
        events = drain(stream_a, 2, 5)
        actions = [(e[1].get("action"), e[1].get("record", {}).get("id")) for e in events]
        if actions != [("create", item_id), ("update", item_id)]:
            failures.add(code, f"{message} (dono recebeu {actions})")
        created_b = api.request("POST", base, b.token, body_for(spec, b, ids_b))
        b_id = created_b.json()["id"]
        b_events = drain(stream_b, 5, 5)
        b_ids = {e[1].get("record", {}).get("id") for e in b_events}
        if b_ids != {b_id}:
            failures.add(code, f"{message} (B recebeu {b_ids})")
        guest_events = drain(stream_guest, 1, 1)
        if guest_events:
            failures.add(code, f"{message} (visitante recebeu {guest_events})")

        old_client = stream_a.client_id(0.1) if False else stream_a._client_id
        stream_a.close()
        again = open_stream()
        new_client = again.client_id(5)
        if new_client == old_client:
            failures.add(code, f"{message} (clientId igual após reconectar)")
        again._client_id = new_client
        if again.subscribe(api, a.token, [topic]) != 204:
            failures.add(code, f"{message} (reassinar)")
            return
        api.request("POST", base, a.token, body_for(spec, a, ids_a))
        if not drain(again, 1, 5):
            failures.add(code, f"{message} (sem evento após reconectar)")
    finally:
        for stream in streams:
            stream.close()


# ---------------------------------------------------------------- main

EXPECTED = {
    "sem login: list": 200,
    "sem login: view de outro dono": 404,
    "sem login: update de outro dono": 404,
    "sem login: delete de outro dono": 404,
    "sem login: create com user de A": 400,
    "B: list": 200,
    "B: view de outro dono": 404,
    "B: update de outro dono": 404,
    "B: delete de outro dono": 404,
    "B: create com user de A": 400,
    "users: create": 403,
    "login com senha errada": 400,
    "auth-refresh com token inválido": 401,
    "token inválido em list": 200,
    "id repetido fora do lote": 400,
    "id repetido dentro do lote": 400,
}


def print_summary(failures: Failures) -> None:
    print("\ncaminho -> status observado (esperado)")
    for label, expected in EXPECTED.items():
        observed = failures.observed.get(label)
        line = f"  {label}: {observed} (esperado {expected})"
        print(line if observed == expected else f"{line}\n    observação: diferente do passo 3.3")
    for code in sorted(failures.by_code):
        print(f"\n{code.name} ({code.value}):")
        for message in failures.by_code[code]:
            print(f"  - {message}")
    if not failures.by_code:
        print("\nTudo certo: permissões e provas 0.1 a 0.5.")


def run_checks(server: PbServer, verbose: bool, failures: Failures) -> None:
    api = Api(server.base_url, verbose)
    su = api.auth("_superusers", server.superuser_email, server.superuser_password).token
    _SUPERUSER_TOKEN[server.base_url] = su
    sessions: list[Session] = []
    for email in ("a@perm.test", "b@perm.test"):
        password = secrets.token_urlsafe(9)
        created = api.request(
            "POST", "/api/collections/users/records", su,
            {"email": email, "password": password, "passwordConfirm": password, "verified": True, "name": email[0]},
        )
        if created.status_code != 200:
            raise ServerFailed(f"criar {email} falhou: {created.status_code} {created.text}")
        sessions.append(api.auth("users", email, password))
    a, b = sessions

    ids_a, ids_b = seed_chain(api, a), seed_chain(api, b)
    spares_a, spares_b = seed_chain(api, a, 1, ids_a), seed_chain(api, b, 1, ids_b)

    def guarded(code: ExitCode, label: str, fn: Callable[[], None]) -> None:
        try:
            fn()
        except Exception as error:  # a broken family must not hide the others
            failures.add(code, f"{label} lançou {type(error).__name__}: {error}")

    guarded(ExitCode.PERMISSIONS, "matriz", lambda: check_matrix(api, su, a, b, ids_a, ids_b, failures, spares_a, spares_b))
    guarded(ExitCode.PERMISSIONS, "users", lambda: check_users(api, su, a, b, failures))
    guarded(ExitCode.PERMISSIONS, "view", lambda: check_totals_view(api, a, b, ids_a, failures, su))
    guarded(ExitCode.BATCH_CHAIN, "prova 0.1", lambda: prove_batch_chain(api, a, b, ids_a, ids_b, su, failures))
    guarded(ExitCode.RATE_LIMIT, "prova 0.2", lambda: prove_rate_limit(api, a, ids_a, failures))
    guarded(ExitCode.OPTIONAL_RELATION, "prova 0.3", lambda: prove_optional_relation(api, a, b, ids_a, ids_b, failures))
    guarded(ExitCode.DUPLICATE_ID, "prova 0.4", lambda: prove_duplicate_id(api, a, ids_a, su, failures, verbose))
    guarded(ExitCode.REALTIME, "prova 0.5", lambda: prove_realtime(api, a, b, ids_a, ids_b, failures))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="PocketBase permission test and Phase 0 proofs")
    parser.add_argument("--pb-bin", type=Path, default=DEFAULT_PB_BIN)
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args(argv)

    import os

    if not (args.pb_bin.is_file() and os.access(args.pb_bin, os.X_OK)):
        print("Rode `make setup` primeiro")
        print(f"Procurei em: {args.pb_bin}")
        return ExitCode.BINARY_MISSING

    failures = Failures()
    with tempfile.TemporaryDirectory(prefix=DIR_PREFIX) as tmp:
        data_dir = Path(tmp) / "pb_data"
        try:
            with PbServer(args.pb_bin, data_dir, free_port()) as server:
                run_checks(server, args.verbose, failures)
        except ServerFailed as error:
            print("O PocketBase de teste não subiu:")
            print(error)
            return ExitCode.SERVER_FAILED
    print_summary(failures)
    return failures.first_code()


if __name__ == "__main__":
    raise SystemExit(main())
