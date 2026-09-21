> HONOR C00 frozen specification — research date 2026-09-20.
> Month-1 hard operating ceiling: $56.03 USD. Later builders may not silently change frozen contracts.

# Acceptance Criteria

Final system acceptance requires a controlled proof with real durable artifacts and evidence, not screenshots of mocked success. A test campaign/source may be owner-owned or otherwise authorized; no live campaign terms may be invented.

## Required E2E proof
1. Owner opens installed/standalone-capable HONOR PWA on iPhone.
2. `Generate Tomorrow` initiates one durable generation run.
3. System selects or owner selects campaign; normalized rules and evidence are visible; unknowns remain UNKNOWN.
4. Source eligibility is established with provenance/evidence.
5. Source ingests and is hashed/stored.
6. Transcript is produced and model/cost logged.
7. Candidates are discovered, scored, and ranked with persisted features.
8. Finalist is selected with rationale.
9. Edit plan is created.
10. Music/SFX plan is created where allowed, including render-safe provenance and/or platform-native audio recommendation.
11. Render job is durable and restart-safe.
12. Finished 9:16 short is rendered with captions and mixed audio.
13. Automated QC runs and all hard READY checks pass; a deliberately broken fixture must fail/eject.
14. Final asset uploads to R2, hash/metadata stored, and clip becomes READY only after verified upload/QC.
15. Clip appears in PWA with exact recommended account/platform/time guidance.
16. From iPhone, owner can play and download/share/save the MP4 using browser-supported flows.
17. Owner can copy caption/title/hashtags.
18. Platform-native audio recommendation is shown when applicable and clearly separate from baked audio.
19. Owner manually posts in native platform app.
20. Owner records post URL in HONOR; POST_RECORDED event emitted.
21. Submission state is tracked, including NOT_REQUIRED when appropriate.
22. +2h/+24h/+72h/final check-ins become due according to configuration.
23. Analytics can be entered/imported without guessing unknown metrics.
24. Historical performance persists and a later generation run reads prior account/edit/audio outcomes.
25. Cost ledger records transcription, reasoning/media-related API usage, infrastructure allocation, and Polli costs where incurred.
26. Cost screen shows actual/estimated, projected month end, remaining $56.03 budget, and reserve state.
27. Test attempts to enqueue paid optional work beyond governor and proves it queues/postpones/blocks rather than spending.
28. Revenue state transitions demonstrate no double counting across accrued/approved/withdrawable/withdrawn.
29. X/$4,000 uses confirmed current-month gross campaign revenue only.
30. Self-funded logic tests TRUE, FALSE, and UNKNOWN/not-verified cases.
31. Polli text returns exact authoritative finance/cost figures from tools with labels.
32. Polli voice works via server-mediated WebRTC session; permanent OpenAI key absent from client/network-visible app config.
33. Polli voice session cost is recorded.
34. Durable queued/running state survives service/Droplet container restart.
35. Duplicate dispatch fixture does not duplicate render/post/ledger effects.
36. Transient job failure retries according to policy; terminal failure has owner-visible reason.
37. No secret appears in client JS bundle, API response, logs, report, screenshot fixture, Git history, or generated media metadata.
38. Nightly backup job produces encrypted restic snapshot to private R2 and heartbeat.
39. Restore drill recreates a clean test database/schema/data set and verifies key row counts/hashes.
40. iPhone health screen shows web/API/worker/backup status.

## Visual acceptance
- Screenshots/video at representative iPhone portrait widths.
- Safe area/notch/Dynamic Island respected.
- 44px minimum touch targets.
- VoiceOver labels on Generate Tomorrow, Polli mic/control, clip actions, finance states.
- Reduced motion tested.
- Polli orb has all seven states and graceful fallback.
- No default controls/generic SaaS/Tailwind-card look.
- Gold reads metallic through controlled tonal/specular system.

## Media fixture acceptance
Test fixtures include:
- single speaker landscape source;
- two-speaker source;
- no-face source;
- low-audio source;
- intentional fade/still so anomaly detector avoids false positive;
- broken/corrupt media;
- excessive caption case;
- duplicate/near-duplicate clip;
- campaign forbidding music/SFX;
- unknown uniqueness rule.

## Contract tests
Must validate OpenAPI/request schemas, event envelopes/names, job transitions, rule keys/unknown semantics, Polli tools, financial equations, cost governor, and DB migration invariants.

## C00 exit versus final product acceptance
C00 itself is acceptable when this frozen handoff package is complete, internally consistent, researched from current official sources, contains no secrets, and makes concrete provider/version/cost choices. It does not claim the E2E proof above is already implemented.

