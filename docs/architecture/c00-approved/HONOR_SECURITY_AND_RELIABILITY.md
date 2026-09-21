> HONOR C00 frozen specification — research date 2026-09-20.
> Month-1 hard operating ceiling: $56.03 USD. Later builders may not silently change frozen contracts.

# Security and Reliability

## Secrets
Allowed in repo: `.env.example` containing names/placeholders only.
Forbidden from commit: live `.env`, API keys, DB passwords, service-role keys, SSH private keys, R2 secrets, signed URLs, webhook secrets, recovery codes.

Server-only secrets:
- OpenAI project API key
- direct Postgres credentials (`DATABASE_APP_URL`; `DATABASE_ADMIN_URL` only in maintenance context); Supabase secret/service-role keys are not used by V1 runtime
- R2 access secret
- Better Stack heartbeat tokens/API token if used
- deployment SSH private credential
- future provider webhook secrets

Client-visible config can include public origin, Supabase URL, and publishable/anon key as designed. Never label a public key as a privileged secret.

## Secret stores
Production deployment secrets live in GitHub **repository Actions secrets** and/or root-owned server environment files injected at deploy; no secret is copied into docs/checkpoint screenshots. Runtime logs redact values matching secret headers/tokens and signed query params.

## AuthN/AuthZ
- Supabase Auth is owner identity provider.
- FastAPI verifies short-lived Supabase JWT against current trusted signing keys/JWKS and validates issuer/audience/expiry.
- Single-owner role in V1, but authorization checks still exist; never treat possession of a URL as authorization.
- Supabase secret/service-role keys are not used by V1 runtime; browser business-data access is prohibited and normal server runtime uses `honor_app` direct Postgres plus JWT verification.
- RLS protects direct DB-access pathways; append-only finance/events/audit tables are not directly client-writable.

## Browser/session boundary
- HTTPS only in production.
- Strict origin/CORS allowlist: the deployed HONOR origin only.
- Authorization bearer/session data is short-lived and never printed.
- CSP, frame-ancestors denial, MIME sniffing protection, referrer policy, permissions policy, and secure headers set at Caddy/Next.
- Avoid rendering unsanitized campaign HTML; terms are stored/rendered as escaped text or sanitized trusted subset.
- CSRF protection is required for any cookie-authenticated mutation. Bearer-token APIs still validate Origin where appropriate.

## Rate limiting
Redis-backed per-user/IP hashed counters for sensitive endpoints: auth-adjacent flows, Polli session creation/query, source/campaign import, generation create. Fail closed on abusive bursts but do not make Redis outage destroy durable work.

## Safe file/URL ingest
- allow only `https` by default; explicit `http` requires owner/manual exception.
- resolve DNS and block loopback, link-local, RFC1918/private, metadata-service, and other SSRF-sensitive targets unless an explicit internal integration is approved.
- enforce download byte/time limits before full fetch.
- inspect declared MIME but trust `ffprobe`/magic result over extension.
- reject executable/archive formats unless a future approved importer needs them.
- filename is metadata only; generate own object key.
- compute SHA-256.
- media processing runs unprivileged with no provider credentials mounted and no network access where feasible.
- temp directory quota and cleanup always run.

## Media sandbox
FFmpeg/OpenCV worker subprocess/container:
- unprivileged UID/GID;
- read-only input mount and isolated writable temp/output;
- network disabled during decode/render unless a specific stage requires provider access outside sandbox;
- CPU/memory/pid/time limits;
- no Docker socket;
- no host secret mounts;
- patched FFmpeg image.

## Provider/webhook security
Any future webhook requires HTTPS, provider signature verification, timestamp/replay window, idempotency, and raw body hashing. Unsigned provider callbacks are untrusted input.

## Logging/audit
Structured JSON fields: timestamp, level, service, request_id, correlation_id, job_id, entity IDs, event, duration, safe provider request ID, status/failure code. Never log auth headers, cookies, secret env values, full signed URLs, or sensitive raw campaign credentials.

Audit log covers login-sensitive actions, owner resolutions, finance transitions, provider config changes, Polli tool calls, and deployment/admin actions where available.

