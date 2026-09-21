from __future__ import annotations

import asyncio
import os
import tempfile
from pathlib import Path

import pytest

from scripts.migrate import apply_migrations
from tests.integration.conftest import ADMIN_URL, APP_URL, OWNER, admin_psql, app_psql

pytestmark = pytest.mark.integration


def test_clean_migration_and_security_contract(migrated_database):
    assert migrated_database == [
        "0000_extensions_and_role.sql",
        "0001_c00_database_contract.sql",
        "0002_runtime_security.sql",
    ]
    assert admin_psql("SELECT count(*) FROM pg_tables WHERE schemaname='public'") == "44"
    assert admin_psql(
        "SELECT (CASE WHEN rolcanlogin THEN 't' ELSE 'f' END)||','||"
        "(CASE WHEN rolsuper THEN 't' ELSE 'f' END)||','||"
        "(CASE WHEN rolcreatedb THEN 't' ELSE 'f' END)||','||"
        "(CASE WHEN rolcreaterole THEN 't' ELSE 'f' END)||','||"
        "(CASE WHEN rolinherit THEN 't' ELSE 'f' END)||','||"
        "(CASE WHEN rolbypassrls THEN 't' ELSE 'f' END) "
        "FROM pg_roles WHERE rolname='honor_app'"
    ) == "t,f,f,f,f,f"
    assert admin_psql(
        "SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace "
        "WHERE n.nspname='public' AND c.relkind='r' AND c.relrowsecurity AND c.relforcerowsecurity"
    ) == "44"
    assert admin_psql(
        "SELECT count(*) FROM information_schema.role_table_grants "
        "WHERE grantee='honor_app' AND privilege_type='DELETE' AND table_schema='public'"
    ) == "0"
    assert admin_psql("SELECT count(*) FROM honor_migrations.schema_migrations") == "3"


def test_second_migration_apply_is_noop(migrated_database):
    assert asyncio.run(apply_migrations(ADMIN_URL)) == []


def test_changed_checksum_of_applied_migration_fails(migrated_database, tmp_path: Path):
    migration = tmp_path / "9001_checksum_test.sql"
    migration.write_text("SELECT 1;\n")
    assert asyncio.run(apply_migrations(ADMIN_URL, tmp_path)) == [migration.name]
    migration.write_text("SELECT 2;\n")
    with pytest.raises(RuntimeError, match="checksum changed"):
        asyncio.run(apply_migrations(ADMIN_URL, tmp_path))


def test_concurrent_migration_attempts_serialize(migrated_database, tmp_path: Path):
    migration = tmp_path / "9002_concurrent_test.sql"
    migration.write_text("SELECT pg_sleep(0.5);\n")

    async def run_both():
        return await asyncio.gather(
            apply_migrations(ADMIN_URL, tmp_path),
            apply_migrations(ADMIN_URL, tmp_path),
        )

    first, second = asyncio.run(run_both())
    assert sorted([first, second], key=len) == [[], [migration.name]]


def test_owner_context_is_transaction_local_on_reused_session(migrated_database):
    out = app_psql(
        f"""
        BEGIN;
        SELECT set_config('honor.owner_user_id','{OWNER}',true);
        SELECT count(*) FROM owner_profiles WHERE user_id='{OWNER}'::uuid;
        COMMIT;
        BEGIN;
        SELECT COALESCE(current_setting('honor.owner_user_id',true),'');
        SELECT count(*) FROM owner_profiles;
        ROLLBACK;
        """
    )
    lines = [line for line in str(out).splitlines() if line not in {"BEGIN", "COMMIT", "ROLLBACK"}]
    assert lines[-3:] == ["1", "", "0"]


def test_runtime_delete_and_direct_lifecycle_bypass_are_rejected(migrated_database):
    invalid = app_psql(
        f"""
        BEGIN;
        SELECT set_config('honor.owner_user_id','{OWNER}',true);
        INSERT INTO jobs(id,job_type,domain_entity_type,domain_entity_id,state,stage,max_attempts,
          idempotency_key,dispatch_token,correlation_id,timeout_seconds)
        VALUES(gen_random_uuid(),'foundation-test','test',gen_random_uuid(),'succeeded','backup',1,
          'c01-invalid-lifecycle-'||gen_random_uuid()::text,gen_random_uuid(),gen_random_uuid(),30);
        COMMIT;
        """,
        check=False,
    )
    assert invalid.returncode != 0
    assert "invalid lifecycle creation/transition" in (invalid.stderr + invalid.stdout)
    denied = app_psql(
        f"BEGIN; SELECT set_config('honor.owner_user_id','{OWNER}',true); DELETE FROM jobs; COMMIT;",
        check=False,
    )
    assert denied.returncode != 0
    assert "permission denied" in (denied.stderr + denied.stdout).lower()


