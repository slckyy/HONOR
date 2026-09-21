import pytest

from honor_api.jobs import (
    DurableJob,
    JobSpec,
    assert_job_transition,
    deterministic_dispatch_token,
    deterministic_job_id,
    dispatch_payload,
)


def test_deterministic_job_and_dispatch_ids():
    job_id = deterministic_job_id("render", "abc")
    assert job_id == deterministic_job_id("render", "abc")
    assert deterministic_dispatch_token(job_id) == deterministic_dispatch_token(job_id)


def test_job_graph():
    assert_job_transition("queued", "running")
    assert_job_transition("running", "retrying")
    assert_job_transition("retrying", "queued")


def test_terminal_rejects():
    with pytest.raises(ValueError):
        assert_job_transition("succeeded", "running")


def test_job_spec_rejects_unknown_stage():
    spec = JobSpec(
        job_type="future",
        domain_entity_type="clip",
        domain_entity_id="11111111-1111-4111-8111-111111111111",
        stage="made_up",
        idempotency_key="x",
        correlation_id="22222222-2222-4222-8222-222222222222",
    )
    with pytest.raises(ValueError):
        spec.validate()


def test_broker_payload_contains_only_durable_identity():
    job = DurableJob(
        id="11111111-1111-4111-8111-111111111111",
        dispatch_token="22222222-2222-4222-8222-222222222222",
        state="queued",
        stage="render",
        version=1,
        idempotency_key="render:test",
    )
    assert dispatch_payload(job) == {
        "job_id": job.id,
        "dispatch_token": job.dispatch_token,
    }
    assert job.celery_task_id == job.id
