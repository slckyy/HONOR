"""Frozen C02 OpenAPI conformance harness.

These tests deliberately use the checked-in OpenAPI document as the machine
authority; a hand-maintained list of response fields cannot make a route pass.
The database integration suite exercises the same validators against live API
responses when the Postgres service is available in CI.
"""
from __future__ import annotations

import json
from pathlib import Path

import pytest
from jsonschema import Draft202012Validator, FormatChecker, RefResolver


ROOT = Path(__file__).resolve().parents[2]
OPENAPI = json.loads((ROOT / "packages/contracts/openapi/HONOR_OPENAPI.json").read_text())
STORE = {}
for path in (ROOT / "packages/contracts/jsonschema").glob("*.json"):
    doc = json.loads(path.read_text())
    STORE[f"jsonschema/{path.name}"] = doc
    if doc.get("$id"):
        STORE[doc["$id"]] = doc
BASE = {"$id": "https://honor.local/openapi/HONOR_OPENAPI.json", **OPENAPI}


def validate(name: str, value: object) -> None:
    validator = Draft202012Validator(
        OPENAPI["components"]["schemas"][name],
        resolver=RefResolver.from_schema(BASE, store=STORE),
        format_checker=FormatChecker(),
    )
    errors = list(validator.iter_errors(value))
    assert not errors, f"{name}: {errors[0].message if errors else ''}"


def test_every_c02_operation_has_frozen_contract():
    paths = [
        "/v1/campaigns", "/v1/campaigns/import", "/v1/campaigns/{id}",
        "/v1/sources/import", "/v1/sources/{id}", "/v1/uploads/intents",
        "/v1/uploads/{id}/complete", "/v1/submissions", "/v1/analytics/due",
        "/v1/analytics/check-ins", "/v1/payout-events", "/v1/finance/summary",
        "/v1/costs/summary",
    ]
    for path in paths:
        operation = OPENAPI["paths"][path]["get" if path.endswith("due") or path.endswith("summary") or path in {"/v1/campaigns", "/v1/campaigns/{id}", "/v1/sources/{id}"} else "post"]
        assert operation.get("operationId")
        assert any(code in operation["responses"] for code in ("200", "201", "202"))


def test_manual_campaign_request_and_accepted_response_are_exact():
    validate("CampaignImportRequest", {"method":"MANUAL","provider":"fixture","title":"Fixture","campaign_url":None,"external_campaign_id":None,"terms_text":"terms","terms_upload_id":None})
    validate("CampaignImportAccepted", {"campaign_id":"00000000-0000-0000-0000-000000000001","job_id":"00000000-0000-0000-0000-000000000002","status":"VERIFYING","correlation_id":"00000000-0000-0000-0000-000000000003"})


def test_frozen_discriminators_reject_legacy_names():
    with pytest.raises(Exception):
        validate("CampaignImportRequest", {"variant":"MANUAL"})
    with pytest.raises(Exception):
        validate("PayoutEventRequest", {"variant":"CREATE"})