## C00 Round-2 contract regression acceptance
- Auth route scan finds no active `/auth/callback`; all canonical docs list only token-hash `/auth/confirm` for Invite/Recovery.
- Submission graph has one creation set and one transition graph across SQL/Markdown/OpenAPI; `UNKNOWN -> ACCEPTED|REJECTED` is valid, terminal states cannot move.
- Analytics check-in graph has one creation set and one transition graph; direct `PENDING -> COMPLETED` is rejected, while `DUE -> COMPLETED` and late `MISSED -> COMPLETED` succeed.
- Polli JSON and Markdown both freeze 12 identical tools, max 6 calls/turn, max 60/session, identical envelope/source/warning fields, and exact typed result data; no semantic `{}` schema remains.
- Finance tests cover `FACTORY_SELF_FUNDED`, `NOT_SELF_FUNDED`, and `UNKNOWN_NOT_VERIFIED`; the UNKNOWN sample requires `net_profit_usd=null` and `net_profit_truth_state=INCOMPLETE_UNKNOWN`. No boolean self-funded mirror exists.
- Public `${HONOR_PUBLIC_ORIGIN}/healthz` resolves through Caddy to internal `${HONOR_INTERNAL_API_ORIGIN}/healthz`; owner `/api/readyz` resolves through BFF to internal `/readyz` and requires auth.
- Redis without/wrong `REDIS_PASSWORD` fails; correct authenticated Redis/Celery URLs succeed; port 6379 is not publicly published.
- Runtime DB role `honor_app` is NOBYPASSRLS/non-owner, has no DELETE, append-only tables reject UPDATE/DELETE, admin-only class rejects runtime mutation, and browser/Supabase service roles have no HONOR DML grants.
- Every OpenAPI error response validates only operation/status-specific codes.

- Operation/status error schemas reject unrelated taxonomy values; upload-only errors cannot validate on finance endpoints, and 401 accepts only `AUTH_REQUIRED|AUTH_INVALID`.
- DB RLS test proves `owner_profiles` uses a non-recursive direct owner policy and every other table is covered exactly once by `HONOR_DB_ACCESS_MATRIX.json`.


# Round-3 semantic acceptance additions
- Governor behavior is exact: `42.99 NORMAL`, `43.00 OPTIONAL_PAUSED`, `43.01 OPTIONAL_PAUSED`, `51.02 OPTIONAL_PAUSED`, `51.03 RESERVE`, `56.02 RESERVE`, `56.03 HARD_STOP`. No optional paid admission at or above `$43.00`.
- Prepaid purchases count at purchase time and are not double-counted when consumed; provider reporting lag cannot bypass reservations.
- Public Caddy has no FastAPI business `/v1/*` route; `/api/v1/*` is BFF-mediated; `/readyz` is private; `/healthz` is minimal liveness.
- Human API registry and exact embedded request/response schemas match OpenAPI.
- Every SQL JSONB column maps to an included validated C00 schema; C01 implements rather than designs these V1 shapes.
- Owner bootstrap proves exactly one authorized owner profile and `403 OWNER_FORBIDDEN` for another authenticated Supabase user.
- Separate R2 media and backup credentials are bucket-scoped and cross-bucket access fails.

# C00 Round-3 final consistency regression acceptance
- Governor boundary mapping is exact: `42.99 NORMAL`; `43.00 OPTIONAL_PAUSED`; `43.01 OPTIONAL_PAUSED`; `51.02 OPTIONAL_PAUSED`; `51.03 RESERVE`; `56.02 RESERVE`; `56.03 HARD_STOP`. The test also validates action admission using post-admission exposure: optional cannot cross/reach $43.00; core-required cannot cross/reach $51.03; reserve emergency cannot cross/reach $56.03.
- Prepaid funding is counted at purchase in cash exposure; usage funded by remaining already-counted credit does not add the same dollars again; queued work above remaining credit adds only the excess; provider reporting lag cannot remove pre-dispatch reservations.
- Production network test proves Caddy has no public FastAPI `/v1/*` route. Browser business traffic is `/api/v1/* -> Next.js BFF -> http://api:8000/v1/*`; authenticated readiness is `/api/readyz -> BFF -> /readyz`; only `/healthz` may proxy directly to FastAPI.
- `HONOR_API_CONTRACTS.md` and `HONOR_API_HUMAN_REGISTRY.json` are generated from OpenAPI; operation IDs/methods/paths/auth/idempotency/request schema IDs and embedded resolved request/response schemas must be identical.
- Every SQL JSONB column maps to exactly one included validated C00 schema. Product-significant JSONB cannot be delegated to C01 design. The only opaque schemas are `provider_usage.raw.v1` and `audit.metadata_redacted.v1`, with enforced depth/redaction bounds and no product-logic dependency.
- Supabase bootstrap proves the invited Auth owner's UUID equals `HONOR_OWNER_USER_ID`, one active `owner_profiles` row matches it, and a separately authenticated non-owner receives `403 OWNER_FORBIDDEN`.
- R2 runtime media and Restic backup use distinct one-bucket credentials; each must fail against the opposite bucket. AWS-compatible Restic credential names exist only as container aliases from `R2_BACKUP_*`.
- Every credential variable in `.env.example` is represented in `HONOR_SECRET_ENV_REGISTRY.json` and documented in owner setup/security.

