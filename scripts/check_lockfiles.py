#!/usr/bin/env python3
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def fail(message: str) -> None:
    raise SystemExit(f"LOCK CHECK FAILED: {message}")


lock = json.loads((ROOT / "package-lock.json").read_text())
if lock.get("lockfileVersion") != 3:
    fail("package-lock.json must be npm lockfileVersion 3")
packages = lock.get("packages") or {}
if len(packages) < 25:
    fail("package-lock.json is not a resolved dependency graph")
for workspace in ("apps/web", "packages/design-system"):
    if workspace not in packages:
        fail(f"package-lock.json missing workspace {workspace}")
for key, info in packages.items():
    if not key.startswith("node_modules/") or info.get("link"):
        continue
    if "version" not in info:
        fail(f"{key} missing resolved version")
    if "resolved" not in info or "integrity" not in info:
        fail(f"{key} missing registry resolution/integrity metadata")
    for dependency in info.get("dependencies", {}):
        if f"node_modules/{dependency}" not in packages:
            fail(f"{key} dependency {dependency} is absent from the resolved graph")

web = json.loads((ROOT / "apps/web/package.json").read_text())
for section in ("dependencies", "devDependencies"):
    for name, requested in web.get(section, {}).items():
        if name == "@honor/design-system":
            continue
        info = packages.get(f"node_modules/{name}")
        if not info:
            fail(f"lock missing direct dependency {name}")
        if requested != info.get("version"):
            fail(f"direct dependency {name} requested {requested}, locked {info.get('version')}")

req_lines = []
for raw in (ROOT / "requirements.lock").read_text().splitlines():
    line = raw.strip()
    if not line or line.startswith("#") or line.startswith("--"):
        continue
    req_lines.append(line)
    if not re.match(r"^[A-Za-z0-9_.-]+(?:\[[A-Za-z0-9_,.-]+\])?==[^\s;]+(?:\s*;.*)?$", line):
        fail(f"unfrozen Python requirement: {line}")
if len(req_lines) < 35:
    fail("requirements.lock does not contain a full transitive resolution")
for required in ("starlette", "pydantic-core", "kombu", "botocore", "httpcore", "jsonschema-specifications"):
    if not any(line.lower().startswith(required.lower() + "==") for line in req_lines):
        fail(f"requirements.lock missing transitive dependency {required}")

for cache in ROOT.rglob("*.tsbuildinfo"):
    if any(part in {".git", ".next", "node_modules"} for part in cache.parts):
        continue
    fail(f"generated TypeScript build cache committed: {cache.relative_to(ROOT)}")

ci = (ROOT / ".github/workflows/ci.yml").read_text()
if "npm ci" not in ci:
    fail("CI must use npm ci")
for dockerfile in (ROOT / "apps/web/Dockerfile",):
    text = dockerfile.read_text()
    if "npm ci" not in text or "npm install" in text:
        fail(f"{dockerfile.relative_to(ROOT)} must use npm ci only")

print(f"OK: npm resolved packages={len(packages)}; Python locked requirements={len(req_lines)}")
