# /// script
# requires-python = ">=3.12"
# dependencies = ["httpx>=0.27", "psycopg[binary]>=3.2"]
# ///
"""Copies the production data from the old Supabase Postgres to PocketBase.

Usage (from anywhere):
  uv run tool/migrate_data.py --rehearsal [--env-file PATH] [--pb-bin PATH] [--verbose]
  uv run tool/migrate_data.py --apply     [--env-file PATH] [--id-map PATH] [--verbose]

`--rehearsal` starts a throwaway PocketBase (temporary folder, project migrations),
copies everything into it, checks the counts and deletes it. `--apply` writes to
the PocketBase at `PB_URL` (loopback only: run it on the VPS).

Credentials come from the environment first, then from `--env-file`
(default `~/.config/shopping-list/migration.env`, must be `chmod 600`):
  LEGACY_DB_URL        connection string of the old Postgres, without password
  PGPASSWORD           password of the old Postgres (read by libpq)
  PB_OWNER_EMAIL       e-mail of the owner account in `users`
  PB_OWNER_PASSWORD    password of the owner account (at least 8 characters)
  PB_URL               --apply only: http://127.0.0.1:<port>
  PB_SUPERUSER_EMAIL   --apply only
  PB_SUPERUSER_PASSWORD --apply only

The old database is opened exactly once per run, read-only, with no retry.

Exit codes:
  0  copied and counts match         9  old database connection or read failed
  2  invalid command line (argparse) 10 data that cannot be copied
  3  credentials missing             11 owner already has data and there is no id map
  4  credentials invalid             12 owner account could not be created
  5  PocketBase binary missing       13 a write batch failed
  6  throwaway server did not start  14 counts do not match
  7  target unreachable              15 owner test login failed
  8  superuser login failed
"""

from __future__ import annotations

import argparse
import json
import os
import random
import re
import secrets
import socket
import stat
import string
import subprocess
import sys
import tempfile
import time
from collections.abc import Callable, Iterator, Mapping, Sequence
from dataclasses import dataclass, field
from datetime import UTC, date, datetime
from decimal import Decimal
from enum import IntEnum, StrEnum
from pathlib import Path
from typing import Any

import httpx


class ExitCode(IntEnum):
    OK = 0
    CREDENTIALS_MISSING = 3
    CREDENTIALS_INVALID = 4
    BINARY_MISSING = 5
    SERVER_FAILED = 6
    TARGET_UNREACHABLE = 7
    TARGET_AUTH_FAILED = 8
    LEGACY_CONNECTION_FAILED = 9
    INVALID_DATA = 10
    TARGET_NOT_EMPTY = 11
    OWNER_FAILED = 12
    WRITE_FAILED = 13
    COUNT_MISMATCH = 14
    OWNER_LOGIN_FAILED = 15


class Mode(StrEnum):
    REHEARSAL = "rehearsal"
    APPLY = "apply"


class BaseUnit(StrEnum):
    GRAM = "gram"
    MILLILITER = "milliliter"
    UNIT = "unit"
    CENTIMETER = "centimeter"


class SellingMode(StrEnum):
    BY_WEIGHT = "by_weight"
    BY_PIECE = "by_piece"


LEGACY_BASE_UNITS = frozenset({"kilogram", "liter"})

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_PB_BIN = ROOT / "pocketbase" / "pocketbase"
MIGRATIONS_DIR = ROOT / "pocketbase" / "pb_migrations"
DEFAULT_ENV_FILE = Path.home() / ".config" / "shopping-list" / "migration.env"
DEFAULT_ID_MAP = Path.home() / ".config" / "shopping-list" / "id-map.json"

BATCH_SIZE = 50
MIN_PASSWORD_LENGTH = 8
LEGACY_CONNECT_TIMEOUT_S = 15
HEALTH_TIMEOUT_S = 15
HTTP_TIMEOUT_S = 30
PAGE_SIZE = 500
ID_LENGTH = 15
ID_ALPHABET = string.ascii_lowercase + string.digits
OWNER_COLLECTION = "users"
SUPERUSER_COLLECTION = "_superusers"
REHEARSAL_SUPERUSER_EMAIL = "rehearsal@migrate.test"

