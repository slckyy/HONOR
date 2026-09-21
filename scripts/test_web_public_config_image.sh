#!/usr/bin/env bash
set -euo pipefail
IMAGE="honor-web:c01-public-config-test"
PUB_URL='https://fixture-public.supabase.invalid'
PUB_KEY='sb_publishable_fixture_public_key_123456789'
BFF='/api/v1-fixture'
# Host-only canaries are intentionally NOT Docker build args.
export DATABASE_APP_URL='postgresql://server-only-canary:never-bundle@example.invalid/db'
export REDIS_PASSWORD='SERVER_ONLY_REDIS_CANARY_123456789012345'
export R2_MEDIA_SECRET_ACCESS_KEY='SERVER_ONLY_R2_CANARY'
export OPENAI_API_KEY='SERVER_ONLY_OPENAI_CANARY'
export RESTIC_PASSWORD='SERVER_ONLY_RESTIC_CANARY'
export DEPLOY_SSH_PRIVATE_KEY='SERVER_ONLY_DEPLOY_CANARY'

docker build -t "$IMAGE" -f apps/web/Dockerfile   --build-arg NEXT_PUBLIC_SUPABASE_URL="$PUB_URL"   --build-arg NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY="$PUB_KEY"   --build-arg NEXT_PUBLIC_HONOR_BFF_BASE="$BFF" .
for value in "$PUB_URL" "$PUB_KEY" "$BFF"; do
  docker run --rm "$IMAGE" sh -ec 'grep -R -F -- "$1" /app/apps/web/.next/static >/dev/null' sh "$value"
done
# Runtime overrides cannot rewrite the already-inlined browser asset.
docker run --rm -e NEXT_PUBLIC_SUPABASE_URL=https://runtime-override.invalid "$IMAGE"   sh -ec 'grep -R -F -- "$1" /app/apps/web/.next/static >/dev/null && ! grep -R -F -- "$2" /app/apps/web/.next/static >/dev/null'   sh "$PUB_URL" 'https://runtime-override.invalid'
for value in "$DATABASE_APP_URL" "$REDIS_PASSWORD" "$R2_MEDIA_SECRET_ACCESS_KEY" "$OPENAI_API_KEY" "$RESTIC_PASSWORD" "$DEPLOY_SSH_PRIVATE_KEY"; do
  docker run --rm "$IMAGE" sh -ec '! grep -R -F -- "$1" /app 2>/dev/null' sh "$value"
done
