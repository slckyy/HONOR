#!/usr/bin/env python3
from __future__ import annotations
import hashlib
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
MANIFEST=ROOT/'MANIFEST_C01_SHA256.txt'
EXCLUDED_DIRS={'.git','.venv','node_modules','.next','.pytest_cache','__pycache__'}
EXCLUDED_SUFFIXES={'.pyc','.pyo','.tsbuildinfo'}


def included(path: Path) -> bool:
    rel=path.relative_to(ROOT)
    if path == MANIFEST: return False
    if any(part in EXCLUDED_DIRS for part in rel.parts): return False
    if path.suffix in EXCLUDED_SUFFIXES: return False
    return path.is_file()


def expected_entries() -> dict[str,str]:
    out={}
    for path in sorted((p for p in ROOT.rglob('*') if included(p)), key=lambda p:p.as_posix()):
        rel='./'+path.relative_to(ROOT).as_posix()
        out[rel]=hashlib.sha256(path.read_bytes()).hexdigest()
    return out


def read_manifest() -> dict[str,str]:
    out={}
    for raw in MANIFEST.read_text().splitlines():
        if not raw.strip(): continue
        digest, rel=raw.split('  ',1)
        if rel in out: raise SystemExit(f'duplicate manifest path: {rel}')
        out[rel]=digest
    return out


def main() -> None:
    expected=expected_entries(); actual=read_manifest()
    if set(expected)!=set(actual):
        missing=sorted(set(expected)-set(actual)); extra=sorted(set(actual)-set(expected))
        raise SystemExit(f'C01 manifest inventory drift: missing={missing} extra={extra}')
    bad=[p for p in expected if expected[p]!=actual[p]]
    if bad: raise SystemExit('C01 manifest checksum drift: '+', '.join(bad))
    print(f'OK: C01 manifest {len(expected)} files verified')

if __name__=='__main__': main()
