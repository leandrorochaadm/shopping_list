#!/usr/bin/env bash
# Serves a release build to the iPhone over the tailnet, against the local
# Postgres. The camera needs HTTPS, and `tailscale serve` is what gives it:
# the app on https://<mac>/ and the API on https://<mac>:8443, tailnet only.
# Ctrl+C stops the web server and the API; the serve config stays, and
# `tailscale serve reset` removes it.
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

api_up() { curl -fsS -o /dev/null "$health_url" -H "apikey: $SUPABASE_ANON_KEY" 2>/dev/null; }

if ! api_up; then
  "$here/up.sh" &
  trap 'kill %1 2>/dev/null || true' EXIT INT TERM
  for _ in $(seq 30); do api_up && break; sleep 0.5; done
  api_up || { echo "the API did not come up -- check: tool/local_dev/up.sh" >&2; exit 1; }
fi

host="$(tailscale status --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["Self"]["DNSName"].rstrip("."))')"

cd "$here/../.."
flutter build web --release \
  --dart-define=SUPABASE_URL="https://$host:8443" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"

# Not silenced: with Serve off in the tailnet, this prints the link to turn it
# on and waits there.
tailscale serve --bg --https=443 http://127.0.0.1:8080
tailscale serve --bg --https=8443 http://127.0.0.1:54321

echo "open on the iPhone: https://$host"
python3 -m http.server 8080 --bind 127.0.0.1 --directory build/web
