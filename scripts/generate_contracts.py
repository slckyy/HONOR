from __future__ import annotations

from pathlib import Path
import argparse
import json

ROOT = Path(__file__).resolve().parents[1]
CONTRACTS = ROOT / "packages/contracts"


def build_outputs() -> dict[str, str]:
    openapi = json.loads((CONTRACTS / "openapi/HONOR_OPENAPI.json").read_text())
    operations: list[dict[str, object]] = []
    for path, item in openapi["paths"].items():
        for method, operation in item.items():
            if method.upper() not in {"GET", "POST", "PUT", "PATCH", "DELETE"}:
                continue
            operations.append(
                {
                    "method": method.upper(),
                    "path": path,
                    "operationId": operation["operationId"],
                    "authorization": operation.get("x-honor-authorization"),
                    "idempotency": operation.get("x-honor-idempotency"),
                }
            )
    operations.sort(key=lambda value: (str(value["path"]), str(value["method"])))

    polli = json.loads((CONTRACTS / "polli-tools/HONOR_POLLI_TOOL_SCHEMAS.json").read_text())
    tools = [
        {
            "name": name,
            "read_only": spec["metadata"]["read_only"],
            "scope": spec["metadata"]["authorization_scope"],
        }
        for name, spec in polli["tools"].items()
    ]
    tools.sort(key=lambda value: str(value["name"]))

    registry = json.loads((CONTRACTS / "HONOR_JSONB_SCHEMA_REGISTRY.json").read_text())
    columns = registry["columns"]

    return {
        "openapi_operations.json": json.dumps(operations, indent=2) + "\n",
        "polli_tools.json": json.dumps(tools, indent=2) + "\n",
        "jsonb_columns.json": json.dumps(columns, indent=2, sort_keys=True) + "\n",
        "openapi_operations.ts": (
            "export const OPENAPI_OPERATIONS = "
            + json.dumps(operations, separators=(",", ":"))
            + " as const;\n"
        ),
        "polli_tools.ts": (
            "export const POLLI_TOOLS = "
            + json.dumps(tools, separators=(",", ":"))
            + " as const;\n"
        ),
        "contracts.py": (
            "OPENAPI_OPERATIONS = "
            + repr(operations)
            + "\nPOLLI_TOOLS = "
            + repr(tools)
            + "\nJSONB_COLUMNS = "
            + repr(columns)
            + "\n"
        ),
    }


def write_outputs(destination: Path) -> None:
    destination.mkdir(parents=True, exist_ok=True)
    for name, content in build_outputs().items():
        (destination / name).write_text(content)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--output",
        type=Path,
        default=CONTRACTS / "generated",
        help="Destination for generated files.",
    )
    args = parser.parse_args()
    write_outputs(args.output)


if __name__ == "__main__":
    main()
