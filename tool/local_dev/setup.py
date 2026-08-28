# /// script
# requires-python = ">=3.12"
# dependencies = []
# ///
"""Prepares a local Postgres to answer as the app's Supabase backend.

The app is Flutter Web: it cannot open a Postgres socket, it speaks PostgREST
over HTTP. So "use the local Postgres in development" means three pieces —
the database itself, PostgREST in front of it, and a proxy that maps the
`/rest/v1` prefix supabase_flutter builds onto PostgREST's root.

This script owns the first piece and writes the config for the other two.
`up.sh` starts them. Realtime is NOT part of this: it has no native binary,
so H5 still needs the hosted project.

    uv run tool/local_dev/setup.py            # apply pending migrations, keep data
    uv run tool/local_dev/setup.py --reset    # drop and rebuild from scratch
    uv run tool/local_dev/setup.py --no-seed  # do not load supabase/seed.sql
    uv run tool/local_dev/setup.py --seed     # load the seed into an existing database
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import hmac
import json
import secrets
import subprocess
import sys
import time
from pathlib import Path

DB_NAME = "shopping_list_dev"
PG_PORT = 5432
POSTGREST_PORT = 3000
# The port the Supabase CLI would use for its gateway. Nothing is competing for
# it here (no containers), and keeping it makes the SUPABASE_URL familiar.
PROXY_PORT = 54321
# Ten years. This token never leaves the machine; an expiry prompt mid-session
# would only cost time.
TOKEN_LIFETIME_SECONDS = 10 * 365 * 24 * 3600

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
SECRET_FILE = HERE / ".jwt_secret"
ENV_FILE = HERE / ".env"


def run_psql(database: str, *args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    cmd = ["psql", "-v", "ON_ERROR_STOP=1", "-q", "-d", database, *args]
    return subprocess.run(cmd, capture_output=True, text=True, check=check)


def require_postgres() -> None:
    """Fails with a sentence instead of a Python traceback.

    Everything below shells out to psql/createdb; with the server down each one
    dies on its own with a CalledProcessError, and the first thing the reader
    sees is a stack trace from subprocess.py.
    """
    probe = subprocess.run(["pg_isready", "-q"], capture_output=True)
    if probe.returncode != 0:
        sys.exit(
            "postgres is not reachable.\n"
            "Start it with:\n"
            "  brew services start postgresql@17"
        )


def database_exists() -> bool:
    out = subprocess.run(
        ["psql", "-lqtA", "-F", "|"], capture_output=True, text=True, check=True
    ).stdout
    return any(line.split("|")[0] == DB_NAME for line in out.splitlines())


def b64url(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode()


def make_jwt(secret: str, role: str) -> str:
    """A Supabase anon key is just an HS256 JWT carrying a `role` claim.

    PostgREST validates the signature with the same secret and does SET ROLE
    from that claim -- which is what turns the RLS policies on. No library
    needed for one signature.
    """
    now = int(time.time())
    header = {"alg": "HS256", "typ": "JWT"}
    payload = {
        "role": role,
        "iss": "shopping-list-local",
        "iat": now,
        "exp": now + TOKEN_LIFETIME_SECONDS,
    }
    signing_input = ".".join(
        b64url(json.dumps(part, separators=(",", ":")).encode())
        for part in (header, payload)
    ).encode()
    signature = hmac.new(secret.encode(), signing_input, hashlib.sha256).digest()
    return f"{signing_input.decode()}.{b64url(signature)}"


def existing_anon_key(secret: str) -> str | None:
    """The key already in .env, when it is still signed by the current secret.

    Minting a fresh one on every run would change the value the developer may
    have pasted into an IDE launch config or a shell history, for no gain: the
    old token stays valid anyway, because the secret did not change.
    """
    if not ENV_FILE.exists():
        return None
    for line in ENV_FILE.read_text().splitlines():
        key, _, value = line.partition("=")
        if key != "SUPABASE_ANON_KEY" or not value:
            continue
        signing_input, _, signature = value.rpartition(".")
        expected = b64url(
            hmac.new(secret.encode(), signing_input.encode(), hashlib.sha256).digest()
        )
        return value if hmac.compare_digest(signature, expected) else None
    return None


def load_or_create_secret() -> str:
    if SECRET_FILE.exists():
        return SECRET_FILE.read_text().strip()
    # PostgREST refuses secrets shorter than 32 bytes for HS256.
    secret = secrets.token_urlsafe(48)
    SECRET_FILE.write_text(secret + "\n")
    SECRET_FILE.chmod(0o600)
    return secret


HISTORY_TABLE = "supabase_migrations.schema_migrations"


def run_sql_file(path: Path, *extra: str) -> None:
    """Applies one .sql file in a single transaction, or exits with its error.

    `-1` matters: without it a migration that fails halfway leaves the database
    holding the objects it managed to create, and the next run reports a
    conflict on those instead of the real error.
    """
    result = subprocess.run(
        ["psql", "-v", "ON_ERROR_STOP=1", "-q", "-1", "-d", DB_NAME, "-f", str(path), *extra],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print(result.stderr.strip(), file=sys.stderr)
        sys.exit(f"failed on {path.relative_to(REPO)}")


def ensure_history_table() -> None:
    """The same table the Supabase CLI keeps, with the same name.

    Without it every run would replay every migration, and the second one dies
    on `create table category` -- the migrations are written to run once, which
    is correct for migrations. This is what makes a new migration land on a
    database that already has data, instead of forcing --reset.
    """
    run_psql(
        DB_NAME,
        "-c",
        "create schema if not exists supabase_migrations;",
        "-c",
        f"create table if not exists {HISTORY_TABLE} ("
        " version text primary key,"
        " name text,"
        " inserted_at timestamptz not null default now());",
    )


def public_schema_populated() -> bool:
    """True when the app's tables already exist, history table aside."""
    out = run_psql(
        DB_NAME,
        "-tA",
        "-c",
        "select count(*) from pg_tables where schemaname = 'public';",
    ).stdout
    return int(out.strip() or 0) > 0