OWNER_EMAIL_PATTERN = re.compile(r"^[^@\s\"']+@[^@\s\"']+\.[^@\s\"']+$")
LOOPBACK_URL_PATTERN = re.compile(r"^http://(127\.0\.0\.1|localhost):\d+/?$")

_COMMON_VARS = ("LEGACY_DB_URL", "PGPASSWORD", "PB_OWNER_EMAIL", "PB_OWNER_PASSWORD")
REQUIRED_VARS: Mapping[Mode, tuple[str, ...]] = {
    Mode.REHEARSAL: _COMMON_VARS,
    Mode.APPLY: (*_COMMON_VARS, "PB_URL", "PB_SUPERUSER_EMAIL", "PB_SUPERUSER_PASSWORD"),
}


@dataclass(frozen=True)
class Relation:
    field: str
    target: str
    required: bool


@dataclass(frozen=True)
class TableSpec:
    name: str
    columns: tuple[str, ...]
    relations: tuple[Relation, ...] = ()
    calendar_days: tuple[str, ...] = ()
    instants: tuple[str, ...] = ()
    zero_when_null: tuple[str, ...] = ()
    empty_when_null: tuple[str, ...] = ()


TABLES: tuple[TableSpec, ...] = (
    TableSpec("category", ("name", "active")),
    TableSpec("brand", ("name", "active")),
    TableSpec("store", ("name", "active")),
    TableSpec(
        "product_type",
        ("name", "category_id", "base_unit", "active"),
        relations=(Relation("category_id", "category", True),),
    ),
    TableSpec(
        "product_registration",
        ("product_type_id", "brand_id", "description", "selling_mode", "active"),
        relations=(
            Relation("product_type_id", "product_type", True),
            Relation("brand_id", "brand", False),
        ),
    ),
    TableSpec(
        "product",
        (
            "product_registration_id",
            "piece_count",
            "piece_size",
            "piece_size_unit",
            "total_content",
            "active",
        ),
        relations=(Relation("product_registration_id", "product_registration", True),),
        zero_when_null=("piece_count", "piece_size", "total_content"),
        empty_when_null=("piece_size_unit",),
    ),
    TableSpec(
        "product_barcode",
        ("product_id", "store_id", "code"),
        relations=(Relation("product_id", "product", True), Relation("store_id", "store", False)),
    ),
    TableSpec(
        "shopping_list_item",
        (
            "product_type_id",
            "preferred_registration_id",
            "quantity",
            "entered_on",
            "fulfilled_on",
            "removed_on",
            "picked",
            "not_found",
        ),
        relations=(
            Relation("product_type_id", "product_type", True),
            Relation("preferred_registration_id", "product_registration", False),
        ),
        calendar_days=("entered_on", "fulfilled_on", "removed_on"),
        zero_when_null=("quantity",),
    ),
    TableSpec(
        "purchase",
        ("purchase_date", "store_id", "registered_by", "created_at"),
        relations=(Relation("store_id", "store", True),),
        calendar_days=("purchase_date",),
        instants=("created_at",),
        empty_when_null=("registered_by",),
    ),
    TableSpec(
        "purchase_item",
        ("purchase_id", "product_id", "quantity", "quantity_in_base_unit", "total_paid"),
        relations=(Relation("purchase_id", "purchase", True), Relation("product_id", "product", True)),
    ),
    TableSpec(
        "list_write_off",
        ("purchase_item_id", "shopping_list_item_id", "quantity_written_off", "cleared_not_found"),
        relations=(
            Relation("purchase_item_id", "purchase_item", True),
            Relation("shopping_list_item_id", "shopping_list_item", True),
        ),
    ),
    TableSpec("spending_cap", ("amount", "effective_from"), calendar_days=("effective_from",)),
    TableSpec(
        "spending_cap_alert",
        ("month", "warned_80_at", "warned_100_at"),
        calendar_days=("month",),
        instants=("warned_80_at", "warned_100_at"),
    ),
)


# --- Credentials -----------------------------------------------------------------


class CredentialsError(Exception):
    """User-facing credentials problem; the message never carries a secret value."""

    def __init__(self, code: ExitCode, message: str) -> None:
        super().__init__(message)
        self.code = code


