# Shortcuts for local development. The scripts under tool/ are the source;
# these targets only name them.

DB ?= shopping_list_dev

.PHONY: run phone api seed

# The app against the local Postgres, starting the API if it is not up.
run:
	tool/local_dev/run.sh

# A release build for the iPhone, over HTTPS on the tailnet.
phone:
	tool/local_dev/phone.sh

# Only the API (PostgREST + Caddy), for when the app runs elsewhere.
api:
	tool/local_dev/up.sh

# Regenerates supabase/seed.sql anchored on today and applies it locally.
# It WIPES the catalog, purchases and list of $(DB) first.
seed:
	uv run tool/make_seed.py
	psql -v ON_ERROR_STOP=1 -q -d $(DB) -f supabase/seed.sql