def applied_versions() -> set[str]:
    out = run_psql(DB_NAME, "-tA", "-c", f"select version from {HISTORY_TABLE};").stdout
    return {line.strip() for line in out.splitlines() if line.strip()}


def apply_migrations() -> None:
    """Applies only what the history table has not seen.

    The version is the timestamp prefix of the file name, which is how the
    Supabase CLI names them -- so a database set up here and one set up by
    `supabase db push` agree on what "already applied" means.
    """
    ensure_history_table()
    done = applied_versions()

    # A database built before this script tracked history: the tables are there
    # but nothing is recorded, so every migration below would be replayed and
    # die on the first `create table`. Postgres' own error does not hint at the
    # fix, so say it here.
    if not done and public_schema_populated():
        sys.exit(
            f"{DB_NAME} already has tables but no migration history.\n"
            "It predates this script. Rebuild it with:\n"
            "  uv run tool/local_dev/setup.py --reset"
        )

    print("  applying bootstrap.sql")
    run_sql_file(HERE / "bootstrap.sql")

    pending = 0
    for path in sorted((REPO / "supabase" / "migrations").glob("*.sql")):
        version = path.name.split("_", 1)[0]
        if version in done:
            print(f"  skipping {path.name} (already applied)")
            continue
        print(f"  applying {path.name}")
        # File and bookkeeping in ONE transaction: a migration that is recorded
        # but not applied, or applied but not recorded, is worse than a failure.
        run_sql_file(
            path,
            "-c",
            f"insert into {HISTORY_TABLE} (version, name) values "
            f"('{version}', '{path.name}');",
        )
        pending += 1

    if pending == 0:
        print("  no pending migrations")


def apply_seed() -> None:
    print(f"  applying {Path('supabase/seed.sql')}")
    run_sql_file(REPO / "supabase" / "seed.sql")


def write_service_configs(secret: str) -> None:
    (HERE / "postgrest.conf").write_text(
        f'''# Generated by setup.py -- do not edit, it is overwritten.
db-uri = "postgres://authenticator@localhost:{PG_PORT}/{DB_NAME}"
db-schemas = "public"
# Requests with no valid JWT fall back to this role. The app always sends one,
# but a bare curl against the API should hit RLS too, not an error.
db-anon-role = "anon"
jwt-secret = "{secret}"
server-port = {POSTGREST_PORT}
# Bound to loopback: this speaks for a database with no login in front of it.
server-host = "127.0.0.1"
'''
    )

    (HERE / "Caddyfile").write_text(
        f'''# Generated by setup.py -- do not edit, it is overwritten.
#
# supabase_flutter builds every URL as <SUPABASE_URL>/rest/v1/<table>, which is
# the path the hosted Kong gateway routes. PostgREST serves at the root, so the
# prefix has to come off -- that is the whole job of this file.
:{PROXY_PORT} {{
	handle_path /rest/v1/* {{
		reverse_proxy 127.0.0.1:{POSTGREST_PORT}
	}}
	handle {{
		respond "shopping_list local dev -- the API is under /rest/v1" 200
	}}
}}
'''
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reset", action="store_true", help="drop the database first")
    parser.add_argument("--no-seed", action="store_true", help="do not load the seed")
    parser.add_argument(
        "--seed", action="store_true", help="load the seed into an existing database"
    )
    args = parser.parse_args()

    require_postgres()

    if args.reset and database_exists():
        print(f"dropping {DB_NAME}")
        subprocess.run(["dropdb", DB_NAME], check=True)

    # The seed is for a database that has no data yet. Loading it twice would
    # either duplicate rows or trip the duplicate guard, so a plain re-run does
    # NOT touch it -- --seed is the way to ask for it on purpose.
    created_now = not database_exists()
    if created_now:
        print(f"creating {DB_NAME}")
        subprocess.run(["createdb", DB_NAME], check=True)

    secret = load_or_create_secret()
    anon_key = existing_anon_key(secret) or make_jwt(secret, "anon")

    print("applying schema")
    apply_migrations()
    if args.seed or (created_now and not args.no_seed):
        apply_seed()

    write_service_configs(secret)
    url = f"http://127.0.0.1:{PROXY_PORT}"
    ENV_FILE.write_text(f"SUPABASE_URL={url}\nSUPABASE_ANON_KEY={anon_key}\n")
    # postgrest.conf holds the signing secret and .env holds a key derived from
    # it. Both are git-ignored; keep them off the rest of the machine too.
    for path in (ENV_FILE, HERE / "postgrest.conf"):
        path.chmod(0o600)

    print(
        f"\nready. start the API with:\n"
        f"  tool/local_dev/up.sh\n\n"
        f"then run the app against it with:\n"
        f"  flutter run -d chrome \\\n"
        f"    --dart-define=SUPABASE_URL={url} \\\n"
        f"    --dart-define=SUPABASE_ANON_KEY={anon_key}\n"
    )


if __name__ == "__main__":
    main()
