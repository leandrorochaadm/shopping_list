#!/usr/bin/env bash
# Runs the app against the local PocketBase, with the URL read from
# config/dev.json via --dart-define-from-file.
#
#   tool/local_dev/run.sh              # Chrome, the usual case
#   tool/local_dev/run.sh -d macos     # any flutter run arguments pass through
#
# If PocketBase is not up yet it is started here (make pb-serve) and stopped on
# exit. One you started yourself is left alone -- this script only cleans up
# what it created.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$here/../.."

config_file="config/dev.json"

if [[ ! -f "$config_file" ]]; then
  echo "missing config/dev.json -- run: cp config/dev.json.example config/dev.json" >&2
  exit 1
fi

pb_url="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["POCKETBASE_URL"])' "$config_file")"
health_url="$pb_url/api/health"

pb_up() { curl -fsS -o /dev/null "$health_url" 2>/dev/null; }

if pb_up; then
  echo "PocketBase already up -- leaving it running"
else
  echo "starting PocketBase"
  setsid make pb-serve &
  api_pid=$!
  trap 'kill -- -"$api_pid" 2>/dev/null || kill "$api_pid" 2>/dev/null || true' EXIT INT TERM

  for _ in $(seq 30); do
    pb_up && break
    sleep 0.5
  done

  if ! pb_up; then
    echo "PocketBase did not come up -- run: make setup, then make api" >&2
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

# A shell alias (`flutter='fvm flutter'`) does not reach a script, so fall back
# to fvm when no flutter binary is on the PATH.
if command -v flutter >/dev/null; then
  flutter_cmd=(flutter)
else
  flutter_cmd=(fvm flutter)
fi

echo "running against $pb_url"
"${flutter_cmd[@]}" run --dart-define-from-file="$config_file" "${flutter_args[@]}"
