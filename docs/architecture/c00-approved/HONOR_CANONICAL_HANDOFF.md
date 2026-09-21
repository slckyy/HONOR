> HONOR C00 frozen specification — research date 2026-09-20.
> Month-1 hard operating ceiling: $56.03 USD. Later builders may not silently change frozen contracts.

# HONOR C00 — Canonical Handoff

## 1. Authority and scope
This package is the authoritative C00 build handoff for HONOR. It freezes the initial architecture, repository layout, data semantics, API/event/job contracts, Polli tools, media/audio/QC rules, security posture, visual constitution, provider choices, and the controlled end-to-end acceptance proof. It does **not** claim the product is implemented.

If any later builder believes a frozen contract must change, they must submit this exact structure and wait for Checkpoint Manager approval:

```text
CHANGE REQUEST
- requested change
- reason
- impacted files/contracts
- migration/compatibility effect
- test plan
```

Until approved, the C00 contract remains authoritative.

## 2. Product mission
HONOR converts legitimate campaign opportunities and authorized source material into polished, post-ready short-form video, then learns from real posting, analytics, approval, payout, edit, hook, and audio outcomes.

Owner loop:
`OPEN HONOR → GENERATE TOMORROW → review → manually post in native app → record URL → submit if required → complete check-ins → ask Polli`.

V1 never automates social publishing. It may recommend where/when/how to post, generate copy, and track state; the owner performs posting in native apps.

## 3. Frozen starting topology
- 3 content identities.
- Each mirrored across TikTok, Instagram Reels, and YouTube Shorts.
- 9 starting social accounts total.
- This is account topology, not a daily posting quota.
- No bot farms, spam, account inflation, CAPTCHA bypass, anti-bot evasion, credential theft, session-cookie theft, pirated ingestion, or fake access permissions.

## 4. Frozen technical baseline
- **Monorepo:** one canonical private GitHub repository named `HONOR`.
- **Web:** Next.js 16.3.3 App Router PWA, TypeScript, Node 22 LTS, Tailwind only as a utility layer, bespoke design system.
- **API:** Python 3.13.15 + FastAPI 0.141.1.
- **Async jobs:** Celery 5.6.x + Redis Open Source 8.10.1. Redis is dispatch/coordination only; PostgreSQL is durable job truth.
- **DB/Auth:** Supabase Free for Month-1 controlled pilot; Postgres is authoritative transactional store and Supabase Auth handles owner authentication. Upgrade path to Pro is prepared but not paid in Month 1 unless a change request is approved.
- **Object storage:** Cloudflare R2 Standard.
- **Compute:** DigitalOcean Basic Droplet, Regular CPU, 4 GiB RAM / 2 vCPU / 80 GiB SSD, listed at $24/month at research time.
- **Containers:** Docker Engine + Docker Compose.
- **Edge/TLS:** Caddy 2.x, automatic HTTPS once a domain is attached.
- **Media:** FFmpeg 9.0.2, OpenCV 4.14.x; CPU-first; render concurrency 1 in Month 1.
- **OpenAI routine reasoning:** `gpt-5.6-luna` by default; `gpt-5.6-terra` for deeper multi-factor analysis. `gpt-5.6-sol` is disabled by default in Month 1 and requires explicit owner approval/config override.
- **Transcription:** `gpt-4o-mini-transcribe` default; `gpt-transcribe` retry/quality escalation; diarization only when multi-speaker structure materially needs it.
- **Polli voice:** `gpt-live-1` over WebRTC, session created by HONOR server; browser never receives permanent OpenAI API key.
- **Monitoring:** Better Stack Free for uptime + backup/worker heartbeats.
- **Backups:** nightly encrypted logical/export backup via restic to a dedicated private R2 backup prefix/bucket; restore drill required.
- **Optional GPU:** provider-neutral adapter; Runpod Serverless is the first optional adapter, disabled and unpurchased at launch.

## 5. Frozen cost posture
Hard cap is **$56.03 total Month-1 operating spend**.

