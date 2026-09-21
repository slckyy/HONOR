#!/usr/bin/env bash
set -euo pipefail
: "${DATABASE_ADMIN_URL:?}"
: "${RESTIC_REPOSITORY:?}"
: "${RESTIC_PASSWORD:?}"
: "${R2_BACKUP_ACCESS_KEY_ID:?}"
: "${R2_BACKUP_SECRET_ACCESS_KEY:?}"
export AWS_ACCESS_KEY_ID="$R2_BACKUP_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$R2_BACKUP_SECRET_ACCESS_KEY"
export AWS_DEFAULT_REGION=auto
umask 077

tmp_log="$(mktemp)"
trap 'rm -f "$tmp_log"' EXIT

# restic's human output includes: "snapshot <id> saved". Capture it without exposing secrets.
pg_dump "$DATABASE_ADMIN_URL" --format=custom --no-owner --no-privileges \
  | restic backup --stdin --stdin-filename honor-postgres.dump --tag honor-postgres 2>&1 \
  | tee "$tmp_log"
snapshot_id="$(sed -nE 's/^snapshot ([0-9a-f]+) saved$/\1/p' "$tmp_log" | tail -n 1)"
if [[ -z "$snapshot_id" ]]; then
  echo "backup verification failed: restic did not report a created snapshot" >&2
  exit 1
fi

# Success is not reported until both snapshot existence and repository integrity pass.
restic snapshots "$snapshot_id" >/dev/null
# Lightweight C01 integrity sampling; full restore drills remain a later/live operational action.
restic check --read-data-subset=1/100 >/dev/null

restic forget --keep-daily 14 --keep-weekly 8 --prune
if [[ -n "${BETTERSTACK_BACKUP_HEARTBEAT_URL:-}" ]]; then
  curl --fail --silent --show-error --max-time 10 "$BETTERSTACK_BACKUP_HEARTBEAT_URL" >/dev/null
fi