## Durable jobs
Postgres is source of truth. See event/job contract. Redis is reconstructible. Worker uses idempotent domain operations, leases/heartbeats, retry classification, and restart recovery.

## Backups
Month-1 Free Supabase has no automatic backup entitlement, so HONOR must perform its own nightly logical backup/export of application schema/data, encrypt via restic, and write to private R2 backup storage.

Backup policy at launch:
- nightly database logical backup;
- configuration/migration metadata included, secrets excluded;
- restic encryption password stored separately in secret store;
- retention default: daily 7, weekly 4, subject to R2 budget;
- backup heartbeat to Better Stack;
- weekly `restic check`/integrity verification as feasible;
- at least one controlled restore drill before final acceptance.

Do not assume a backup works because a file exists.

## Object storage durability/retention
R2 objects have immutable-style unique keys based on entity/version, not overwrite-by-name for evidence/finals. Terms/evidence snapshots keep hashes. Lifecycle cleanup for disposable intermediates is explicit and audited.

## Health/monitoring
Public reduced `/healthz`, internal `/readyz`, worker heartbeat, backup heartbeat, scheduled reconciler heartbeat. Better Stack Free monitors public health and heartbeats. Owner PWA has a health screen summarizing web/API/DB/queue/worker/storage/backup freshness without exposing internals/secrets.

## Incident if a secret is exposed
1. Stop using/share path; do not paste the secret again.
2. Rotate/revoke the exposed credential at provider immediately.
3. Remove it from runtime/repo history where applicable; assume copies may persist.
4. Inspect provider/audit logs for unauthorized use.
5. Update secret store and redeploy.
6. Record redacted incident note and affected time window.
7. Reconcile possible cost impact against the $56.03 cap.

## Dependency/CI security
- dependency lockfiles committed;
- GitHub Dependabot alerts/updates enabled where available on Free;
- CI runs unit/contract tests, secret scan, lint/type checks, migration validation;
- production images pinned by digest after validation;
- monthly/urgent dependency security patch process;
- no third-party GitHub Action pinned only to mutable branch; pin to trusted major/tag or commit per security policy.

## Reliability under partial failure
- OpenAI down: AI jobs retry/block; existing ready clips remain available.
- R2 down: no render marked ready until final upload/hash verified.
- Supabase down: mutations fail safely; no Redis-only writes count as truth.
- Redis down: new async dispatch pauses; queued DB jobs recover after Redis returns.
- Worker crash: lease expires and reconciler safely retries.
- Better Stack down: app still functions; monitoring is degraded and visible.
- Cost provider usage endpoint unavailable: estimates remain and reconciliation is delayed; optional paid work may be throttled conservatively.

## C00 Round-2 auth-route freeze
Canonical V1 auth routes are exactly `GET /login`, `POST /auth/login`, `POST /auth/recover`, `GET /auth/confirm?token_hash=...&type=invite|recovery`, `GET /auth/set-password`, `POST /auth/set-password`, and `POST /auth/logout`. No `/auth/callback` or authorization-code callback exists in V1. Supabase Invite and Recovery templates point to `/auth/confirm` and are verified server-side with `verifyOtp`.

## C00 Round-2 health and Redis security freeze
The only unauthenticated public infrastructure route is `${HONOR_PUBLIC_ORIGIN}/healthz`, proxied by Caddy to `HONOR_INTERNAL_API_ORIGIN + /healthz`, returning only `{"status":"ok"}`. Detailed readiness is owner-authenticated at `/api/readyz` through Next.js and internal FastAPI `${HONOR_INTERNAL_READINESS_PATH}` (`/readyz`).

Redis is never exposed on a host/public port. `REDIS_PASSWORD` is a server-only minimum-32-random-byte credential; Redis starts with `requirepass`, and API/Celery use authenticated URLs constructed at runtime. Secret values are redacted from process/log output. A missing/invalid password must fail queue/cache startup closed rather than silently falling back to unauthenticated Redis.

`AUTH_ROUTE_SET_V1: GET /login | POST /auth/login | POST /auth/recover | GET /auth/confirm | GET /auth/set-password | POST /auth/set-password | POST /auth/logout`

The machine-readable V1 route set is `HONOR_AUTH_ROUTES.json`.

