#!/usr/bin/env bash
# Starts the two processes that put an HTTP API in front of the local Postgres.
# Ctrl+C stops both. Run tool/local_dev/setup.py first -- it writes the configs.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for config in postgrest.conf Caddyfile; do
  if [[ ! -f "$here/$config" ]]; then
    echo "missing $config -- run: uv run tool/local_dev/setup.py" >&2
    exit 1
  fi
done

pg_isready -q || { echo "postgres is not running -- brew services start postgresql@17" >&2; exit 1; }

postgrest "$here/postgrest.conf" &
postgrest_pid=$!
caddy run --config "$here/Caddyfile" --adapter caddyfile &
caddy_pid=$!

trap 'kill "$postgrest_pid" "$caddy_pid" 2>/dev/null || true' EXIT INT TERM

echo "API on http://127.0.0.1:54321/rest/v1 -- Ctrl+C to stop"
wait
