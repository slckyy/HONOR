> HONOR C00 frozen specification — research date 2026-09-20.
> Month-1 hard operating ceiling: $56.03 USD. Later builders may not silently change frozen contracts.

# Deployment Plan

## Deployment target
Single DigitalOcean Basic Regular Droplet, 4 GiB RAM / 2 vCPU / 80 GiB SSD, Ubuntu 24.04 LTS default. C00 price assumption: $24/month. Create only at deployment checkpoint so Month-1 billing clock is not started prematurely.

## DNS/domain
A stable HTTPS hostname is required for final production-like iPhone PWA use. Domain purchase is deferred because exact name/price is unknown. Use an existing owner-controlled domain if available. Once chosen, point A/AAAA record to Droplet and let Caddy obtain/renew TLS automatically.

## Containers
Production Compose services:
- `caddy`
- `web` (Next.js)
- `api` (FastAPI)
- `worker` (Celery, concurrency configured conservatively; media queue concurrency 1)
- `scheduler`/reconciler (Celery beat or dedicated process with single-leader lock)
- `redis` (8.10.1, internal-only network)

Postgres/Auth and R2 are external managed services.

## Network
- only 80/443 public at host firewall; SSH restricted and key-only;
- app containers on private Compose network;
- Redis never published publicly;
- Caddy routes normal application traffic to Next.js only. **Caddy MUST NOT route FastAPI `/v1/*` publicly.** Browser `/api/v1/*` is handled by the Next.js BFF, which forwards to internal `http://api:8000/v1/*`;
- provider outbound HTTPS allowed from API/worker; render sandbox has no network where feasible.

## Resource controls
- worker media concurrency 1;
- set memory reservations/limits to prevent one render taking down web/API;
- temp media under dedicated volume/path with quota/cleanup;
- Redis memory cap and eviction policy chosen for broker workload;
- Next.js production build done in CI/build stage, not repeatedly on 4 GiB host if avoidable;
- use swap only as emergency cushion.

## CI/CD
GitHub Free private repo. Workflow:
1. lint/type/unit/contract tests;
2. secret scan;
3. build web/API/worker images;
4. integration tests using disposable services where practical;
5. on protected main/deploy approval, connect to Droplet via stored deploy credential;
6. pull/build signed/pinned artifacts, run migrations once, `docker compose up -d`;
7. health checks;
8. record deployment version.

Keep Actions usage inside included free quota. If quota is near exhaustion, do not incur paid minutes; run only mandatory workflow or postpone optional CI.

## Migrations
- migration is applied before app version requiring it;
- backward-compatible expand/migrate/contract pattern for destructive changes;
- take fresh logical backup before risky migration;
- migration lock prevents concurrent apply;
- migration version shown in health/admin screen.

## Backup job
Nightly:
1. create consistent logical Postgres backup/export with least-privileged credentials;
2. include migration/schema metadata;
3. restic encrypts and sends to private R2 backup repository;
4. verify snapshot listing/check;
5. send Better Stack heartbeat only after success; `/fail` on failure where configured;
6. retention prune within storage budget.

## Deploy sequence
### Phase A — pre-spend
- GitHub private repo.
- Supabase Free project.
- local/CI development and contract tests.
- Better Stack free workspace.

### Phase B — AI/storage integration
- OpenAI HONOR project; initial $10 prepaid, auto-reload off, <=$15 Month-1 allocation.
- R2 Standard subscription/buckets when needed.
- prove cost logging in non-production fixtures.

### Phase C — VPS
- re-verify DigitalOcean plan is still <= frozen planned price; if not, STOP and issue CHANGE REQUEST/budget review.
- create Droplet and SSH key.
- install Docker from official repo.
- deploy Compose stack with no domain yet if doing restricted staging.

### Phase D — HTTPS/PWA
- attach owner domain or approved purchased domain.
- Caddy automatic HTTPS.
- verify manifest/service worker/install behavior on iPhone.

### Phase E — final controlled E2E
Run acceptance contract and restore drill.

## Rollback
- application: redeploy previous known-good image/tag while keeping forward-compatible DB.
- failed migration: prefer forward repair; destructive rollback only from tested migration plan/backup.
- render worker can be independently stopped without losing DB job truth.

## Operations from iPhone
PWA `/health` or equivalent shows: public web/API status, worker last heartbeat, queued/retrying/blocked jobs, last backup success, database/storage connectivity summary, Month-1 cost state. No SSH is required for routine owner operation.

## Scaling after Month 1
Not automatic. Evidence-based change request may move worker to larger CPU, managed Redis, Supabase Pro, or burst GPU. The first optional GPU adapter is Runpod Serverless because it can scale to zero and bills by usage; no always-on GPU is permitted at launch.

## C00 Round-2 auth-route freeze
Canonical V1 auth routes are exactly `GET /login`, `POST /auth/login`, `POST /auth/recover`, `GET /auth/confirm?token_hash=...&type=invite|recovery`, `GET /auth/set-password`, `POST /auth/set-password`, and `POST /auth/logout`. No `/auth/callback` or authorization-code callback exists in V1. Supabase Invite and Recovery templates point to `/auth/confirm` and are verified server-side with `verifyOtp`.

