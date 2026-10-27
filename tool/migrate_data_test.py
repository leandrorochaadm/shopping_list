# /// script
# requires-python = ">=3.12"
# dependencies = ["httpx>=0.27", "psycopg[binary]>=3.2"]
# ///
"""Offline tests for tool/migrate_data.py (no network, no Postgres, no PocketBase)."""

from __future__ import annotations

import json
import os
import random
import re
import stat
import sys
import tempfile
import unittest
from datetime import UTC, date, datetime, timedelta, timezone
from decimal import Decimal
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import migrate_data as m  # noqa: E402

GOOD_ENV = {
    "LEGACY_DB_URL": "postgresql://u@host:5432/db",
    "PGPASSWORD": "secret-pg",
    "PB_OWNER_EMAIL": "dono@example.com",
    "PB_OWNER_PASSWORD": "12345678",
}
APPLY_ENV = {
    **GOOD_ENV,
    "PB_URL": "http://127.0.0.1:8095",
    "PB_SUPERUSER_EMAIL": "root@example.com",
    "PB_SUPERUSER_PASSWORD": "root-pass",
}
ID_PATTERN = re.compile(r"^[a-z0-9]{15}$")


def write_env(folder: Path, text: str, mode: int = 0o600) -> Path:
    path = folder / "migration.env"
    path.write_text(text, encoding="utf-8")
    path.chmod(mode)
    return path


class CredentialsTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)

    def load(self, env: dict[str, str], path: Path | None = None, mode: m.Mode = m.Mode.REHEARSAL):
        return m.load_credentials(mode, env, path or self.folder / "none.env")

    def test_environment_alone_is_enough(self) -> None:
        creds = self.load(GOOD_ENV)
        self.assertEqual(creds.owner_email, "dono@example.com")

    def test_missing_file_exits_3(self) -> None:
        with self.assertRaises(m.CredentialsError) as caught:
            self.load({})
        self.assertEqual(caught.exception.code, m.ExitCode.CREDENTIALS_MISSING)
        self.assertIn("Arquivo de credenciais não encontrado", str(caught.exception))

    def test_loose_permissions_exit_4(self) -> None:
        path = write_env(self.folder, "PGPASSWORD=x\n", 0o644)
        with self.assertRaises(m.CredentialsError) as caught:
            self.load({}, path)
        self.assertEqual(caught.exception.code, m.ExitCode.CREDENTIALS_INVALID)

    def test_file_fills_what_the_environment_lacks(self) -> None:
        text = "\n".join(f'{k}="{v}"' for k, v in GOOD_ENV.items() if k != "PGPASSWORD")
        path = write_env(self.folder, "# comment\n" + text + "\nPGPASSWORD=from-file\n")
        creds = self.load({}, path)
        self.assertEqual(creds.pg_password, "from-file")
        self.assertEqual(creds.legacy_db_url, GOOD_ENV["LEGACY_DB_URL"])

    def test_environment_wins_over_file(self) -> None:
        path = write_env(self.folder, "PB_OWNER_EMAIL=outro@example.com\nPGPASSWORD=file\n")
        creds = self.load({**GOOD_ENV, "PGPASSWORD": "env"}, path)
        self.assertEqual(creds.pg_password, "env")
        self.assertEqual(creds.owner_email, "dono@example.com")

    def test_missing_variable_is_named_without_values(self) -> None:
        path = write_env(self.folder, "PGPASSWORD=zzz-secret\n")
        with self.assertRaises(m.CredentialsError) as caught:
            self.load({}, path)
        self.assertEqual(caught.exception.code, m.ExitCode.CREDENTIALS_MISSING)
        self.assertIn("LEGACY_DB_URL", str(caught.exception))
        self.assertNotIn("zzz-secret", str(caught.exception))

    def test_short_password_exits_4(self) -> None:
        with self.assertRaises(m.CredentialsError) as caught:
            self.load({**GOOD_ENV, "PB_OWNER_PASSWORD": "1234567"})
        self.assertEqual(caught.exception.code, m.ExitCode.CREDENTIALS_INVALID)

    def test_invalid_emails_exit_4(self) -> None:
        for email in ("sem-arroba", "a b@x.com", 'a"b@x.com', "a'b@x.com", "a@semponto"):
            with self.subTest(email=email), self.assertRaises(m.CredentialsError) as caught:
                self.load({**GOOD_ENV, "PB_OWNER_EMAIL": email})
            self.assertEqual(caught.exception.code, m.ExitCode.CREDENTIALS_INVALID)

    def test_apply_needs_target_variables(self) -> None:
        path = write_env(self.folder, "# empty\n")
        with self.assertRaises(m.CredentialsError) as caught:
            self.load(GOOD_ENV, path, mode=m.Mode.APPLY)
        self.assertEqual(caught.exception.code, m.ExitCode.CREDENTIALS_MISSING)
        self.assertIn("PB_URL", str(caught.exception))

    def test_apply_accepts_loopback_only(self) -> None:
        self.assertEqual(self.load(APPLY_ENV, mode=m.Mode.APPLY).pb_url, "http://127.0.0.1:8095")
        self.assertEqual(
            self.load({**APPLY_ENV, "PB_URL": "http://localhost:8095"}, mode=m.Mode.APPLY).pb_url,
            "http://localhost:8095",
        )
        for url in ("https://x-api.example.com", "http://200.141.20.186:8092", "http://127.0.0.1"):
            with self.subTest(url=url), self.assertRaises(m.CredentialsError) as caught:
                self.load({**APPLY_ENV, "PB_URL": url}, mode=m.Mode.APPLY)
            self.assertEqual(caught.exception.code, m.ExitCode.CREDENTIALS_INVALID)


