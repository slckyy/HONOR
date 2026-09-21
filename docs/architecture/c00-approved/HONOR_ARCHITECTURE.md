> HONOR C00 frozen specification — research date 2026-09-20.
> Month-1 hard operating ceiling: $56.03 USD. Later builders may not silently change frozen contracts.

# HONOR Architecture

## System shape
HONOR is a single-owner, iPhone-first PWA backed by a small cloud control plane and a CPU-first media worker.

```text
iPhone Safari / installed PWA
        |
      HTTPS
        |
      Caddy
       | \
       |  \-- public /healthz only --> FastAPI /healthz (liveness only)
       v
    Next.js / BFF
       |  authenticated /api/v1/* and /api/readyz
       v
 private FastAPI http://api:8000
       |
    Postgres (Supabase)
       |
    jobs/events/finance/rules
       |
    Redis broker  <---- Celery worker
    |                       |  intelligence
    |                       |  transcription
    |                       |  FFmpeg/OpenCV render
    |                       |  QC
    |                       v
    +-------------------- Cloudflare R2

Polli voice: iPhone WebRTC <-> OpenAI GPT-Live 1
                         ^
                         | session creation/tool sideband
                       FastAPI
                         |
                 typed deterministic tools
                         |
                      Postgres
```

Production routing invariant: Caddy routes normal application traffic to Next.js. Browser business requests use `/api/v1/*` -> Next.js BFF -> private `http://api:8000/v1/*`; owner readiness uses `/api/readyz` -> BFF -> private `/readyz`. Caddy may directly proxy only public liveness `/healthz` to FastAPI `/healthz`. FastAPI business `/v1/*` is never Internet-routable in production. Browser CORS access to FastAPI is not a V1 path.

## Service boundaries
### `apps/web`
- App Router PWA and install shell.
- Owner review, schedule, clip, analytics, finance, cost, health, and Polli UX.
- Uses short-lived Supabase auth session; no server secrets in client bundle.
- Generates accessible sharing/downloading affordances for final MP4 and copy.
- Offline shell: navigation chrome and last successful read-only snapshot where safe; mutations queue only when explicitly designed for idempotent replay.

### `services/api`
- Canonical `/v1` API.
- AuthN/AuthZ, validation, idempotency admission, provider adapters, presigned media access, Polli session creation, typed read tools.
- Writes durable jobs/events before dispatch.

### `services/worker`
- Celery task execution, periodic analytics reminders, retries, provider polling/imports where compliant, and cost reconciliation.
- No job is considered durable because it exists in Redis; job row in Postgres is authoritative.

### `services/intelligence`
- Rules normalization support, candidate scoring, hook/edit analysis, dynamic allocation, performance analysis, LLM routing.
- Financial math/rule evaluation remains deterministic Python/SQL; model outputs cannot mutate truth directly.

### `services/media`
- Source probing, audio extraction, transcription preparation, moment assembly, face-aware reframe, captions, audio plan execution, render, QC.
- FFmpeg invocation is parameterized and logged; untrusted media is processed in a constrained worker subprocess/container profile.

### `packages/contracts`
- Shared JSON Schema/OpenAPI-derived types, event envelope, enums, rule keys, financial states, Polli tool schemas.

### `packages/design-system`
- Bespoke tokens/components, Polli orb primitives/fallbacks, animation semantics, safe-area primitives, accessibility states.

## Version pins at C00
- Next.js: 16.3.3 Active LTS security-patched line.
- Node.js: 22 LTS (pin exact patch in lock/build image; current researched branch includes 22.23.2).
- Python: 3.13.15.
- FastAPI: 0.141.1.
- Celery: 5.6.3 line.
- Redis Open Source: 8.10.1.
- FFmpeg: 9.0.2.
- OpenCV: 4.14.x rather than the brand-new 5.0 major line for lower integration risk.
- Docker Engine: install current stable from Docker's official Ubuntu repository and pin image digests in deployment.
- Caddy: current 2.x stable; pin container digest in deployment.

Version changes after C00 that alter behavior/contracts require normal dependency PRs; architecture/contract changes require CHANGE REQUEST approval.

## Data ownership
- **Postgres:** canonical structured truth for campaigns, rules, rights, jobs, events, clips, posts, submissions, analytics, finance, costs, audit, Polli tool records.
- **R2:** large binary/JSON artifacts: source files, transcript word timing payloads, intermediate assets retained temporarily, final MP4s, thumbnails, terms snapshots, backups.
- **Redis:** broker, short TTL locks/rate-limit counters, ephemeral worker coordination. Not authoritative.
- **GitHub:** source/config/migrations/docs only. No secrets, raw campaign media, or generated videos.

