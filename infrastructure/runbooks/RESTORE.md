# Restore drill

1. Run only from the admin/backup context with `DATABASE_ADMIN_URL`; never from API/worker containers.
2. Supply `RESTIC_REPOSITORY`, `RESTIC_PASSWORD`, and backup-only R2 credentials through the protected root-owned backup env.
3. Restore first into a disposable database, execute `python3 scripts/check_contract_drift.py`, migration/guard tests, and a row-count sanity check.
4. Record the Restic snapshot ID, timestamps, verification result, and redacted error if any in `backup_runs` using audited admin tooling.
5. A production restore requires an explicit maintenance decision. Never overwrite production merely to demonstrate the script.