## Round-4 schema/provenance acceptance
- OpenAPI structured fields listed in `x-honor-structured-json-schema-map` use the exact packaged JSON Schema via `$ref`; no weaker unrestricted object is accepted.
- Posting recommendation uses only `recommended_publish_at` and validates campaign-required mentions/disclosure/submission instructions plus native-audio ALLOWED/PROHIBITED/UNKNOWN/NOT_APPLICABLE cases.
- Edit plan carries immutable source hash, rule snapshot IDs, rights ID/hash, version/supersession, canonical plan fingerprint, timing-safe cuts, deterministic layout/captions/emphasis/audio cleanup/output requirements, and mandatory render-manifest schema ID.
- A terminal immutable `render_manifests` row records source/edit/audio hashes/versions, licensed render-safe assets, renderer versions, material parameters, output hash, and passed QC.
- `source_rights`/`source_rights_campaigns` are runtime SELECT-only and function-committed; `edit_plans`/`audio_plans` are insert-only; none may be updated/deleted by runtime, and changes create new versions/rows. Existing clip provenance remains unchanged and later evidence cannot manufacture retroactive permission.
- `qc_runs` are terminal-at-insert; retries create rows. A clip cannot enter READY without a passed immutable QC row plus matching immutable render manifest.
- On a reused pooled DB connection, transaction A's `honor.owner_user_id` must be absent in transaction B until B executes transaction-local `set_config(..., true)`.

## Round-5 cross-record integrity acceptance
- Every registered JSONB SQL default validates against its exact schema; no invalid `{}` default survives.
- A clip insert/update is rejected when rights belong to another source, rights are not associated with its campaign, the rule snapshot belongs to another campaign, edit-plan candidate/source/run differs, edit-plan JSON provenance differs, or an audio plan belongs to another edit plan.
- Source-rights/edit/audio version chains reject cross-identity predecessors, skipped versions, and forks.
- `source_rights.expires_at` is the only expiration authority; UNKNOWN never manufactures permission.
- Once a render manifest is accepted or a clip is READY, every protected provenance/output field rejects in-place mutation; lifecycle-only READY -> POSTED/ARCHIVED remains possible.
- Posting recommendation is canonical; caption/title/hashtags are derived mirrors and cannot diverge; recommendation locks when a post exists or state becomes POSTED/ARCHIVED.
- Every HONOR-created function has PUBLIC EXECUTE revoked and a disposition matching `HONOR_DB_ACCESS_MATRIX.json`.


## Round-6 downstream-lineage acceptance

- Campaign A cannot select Campaign B's current terms snapshot; a Campaign A rule cannot cite Campaign B's evidence snapshot.
- A post cannot use an account different from its clip, a platform different from the account/posting recommendation, or a `native_audio_used.platform` different from the post platform. New post recording is accepted only from READY and atomically creates the post plus `READY -> POSTED`; failed insertion cannot leave an incompatible clip state. Idempotent retries do not create duplicate posts.
- A submission cannot name a campaign different from its post's clip campaign.
- An analytics observation cannot reference a check-in belonging to another post.
- An earning cannot pair a post or evidence snapshot from another campaign. Direct transition-history insertion and direct earning-state UPDATE are unavailable to runtime; the approved transition function proves state/history/amount atomicity.
- An already-committed source-rights version cannot gain another campaign association later. New applicability requires a new contiguous rights version committed together with its complete relationship set.
- Rights-stage fixtures prove each required flag independently: false/UNKNOWN `may_ingest`, `may_transcribe`, `may_edit`, `may_render`, `may_publish`, `commercial_use`, or `derivative_edits` blocks the applicable stage; publication additionally requires allowed platform + `platform_limits.<platform>.allowed=true`.
- Posting recommendation time immediately before rights expiration may validate; exactly at or after expiration must fail. UNKNOWN campaign timing cannot be silently treated as permission to recommend a time.
- Native-audio posting snapshot cannot contradict its committed audio-plan authority, platform, rule snapshot, or frozen campaign rule state. Platform-native audio is never baked into HONOR's rendered MP4.

## Round-7 acceptance additions