## Dynamic allocation contract
Allocation is a constrained decision process, not a fixed clip count.

1. Hard-filter combinations with known rule incompatibility, missing rights, unhealthy account, expired/depleted campaign, cost stop, or blocked owner action.
2. Critical unknown campaign facts produce `blocked-owner-action` unless the plan can safely avoid depending on the unknown.
3. Estimate qualified-view and payout distributions from historical account/campaign/edit/audio outcomes with explicit uncertainty.
4. Estimate marginal transcription, reasoning, media, storage, and optional GPU cost.
5. Compute a configurable expected-value score:
   `expected_confirmed_payout - marginal_cost + information_value - uncertainty_penalty`.
6. Apply caps: campaign budget, per-clip payout cap, deadlines, minimum views probability, source uniqueness, account posting health, owner review capacity, and remaining Month-1 budget.
7. Select zero or more experiments. Zero is valid.
8. Persist all inputs, version, rationale components, and confidence so future outcomes can be compared to the recommendation.

No model may bypass hard eligibility/cost rules.

## Polli architecture
- Voice frontend: `gpt-live-1` WebRTC.
- FastAPI creates the Live session using server-held OpenAI credentials; permanent key never enters browser.
- Private tools run server-side and are allowlisted.
- Backend reasoning default: `gpt-5.6-luna`; escalate to `gpt-5.6-terra` when the router marks the request multi-factor/analysis-heavy. Sol off by default Month 1.
- Text fallback calls the same typed tools and backend routing without voice.
- Polli stores enough transcript, tool-result summaries, and session metadata for continuity; raw audio retention is off by default.
- Pull-based interaction; no always-listening mode.

## Reliability model
- Postgres transaction creates job + outbox event; dispatcher publishes to Redis after commit.
- Worker claims job with row-level compare-and-set on state/version.
- Duplicate delivery is safe due to job dispatch token + domain idempotency keys.
- Worker heartbeat and lease detect stuck work.
- Scheduled reconciler republishes durable queued jobs that are missing broker delivery.
- Provider calls use timeouts, retry classification, request IDs, and cost logging.
- Render/AI failures log incurred cost when known.

## Deployment topology
One DigitalOcean Droplet runs Caddy, Next.js, FastAPI, Redis, Celery worker, and scheduled reconciler under Docker Compose. Postgres/Auth and R2 remain managed external services. This avoids paying for several always-on services while preserving clean service boundaries for later scale-out.

Month-1 resource rules:
- 1 media task at a time.
- API/web have memory limits.
- Redis uses maxmemory and persistence only for convenience; no correctness depends on it.
- Worker temp disk quota is enforced and cleaned after each job.
- swap may be configured conservatively as crash protection, not as routine render memory.

## Domain/GPU posture
A custom domain is operationally desirable for the final PWA but is deliberately not purchased at C00 because availability/price are unknown. Existing owner domain may be used later. Runpod Serverless is researched as the first burst adapter but remains disabled and unpurchased until CPU evidence justifies it.

## Round-2 frozen clarifications
Finance self-funded state is tri-state: `FACTORY_SELF_FUNDED | NOT_SELF_FUNDED | UNKNOWN_NOT_VERIFIED`; unknown cost completeness never becomes false/zero. Internal FastAPI origin is `http://api:8000`; business paths carry `/v1` explicitly. Public liveness is `/healthz`; detailed readiness is owner-authenticated through `/api/readyz`. Redis requires server-only password authentication.


## Production routing authority — Round 3
```text
Internet/iPhone -> Caddy
  /healthz -> FastAPI http://api:8000/healthz       [public minimal liveness]
  all application traffic -> Next.js
      /api/v1/* -> BFF -> FastAPI http://api:8000/v1/* [owner JWT]
      /api/readyz -> BFF -> FastAPI http://api:8000/readyz [owner JWT]
```
FastAPI business `/v1/*` is not Internet-routable in production. Internal `/readyz` is not public. Production browser CORS access to FastAPI is not part of V1.

## Round-4 provenance/data-interchange freeze
The media pipeline consumes immutable/versioned `source_rights`, `edit_plans`, and `audio_plans` records. `edit_plan.v1` is the deterministic C03→C04 render instruction contract; `render_manifest.v1` is the immutable terminal record of the accepted render and passed QC. Material revisions create new rows/versions and never rewrite a clip's historical rights/edit/audio provenance. QC rows are inserted only at terminal pass/fail, and READY requires the matching passed QC plus immutable render manifest. Runtime owner identity is established only transaction-locally in PostgreSQL (`set_config(..., true)` / `SET LOCAL`) so pooled connections cannot carry owner context across transactions.
