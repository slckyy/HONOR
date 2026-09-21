"""Runtime access to the frozen C00/C02 OpenAPI schemas.

The API intentionally does not duplicate request/response registries in Python.
This module resolves the checked-in OpenAPI document and is used by the C02
routes and contract tests for exact additional-property and discriminator
validation.
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from jsonschema import Draft202012Validator, FormatChecker, RefResolver

ROOT = Path(__file__).resolve().parents[3]
OPENAPI = json.loads((ROOT / "packages/contracts/openapi/HONOR_OPENAPI.json").read_text())
SCHEMAS = OPENAPI["components"]["schemas"]
_BASE = {"$id": "https://honor.local/openapi/HONOR_OPENAPI.json", **OPENAPI}
_STORE: dict[str, Any] = {}
for _path in (ROOT / "packages/contracts/jsonschema").glob("*.json"):
    _doc = json.loads(_path.read_text())
    _STORE[f"jsonschema/{_path.name}"] = _doc
    _STORE[_doc.get("$id", "")] = _doc


def _resolve(schema: dict[str, Any]) -> dict[str, Any]:
    return schema


def schema(name: str) -> dict[str, Any]:
    return SCHEMAS[name]


def validate(name: str, value: Any) -> None:
    """Raise ValueError when *value* does not satisfy the frozen schema."""
    resolver = RefResolver.from_schema(_BASE, store=_STORE)
    errors = sorted(
        Draft202012Validator(schema(name), resolver=resolver, format_checker=FormatChecker()).iter_errors(value),
        key=lambda error: list(error.path),
    )
    if errors:
        error = errors[0]
        path = ".".join(str(part) for part in error.path) or "$"
        raise ValueError(f"{name} at {path}: {error.message}")


def validate_request(name: str, value: Any) -> None:
    try:
        validate(name, value)
    except ValueError as exc:
        raise ValueError(str(exc)) from exc
