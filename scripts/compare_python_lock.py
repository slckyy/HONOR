#!/usr/bin/env python3
"""Compare two fully pinned requirement graphs by normalized distribution name/version.

Extras on a direct requirement (for example PyJWT[crypto]) do not change the locked
wheel version, so they are stripped for graph comparison. Environment markers are
resolved by `uv pip compile` before this check runs.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

LINE = re.compile(r"^([A-Za-z0-9_.-]+)(?:\[[^\]]+\])?==([^\s;]+)")


def canonical(name: str) -> str:
    return re.sub(r"[-_.]+", "-", name).lower()


def parse(path: Path) -> dict[str, str]:
    result: dict[str, str] = {}
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith(("#", "--")):
            continue
        match = LINE.match(line)
        if not match:
            raise SystemExit(f"unrecognized locked requirement in {path}: {line}")
        name, version = canonical(match.group(1)), match.group(2)
        if name in result and result[name] != version:
            raise SystemExit(f"duplicate conflicting pin for {name} in {path}")
        result[name] = version
    return result


def main() -> int:
    if len(sys.argv) != 3:
        raise SystemExit("usage: compare_python_lock.py EXPECTED REGENERATED")
    expected, regenerated = map(lambda x: parse(Path(x)), sys.argv[1:])
    if expected != regenerated:
        missing = sorted(set(expected) - set(regenerated))
        added = sorted(set(regenerated) - set(expected))
        changed = sorted(k for k in expected.keys() & regenerated.keys() if expected[k] != regenerated[k])
        raise SystemExit(
            "Python lock drift: "
            f"missing={missing} added={added} "
            f"changed={[(k, expected[k], regenerated[k]) for k in changed]}"
        )
    print(f"OK: Python lock graph reproduced exactly ({len(expected)} packages)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