Budget envelope:
- DigitalOcean fixed infrastructure: **$24.00** planned.
- OpenAI Month-1 project ceiling: **$15.00** planned maximum, with auto-reload off and HONOR's own stricter internal governor.
- Variable/provider-overage contingency: **$12.03**.
- Emergency reserve: **$5.00**.
- Total: **$56.03**.

Expected normal controlled-pilot spend is below the cap; this is not a promise because usage, taxes, exchange rates, provider billing lag, and overages can vary. `HONOR_COST_GOVERNOR.json` is authoritative: `NORMAL` below **$43.00** exposure; `OPTIONAL_PAUSED` from **$43.00** through `< $51.03` with no new optional paid work; `RESERVE` from **$51.03** through `< $56.03` for emergency/recovery/security/reconciliation only; and `HARD_STOP` at **$56.03** or above. Exposure is counted cash spend + unpaid committed cost + admitted/queued unfunded reservations. Prepaid funding counts in full when purchased and is not double-counted when the credit is consumed.

OpenAI project/provider limits are defense-in-depth, not the sole governor: provider usage reporting can lag. HONOR records its own usage estimates before dispatch and actual usage after response.

## 6. Core invariants
1. Unknown campaign facts stay `UNKNOWN`; null is never silently interpreted as permission.
2. Every campaign rule used for a decision has attributable, timestamped evidence or is explicitly unknown.
3. Every source has provenance and rights eligibility before transcription/rendering.
4. Redis loss cannot erase authoritative job state.
5. Duplicate queue delivery cannot create duplicate financial events, posts, submissions, renders, or payouts.
6. Broken renders never silently become `READY`.
7. Polli uses typed allowlisted tools; no unrestricted SQL, shell, cloud-admin, or arbitrary HTTP tools.
8. Deterministic math comes before model narration for money, budgets, sums, rates, ROI, and target progress.
9. No permanent OpenAI API key, R2 key, Supabase service key, VPS credential, or provider credential appears in browser code.
10. V1 social publishing remains manual.
11. The $4,000/month number is a target-progress denominator only, never a forecast, promise, or guaranteed outcome.
12. `FACTORY SELF-FUNDED` is only true under the frozen finance rule in `HONOR_FINANCIAL_AND_CAMPAIGN_RULES.md`.

## 7. Learning loop
Canonical flow:
`campaign selection → rules normalization → source eligibility → source ingestion → transcription → candidate discovery → scoring → finalist selection → edit plan → audio plan → render → automated QC → schedule/recommendation → manual post → URL record → campaign submission → analytics check-ins → approval/payout → database → performance analysis → future generation consumes outcomes`.

Default check-ins are approximately +2h, +24h, +72h, and final campaign/payout window. They are configuration values per platform/campaign, not hard-coded universal truth.

## 8. Month-1 operating principle
Month 1 is a controlled production pilot, not arbitrary throughput. The allocator can recommend zero output. CPU render concurrency is one. Optional burst GPU is disabled. Source/intermediate retention is aggressively managed to remain inside R2 free usage when practical. Any recommendation that depends on an unknown critical rule is blocked for owner action rather than guessed.

## 9. Builder start rule
Every later builder must first read, in order:
1. `HONOR_CANONICAL_HANDOFF.md`
2. the contract file relevant to its checkpoint
3. `HONOR_FROZEN_REPO_LAYOUT.txt`
4. `CHECKPOINT_C00_REPORT.md`

No builder may replace the architecture with a preferred stack without an approved CHANGE REQUEST.

## Round-2 frozen clarifications
Finance self-funded state is tri-state: `FACTORY_SELF_FUNDED | NOT_SELF_FUNDED | UNKNOWN_NOT_VERIFIED`; unknown cost completeness never becomes false/zero. Internal FastAPI origin is `http://api:8000`; business paths carry `/v1` explicitly. Public liveness is `/healthz`; detailed readiness is owner-authenticated through `/api/readyz`. Redis requires server-only password authentication.


