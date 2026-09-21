import asyncio
from datetime import datetime, timezone

import pytest

from honor_api.polli import PolliGateway, PolliPersistence, PolliRegistry

EXPECTED = {
    "finance_summary", "cost_summary", "campaign_performance", "account_performance",
    "edit_feature_performance", "audio_feature_performance", "due_actions",
    "target_progress", "generation_run_status", "clip_status", "allocation_analysis",
    "fact_evidence",
}


def test_registry_exact_names_and_read_only_metadata():
    registry = PolliRegistry()
    assert set(registry.names()) == EXPECTED
    assert len(registry.names()) == 12
    assert all(tool["metadata"]["read_only"] is True for tool in registry.tools.values())


def test_gateway_rejects_unknown_and_has_no_arbitrary_capability():
    gateway = PolliGateway()
    for forbidden in ("sql", "shell", "http", "cloud-admin", "mutation"):
        with pytest.raises(ValueError):
            gateway.registry.validate_arguments(forbidden, {})
        assert forbidden not in gateway.registry.names()
    assert gateway.FORBIDDEN_CAPABILITIES == {"sql", "shell", "http", "cloud-admin", "mutation"}


def test_gateway_validates_result_and_invokes_hooks():
    registry = PolliRegistry()
    name = "generation_run_status"
    args_schema = registry.tools[name]["arguments_schema"]
    required = args_schema.get("required", [])
    # Contract changes should not be papered over by this foundation test.
    assert required
    args = {}
    for field in required:
        spec = args_schema["properties"][field]
        if spec.get("format") == "uuid":
            args[field] = "00000000-0000-0000-0000-000000000001"
        elif spec.get("type") == "string":
            args[field] = spec.get("enum", ["test"])[0]
        else:
            pytest.skip("fixture builder intentionally supports only current frozen arguments")

    class Rate:
        called = False
        async def check(self, owner_id, tool_name):
            self.called = True
            return True

    class Audit:
        events = []
        async def record(self, **event):
            self.events.append(event)

    rate, audit = Rate(), Audit()
    gateway = PolliGateway(registry=registry, rate_limit=rate, audit=audit)

    async def handler(_args):
        # Deliberately return an invalid payload to prove result validation is active.
        return {"definitely_not_the_contract": True}

    gateway.register_read_only(name, handler)
    with pytest.raises(Exception):
        asyncio.run(gateway.call(name, args, owner_id="00000000-0000-0000-0000-000000000001", request_id="00000000-0000-0000-0000-000000000002"))
    assert rate.called
    assert audit.events and audit.events[0]["tool_name"] == name


class FakeConn:
    def __init__(self):
        self.calls = []
    async def execute(self, sql, *args):
        self.calls.append((sql, args))
        return "OK"


def test_polli_persistence_writes_session_and_tool_audit_rows():
    conn = FakeConn()
    persistence = PolliPersistence(conn)
    session_id = asyncio.run(
        persistence.start_session(
            owner_id="00000000-0000-0000-0000-000000000001",
            mode="TEXT",
            backend_model_route="foundation-test-route",
        )
    )
    now = datetime.now(timezone.utc)
    call_id = asyncio.run(
        persistence.record_tool_call(
            session_id=session_id,
            turn_id=None,
            tool_name="cost_summary",
            args={},
            result_summary={"truth": "UNKNOWN"},
            owner_id="00000000-0000-0000-0000-000000000001",
            started_at=now,
            finished_at=now,
        )
    )
    assert session_id and call_id
    assert "INSERT INTO polli_sessions" in conn.calls[0][0]
    assert "INSERT INTO polli_tool_calls" in conn.calls[1][0]
