#!/usr/bin/env bash
# Serves a release build to the iPhone over the tailnet, against the local
# PocketBase. The camera needs HTTPS, and `tailscale serve` is what gives it:
# the app on https://<host>/ and PocketBase on https://<host>:8443, tailnet
# only. Ctrl+C stops the web server and the PocketBase this script started; the
# serve config stays, and `tailscale serve reset` removes it.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$here/../.."

health_url="http://127.0.0.1:8095/api/health"

api_up() { curl -fsS -o /dev/null "$health_url" 2>/dev/null; }

if ! api_up; then
  setsid make pb-serve &
  api_pid=$!
  trap 'kill -- -"$api_pid" 2>/dev/null || kill "$api_pid" 2>/dev/null || true' EXIT INT TERM
  for _ in $(seq 30); do api_up && break; sleep 0.5; done
  api_up || { echo "PocketBase did not come up -- run: make setup, then make api" >&2; exit 1; }
fi

host="$(tailscale status --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["Self"]["DNSName"].rstrip("."))')"

python3 -c 'import json,sys; json.dump({"POCKETBASE_URL": "https://" + sys.argv[1] + ":8443"}, open("config/phone.json", "w"))' "$host"
flutter build web --release --dart-define-from-file=config/phone.json

# Not silenced: with Serve off in the tailnet, this prints the link to turn it
# on and waits there.
tailscale serve --bg --https=443 http://127.0.0.1:8080
tailscale serve --bg --https=8443 http://127.0.0.1:8095

echo "open on the iPhone: https://$host"
python3 -m http.server 8080 --bind 127.0.0.1 --directory build/web