class DatesTest(unittest.TestCase):
    def test_calendar_day(self) -> None:
        self.assertEqual(m.to_calendar_day(date(2026, 10, 2)), "2026-10-02 00:00:00.000Z")

    def test_instant_converts_to_utc_and_cuts_milliseconds(self) -> None:
        value = datetime(2026, 10, 2, 9, 30, 15, 123456, tzinfo=timezone(timedelta(hours=-3)))
        self.assertEqual(m.to_instant(value), "2026-10-02 12:30:15.123Z")

    def test_instant_utc_passthrough(self) -> None:
        self.assertEqual(
            m.to_instant(datetime(2026, 1, 1, 0, 0, 0, tzinfo=UTC)), "2026-01-01 00:00:00.000Z"
        )

    def test_naive_instant_is_refused(self) -> None:
        with self.assertRaises(ValueError):
            m.to_instant(datetime(2026, 10, 2, 9, 30))


class IdMapTest(unittest.TestCase):
    def test_ids_have_pocketbase_format(self) -> None:
        for _ in range(50):
            self.assertRegex(m.new_record_id(), ID_PATTERN)

    def test_same_uuid_same_id(self) -> None:
        ids = m.IdMap()
        self.assertEqual(ids.id_for("brand", "u1"), ids.id_for("brand", "u1"))

    def test_different_uuids_different_ids(self) -> None:
        ids = m.IdMap()
        self.assertNotEqual(ids.id_for("brand", "u1"), ids.id_for("brand", "u2"))

    def test_collision_is_regenerated(self) -> None:
        ids = m.IdMap()
        sequence = iter(["aaaaaaaaaaaaaaa", "aaaaaaaaaaaaaaa", "bbbbbbbbbbbbbbb"])
        first = ids.id_for("brand", "u1", lambda: next(sequence))
        second = ids.id_for("store", "u2", lambda: next(sequence))
        self.assertEqual((first, second), ("aaaaaaaaaaaaaaa", "bbbbbbbbbbbbbbb"))

    def test_seeded_rng_is_deterministic(self) -> None:
        self.assertEqual(m.new_record_id(random.Random(1)), m.new_record_id(random.Random(1)))

    def test_save_and_load_roundtrip_with_private_mode(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "sub" / "id-map.json"
            ids = m.IdMap()
            new_id = ids.id_for("brand", "u1")
            ids.save(path)
            self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
            self.assertEqual(m.IdMap.load(path).get("brand", "u1"), new_id)
            self.assertEqual(json.loads(path.read_text()), {"brand": {"u1": new_id}})
            self.assertFalse(path.with_name("id-map.json.tmp").exists())

    def test_load_missing_file_is_empty(self) -> None:
        self.assertIsNone(m.IdMap.load(Path("/nonexistent/id-map.json")).get("brand", "u1"))


def spec(name: str) -> m.TableSpec:
    return next(s for s in m.TABLES if s.name == name)


class BuildBodyTest(unittest.TestCase):
    def setUp(self) -> None:
        self.ids = m.IdMap()

    def test_tables_cover_thirteen_collections_in_dependency_order(self) -> None:
        names = [s.name for s in m.TABLES]
        self.assertEqual(len(names), 13)
        for index, table in enumerate(m.TABLES):
            for relation in table.relations:
                self.assertLess(names.index(relation.target), index)

    def test_owner_and_mapped_relations(self) -> None:
        category = self.ids.id_for("category", "c1")
        body = m.build_body(
            spec("product_type"),
            {"id": "t1", "name": "Leite", "category_id": "c1", "base_unit": "milliliter", "active": True},
            self.ids,
            "owner0000000001",
        )
        self.assertEqual(body["user"], "owner0000000001")
        self.assertEqual(body["category_id"], category)
        self.assertRegex(str(body["id"]), ID_PATTERN)

    def test_null_optional_relation_becomes_empty(self) -> None:
        self.ids.id_for("product_type", "t1")
        body = m.build_body(
            spec("product_registration"),
            {
                "id": "r1",
                "product_type_id": "t1",
                "brand_id": None,
                "description": "",
                "selling_mode": "by_piece",
                "active": True,
            },
            self.ids,
            "o",
        )
        self.assertEqual(body["brand_id"], "")

    def test_null_numbers_and_text_conversions(self) -> None:
        self.ids.id_for("product_registration", "r1")
        body = m.build_body(
            spec("product"),
            {
                "id": "p1",
                "product_registration_id": "r1",
                "piece_count": None,
                "piece_size": None,
                "piece_size_unit": None,
                "total_content": None,
                "active": True,
            },
            self.ids,
            "o",
        )
        self.assertEqual(
            (body["piece_count"], body["piece_size"], body["total_content"], body["piece_size_unit"]),
            (0, 0, 0, ""),
        )

    def test_list_item_dates_and_null_dates(self) -> None:
        self.ids.id_for("product_type", "t1")
        body = m.build_body(
            spec("shopping_list_item"),
            {
                "id": "s1",
                "product_type_id": "t1",
                "preferred_registration_id": None,
                "quantity": Decimal("2"),
                "entered_on": date(2026, 10, 1),
                "fulfilled_on": None,
                "removed_on": None,
                "picked": False,
                "not_found": False,
            },
            self.ids,
            "o",
        )
        self.assertEqual(body["entered_on"], "2026-10-01 00:00:00.000Z")
        self.assertEqual(body["fulfilled_on"], "")
        self.assertEqual(body["quantity"], 2)
        self.assertNotIn("preferred_brand_id", body)
        self.assertNotIn("preferred_product_id", body)

    def test_decimal_with_fraction_becomes_float(self) -> None:
        self.assertEqual(m._plain_number(Decimal("1.5")), 1.5)

    def test_purchase_instant_and_null_registered_by(self) -> None:
        self.ids.id_for("store", "st1")
        body = m.build_body(
            spec("purchase"),
            {
                "id": "pu1",
                "purchase_date": date(2026, 10, 2),
                "store_id": "st1",
                "registered_by": None,
                "created_at": datetime(2026, 10, 2, 9, 30, 15, 123456, tzinfo=timezone(timedelta(hours=-3))),
            },
            self.ids,
            "o",
        )
        self.assertEqual(body["created_at"], "2026-10-02 12:30:15.123Z")
        self.assertEqual(body["registered_by"], "")

    def test_unmapped_relation_raises(self) -> None:
        with self.assertRaises(KeyError):
            m.build_body(
                spec("product_type"),
                {"id": "t1", "name": "x", "category_id": "missing", "base_unit": "gram", "active": True},
                self.ids,
                "o",
            )


def minimal_rows() -> dict[str, list[dict[str, object]]]:
    rows: dict[str, list[dict[str, object]]] = {s.name: [] for s in m.TABLES}
    rows["category"] = [{"id": "c1"}]
    rows["product_type"] = [{"id": "t1", "category_id": "c1", "base_unit": "gram"}]
    rows["product_registration"] = [
        {"id": "r1", "product_type_id": "t1", "brand_id": None, "selling_mode": "by_piece"}
    ]
    rows["product"] = [{"id": "p1", "product_registration_id": "r1", "piece_size_unit": "gram"}]
    return rows


class ValidateTest(unittest.TestCase):
    def test_clean_rows(self) -> None:
        self.assertEqual(m.validate_rows(minimal_rows()), [])

    def test_legacy_unit_points_to_migration(self) -> None:
        rows = minimal_rows()
        rows["product_type"][0]["base_unit"] = "kilogram"
        problems = m.validate_rows(rows)
        self.assertEqual(len(problems), 1)
        self.assertIn("kilogram", problems[0])
        self.assertIn("migration", problems[0])

    def test_unknown_unit_and_selling_mode(self) -> None:
        rows = minimal_rows()
        rows["product"][0]["piece_size_unit"] = "pound"
        rows["product_registration"][0]["selling_mode"] = "by_magic"
        self.assertEqual(len(m.validate_rows(rows)), 2)

    def test_dangling_relation(self) -> None:
        rows = minimal_rows()
        rows["product"][0]["product_registration_id"] = "ghost"
        self.assertEqual(len(m.validate_rows(rows)), 1)

    def test_required_relation_null(self) -> None:
        rows = minimal_rows()
        rows["product_type"][0]["category_id"] = None
        self.assertEqual(len(m.validate_rows(rows)), 1)

    def test_naive_instant_reported(self) -> None:
        rows = minimal_rows()
        rows["spending_cap_alert"] = [
            {"id": "a1", "month": date(2026, 10, 1), "warned_80_at": datetime(2026, 10, 2), "warned_100_at": None}
        ]
        problems = m.validate_rows(rows)
        self.assertEqual(len(problems), 1)
        self.assertIn("warned_80_at", problems[0])


class BatchTest(unittest.TestCase):
    def test_batches_of_fifty(self) -> None:
        chunks = list(m.batched(list(range(120))))
        self.assertEqual([len(c) for c in chunks], [50, 50, 20])
        self.assertEqual(list(m.batched([])), [])

    def test_sub_error_dict_shape(self) -> None:
        payload = {
            "data": {
                "requests": {
                    "1": {"response": {"status": 400, "data": {"name": {"code": "validation_required"}}}}
                }
            }
        }
        self.assertEqual(
            m.batch_sub_error(payload), (1, 400, {"name": {"code": "validation_required"}})
        )

    def test_sub_error_list_shape(self) -> None:
        payload = {"data": {"requests": [{}, {"response": {"status": 404, "data": {}}}]}}
        self.assertEqual(m.batch_sub_error(payload), (1, 404, {}))

    def test_sub_error_unknown_shape(self) -> None:
        self.assertIsNone(m.batch_sub_error({"data": {}}))
        self.assertIsNone(m.batch_sub_error({}))
        self.assertIsNone(m.batch_sub_error({"data": {"requests": {"x": {}}}}))


class CountsTest(unittest.TestCase):
    def test_all_match(self) -> None:
        counts = {s.name: 2 for s in m.TABLES}
        lines = m.compare_counts(counts, counts)
        self.assertEqual(len(lines), 13)
        self.assertTrue(all(line.matches for line in lines))

    def test_mismatch_is_flagged(self) -> None:
        source = {s.name: 2 for s in m.TABLES}
        target = {**source, "brand": 1}
        bad = [line for line in m.compare_counts(source, target) if not line.matches]
        self.assertEqual([line.collection for line in bad], ["brand"])


class MainTest(unittest.TestCase):
    def test_rehearsal_without_credentials_exits_3(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            saved = {k: os.environ.pop(k) for k in list(os.environ) if k in m.REQUIRED_VARS[m.Mode.APPLY]}
            try:
                code = m.main(["--rehearsal", "--env-file", str(Path(folder) / "absent.env")])
            finally:
                os.environ.update(saved)
        self.assertEqual(code, m.ExitCode.CREDENTIALS_MISSING)

    def test_missing_binary_exits_5_before_touching_legacy(self) -> None:
        saved = {k: os.environ.get(k) for k in GOOD_ENV}
        os.environ.update(GOOD_ENV)
        try:
            code = m.main(["--rehearsal", "--pb-bin", "/nonexistent/pocketbase"])
        finally:
            for key, value in saved.items():
                if value is None:
                    os.environ.pop(key, None)
                else:
                    os.environ[key] = value
        self.assertEqual(code, m.ExitCode.BINARY_MISSING)

    def test_modes_are_exclusive(self) -> None:
        with self.assertRaises(SystemExit) as caught:
            m.parse_args(["--rehearsal", "--apply"])
        self.assertEqual(caught.exception.code, 2)

    def test_a_mode_is_required(self) -> None:
        with self.assertRaises(SystemExit):
            m.parse_args([])


if __name__ == "__main__":
    unittest.main()