### Canonical Redis V1 startup/auth contract
Redis is reachable only on the internal Docker Compose network and publishes no host port. The container command/config contract is equivalent to `redis-server --protected-mode yes --requirepass "$REDIS_PASSWORD" --appendonly yes`; the secret is supplied from the root-owned server secret environment at container start, never committed and never printed. API/worker construct `redis://:${REDIS_PASSWORD}@${REDIS_HOST}:${REDIS_PORT}/<db>` server-side. Celery broker DB is `1`; result backend DB is `2`; HONOR cache/lease DB is `0`. A missing or wrong password must fail closed.

Credential mapping machine authority: `HONOR_SECRET_ENV_REGISTRY.json`.


## R2 credential separation — Round 3
`R2_MEDIA_ACCESS_KEY_ID/R2_MEDIA_SECRET_ACCESS_KEY` are bucket-scoped to media and are available only to API/worker/media. `R2_BACKUP_ACCESS_KEY_ID/R2_BACKUP_SECRET_ACCESS_KEY` are bucket-scoped to backups and are available only to backup/restic. Next.js/browser receives neither. Restic receives the backup pair under its S3-compatible `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` names only inside that container.

Rotation: create a same-scope replacement token, update only its secret pair, restart only affected consumers, run redacted bucket-specific verification, then revoke the old token.

Monitoring secrets are mapped as follows: `BETTERSTACK_API_TOKEN` is optional setup-only server secret; `BETTERSTACK_BACKUP_HEARTBEAT_URL` is injected only into backup; `BETTERSTACK_WORKER_HEARTBEAT_URL` only into worker. Heartbeat URLs are treated as secrets because the token is embedded in the URL.

## Canonical credential/env receiver matrix
Machine authority: `HONOR_SECRET_ENV_REGISTRY.json`. No credential below belongs in browser/client JavaScript or ordinary logs.

| Variable | Store / permitted receiver | Security rule |
|---|---|---|
| `DATABASE_APP_URL` | root-owned runtime env; API + worker | `honor_app`, NOBYPASSRLS, no table ownership |
| `DATABASE_ADMIN_URL` | root-owned admin/backup env; migration/bootstrap/backup only | never normal API/worker/browser runtime |
| `REDIS_PASSWORD` | root-owned runtime env; Redis/API/worker/Celery | minimum 32 random bytes; authenticated internal network only |
| `R2_MEDIA_ACCESS_KEY_ID`, `R2_MEDIA_SECRET_ACCESS_KEY` | root-owned runtime env; API/worker/media | Object R/W scoped only to `honor-media` |
| `R2_BACKUP_ACCESS_KEY_ID`, `R2_BACKUP_SECRET_ACCESS_KEY` | root-owned backup env; backup/restic | Object R/W scoped only to `honor-backups`; mapped inside container to AWS-compatible names |
| `RESTIC_PASSWORD` | root-owned backup env; backup/restic only | separate from R2 credential; rotate with documented Restic procedure |
| `OPENAI_API_KEY` | root-owned runtime env; API/worker/Polli | never browser; project budget is defense-in-depth |
| `BETTERSTACK_API_TOKEN` | root-owned monitoring setup env | optional; setup-only |
| `BETTERSTACK_BACKUP_HEARTBEAT_URL`, `BETTERSTACK_WORKER_HEARTBEAT_URL` | root-owned backup/worker env | secret URLs; redact query/path tokens |
| `RUNPOD_API_KEY` | unset at launch | deferred GPU only after approved CHANGE REQUEST/activation |
| `DEPLOY_SSH_PRIVATE_KEY` | GitHub Actions **repository secret only** | never stored in repo/server app env/chat; dedicated deploy key |

R2 runtime and backup credentials are intentionally separate. Cross-bucket access is a failed acceptance test.

## Transaction-local database identity and immutable provenance
`honor.owner_user_id` is request/job identity and MUST be set only with `SELECT set_config('honor.owner_user_id', $1, true)` (or exact `SET LOCAL` equivalent) after `BEGIN`. The third argument `true` is non-optional. Session-global owner identity is forbidden on pooled connections. Commit/rollback clears the local setting; a reused connection must authorize nothing until the next transaction establishes identity. `honor_app` has schema USAGE only, no CREATE, no object ownership, no BYPASSRLS, no runtime DELETE, no current V1 sequence grants, and EXECUTE only on the exact runtime helper/guard allowlist frozen in `HONOR_DB_ACCESS_MATRIX.json`; every other HONOR-created function is explicitly PUBLIC-revoked and is either admin-only or unexecutable by `honor_app`.

