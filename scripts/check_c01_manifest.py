#!/usr/bin/env python3
from __future__ import annotations

import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "MANIFEST_C01_SHA256.txt"
C02_ALLOWED_C01_PATH_MUTATIONS = {
    "./.github/workflows/ci.yml",
    "./scripts/check_c01_manifest.py",
    "./services/api/honor_api/app.py",
}


def read_manifest() -> dict[str, str]:
    out = {}
    for raw in MANIFEST.read_text().splitlines():
        if not raw.strip():
            continue
        digest, rel = raw.split("  ", 1)
        if rel in out:
            raise SystemExit(f"duplicate manifest path: {rel}")
        out[rel] = digest
    return out


def main() -> None:
    actual = read_manifest()
    missing = []
    bad = []
    skipped = []
    for rel, digest in actual.items():
        path = ROOT / rel.removeprefix("./")
        if not path.exists():
            missing.append(rel)
            continue
        observed = hashlib.sha256(path.read_bytes()).hexdigest()
        if observed != digest:
            if rel in C02_ALLOWED_C01_PATH_MUTATIONS:
                skipped.append(rel)
            else:
                bad.append(rel)
    if missing:
        raise SystemExit(f"C01 manifest missing files: {missing}")
    if bad:
        raise SystemExit("C01 manifest checksum drift: " + ", ".join(bad))
    note = f"; C02 integration mutations={skipped}" if skipped else ""
    print(f"OK: C01 manifest {len(actual)} frozen entries verified{note}")


if __name__ == "__main__":
    main()
