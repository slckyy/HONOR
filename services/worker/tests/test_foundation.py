import ast
from pathlib import Path

from honor_worker.durable_jobs import RETRY_DELAYS_SECONDS, retry_delay

ROOT = Path(__file__).resolve().parents[3]


def test_worker_contract_is_durable_truth_not_redis():
    text = (ROOT / "packages/contracts/events/HONOR_STATE_MACHINES.json").read_text()
    assert "failed-terminal" in text and "blocked-owner-action" in text
    durable = (ROOT / "services/worker/honor_worker/durable_jobs.py").read_text()
    assert "SELECT * FROM jobs" in durable
    assert "FOR UPDATE" in durable
    assert "dispatch_token" in durable
    assert "pg_try_advisory_lock" in durable
    assert "JOB_SUCCEEDED" in durable and "JOB_RETRY_SCHEDULED" in durable


def test_broker_foundation_task_accepts_only_durable_identity():
    tree = ast.parse((ROOT / "services/worker/honor_worker/tasks.py").read_text())
    function = next(node for node in ast.walk(tree) if isinstance(node, ast.FunctionDef) and node.name == "foundation_echo")
    assert [arg.arg for arg in function.args.args] == ["self", "job_id", "dispatch_token"]


def test_retry_backoff_matches_frozen_foundation_schedule():
    assert RETRY_DELAYS_SECONDS == (30, 120, 600, 1800, 7200)
    assert [retry_delay(i) for i in range(1, 6)] == [30, 120, 600, 1800, 7200]


def test_reconciler_is_single_leader_and_production_service_exists():
    reconciler = (ROOT / "services/worker/honor_worker/reconciler.py").read_text()
    assert "pg_try_advisory_lock" in reconciler
    assert "state='retrying'" in reconciler and "state='queued'" in reconciler
    prod = (ROOT / "infrastructure/docker/compose.production.yml").read_text()
    assert '"reconciler"' in prod and 'honor_worker.reconciler' in prod