def test_precommit_owner_review_resolves_before_target_exists(migrated_database):
    campaign = "10000000-0000-4000-8000-000000000001"
    snapshot = "10000000-0000-4000-8000-000000000002"
    source = "10000000-0000-4000-8000-000000000003"
    rights = "10000000-0000-4000-8000-000000000004"
    transcript = "10000000-0000-4000-8000-000000000005"
    run = "10000000-0000-4000-8000-000000000006"
    candidate = "10000000-0000-4000-8000-000000000007"
    action = "10000000-0000-4000-8000-000000000008"
    target = "10000000-0000-4000-8000-000000000009"
    admin_psql(
        f"""
        SET session_replication_role=replica;
        INSERT INTO campaigns(id,provider,title) VALUES('{campaign}','fixture','fixture') ON CONFLICT DO NOTHING;
        INSERT INTO campaign_terms_snapshots(id,campaign_id,captured_at,storage_object_key,sha256,capture_method)
          VALUES('{snapshot}','{campaign}',statement_timestamp(),'fixture/terms','{'a'*64}','MANUAL_ENTRY') ON CONFLICT DO NOTHING;
        INSERT INTO campaign_rule_items(id,campaign_id,terms_snapshot_id,rule_key,knowledge_state,typed_value,confidence,evidence_snapshot_id,evidence_locator,verified_at,verified_by)
          VALUES(gen_random_uuid(),'{campaign}','{snapshot}','content_restrictions','KNOWN',
          '{{"value":{{"clauses":[{{"code":"NO_MISLEADING_CLAIMS"}}]}}}}'::jsonb,1,'{snapshot}','fixture',statement_timestamp(),'BUILDER')
          ON CONFLICT DO NOTHING;
        INSERT INTO campaign_rule_set_commits(campaign_id,terms_snapshot_id,rule_count,rules_sha256)
          VALUES('{campaign}','{snapshot}',32,'{'b'*64}') ON CONFLICT DO NOTHING;
        INSERT INTO sources(id,origin_type,provider,title,ingest_status)
          VALUES('{source}','OWNER_OWNED','fixture','source','READY') ON CONFLICT DO NOTHING;
        INSERT INTO source_rights(id,source_id,rights_version,eligibility,authorized_uses,platform_limits,evidence_type,evidence_uri,evidence_captured_at,record_hash)
          VALUES('{rights}','{source}',1,'ELIGIBLE','{{}}','{{}}','fixture','https://example.invalid/evidence',statement_timestamp(),'{'c'*64}') ON CONFLICT DO NOTHING;
        INSERT INTO source_rights_campaigns(source_rights_id,campaign_id) VALUES('{rights}','{campaign}') ON CONFLICT DO NOTHING;
        INSERT INTO transcripts(id,source_id,campaign_id,rights_id,provider,model,status,transcript_sha256,completed_at)
          VALUES('{transcript}','{source}','{campaign}','{rights}','fixture','fixture','SUCCEEDED','{'d'*64}',statement_timestamp()) ON CONFLICT DO NOTHING;
        INSERT INTO generation_runs(id,target_date,requested_by,state,stage,strategy_version,budget_snapshot,requested_constraints,correlation_id)
          VALUES('{run}',current_date,'{OWNER}','queued','campaign_import','fixture','{{}}','{{}}',gen_random_uuid()) ON CONFLICT DO NOTHING;
        INSERT INTO candidates(id,generation_run_id,source_id,transcript_id,scoring_version,start_ms,end_ms,transcript_excerpt,
          context_independence_score,hook_score,payoff_score,editability_score,rule_fit_score,novelty_score,overall_score,features)
          VALUES('{candidate}','{run}','{source}','{transcript}','fixture',0,1000,'fixture',1,1,1,1,1,1,1,'{{"start_ms":0,"end_ms":1000}}') ON CONFLICT DO NOTHING;
        SET session_replication_role=origin;
        """
    )
    resolution = (
        '{"resolution_type":"RESTRICTION_COMPLIANCE","review_phase":"PRECOMMIT","decision":"COMPLIANT",'
        '"restriction_code":"NO_MISLEADING_CLAIMS","campaign_id":"'+campaign+'","rule_snapshot_id":"'+snapshot+'",'
        '"candidate_id":"'+candidate+'","target_type":"EDIT_PLAN","target_id":"'+target+'","target_version":1,'
        '"subject_sha256":"' + ('e'*64) + '","note":null}'
    )
    out = app_psql(
        f"""
        BEGIN;
        SELECT set_config('honor.owner_user_id','{OWNER}',true);
        INSERT INTO owner_actions(id,action_type,title,reason,entity_type,entity_id)
          VALUES('{action}','CAMPAIGN_RULE','Review','fixture','RESTRICTION_COMPLIANCE','{candidate}');
        UPDATE owner_actions SET status='RESOLVED',resolution=$json${resolution}$json$::jsonb WHERE id='{action}';
        SELECT status::text||':'||(resolution->>'review_phase')||':'||
          (NOT EXISTS(SELECT 1 FROM edit_plans WHERE id='{target}'))::text
          FROM owner_actions WHERE id='{action}';
        COMMIT;
        """
    )
    assert "RESOLVED:PRECOMMIT:true" in str(out)
