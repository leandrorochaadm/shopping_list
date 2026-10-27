# Shortcuts for local development. The scripts under tool/ are the source;
# these targets only name them.

SHELL := /bin/bash
.SHELLFLAGS := -euo pipefail -c

PB_VERSION := 0.40.5
PB_DIR := pocketbase
PB_BIN := $(PB_DIR)/pocketbase
PB_DATA := $(PB_DIR)/pb_data
PB_MIGRATIONS := $(PB_DIR)/pb_migrations
PB_HOST := 127.0.0.1:8095
# Changing PB_VERSION downloads the new binary on the next command.
PB_STAMP := $(PB_DIR)/.installed-$(PB_VERSION)

SUPERUSER_EMAIL := admin@example.com
SUPERUSER_PASSWORD := Admin@12345

DEV_CONFIG := config/dev.json
PROD_CONFIG := config/prod.json

PB_OS := $(if $(filter Darwin,$(shell uname -s)),darwin,linux)
PB_CPU := $(if $(filter arm64 aarch64,$(shell uname -m)),arm64,amd64)
PB_ZIP := pocketbase_$(PB_VERSION)_$(PB_OS)_$(PB_CPU).zip
PB_URL := https://github.com/pocketbase/pocketbase/releases/download/v$(PB_VERSION)
SHA256 := $(if $(shell command -v sha256sum),sha256sum,shasum -a 256)

.PHONY: run phone api seed help setup pb-install pb-migrate pb-superuser \
	pb-serve pb-reset config run-android test test-tool check build-web build-apk

# The app against the local PocketBase, starting it if it is not up.
run:
	tool/local_dev/run.sh

# A release build for the iPhone against the local PocketBase, over HTTPS on the tailnet.
phone:
	tool/local_dev/phone.sh

# Only the local PocketBase, for when the app runs elsewhere.
api: pb-serve

# Needs `make api` (or `make pb-serve`) up in another terminal. Wipes and
# rewrites only the records of dev@local.test.
seed:
	uv run tool/pb_seed.py

help: ## List the available targets
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-14s %s\n", $$1, $$2}'

setup: $(PB_STAMP) pb-migrate pb-superuser $(DEV_CONFIG) ## First-time dev setup (then: make pb-serve)
	flutter pub get

pb-install: $(PB_STAMP) ## Download and verify the PocketBase binary for this machine

$(PB_STAMP):
	mkdir -p $(PB_DIR)
	curl -fsSL --retry 3 -o $(PB_DIR)/$(PB_ZIP) $(PB_URL)/$(PB_ZIP)
	curl -fsSL --retry 3 -o $(PB_DIR)/checksums.txt $(PB_URL)/checksums.txt
	cd $(PB_DIR) && grep ' $(PB_ZIP)$$' checksums.txt | $(SHA256) -c -
	unzip -o -q $(PB_DIR)/$(PB_ZIP) pocketbase -d $(PB_DIR)
	rm -f $(PB_DIR)/$(PB_ZIP) $(PB_DIR)/checksums.txt $(PB_DIR)/.installed-*
	touch $@

pb-migrate: $(PB_STAMP) ## Apply the migrations
	$(PB_BIN) migrate up --dir=$(PB_DATA) --migrationsDir=$(PB_MIGRATIONS)

pb-superuser: $(PB_STAMP) ## Create or update the local superuser
	$(PB_BIN) superuser upsert $(SUPERUSER_EMAIL) $(SUPERUSER_PASSWORD) --dir=$(PB_DATA)

pb-serve: $(PB_STAMP) ## Start PocketBase (panel at http://$(PB_HOST)/_/)
	$(PB_BIN) serve --http=$(PB_HOST) --dir=$(PB_DATA) --migrationsDir=$(PB_MIGRATIONS) --automigrate=false

pb-reset: ## Delete local data and redo migrations + superuser (stop the server first)
	rm -rf $(PB_DATA)
	$(MAKE) pb-migrate pb-superuser

$(DEV_CONFIG):
	cp config/dev.json.example $(DEV_CONFIG)

config: $(DEV_CONFIG) ## Create config/dev.json from the example

run-android: $(DEV_CONFIG) ## Run on Android (emulator needs POCKETBASE_URL=http://10.0.2.2:8095)
	flutter run -d android --dart-define-from-file=$(DEV_CONFIG)

test: ## Run the Flutter tests
	flutter test

test-tool: ## Run the Python tool tests
	uv run --with pytest --with httpx pytest tool/

check: test test-tool ## Run every test

build-web: ## Build the web release (needs config/prod.json)
	flutter build web --release --dart-define-from-file=$(PROD_CONFIG)

build-apk: ## Build the Android release (needs config/prod.json)
	flutter build apk --release --dart-define-from-file=$(PROD_CONFIG)
