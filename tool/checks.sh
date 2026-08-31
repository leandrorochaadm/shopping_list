#!/usr/bin/env bash
# Runs supabase/checks/*.sql against the hosted project, in migration order.
#
#   tool/checks.sh
#
# There is no assertion framework in those files: each block prints a line
# whose expected value is written next to it in the SQL. This script only makes
# them run and keeps the output; reading it is by hand.
#
# Five of the six wrap everything in `begin; ... rollback;`, so a run leaves no
# trace. The sixth, normalize_cases.sql, only selects.
#
# The credentials come from .env (see .env.example). Direct connection is
# IPv6-only on the hosted project; export SUPABASE_DB_HOST, SUPABASE_DB_PORT
# and SUPABASE_DB_USER to go through the pooler instead.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
env_file="$root/.env"
out_dir="$root/temp/checks"

[[ -f "$env_file" ]] || { echo "missing .env -- copy .env.example" >&2; exit 1; }
set -a
# shellcheck disable=SC1090
source "$env_file"
set +a

: "${SUPABASE_PROJECT_REF:?set SUPABASE_PROJECT_REF in .env}"
: "${SUPABASE_DB_PASSWORD:?set SUPABASE_DB_PASSWORD in .env}"

host="${SUPABASE_DB_HOST:-db.${SUPABASE_PROJECT_REF}.supabase.co}"
port="${SUPABASE_DB_PORT:-5432}"
user="${SUPABASE_DB_USER:-postgres}"
export PGPASSWORD="$SUPABASE_DB_PASSWORD"

mkdir -p "$out_dir"
echo "running against $user@$host:$port"

# Migration order, not alphabetical: a file reads what the ones before it built.
for name in normalize purchase_write purchase_correction period_report spending_cap type_consumption; do
  file="$root/supabase/checks/${name}_cases.sql"
  printf '\n== %s ==\n' "$name"
  if psql -h "$host" -p "$port" -U "$user" -d postgres \
      -v ON_ERROR_STOP=1 -f "$file" > "$out_dir/$name.out" 2>&1; then
    echo "ok -- temp/checks/$name.out"
  else
    echo "FAILED -- last lines:"
    tail -5 "$out_dir/$name.out"
    exit 1
  fi
done

printf '\nall six ran. The expected values are written beside each case in the SQL.\n'
