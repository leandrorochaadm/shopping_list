# /// script
# requires-python = ">=3.12"
# dependencies = ["pytest"]
# ///
import json
from pathlib import Path

import pytest

import write_prod_config as w

URL = "https://pb.example.com"


def run(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path, env: dict[str, str]
) -> tuple[int, Path]:
    for name in (w.POCKETBASE_URL_KEY, w.SENTRY_DSN_KEY):
        monkeypatch.delenv(name, raising=False)
    for name, value in env.items():
        monkeypatch.setenv(name, value)
    out = tmp_path / "sub" / "prod.json"
    return w.main(["--output", str(out)]), out


def test_all_filled_strips_spaces(monkeypatch, tmp_path):
    code, out = run(
        monkeypatch,
        tmp_path,
        {
            "POCKETBASE_URL": f"  {URL} ",
            "SENTRY_DSN": " https://x@o0.ingest.sentry.io/1 ",
        },
    )
    assert code == 0
    assert json.loads(out.read_text(encoding="utf-8")) == {
        "POCKETBASE_URL": URL,
        "SENTRY_DSN": "https://x@o0.ingest.sentry.io/1",
    }


def test_missing_sentry_dsn_writes_empty(monkeypatch, tmp_path):
    code, out = run(monkeypatch, tmp_path, {"POCKETBASE_URL": URL})
    assert code == 0
    assert json.loads(out.read_text(encoding="utf-8"))["SENTRY_DSN"] == ""


def test_missing_url(monkeypatch, tmp_path, capsys):
    code, out = run(monkeypatch, tmp_path, {})
    assert code == 1
    assert "POCKETBASE_URL" in capsys.readouterr().out
    assert not out.exists()


def test_blank_url_is_missing(monkeypatch, tmp_path, capsys):
    code, out = run(monkeypatch, tmp_path, {"POCKETBASE_URL": "   "})
    assert code == 1
    assert "Missing: POCKETBASE_URL" in capsys.readouterr().out
    assert not out.exists()


@pytest.mark.parametrize(
    "url",
    [
        "http://pb.example.com",
        "http://127.0.0.1:55390",
        "pb.example.com",
        "ftp://pb.example.com",
        "https://[pb.example.com",
    ],
)
def test_non_https_url_rejected(monkeypatch, tmp_path, capsys, url):
    code, out = run(monkeypatch, tmp_path, {"POCKETBASE_URL": url})
    captured = capsys.readouterr()
    assert code == 1
    assert "https://" in captured.out
    assert "POCKETBASE_URL" in captured.out
    assert url not in captured.out + captured.err
    assert not out.exists()


def test_https_without_host_rejected(monkeypatch, tmp_path, capsys):
    code, out = run(monkeypatch, tmp_path, {"POCKETBASE_URL": "https://"})
    assert code == 1
    assert "POCKETBASE_URL" in capsys.readouterr().out
    assert not out.exists()


@pytest.mark.parametrize(
    "url",
    ["https://pb.example.com", "https://pb.example.com/", "https://pb.example.com:8090"],
)
def test_https_url_accepted(monkeypatch, tmp_path, url):
    code, out = run(monkeypatch, tmp_path, {"POCKETBASE_URL": url})
    assert code == 0
    assert json.loads(out.read_text(encoding="utf-8"))["POCKETBASE_URL"] == url
