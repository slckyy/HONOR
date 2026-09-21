#!/usr/bin/env python3
from __future__ import annotations

import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "MANIFEST_C02_SHA256.txt"
EXCLUDED_PARTS = {
    ".git",
    ".next",
    ".pytest_cache",
    ".ruff_cache",
    ".venv",
    "__pycache__",
    "node_modules",
}
EXCLUDED_SUFFIXES = {".pyc", ".pyo", ".tsbuildinfo"}


def release_files() -> dict[str, str]:
    files: dict[str, str] = {}
    for path in sorted(ROOT.rglob("*")):
        if not path.is_file() or path == MANIFEST:
            continue
        relative = path.relative_to(ROOT)
        if any(part in EXCLUDED_PARTS for part in relative.parts):
            continue
        if path.suffix in EXCLUDED_SUFFIXES:
            continue
        name = "./" + relative.as_posix()
        files[name] = hashlib.sha256(path.read_bytes()).hexdigest()
    return files


def read_manifest() -> dict[str, str]:
    entries: dict[str, str] = {}
    for raw in MANIFEST.read_text(encoding="utf-8").splitlines():
        if not raw:
            continue
        digest, name = raw.split("  ", 1)
        if name in entries:
            raise SystemExit(f"duplicate C02 manifest path: {name}")
        entries[name] = digest
    return entries


def main() -> None:
    expected = read_manifest()
    observed = release_files()
    missing = sorted(set(expected) - set(observed))
    extra = sorted(set(observed) - set(expected))
    changed = sorted(name for name in expected.keys() & observed.keys() if expected[name] != observed[name])
    if missing or extra or changed:
        raise SystemExit(
            f"C02 release inventory mismatch: missing={missing}, extra={extra}, changed={changed}"
        )
    print(f"OK: C02 manifest {len(expected)} exact release entries verified")


if __name__ == "__main__":
    main()