@dataclass(frozen=True)
class Credentials:
    legacy_db_url: str
    pg_password: str
    owner_email: str
    owner_password: str
    pb_url: str | None = None
    superuser_email: str | None = None
    superuser_password: str | None = None


def read_env_file(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "'\"":
            value = value[1:-1]
        values[key.strip()] = value
    return values


def check_target_url(url: str) -> None:
    if not LOOPBACK_URL_PATTERN.match(url):
        raise CredentialsError(
            ExitCode.CREDENTIALS_INVALID,
            "No --apply, PB_URL tem de ser http://127.0.0.1:<porta>: "
            "rode da VPS (o login de superusuário é fechado de fora).",
        )


def load_credentials(mode: Mode, env: Mapping[str, str], env_file: Path) -> Credentials:
    required = REQUIRED_VARS[mode]
    values = {name: env[name] for name in required if env.get(name)}
    missing = [name for name in required if name not in values]
    if missing:
        try:
            info = env_file.stat()
        except OSError:
            info = None
        if info is None:
            raise CredentialsError(
                ExitCode.CREDENTIALS_MISSING,
                f"Arquivo de credenciais não encontrado: {env_file}. "
                "O dono preenche o arquivo (chmod 600) e roda de novo.",
            )
        if stat.S_IMODE(info.st_mode) & 0o077:
            raise CredentialsError(
                ExitCode.CREDENTIALS_INVALID,
                f"O arquivo de credenciais pode ser lido por outros usuários. Rode chmod 600 {env_file}.",
            )
        try:
            from_file = read_env_file(env_file)
        except (OSError, UnicodeDecodeError):
            raise CredentialsError(
                ExitCode.CREDENTIALS_MISSING,
                f"Arquivo de credenciais não encontrado: {env_file}. "
                "O dono preenche o arquivo (chmod 600) e roda de novo.",
            ) from None
        for name in missing:
            if from_file.get(name):
                values[name] = from_file[name]
        missing = [name for name in required if name not in values]
        if missing:
            raise CredentialsError(
                ExitCode.CREDENTIALS_MISSING,
                f"Faltam no arquivo de credenciais: {', '.join(missing)}.",
            )
    if len(values["PB_OWNER_PASSWORD"]) < MIN_PASSWORD_LENGTH:
        raise CredentialsError(
            ExitCode.CREDENTIALS_INVALID,
            f"A senha do dono precisa ter pelo menos {MIN_PASSWORD_LENGTH} caracteres.",
        )
    if not OWNER_EMAIL_PATTERN.match(values["PB_OWNER_EMAIL"]):
        raise CredentialsError(ExitCode.CREDENTIALS_INVALID, "E-mail do dono inválido em PB_OWNER_EMAIL.")
    if mode is Mode.APPLY:
        check_target_url(values["PB_URL"])
    return Credentials(
        legacy_db_url=values["LEGACY_DB_URL"],
        pg_password=values["PGPASSWORD"],
        owner_email=values["PB_OWNER_EMAIL"],
        owner_password=values["PB_OWNER_PASSWORD"],
        pb_url=values.get("PB_URL"),
        superuser_email=values.get("PB_SUPERUSER_EMAIL"),
        superuser_password=values.get("PB_SUPERUSER_PASSWORD"),
    )


# --- Pure helpers ----------------------------------------------------------------


def new_record_id(rng: random.Random | None = None) -> str:
    if rng is not None:
        return "".join(rng.choices(ID_ALPHABET, k=ID_LENGTH))
    return "".join(secrets.choice(ID_ALPHABET) for _ in range(ID_LENGTH))


class IdMap:
    """Legacy uuid -> PocketBase id, per collection; persisted so a rerun reuses the ids."""

    def __init__(self, data: dict[str, dict[str, str]] | None = None) -> None:
        self._data: dict[str, dict[str, str]] = data if data is not None else {}

    @classmethod
    def load(cls, path: Path) -> IdMap:
        if not path.exists():
            return cls()
        return cls(json.loads(path.read_text(encoding="utf-8")))

    def save(self, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        temp = path.with_name(f"{path.name}.tmp")
        fd = os.open(temp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(self._data, handle, indent=1, sort_keys=True)
        os.replace(temp, path)

    def _used(self) -> set[str]:
        return {value for table in self._data.values() for value in table.values()}

    def id_for(
        self, collection: str, legacy_id: str, generate: Callable[[], str] = new_record_id
    ) -> str:
        table = self._data.setdefault(collection, {})
        if legacy_id in table:
            return table[legacy_id]
        used = self._used()
        new_id = generate()
        while new_id in used:
            new_id = generate()
        table[legacy_id] = new_id
        return new_id

    def get(self, collection: str, legacy_id: str) -> str | None:
        return self._data.get(collection, {}).get(legacy_id)


def to_calendar_day(value: date) -> str:
    day = value.date() if isinstance(value, datetime) else value
    return f"{day.isoformat()} 00:00:00.000Z"


def to_instant(value: datetime) -> str:
    if value.tzinfo is None:
        raise ValueError("instant without time zone")
    utc = value.astimezone(UTC)
    return f"{utc:%Y-%m-%d %H:%M:%S}.{utc.microsecond // 1000:03d}Z"


def _text(value: object) -> str:
    return str(value)


def _check_unit(table: str, uuid: str, value: object, problems: list[str]) -> None:
    text = _text(value)
    if text in {unit.value for unit in BaseUnit}:
        return
    if text in LEGACY_BASE_UNITS:
        problems.append(
            f"{table} {uuid}: unidade antiga '{text}'. "
            "A migration de 07/09/2026 não está aplicada na origem."
        )
    else:
        problems.append(f"{table} {uuid}: unidade desconhecida '{text}'.")


def validate_rows(rows: Mapping[str, list[dict[str, object]]]) -> list[str]:
    problems: list[str] = []
    known = {name: {_text(r["id"]) for r in rows.get(name, [])} for name in (s.name for s in TABLES)}
    for spec in TABLES:
        for row in rows.get(spec.name, []):
            uuid = _text(row["id"])
            if spec.name == "product_type":
                _check_unit(spec.name, uuid, row.get("base_unit"), problems)
            if spec.name == "product" and row.get("piece_size_unit") is not None:
                _check_unit(spec.name, uuid, row["piece_size_unit"], problems)
            if spec.name == "product_registration" and _text(row.get("selling_mode")) not in {
                mode.value for mode in SellingMode
            }:
                problems.append(
                    f"{spec.name} {uuid}: modo de venda desconhecido '{_text(row.get('selling_mode'))}'."
                )
            for relation in spec.relations:
                target = row.get(relation.field)
                if target is None:
                    if relation.required:
                        problems.append(f"{spec.name} {uuid}: {relation.field} vazio.")
                elif _text(target) not in known[relation.target]:
                    problems.append(
                        f"{spec.name} {uuid}: {relation.field} aponta para um registro que não foi lido."
                    )
            for column in spec.instants:
                value = row.get(column)
                if value is not None:
                    try:
                        to_instant(value)  # type: ignore[arg-type]
                    except ValueError:
                        problems.append(f"{spec.name} {uuid}: {column} sem fuso horário.")
    return problems


def _plain_number(value: object) -> object:
    if isinstance(value, Decimal):
        return int(value) if value == value.to_integral_value() else float(value)
    return value


def build_body(
    spec: TableSpec, row: Mapping[str, object], ids: IdMap, owner_id: str
) -> dict[str, object]:
    body: dict[str, object] = {"id": ids.id_for(spec.name, _text(row["id"])), "user": owner_id}
    relations = {relation.field: relation for relation in spec.relations}
    for column in spec.columns:
        value = row.get(column)
        if column in relations:
            if value is None:
                body[column] = ""
            else:
                mapped = ids.get(relations[column].target, _text(value))
                if mapped is None:
                    raise KeyError(f"{spec.name}.{column}: {value} has no mapped id")
                body[column] = mapped
        elif column in spec.calendar_days:
            body[column] = "" if value is None else to_calendar_day(value)  # type: ignore[arg-type]
        elif column in spec.instants:
            body[column] = "" if value is None else to_instant(value)  # type: ignore[arg-type]
        elif value is None and column in spec.zero_when_null:
            body[column] = 0
        elif value is None and column in spec.empty_when_null:
            body[column] = ""
        else:
            body[column] = _plain_number(value)
    return body


def batched[T](items: Sequence[T], size: int = BATCH_SIZE) -> Iterator[list[T]]:
    for start in range(0, len(items), size):
        yield list(items[start : start + size])


def batch_sub_error(payload: Mapping[str, object]) -> tuple[int, int, dict[str, object]] | None:
    """(index, status, data) of the first failed sub-request, or None if the shape is unknown."""
    data = payload.get("data")
    requests = data.get("requests") if isinstance(data, dict) else None
    if isinstance(requests, dict):
        try:
            items = sorted(requests.items(), key=lambda pair: int(pair[0]))
        except ValueError:
            return None
        entries = [(int(key), entry) for key, entry in items]
    elif isinstance(requests, list):
        entries = list(enumerate(requests))
    else:
        return None
    for index, entry in entries:
        inner = entry.get("response") if isinstance(entry, dict) else None
        if isinstance(inner, dict) and isinstance(inner.get("status"), int) and inner["status"] >= 400:
            inner_data = inner.get("data")
            return index, inner["status"], inner_data if isinstance(inner_data, dict) else {}
    return None


@dataclass(frozen=True)
class CountLine:
    collection: str
    source: int
    target: int

    @property
    def matches(self) -> bool:
        return self.source == self.target


def compare_counts(source: Mapping[str, int], target: Mapping[str, int]) -> list[CountLine]:
    return [CountLine(spec.name, source.get(spec.name, 0), target.get(spec.name, 0)) for spec in TABLES]


# --- Legacy database -------------------------------------------------------------


class LegacyError(Exception):
    """Failure reading the old database; the message is safe to print."""


def legacy_connect_message(error: Exception) -> str:
    return (
        f"Não foi possível conectar ao banco antigo ({type(error).__name__}: {error}). "
        "Não tente de novo antes de conferir a senha: tentativas erradas bloqueiam o endereço. "
        "Máquina sem IPv6 usa o endereço do Session pooler em LEGACY_DB_URL."
    )


def read_legacy(conninfo: str) -> dict[str, list[dict[str, object]]]:
    import psycopg
    from psycopg import IsolationLevel
    from psycopg.rows import dict_row

    try:
        connection = psycopg.connect(
            conninfo, connect_timeout=LEGACY_CONNECT_TIMEOUT_S, row_factory=dict_row
        )
    except psycopg.Error as error:
        raise LegacyError(legacy_connect_message(error)) from None
    table = ""
    try:
        connection.read_only = True
        connection.isolation_level = IsolationLevel.REPEATABLE_READ
        result: dict[str, list[dict[str, object]]] = {}
        for spec in TABLES:
            table = spec.name
            columns = ", ".join(("id", *spec.columns))
            cursor = connection.execute(f"select {columns} from public.{spec.name} order by id")  # noqa: S608
            result[spec.name] = [dict(row) for row in cursor.fetchall()]
        return result
    except psycopg.Error as error:
        raise LegacyError(
            f"Não foi possível ler a tabela {table} do banco antigo ({type(error).__name__}: {error}). "
            "Nada foi gravado."
        ) from None
    finally:
        connection.close()


# --- Target PocketBase -----------------------------------------------------------


class BinaryMissing(Exception):
    pass


class ServerFailed(Exception):
    pass


def free_port() -> int:
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


class DisposablePocketBase:
    """Throwaway PocketBase for --rehearsal: temp folder, project migrations, deleted on exit."""

    def __init__(self, pb_bin: Path) -> None:
        self.pb_bin = pb_bin
        self.superuser_email = REHEARSAL_SUPERUSER_EMAIL
        self.superuser_password = secrets.token_urlsafe(18)
        self.url = ""
        self._temp = tempfile.TemporaryDirectory(prefix="shop-pb-migrate-")
        self.folder = Path(self._temp.name)
        self._process: subprocess.Popen[bytes] | None = None
        self._log = None

    def _run(self, *args: str) -> None:
        result = subprocess.run([str(self.pb_bin), *args], capture_output=True, text=True)
        if result.returncode != 0:
            raise ServerFailed(result.stderr or result.stdout)

    def __enter__(self) -> DisposablePocketBase:
        try:
            if not self.pb_bin.is_file() or not os.access(self.pb_bin, os.X_OK):
                raise BinaryMissing(str(self.pb_bin))
            data = f"--dir={self.folder / 'pb_data'}"
            migrations = f"--migrationsDir={MIGRATIONS_DIR}"
            self._run("migrate", "up", data, migrations)
            self._run("superuser", "upsert", self.superuser_email, self.superuser_password, data)
            port = free_port()
            self.url = f"http://127.0.0.1:{port}"
            log_path = self.folder / "serve.log"
            self._log = log_path.open("wb")
            self._process = subprocess.Popen(
                [str(self.pb_bin), "serve", f"--http=127.0.0.1:{port}", data, migrations],
                stdout=self._log,
                stderr=subprocess.STDOUT,
            )
            deadline = time.monotonic() + HEALTH_TIMEOUT_S
            while time.monotonic() < deadline and self._process.poll() is None:
                try:
                    if httpx.get(f"{self.url}/api/health", timeout=1).status_code == 200:
                        return self
                except httpx.HTTPError:
                    pass
                time.sleep(0.2)
            self._log.flush()
            raise ServerFailed(log_path.read_text(errors="replace") or "sem resposta em /api/health")
        except BaseException:
            self.__exit__(None, None, None)
            raise

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
        self._temp.cleanup()


class Target:
    """Thin httpx client over the target PocketBase; never raises on status."""

    def __init__(self, base_url: str, verbose: bool = False) -> None:
        self.verbose = verbose
        self.client = httpx.Client(base_url=base_url.rstrip("/"), timeout=HTTP_TIMEOUT_S)

    def _send(
        self,
        method: str,
        path: str,
        token: str | None = None,
        body: dict[str, Any] | None = None,
        params: dict[str, Any] | None = None,
    ) -> httpx.Response:
        headers = {"Authorization": token} if token else {}
        response = self.client.request(method, path, headers=headers, json=body, params=params)
        if self.verbose:
            print(f"  {method} {path} -> {response.status_code}", file=sys.stderr)
        return response

    def health(self) -> bool:
        try:
            return self._send("GET", "/api/health").status_code == 200
        except httpx.HTTPError:
            return False

    def _login(self, collection: str, email: str, password: str) -> str:
        response = self._send(
            "POST",
            f"/api/collections/{collection}/auth-with-password",
            body={"identity": email, "password": password},
        )
        if response.status_code != 200:
            raise PermissionError(collection)
        return str(response.json()["token"])

    def auth_superuser(self, email: str, password: str) -> str:
        return self._login(SUPERUSER_COLLECTION, email, password)

    def auth_owner(self, email: str, password: str) -> str:
        return self._login(OWNER_COLLECTION, email, password)

    def find_owner(self, token: str, email: str) -> str | None:
        response = self._send(
            "GET",
            f"/api/collections/{OWNER_COLLECTION}/records",
            token,
            params={"filter": f'email = "{email}"', "fields": "id", "perPage": 1},
        )
        items = response.json().get("items", []) if response.status_code == 200 else []
        return str(items[0]["id"]) if items else None

    def create_owner(self, token: str, email: str, password: str) -> str:
        response = self._send(
            "POST",
            f"/api/collections/{OWNER_COLLECTION}/records",
            token,
            {"email": email, "password": password, "passwordConfirm": password, "verified": True},
        )
        if response.status_code not in (200, 201):
            raise OwnerCreationError(owner_error_lines(response))
        return str(response.json()["id"])

    def _owned_pages(self, token: str, collection: str, owner_id: str) -> Iterator[list[str]]:
        page = 1
        while True:
            response = self._send(
                "GET",
                f"/api/collections/{collection}/records",
                token,
                params={
                    "filter": f'user = "{owner_id}"',
                    "fields": "id",
                    "perPage": PAGE_SIZE,
                    "page": page,
                },
            )
            if response.status_code != 200:
                raise OwnerCreationError([f"{collection}: {response.status_code}"])
            payload = response.json()
            yield [str(item["id"]) for item in payload.get("items", [])]
            if page >= int(payload.get("totalPages", 1)):
                return
            page += 1

    def owner_record_count(self, token: str, collection: str, owner_id: str) -> int:
        return len(self.existing_ids(token, collection, owner_id))

    def existing_ids(self, token: str, collection: str, owner_id: str) -> set[str]:
        return {item for page in self._owned_pages(token, collection, owner_id) for item in page}

    def write_batch(
        self, token: str, collection: str, bodies: list[dict[str, object]]
    ) -> httpx.Response:
        requests = [
            {"method": "POST", "url": f"/api/collections/{collection}/records", "body": body}
            for body in bodies
        ]
        return self._send("POST", "/api/batch", token, {"requests": requests})

    def count_as(self, token: str, collection: str) -> int:
        response = self._send(
            "GET", f"/api/collections/{collection}/records", token, params={"perPage": 1}
        )
        if response.status_code != 200:
            return -1
        return int(response.json().get("totalItems", 0))


class OwnerCreationError(Exception):
    def __init__(self, lines: list[str]) -> None:
        super().__init__("; ".join(lines))
        self.lines = lines


def owner_error_lines(response: httpx.Response) -> list[str]:
    try:
        data = response.json().get("data", {})
    except ValueError:
        data = {}
    lines = [f"{name}: {info.get('code', '?')}" for name, info in data.items() if isinstance(info, dict)]
    return lines or [f"status {response.status_code}"]


# --- Orchestration ---------------------------------------------------------------


@dataclass
class Run:
    mode: Mode
    credentials: Credentials
    target: Target
    token: str
    id_map_path: Path
    rows: dict[str, list[dict[str, object]]] = field(default_factory=dict)


def fail(code: ExitCode, *lines: str) -> int:
    for line in lines:
        print(line, file=sys.stderr)
    return int(code)


def describe_batch_failure(response: httpx.Response) -> str:
    try:
        payload = response.json()
    except ValueError:
        payload = {}
    sub = batch_sub_error(payload) if isinstance(payload, dict) else None
    if sub is None:
        return str(response.status_code)
    _, status, data = sub
    parts = [f"{name}: {info.get('code', '?')}" for name, info in data.items() if isinstance(info, dict)]
    return f"{status} {', '.join(parts)}" if parts else str(status)


def copy_and_check(run: Run) -> int:
    creds, target, token = run.credentials, run.target, run.token
    rows = run.rows
    owner_id = target.find_owner(token, creds.owner_email)
    if run.mode is Mode.APPLY and owner_id is not None and not run.id_map_path.exists():
        if any(target.owner_record_count(token, spec.name, owner_id) > 0 for spec in TABLES):
            return fail(
                ExitCode.TARGET_NOT_EMPTY,
                f"O dono já tem dados no destino e não há mapa de ids em {run.id_map_path}. "
                "Nada foi copiado.",
            )
    if owner_id is None:
        try:
            owner_id = target.create_owner(token, creds.owner_email, creds.owner_password)
        except OwnerCreationError as error:
            return fail(
                ExitCode.OWNER_FAILED, "Não foi possível criar a conta do dono:", *error.lines
            )

    ids = IdMap.load(run.id_map_path)
    for spec in TABLES:
        for row in rows[spec.name]:
            ids.id_for(spec.name, _text(row["id"]))
    ids.save(run.id_map_path)

    for spec in TABLES:
        existing = target.existing_ids(token, spec.name, owner_id)
        bodies = [build_body(spec, row, ids, owner_id) for row in rows[spec.name]]
        pending = [body for body in bodies if body["id"] not in existing]
        skipped = len(bodies) - len(pending)
        copied = 0
        for number, chunk in enumerate(batched(pending), start=1):
            try:
                response = target.write_batch(token, spec.name, chunk)
            except httpx.HTTPError as error:
                return fail(
                    ExitCode.WRITE_FAILED,
                    f"A cópia de {spec.name} parou no lote {number} ({type(error).__name__}).",
                )
            if response.status_code != 200:
                message = (
                    f"A cópia de {spec.name} parou no lote {number} ({describe_batch_failure(response)})."
                )
                if run.mode is Mode.APPLY:
                    message += " Rode de novo: o que já foi copiado é pulado."
                return fail(ExitCode.WRITE_FAILED, message)
            copied += len(chunk)
        print(f"{spec.name}: {copied} copiados ({skipped} já estavam lá)")

    try:
        owner_token = target.auth_owner(creds.owner_email, creds.owner_password)
    except PermissionError:
        return fail(
            ExitCode.OWNER_LOGIN_FAILED,
            "O login de teste do dono falhou. A conta já existia com outra senha?",
        )
    counts = {spec.name: target.count_as(owner_token, spec.name) for spec in TABLES}
    lines = compare_counts({name: len(items) for name, items in rows.items()}, counts)
    width = max(len(line.collection) for line in lines)
    for line in lines:
        status = "ok" if line.matches else "DIFERENTE"
        print(f"{line.collection:<{width}}  origem {line.source}  destino {line.target}  {status}")
    if not all(line.matches for line in lines):
        return fail(ExitCode.COUNT_MISMATCH, "A contagem não bate.")
    print("Cópia conferida: as 13 coleções batem com a origem.")
    if run.mode is Mode.REHEARSAL:
        print("Ensaio: nada foi gravado em produção.")
    return int(ExitCode.OK)


def run_against(
    mode: Mode,
    creds: Credentials,
    base_url: str,
    superuser_email: str,
    superuser_password: str,
    id_map_path: Path,
    verbose: bool,
) -> int:
    target = Target(base_url, verbose)
    if not target.health():
        return fail(ExitCode.TARGET_UNREACHABLE, f"Não foi possível falar com o PocketBase em {base_url}.")
    try:
        token = target.auth_superuser(superuser_email, superuser_password)  # one attempt only
    except (PermissionError, httpx.HTTPError):
        return fail(
            ExitCode.TARGET_AUTH_FAILED,
            "O login de superusuário falhou. Confira PB_SUPERUSER_EMAIL e PB_SUPERUSER_PASSWORD.",
        )
    try:
        rows = read_legacy(creds.legacy_db_url)
    except LegacyError as error:
        return fail(ExitCode.LEGACY_CONNECTION_FAILED, str(error))
    problems = validate_rows(rows)
    if problems:
        return fail(ExitCode.INVALID_DATA, "Dados que não podem ser copiados:", *problems)
    run = Run(mode, creds, target, token, id_map_path, rows)
    return copy_and_check(run)


def parse_args(argv: list[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Copia os dados do Supabase para o PocketBase.")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--rehearsal", action="store_true", help="ensaio num PocketBase descartável")
    group.add_argument("--apply", action="store_true", help="copia para o PB_URL (loopback)")
    parser.add_argument("--env-file", type=Path, default=DEFAULT_ENV_FILE)
    parser.add_argument("--id-map", type=Path, default=DEFAULT_ID_MAP, help="só vale no --apply")
    parser.add_argument("--pb-bin", type=Path, default=DEFAULT_PB_BIN, help="só vale no --rehearsal")
    parser.add_argument("--verbose", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    mode = Mode.APPLY if args.apply else Mode.REHEARSAL
    try:
        creds = load_credentials(mode, os.environ, args.env_file)
    except CredentialsError as error:
        return fail(error.code, str(error))
    os.environ["PGPASSWORD"] = creds.pg_password

    if mode is Mode.APPLY:
        assert creds.pb_url and creds.superuser_email and creds.superuser_password
        return run_against(
            mode,
            creds,
            creds.pb_url,
            creds.superuser_email,
            creds.superuser_password,
            args.id_map,
            args.verbose,
        )
    try:
        with DisposablePocketBase(args.pb_bin) as server:
            return run_against(
                mode,
                creds,
                server.url,
                server.superuser_email,
                server.superuser_password,
                server.folder / "id-map.json",
                args.verbose,
            )
    except BinaryMissing as error:
        return fail(ExitCode.BINARY_MISSING, "Rode `make setup` primeiro.", str(error))
    except ServerFailed as error:
        return fail(ExitCode.SERVER_FAILED, "O PocketBase de ensaio não subiu:", str(error))


if __name__ == "__main__":
    sys.exit(main())