Rights and rights↔campaign applicability are historical provenance with **function-only runtime append** through `honor_commit_source_rights_version(...)`; direct `honor_app` INSERT/UPDATE/DELETE is not granted. Edit plans, audio plans, terminal QC rows, render manifests, events, and audits are runtime append-only as frozen by the access matrix. Immutability triggers reject UPDATE/DELETE even if a future grant drifts. Material revisions are new versioned rows.

## Round-5 database function privilege disposition
Every HONOR-created function explicitly revokes PUBLIC EXECUTE. Runtime RLS/trigger helpers are allowlisted in `HONOR_DB_ACCESS_MATRIX.json`; the submission/check-in transition predicate helpers are admin/reference-only and are not granted to `honor_app`. Unlisted function execution remains forbidden. Cross-record/version/provenance-lock triggers execute under the transaction-local owner context and do not grant ownership, DELETE, BYPASSRLS, or unrestricted mutation.


## Round-6 downstream integrity security boundary

Same-parent lineage is enforced at the database boundary, not trusted to API callers: campaign/snapshot, post/clip/account/platform, submission/post/campaign, analytics observation/check-in/post, and earning/post/evidence/campaign relationships are composite-FK or guarded invariants. Manual post recording locks the clip row and atomically advances READY -> POSTED in the same transaction.

`source_rights` and `source_rights_campaigns` are direct SELECT-only for `honor_app`; their only runtime write authority is the narrowly scoped SECURITY DEFINER `honor_commit_source_rights_version(...)`, which requires transaction-local owner authorization and inserts the rights version plus complete campaign applicability atomically. `earnings` transition history is similarly function-controlled: runtime cannot directly insert `earning_state_transitions`; only `honor_transition_earning(...)` may append the transition and update current state atomically. Both functions have PUBLIC EXECUTE revoked and are exact allowlist entries.

## Round-7 integrity functions

The database adds explicit PUBLIC-EXECUTE revocation and exact `honor_app` EXECUTE disposition for campaign-rule guard/activation/mirror, current-rights selection, candidate/transcript lineage, allocation history, lifecycle guards, generation-history guard and experiment-history guard. Runtime still owns no tables, has no BYPASSRLS and no general DELETE.

## Round-7 runtime mutation boundary
The runtime role cannot update immutable campaign rule rows, candidates, committed allocations, or exposed experiment assignment identity. Current campaign mirror columns are function-controlled by `honor_activate_campaign_rule_snapshot()`. Rights action checks are time-aware and select the latest source-rights version available at the action timestamp before checking stage authorization; later grants cannot authorize earlier work and later narrowing/revocation blocks future paid work without rewriting history.

## Round-11 immutable human/audio evidence

Restriction OWNER_REVIEW evidence is bound to a terminal immutable owner action and its `resolution_sha256`; caller-supplied historical `resolved_at` cannot manufacture retroactive approval. `owner_actions` terminal context and resolution cannot be rewritten or reopened.

Audio asset rights are least-permission and fail closed. Runtime services have SELECT-only catalog access. Material audio asset rights/provenance are immutable versions; only one-way `active=true -> false` future-use revocation is permitted administratively. Automatic embedding rechecks current eligibility before paid rendering and again at manifest admission.

### PRECOMMIT human-review integrity
Restriction owner review is not a free-form approval. `RESTRICTION_COMPLIANCE` owner resolutions are `PRECOMMIT`, DB-timed, terminal and hash-bound. A reserved future target UUID/version/hash replaces the former circular target-existence requirement. Candidate/source/campaign/sealed-rule/restriction context must already exist at resolution. The final edit-plan or posting-recommendation guard consumes the review only when target UUID, version, hash and exact lineage all match and the review/proof predate the DB-authored commit/revision. This preserves no-retroactive-approval semantics.