## Governor state authority
Expected normal controlled-pilot spend is below the cap; this is not a promise because usage, taxes, exchange rates, provider billing lag, and overages can vary. `HONOR_COST_GOVERNOR.json` is authoritative: `NORMAL` below **$43.00** exposure; `OPTIONAL_PAUSED` from **$43.00** through `< $51.03` with no new optional paid work; `RESERVE` from **$51.03** through `< $56.03` for emergency/recovery/security/reconciliation only; and `HARD_STOP` at **$56.03** or above. Exposure is counted cash spend + unpaid committed cost + admitted/queued unfunded reservations. Prepaid funding counts in full when purchased and is not double-counted when the credit is consumed.

## Cost governor state freeze
- `NORMAL`: exposure `< 43.000000`; optional paid work requires post-admission exposure `< 43.000000`.
- `OPTIONAL_PAUSED`: `43.000000 <= exposure < 51.030000`; no new optional paid work; core-required work only if post-admission exposure remains `< 51.030000`.
- `RESERVE`: `51.030000 <= exposure < 56.030000`; only emergency/recovery/security/reconciliation paid work, and only if post-admission exposure remains `< 56.030000`.
- `HARD_STOP`: exposure `>= 56.030000`; no new paid work.

Projected month-end spend is informational and cannot loosen admission. Provider-reported usage lag cannot override HONOR's pre-dispatch reservation.

## Round-4 final schema/provenance freeze
- Canonical JSON Schemas in `jsonschema/` are single authorities. OpenAPI references structured JSONB contracts rather than weakening or duplicating them.
- Manual posting uses the frozen `clip.posting_recommendation.v1` object and only the timestamp name `recommended_publish_at`. Native audio is a separate platform recommendation and is never baked into HONOR's rendered MP4. Campaign rules override it.
- `edit_plan.v1` and `render_manifest.v1` freeze C03/C04 provenance and deterministic render interchange.
- `source_rights`, `source_rights_campaigns`, `edit_plans`, `audio_plans`, terminal `qc_runs`, and `render_manifests` are immutable/versioned historical records. No retroactive rights rewrite is permitted.
- RLS owner context is transaction-local (`set_config(..., true)`/`SET LOCAL`) and MUST disappear when the transaction ends, including on pooled connection reuse.

## Round-5 integrity additions
Cross-record provenance is now a frozen database invariant. Clips cannot combine unrelated rights/source/campaign/rule/edit/audio records; accepted render lineage is immutable; rights/edit/audio version chains are contiguous and non-forking; `source_rights.expires_at` is the single expiration authority; and `clips.posting_recommendation` is the canonical posting snapshot with database-derived convenience mirrors.


## Round-6 downstream lineage freeze
Campaign terms/evidence snapshots are same-campaign constrained; posts are bound to their clip/account/platform and recorded atomically with READY -> POSTED; submissions, analytics observations, and earnings cannot cross their parent post/campaign/check-in lineage. Rights campaign applicability is committed atomically with each new rights version and cannot be appended later to historical versions. `HONOR_RIGHTS_STAGE_MATRIX.json` is the exact stage-permission authority; false/UNKNOWN rights never upgrade to permission. Timed posting recommendations must be strictly before rights expiration and cannot bypass UNKNOWN campaign timing. Committed audio-plan native guidance is the planning authority and the posting snapshot must agree.

## Round-7 campaign truth and historical decision freeze

`campaign_terms_snapshots.id` identifies an immutable normalized rule snapshot; historical consumption additionally requires its immutable `campaign_rule_set_commits` seal. All 32 normalized rules are immutable rows scoped to that ID and validated by `HONOR_CAMPAIGN_RULE_REGISTRY.json`; UNKNOWN always has a null value. Current `campaigns` scalar fields are query mirrors only. Allocation/media/QC/posting consume the exact historical snapshot and `HONOR_CAMPAIGN_RULE_CONSUMPTION.json`; critical UNKNOWN rules block the affected stage.

Future work uses the latest committed source-rights version available at action time; later evidence never authorizes earlier work and narrowing/revocation never falls back to an older broader version. Candidate/transcript, generation/allocation, experiment assignment, and analytics learning histories are frozen as described in the database contract.

