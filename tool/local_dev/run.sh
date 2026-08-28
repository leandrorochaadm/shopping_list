#!/usr/bin/env bash
# Runs the app against the local Postgres, with the two --dart-define filled in
# from the generated .env. Without them the app falls back to the fakes, which
# is the whole reason this script exists.
#
#   tool/local_dev/run.sh              # Chrome, the usual case
#   tool/local_dev/run.sh -d macos     # any flutter run arguments pass through
#
# If the API is not up yet it is started here and stopped on exit. An API you
# started yourself with up.sh is left alone -- this script only cleans up what
# it created.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
env_file="$here/.env"
health_url="http://127.0.0.1:54321/rest/v1/store?select=id&limit=1"

if [[ ! -f "$env_file" ]]; then
  echo "missing .env -- run: uv run tool/local_dev/setup.py" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$env_file"
set +a

if curl -fsS -o /dev/null "$health_url" -H "apikey: $SUPABASE_ANON_KEY" 2>/dev/null; then
  echo "API already up -- leaving it running"
else
  echo "starting the API"
  "$here/up.sh" &
  api_pid=$!
  trap 'kill -- -"$api_pid" 2>/dev/null || kill "$api_pid" 2>/dev/null || true' EXIT INT TERM

  for _ in $(seq 30); do
    if curl -fsS -o /dev/null "$health_url" -H "apikey: $SUPABASE_ANON_KEY" 2>/dev/null; then
      break
    fi
    sleep 0.5
  done

  if ! curl -fsS -o /dev/null "$health_url" -H "apikey: $SUPABASE_ANON_KEY" 2>/dev/null; then
    echo "the API did not come up -- check: tool/local_dev/up.sh" >&2
    exit 1
  fi
fi

# An array, not "${@:--d chrome}": that default expands as ONE word, and
# flutter would receive a single argument spelled "-d chrome".
if [[ $# -gt 0 ]]; then
  flutter_args=("$@")
else
  flutter_args=(-d chrome)
fi

echo "running against $SUPABASE_URL"
flutter run \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  "${flutter_args[@]}"
