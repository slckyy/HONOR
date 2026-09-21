#!/usr/bin/env bash
set -euo pipefail
: "${DATABASE_ADMIN_URL:?}"; : "${RESTIC_REPOSITORY:?}"; : "${RESTIC_PASSWORD:?}"; : "${RESTORE_SNAPSHOT_ID:?set snapshot id explicitly}"
: "${R2_BACKUP_ACCESS_KEY_ID:?}"; : "${R2_BACKUP_SECRET_ACCESS_KEY:?}"
export AWS_ACCESS_KEY_ID="$R2_BACKUP_ACCESS_KEY_ID" AWS_SECRET_ACCESS_KEY="$R2_BACKUP_SECRET_ACCESS_KEY" AWS_DEFAULT_REGION=auto
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
restic restore "$RESTORE_SNAPSHOT_ID" --target "$work"
dump=$(find "$work" -name honor-postgres.dump -type f -print -quit); test -n "$dump"
pg_restore --clean --if-exists --no-owner --no-privileges --dbname "$DATABASE_ADMIN_URL" "$dump"