C00 validation must prove: nested native-audio platform equality; immutable snapshot-scoped 32-key campaign truth; KNOWN evidence/UNKNOWN-null semantics; exact key-specific rule typing; scalar mirror consistency; critical-rule stage consumers; UNKNOWN account region/followers block eligibility; action-time/current-version rights; required attribution and most-restrictive duration; lifecycle creation/transition guards; candidate-to-successful-transcript lineage; immutable candidate/run/allocation history; structured speaker/topic/hook/confidence support; nullable completion/watch/follower learning metrics; and minimal immutable experiment assignment persistence.

## C00 Round-8 integrity regression acceptance

- An incomplete/unsealed campaign rule set cannot be consumed; sealing requires exactly 32 keys, closes INSERT/UPDATE/DELETE history, and enforces evidence <= verification <= seal <= action chronology.
- A superseded campaign snapshot cannot become current again; later verification/reversion creates a later evidence/rule snapshot and seal.
- Caller-supplied historical/future timestamps cannot bypass current rights on paid transcription, allocation, edit/audio planning, clip recommendation or render-manifest acceptance; `PLANNED -> RENDERING` revalidates RENDER rights before cost and READY revalidates again.
- Every frozen restriction code has positive/negative machine fixtures and exact source/edit/content/uniqueness proof semantics; unrepresentable provider nuance remains UNKNOWN.
- Render-audio PROHIBITED/UNKNOWN/class/density states constrain the actual audio plan and exact render-safe manifest assets; operational instructions survive into compliance/QC evidence.
- Disclosure CAPTION/VIDEO/BOTH/PROVIDER_SUBMISSION placement survives posting/edit/render/QC/submission; VIDEO/BOTH is never reduced to caption-only text. Submission deadline exactly mirrors sealed campaign `deadline_at` when KNOWN and blocks when UNKNOWN.
- DRAFT->RUNNING requires >=2 arms and exactly one control without simultaneous design mutation; no later arm/design mutation; assignments only while RUNNING with DB-authored assignment/exposure chronology and exact unit lineage.
- JSON Schema/$ref, OpenAPI JSON/V1/YAML equivalence, human API parity, DB function/privilege checks, secret scan, budget/auth/provenance regressions, SHA-256 manifest and extracted-ZIP validation remain intact.

## Round-9 C00 review additions

Checkpoint review must verify database-enforced per-key campaign typed-value validation, exactly one rule snapshot across edit/audio/clip/render lineage, code-specific restriction proof kinds, race-safe final uniqueness reservations, canonical derived QC truth, DB-time recommendation revision authorization, parent-row experiment serialization, and immutable stopping history. These are C00 contract checks only; they do not authorize C01 implementation.

## Round-10 C00 review additions

Checkpoint review must reject wrong-rule-key restriction placement, duplicate/contradictory clause compliance, arbitrary proof strings, unrelated/unresolved/late owner review, null-plan manifests containing render-safe assets, render-audio N/A that masks applicable policy, stale posting-content proof after a recommendation revision, and experiment-arm id/parent/creation-time rewrites. The posting check must be driven by the frozen consuming-stage matrix rather than by an unversioned free-form convention.

## Round-11 acceptance additions

- Every material posting recommendation version has exact posting-stage restriction evidence bound to that version; prior-version proof is never silently carried forward.
- Automatic render-safe MUSIC/SFX passes the frozen active/render-safe/commercial/derivative/platform/no-campaign-restriction/no-attribution/license-evidence predicate at plan commit, render start and manifest admission.
- Render manifest MUSIC/SFX UUID, kind, SHA-256 and license reference exactly match immutable canonical asset versions and committed-plan membership.
- Audio asset material provenance/rights are immutable; future-use deactivation is one-way.
- Owner actions are OPEN-only at creation, terminal transitions are DB-timed, terminal resolution/context is immutable and owner-review proof binds the resolution hash.
- `experiments.id/created_at` and `experiment_assignments.id` are explicitly immutable.
- Null-audio manifests cannot claim planned music/SFX in `audio_rule_compliance`.

### Round 12 checkpoint additions
- PRECOMMIT OWNER_REVIEW has an acyclic executable order for edit plans, initial posting recommendations and posting revisions.
- Owner resolution binds `review_phase`, reserved target UUID, target version, subject SHA-256, campaign, sealed rule snapshot, candidate and restriction code without requiring the not-yet-committed target row.
- Consumption rejects target/version/hash/context mismatch, reuse across versions/targets, unresolved/late review, and retroactive review.
- Canonical release ZIP contains no `__pycache__`, `.pyc`, temp or extraction artifacts; every regular file except `MANIFEST_SHA256.txt` is manifested.
