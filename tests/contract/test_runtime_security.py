from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SECURITY_SQL = (ROOT / "infrastructure/migrations/0002_runtime_security.sql").read_text()
ACCESS = json.loads((ROOT / "packages/contracts/HONOR_DB_ACCESS_MATRIX.json").read_text())


def test_every_frozen_table_has_forced_rls_and_no_delete_grant() -> None:
    tables: set[str] = set()
    for spec in ACCESS["classes"].values():
        tables.update(spec["tables"])
    assert len(tables) == 44
    for table in sorted(tables):
        assert f"ALTER TABLE {table} ENABLE ROW LEVEL SECURITY;" in SECURITY_SQL
        assert f"ALTER TABLE {table} FORCE ROW LEVEL SECURITY;" in SECURITY_SQL
        assert not re.search(rf"GRANT[^;]*DELETE[^;]*\b{re.escape(table)}\b", SECURITY_SQL, re.I)
    assert "REVOKE DELETE ON ALL TABLES IN SCHEMA public FROM honor_app;" in SECURITY_SQL


def test_owner_profiles_direct_policy_does_not_recurse() -> None:
    expected = (
        "CREATE POLICY honor_owner_direct ON owner_profiles FOR SELECT TO honor_app "
        "USING (user_id::text=current_setting('honor.owner_user_id',true) AND active=true);"
    )
    assert expected in SECURITY_SQL
    assert "honor_owner_authorized()" not in expected


def test_campaign_update_is_column_limited() -> None:
    assert "GRANT SELECT, INSERT ON campaigns TO honor_app;" in SECURITY_SQL
    assert "GRANT UPDATE(title,currency,canonical_url,updated_at) ON campaigns TO honor_app;" in SECURITY_SQL
    assert "GRANT SELECT, INSERT, UPDATE ON campaigns TO honor_app;" not in SECURITY_SQL


def test_cost_ledger_update_is_reconciliation_only() -> None:
    assert "GRANT SELECT, INSERT ON cost_ledger TO honor_app;" in SECURITY_SQL
    assert "GRANT UPDATE(actual_cost_usd,reconciled_at) ON cost_ledger TO honor_app;" in SECURITY_SQL
    assert "GRANT SELECT, INSERT, UPDATE ON cost_ledger TO honor_app;" not in SECURITY_SQL


def test_function_execute_allowlist_matches_frozen_matrix() -> None:
    granted = set(
        re.findall(r"GRANT EXECUTE ON FUNCTION\s+(.+?)\s+TO honor_app;", SECURITY_SQL)
    )
    expected = set(ACCESS["function_privileges"]["honor_app_execute_only"])
    assert granted == expected
    for signature in ACCESS["function_privileges"]["admin_only_no_honor_app_execute"]:
        assert signature not in granted
    assert "REVOKE ALL ON FUNCTION %s FROM PUBLIC" in SECURITY_SQL


def test_data_api_roles_are_stripped_of_business_table_privileges() -> None:
    assert "REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon" in SECURITY_SQL
    assert "REVOKE ALL ON ALL TABLES IN SCHEMA public FROM authenticated" in SECURITY_SQL

def test_cost_reconciliation_is_one_time_and_audited_by_trigger():
    sql = SECURITY_SQL
    assert "c01_cost_ledger_reconciliation_guard" in sql
    assert "OLD.actual_cost_usd IS NOT NULL" in sql
    assert "NEW.actual_cost_usd IS NULL" in sql
    assert "INSERT INTO audit_log" in sql
    assert "COST_LEDGER_RECONCILED" in sql