## Round-7 campaign truth and decision-history freeze
`campaign_terms_snapshots.id` identifies the immutable campaign rule snapshot; it is usable only after its immutable `campaign_rule_set_commits` seal. Every normalized rule row is scoped to that ID and is insert-only. `HONOR_CAMPAIGN_RULE_REGISTRY.json` is the exact per-key type/unit/consumer authority for the 32 canonical keys; `HONOR_CAMPAIGN_RULE_CONSUMPTION.json` freezes stage blocking. Current campaign scalar columns are query mirrors only and cannot replace the historical rule snapshot pinned by allocations/edit plans/clips. Future work selects the newest source-rights version available at action time and never falls back to an obsolete broader version. Candidates pin exact successful transcripts; allocations/candidates/experiment assignments are historical decision evidence and are never rewritten after commitment/exposure.

## Round-8 cross-time integrity freeze

Campaign rule history is two-phase: evidence/normalization may be assembled first, then a single DB-authoritative seal commits the exact 32-row set and hash. No decision consumes an unsealed set and no rule can be appended after seal; all verification/evidence/seal/action chronology is monotonic. Superseded snapshots never reactivate; genuine provider reversion creates new evidence and a new sealed snapshot.

Internal authorization times are DB-authored for paid transcription, allocation, edit/audio commit, clip recommendation, render start and render-manifest acceptance. `PLANNED -> RENDERING` rechecks current RENDER authority before cost. Restriction-code semantics, render-audio inner-state behavior, disclosure placement and submission-deadline mirroring are machine-frozen. Experiments are fully predeclared at RUNNING: at least two arms, exactly one control, immutable design/arms afterward, RUNNING-only assignments, one-way DB-authored exposure, and exact assignment↔run/account/clip linkage for causal use.

## Round-9 runtime truth and serialization freeze

The 32-key campaign registry is enforced again at the database seal boundary: a correct `value_type` label cannot hide an invalid value body. V1 edit/audio/clip/posting/render decisions share exactly one sealed campaign rule snapshot. Restriction compliance requires the code-specific proof kind/reference frozen in `HONOR_CAMPAIGN_RESTRICTION_SEMANTICS.json`; owner review is allowed only for the explicitly owner-resolvable codes.

Final uniqueness is atomic at READY acceptance through immutable accepted-signature reservations, and applicable uniqueness QC must be successful. `HONOR_QC_POLICY.json` is the canonical QC hard-gate/applicability authority and the database derives `qc_runs.passed`. Pre-post recommendation revisions are versioned and reauthorized at current DB time. Experiment child mutations serialize on the parent experiment row, and stopping history cannot be rewritten after RUNNING terminates.

## Round-10 placement, proof-lineage and posting-content freeze

Restriction codes now have one canonical rule-key home. The seal boundary independently rejects a legal code under the wrong restriction key or duplicate semantic code. Every active clause has exactly one canonical edit-plan compliance result; COMPLIANT resolves to an immutable `restriction_proof_artifacts` row whose proof kind, rule/campaign/candidate/source target, hashes, evidence time and result are auditable. Owner-review proofs must resolve through a matching RESOLVED owner action and remain limited to the three frozen owner-resolvable codes.

A null audio plan means exactly zero render-safe MUSIC/SFX assets and cannot turn UNKNOWN/operational render-audio policy into QC N/A. Claim-bearing posting revisions use the centralized consuming-stage matrix and require fresh proof bound to the exact recommendation version and posting-content hash. Experiment-arm id, parent experiment and creation time are immutable; UPDATE/DELETE serialize on the original parent.

## C00 Round-11 integrity additions

Round 11 freezes recommendation-version-complete posting restriction proofs, exact render-safe audio allowed-use eligibility at plan/render/manifest time, immutable audio asset provenance with one-way revocation, an immutable DB-authored owner-action lifecycle for human restriction review, explicit experiment/assignment primary identity immutability, and truthful null-audio manifest claims. These additions do not alter approved providers, topology, budgets, manual posting or visual behavior.

Round 12 removes the OWNER_REVIEW creation-order deadlock without weakening review evidence. Restriction-compliance human review is PRECOMMIT: the immutable owner decision binds a reserved target UUID/version/hash and existing sealed campaign/candidate context, then the immutable proof is consumed only by an exact later edit-plan or posting-recommendation version. The release inventory is exact: no caches/temp files and no unmanifested regular files.
