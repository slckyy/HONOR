from __future__ import annotations

from pathlib import Path
import subprocess
import sys
import tempfile

from generate_contracts import build_outputs

ROOT = Path(__file__).resolve().parents[1]
APPROVED = ROOT / "docs/architecture/c00-approved"
CONTRACTS = ROOT / "packages/contracts"
GENERATED = CONTRACTS / "generated"

CANONICAL_COPIES = {
    "HONOR_OPENAPI.json": CONTRACTS / "openapi/HONOR_OPENAPI.json",
    "HONOR_OPENAPI.yaml": CONTRACTS / "openapi/HONOR_OPENAPI.yaml",
    "HONOR_OPENAPI_V1.json": CONTRACTS / "openapi/HONOR_OPENAPI_V1.json",
    "HONOR_API_HUMAN_REGISTRY.json": CONTRACTS / "openapi/HONOR_API_HUMAN_REGISTRY.json",
    "HONOR_ERROR_CODE_MATRIX.json": CONTRACTS / "openapi/HONOR_ERROR_CODE_MATRIX.json",
    "HONOR_EVENT_AND_JOB_CONTRACTS.md": CONTRACTS / "events/HONOR_EVENT_AND_JOB_CONTRACTS.md",
    "HONOR_STATE_MACHINES.json": CONTRACTS / "events/HONOR_STATE_MACHINES.json",
    "HONOR_POLLI_TOOL_CONTRACTS.md": CONTRACTS / "polli-tools/HONOR_POLLI_TOOL_CONTRACTS.md",
    "HONOR_POLLI_TOOL_SCHEMAS.json": CONTRACTS / "polli-tools/HONOR_POLLI_TOOL_SCHEMAS.json",
    "HONOR_JSONB_SCHEMA_REGISTRY.json": CONTRACTS / "HONOR_JSONB_SCHEMA_REGISTRY.json",
    "HONOR_COST_GOVERNOR.json": CONTRACTS / "HONOR_COST_GOVERNOR.json",
    "HONOR_DB_ACCESS_MATRIX.json": CONTRACTS / "HONOR_DB_ACCESS_MATRIX.json",
    "HONOR_AUTH_ROUTES.json": CONTRACTS / "HONOR_AUTH_ROUTES.json",
}


def fail(message: str) -> None:
    raise SystemExit(message)


for name, destination in CANONICAL_COPIES.items():
    source = APPROVED / name
    if source.read_bytes() != destination.read_bytes():
        fail(f"contract drift: {name}")

approved_schemas = sorted((APPROVED / "jsonschema").glob("*.json"))
repo_schemas = sorted((CONTRACTS / "jsonschema").glob("*.json"))
if len(approved_schemas) != 30 or len(repo_schemas) != 30:
    fail("expected exactly 30 canonical JSON schemas")
if [path.name for path in approved_schemas] != [path.name for path in repo_schemas]:
    fail("JSON Schema filename set drifted")
for source, destination in zip(approved_schemas, repo_schemas, strict=True):
    if source.read_bytes() != destination.read_bytes():
        fail(f"jsonschema drift: {source.name}")

expected = build_outputs()
actual_names = {path.name for path in GENERATED.iterdir() if path.is_file()}
if actual_names != set(expected):
    fail(f"generated artifact set drifted: {sorted(actual_names ^ set(expected))}")
for name, content in expected.items():
    if (GENERATED / name).read_text() != content:
        fail(f"generated contract drift: {name}; run python3 scripts/generate_contracts.py")

# Run the preserved C00 validator in-place without changing approved input bytes.
result = subprocess.run(
    [sys.executable, str(APPROVED / "HONOR_C00_VALIDATION.py")],
    cwd=APPROVED,
    capture_output=True,
    text=True,
)
if result.returncode:
    print(result.stdout)
    print(result.stderr, file=sys.stderr)
    raise SystemExit(result.returncode)

print("OK: frozen C00 copies, 30 schemas, generated outputs, and C00 validator are consistent")
