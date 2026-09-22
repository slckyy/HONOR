"""C02 database-contract coverage.

These checks deliberately exercise the migrated Postgres contract rather than
unit doubles.  CI supplies both an admin connection for migration inspection
and the restricted honor_app connection used by runtime paths.
"""
from __future__ import annotations

import json
from pathlib import Path

from .conftest import admin_psql, app_psql

ROOT = Path(__file__).resolve().parents[2]
REGISTRY = json.loads(
    (ROOT / "docs/architecture/c00-approved/HONOR_CAMPAIGN_RULE_REGISTRY.json").read_text()
)


def test_c02_registry_and_runtime_functions_are_installed(migrated_database):
    assert len(REGISTRY["keys"]) == 32
    columns = app_psql(
        "SELECT column_name FROM information_schema.columns "
        "WHERE table_schema='public' AND table_name='campaign_rule_items' "
        "ORDER BY ordinal_position"
    ).splitlines()
    assert {"campaign_id", "terms_snapshot_id", "rule_key", "knowledge_state", "typed_value"}.issubset(columns)

    functions = set(
        admin_psql(
            """
            SELECT p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')'
            FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
            WHERE n.nspname='public'
              AND p.proname IN (
                'honor_commit_source_rights_version',
                'honor_transition_earning',
                'honor_seal_campaign_rule_set',
                'honor_activate_campaign_rule_snapshot'
              )
            """
        ).splitlines()
    )
    assert any(name.startswith("honor_commit_source_rights_version(") for name in functions)
    assert any(name.startswith("honor_transition_earning(") for name in functions)
    assert any(name.startswith("honor_seal_campaign_rule_set(") for name in functions)
    assert any(name.startswith("honor_activate_campaign_rule_snapshot(") for name in functions)


def test_c02_runtime_role_cannot_mutate_immutable_tables(migrated_database):
    for table in ("campaign_rule_items", "source_rights", "source_rights_campaigns", "earning_state_transitions"):
        result = app_psql(
            f"SELECT has_table_privilege(current_user, 'public.{table}', 'UPDATE')"
        )
        assert result == "f", table


def test_c02_verified_by_enum_uses_frozen_values(migrated_database):
    values = app_psql(
        "SELECT enumlabel FROM pg_enum e JOIN pg_type t ON t.oid=e.enumtypid "
        "WHERE t.typname='verified_by_enum' ORDER BY enumsortorder"
    ).splitlines()
    assert values == ["API", "IMPORTER", "OWNER", "BUILDER"]
