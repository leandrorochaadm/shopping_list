# /// script
# requires-python = ">=3.12"
# dependencies = []
# ///
"""Builds config/prod.json from environment variables (GitHub Secrets in CI)."""

import argparse
import json
import os
import sys
from collections.abc import Mapping
from pathlib import Path
from typing import Final
from urllib.parse import urlsplit

POCKETBASE_URL_KEY: Final = "POCKETBASE_URL"
SENTRY_DSN_KEY: Final = "SENTRY_DSN"
REQUIRED_KEYS: Final[tuple[str, ...]] = (POCKETBASE_URL_KEY,)
HTTPS_SCHEME: Final = "https"
DEFAULT_OUTPUT: Final = "config/prod.json"


class ConfigError(Exception):
    """Raised when the configuration is incomplete or unsafe."""


def build_config(env: Mapping[str, str]) -> dict[str, str]:
    values = {
        name: env.get(name, "").strip()
        for name in (*REQUIRED_KEYS, SENTRY_DSN_KEY)
    }
    missing = [name for name in REQUIRED_KEYS if not values[name]]
    if missing:
        raise ConfigError("Missing: " + ", ".join(missing))
    try:
        parts = urlsplit(values[POCKETBASE_URL_KEY])
        has_host = bool(parts.hostname)
    except ValueError:
        has_host = False
        parts = None
    if parts is None or parts.scheme != HTTPS_SCHEME or not has_host:
        raise ConfigError(f"{POCKETBASE_URL_KEY} must be an https:// address")
    return values


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", default=DEFAULT_OUTPUT)
    args = parser.parse_args(argv)
    try:
        config = build_config(os.environ)
    except ConfigError as error:
        print(f"::error::{error}")
        return 1
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(config, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
