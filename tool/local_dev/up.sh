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

# The same hint setup.py prints, for the same reason: naming the wrong package
# manager sends the reader looking for a `brew` that is not on this machine.
if [[ "$(uname -s)" == "Darwin" ]]; then
  start_postgres="brew services start postgresql@17"
elif [[ -d /run/systemd/system ]]; then
  start_postgres="sudo systemctl start postgresql"
else
  start_postgres="sudo service postgresql start"
fi

pg_isready -q || { echo "postgres is not running -- $start_postgres" >&2; exit 1; }

# Neither binary ships with Postgres, and neither is a Flutter dependency: on a
# fresh machine the failure is `command not found` from inside a backgrounded
# job, which `wait` reports as an exit code with no sentence attached.
for binary in postgrest caddy; do
  command -v "$binary" >/dev/null || {
    echo "$binary is not installed -- see docs/estado-atual.md, \"O banco local\"" >&2
    exit 1
  }
done

postgrest "$here/postgrest.conf" &
postgrest_pid=$!
caddy run --config "$here/Caddyfile" --adapter caddyfile &
caddy_pid=$!

trap 'kill "$postgrest_pid" "$caddy_pid" 2>/dev/null || true' EXIT INT TERM

echo "API on http://127.0.0.1:54321/rest/v1 -- Ctrl+C to stop"
wait