## C00 Round-2 internal/public routing freeze
- `HONOR_INTERNAL_API_ORIGIN=http://api:8000` (server-only; no `/v1` suffix).
- Next.js business BFF base remains browser-safe `NEXT_PUBLIC_HONOR_BFF_BASE=/api/v1`; BFF appends `/v1/...` to the internal origin.
- Caddy public `GET /healthz` -> internal `http://api:8000/healthz` (`HONOR_INTERNAL_LIVENESS_PATH=/healthz`); public body is liveness-only.
- Owner readiness path `/api/readyz` -> BFF -> internal `http://api:8000/readyz` with owner JWT; dependency detail is never public.

## C00 Round-2 Redis authentication freeze
Redis is Compose-network-only and starts with protected mode plus `requirepass` using server-only `REDIS_PASSWORD` (minimum 32 random bytes, URL-safe encoded). No host port is published. API/worker construct authenticated Redis/Celery URLs at runtime from `REDIS_HOST`, `REDIS_PORT`, `REDIS_PASSWORD`, and DB-number variables. The password is generated on the Droplet, stored only in the root-owned server secret file, never committed/logged/chat-pasted, and rotated by updating the secret plus controlled Redis/API/worker restart.

`AUTH_ROUTE_SET_V1: GET /login | POST /auth/login | POST /auth/recover | GET /auth/confirm | GET /auth/set-password | POST /auth/set-password | POST /auth/logout`

The machine-readable V1 route set is `HONOR_AUTH_ROUTES.json`.

### Canonical Redis V1 startup/auth contract
Redis is reachable only on the internal Docker Compose network and publishes no host port. The container command/config contract is equivalent to `redis-server --protected-mode yes --requirepass "$REDIS_PASSWORD" --appendonly yes`; the secret is supplied from the root-owned server secret environment at container start, never committed and never printed. API/worker construct `redis://:${REDIS_PASSWORD}@${REDIS_HOST}:${REDIS_PORT}/<db>` server-side. Celery broker DB is `1`; result backend DB is `2`; HONOR cache/lease DB is `0`. A missing or wrong password must fail closed.

## Monitoring route freeze
Better Stack HTTP uptime uses public `${HONOR_PUBLIC_ORIGIN}${HONOR_PUBLIC_HEALTH_PATH}` (`/healthz`). DigitalOcean Droplet Monitoring uses the agent and therefore has no public HTTP health target. Any separately configured DigitalOcean HTTP uptime probe must use only the same public `/healthz`. Owner readiness `/api/readyz` is never a public monitor target.


## Frozen R2 credential injection
- Runtime media credential: `R2_MEDIA_ACCESS_KEY_ID` + `R2_MEDIA_SECRET_ACCESS_KEY`, Cloudflare R2 Object Read & Write scoped only to `R2_BUCKET_MEDIA`; injected only into API/worker/media.
- Backup credential: `R2_BACKUP_ACCESS_KEY_ID` + `R2_BACKUP_SECRET_ACCESS_KEY`, Object Read & Write scoped only to `R2_BUCKET_BACKUPS`; injected only into backup/restic.
- Docker Compose maps the backup pair **inside the restic container only** as `AWS_ACCESS_KEY_ID=${R2_BACKUP_ACCESS_KEY_ID}` and `AWS_SECRET_ACCESS_KEY=${R2_BACKUP_SECRET_ACCESS_KEY}` with `AWS_DEFAULT_REGION=auto`.
- Next.js/browser receives neither credential. Rotation is independent by bucket scope.

Production business routing is exactly Caddy -> Next.js -> BFF -> private FastAPI. Direct public Caddy -> FastAPI is permitted only for `/healthz`; never for `/v1/*` or `/readyz`.

## R2 / Restic credential injection freeze
- `honor-media` uses a dedicated Cloudflare R2 **Object Read & Write** token scoped only to that bucket: host secrets `R2_MEDIA_ACCESS_KEY_ID` + `R2_MEDIA_SECRET_ACCESS_KEY`. Only API/worker/media receive them.
- `honor-backups` uses a different **Object Read & Write** token scoped only to that bucket: host secrets `R2_BACKUP_ACCESS_KEY_ID` + `R2_BACKUP_SECRET_ACCESS_KEY`. Only backup/restic receives them.
- Inside the backup/restic container, Compose maps `R2_BACKUP_ACCESS_KEY_ID -> AWS_ACCESS_KEY_ID` and `R2_BACKUP_SECRET_ACCESS_KEY -> AWS_SECRET_ACCESS_KEY`; these are aliases required by the S3-compatible Restic backend, not additional credentials.
- `RESTIC_PASSWORD` is a separate backup-only secret. Next.js/browser receives no R2 or Restic credential.
- Rotation is create replacement same-scope token -> update only the relevant secret pair -> restart relevant consumers -> verify correct bucket succeeds and opposite bucket fails -> revoke old token.
