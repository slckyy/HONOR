from __future__ import annotations

import os
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BACKUP = ROOT / "infrastructure" / "backup" / "backup.sh"


def _write_executable(path: Path, body: str) -> None:
    path.write_text(body)
    path.chmod(0o755)


def _fixture_env(tmp_path: Path, *, fail_verify: bool = False) -> tuple[dict[str, str], Path]:
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    trace = tmp_path / "trace"
    _write_executable(bin_dir / "pg_dump", "#!/bin/sh\nprintf 'fixture-dump'\n")
    _write_executable(
        bin_dir / "restic",
        """#!/bin/sh
printf 'restic %s\\n' "$*" >>"$TRACE"
case "$1" in
  backup) cat >/dev/null; printf 'snapshot deadbeef saved\\n' ;;
  snapshots) [ "${FAIL_VERIFY:-0}" != 1 ] ;;
  check|forget) exit 0 ;;
  *) exit 2 ;;
esac
""",
    )
    _write_executable(
        bin_dir / "curl",
        "#!/bin/sh\nprintf 'curl %s\\n' \"$*\" >>\"$TRACE\"\n",
    )
    env = os.environ.copy()
    env.update(
        {
            "PATH": f"{bin_dir}:{env['PATH']}",
            "TRACE": str(trace),
            "FAIL_VERIFY": "1" if fail_verify else "0",
            "DATABASE_ADMIN_URL": "postgresql://postgres:REPLACE_ME@db.example.invalid/postgres",
            "RESTIC_REPOSITORY": "s3:https://example.invalid/honor-backups",
            "RESTIC_PASSWORD": "fixture-restic-password",
            "R2_BACKUP_ACCESS_KEY_ID": "fixture-access-key",
            "R2_BACKUP_SECRET_ACCESS_KEY": "fixture-secret-key",
            "BETTERSTACK_BACKUP_HEARTBEAT_URL": "https://example.invalid/heartbeat",
        }
    )
    return env, trace


def test_backup_verifies_snapshot_and_repository_before_success_heartbeat(tmp_path: Path):
    env, trace = _fixture_env(tmp_path)
    subprocess.run(["bash", str(BACKUP)], env=env, check=True, capture_output=True, text=True)
    calls = trace.read_text().splitlines()
    assert calls[0].startswith("restic backup ")
    assert calls[1] == "restic snapshots deadbeef"
    assert calls[2] == "restic check --read-data-subset=1/100"
    assert calls[3].startswith("restic forget ")
    assert calls[4].startswith("curl ")


def test_backup_verification_failure_never_sends_success_heartbeat(tmp_path: Path):
    env, trace = _fixture_env(tmp_path, fail_verify=True)
    completed = subprocess.run(
        ["bash", str(BACKUP)], env=env, check=False, capture_output=True, text=True
    )
    assert completed.returncode != 0
    calls = trace.read_text().splitlines()
    assert calls[:2] == [
        "restic backup --stdin --stdin-filename honor-postgres.dump --tag honor-postgres",
        "restic snapshots deadbeef",
    ]
    assert not any(call.startswith("curl ") for call in calls)
