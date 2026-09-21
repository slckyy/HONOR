> HONOR C00 frozen specification — research date 2026-09-20.
> Month-1 hard operating ceiling: $56.03 USD. Later builders may not silently change frozen contracts.

# Frozen Database Schema

PostgreSQL/Supabase is the authoritative structured source of truth. All primary keys are UUIDv7 (or UUID with sortable generation if extension support differs). Timestamps are `timestamptz` UTC. Money is `numeric(18,6)` USD unless an external currency is explicitly stored with ISO currency code. Every mutable business table includes `created_at`, `updated_at`, and where needed `version bigint` for optimistic concurrency.

## Auth/owner
### `owner_profiles`
`user_id uuid PK/FK auth.users`, `display_name`, `timezone`, `created_at`, `updated_at`.

### `social_identities`
`id`, `name`, `slug UNIQUE`, `brand_notes`, `active bool`.

### `social_accounts`
`id`, `identity_id`, `platform enum(TIKTOK,INSTAGRAM_REELS,YOUTUBE_SHORTS)`, `handle`, `external_account_id nullable`, `status`, `posting_timezone`, `notes`, UNIQUE(identity_id, platform, handle).

### `account_health_snapshots`
`id`, `social_account_id`, `captured_at`, `health enum(HEALTHY,CAUTION,PAUSED,UNKNOWN)`, `account_region nullable`, `follower_count nullable`, `posting_available nullable`, `signals jsonb`, `evidence_uri nullable`, `source`, `created_at`; UNIQUE(id, social_account_id). Region/followers/posting availability are evidence-backed eligibility facts; NULL means UNKNOWN, never a guessed value.

## Campaign/rules/evidence
### `campaigns`
`id`, `provider`, `campaign_url`, `external_campaign_id`, `status enum(DISCOVERED,VERIFYING,ACTIVE,PAUSED,ENDED,REJECTED,UNKNOWN)`, `title`, `currency`, `start_at`, `end_at`, `deadline_at`, `last_verified_at`, `terms_snapshot_id`, `created_at`, `updated_at`; UNIQUE(provider, external_campaign_id) when external id is present; otherwise canonicalized URL uniqueness.

### `campaign_terms_snapshots`
`id`, `campaign_id`, `captured_at`, `source_url`, `storage_object_key`, `sha256`, `capture_method enum(API,PERMITTED_PAGE,OWNER_UPLOAD,MANUAL_ENTRY)`, `notes`.

### `campaign_rule_items`
One immutable row per canonical rule key **per `campaign_terms_snapshots.id` rule-set snapshot**.
`id`, `campaign_id`, `terms_snapshot_id`, `rule_key`, `knowledge_state enum(KNOWN,UNKNOWN,NOT_APPLICABLE)`, `typed_value jsonb nullable`, `confidence numeric(4,3) nullable`, `evidence_snapshot_id nullable`, `evidence_locator nullable`, `verified_at nullable`, `verified_by enum(API,IMPORTER,OWNER,BUILDER)`, `schema_version=1`, `created_at`, `updated_at`; UNIQUE(campaign_id, terms_snapshot_id, rule_key, schema_version). `terms_snapshot_id` and `evidence_snapshot_id` are same-campaign composite FKs.

`KNOWN` requires a key-compatible typed value, evidence snapshot and verification timestamp; `NOT_APPLICABLE` requires null typed value plus evidence/timestamp; `UNKNOWN` requires null typed value. Rows are insert-only. Later terms/verification create a new terms snapshot plus a complete new 32-row normalized rule set. `HONOR_CAMPAIGN_RULE_REGISTRY.json` is the exact 32-key type/unit/consumer authority.

## Sources/rights/transcription
### `sources`
`id`, `origin_type enum(CAMPAIGN_AUTHORIZED,OWNER_OWNED,EXPLICITLY_LICENSED)`, `source_url nullable`, `provider`, `external_source_id nullable`, `title`, `storage_object_key nullable`, `sha256 nullable`, `duration_ms nullable`, `ingest_status`, `created_at`.

### `source_rights`
`id`, `source_id`, `rights_version`, `supersedes_rights_id nullable`, `eligibility enum(ELIGIBLE,INELIGIBLE,UNKNOWN)`, `authorized_uses jsonb`, `platform_limits jsonb`, `evidence_type`, `evidence_uri/object_key`, `evidence_captured_at`, `expires_at nullable`, `notes`, `schema_version=1`, `record_hash`, `committed_at`, `created_at`. UNIQUE(source_id, rights_version) and UNIQUE(record_hash). Rows are committed-at-insert and immutable; changed/revoked/new evidence creates a new rights version and never rewrites history. `source_rights_campaigns` is the canonical immutable relationship table for the exact rights version used by a campaign/clip. `record_hash` is the RFC8785-canonical SHA-256 of the material rights/evidence payload plus source/version/supersession identity. Version >1 requires a non-null supersedes reference.

A source cannot enter paid transcription/render unless current eligibility is `ELIGIBLE` for the intended campaign/use.

### `transcripts`
`id`, `source_id`, `campaign_id`, `rights_id`, `provider`, `model`, `language`, `duration_ms`, `text_summary`, `word_timing_object_key`, `speaker_data_object_key nullable`, `cost_ledger_id nullable`, `status enum(QUEUED,RUNNING,SUCCEEDED,FAILED)`, `transcript_version`, `supersedes_transcript_id nullable`, `transcript_sha256 nullable`, `completed_at nullable`, `created_at`, `updated_at`. Version chains are contiguous and same-source. Paid attempts pin the latest applicable rights version at action time. `SUCCEEDED` requires immutable transcript hash + completion timestamp; terminal retries create a new version row. A candidate may reference only a successful same-source transcript.

Large word-level payloads live in R2; DB stores immutable identity/hash plus searchable summaries/metadata.

## Generation/intelligence
### `generation_runs`
`id`, `target_date`, `requested_by`, `state`, `strategy_version`, `budget_snapshot jsonb`, `requested_constraints jsonb`, `selected_plan jsonb`, `correlation_id`, `created_at`, `completed_at nullable`.

### `run_campaign_allocations`
`id`, `generation_run_id`, `campaign_id`, `social_account_id`, `source_id`, `rule_snapshot_id`, `rights_id`, `account_health_snapshot_id`, `decision_as_of`, `analysis_version`, `experiment_assignment_id nullable`, `recommended_clip_count`, `expected_payout_usd`, `marginal_cost_usd`, `information_value`, `uncertainty`, `score`, `eligibility_decision enum(ELIGIBLE,INELIGIBLE,UNKNOWN)`, `rationale_json`, `model_version nullable`, `deterministic_rules_version`, `created_at`. Committed allocation rows are append-only decision evidence and pin the exact rule, rights, account-fact, budget/run and analysis/rules/model context used at the decision time.

### `candidates`
`id`, `generation_run_id`, `source_id`, `transcript_id`, `scoring_version`, `experiment_assignment_id nullable`, `start_ms`, `end_ms`, `transcript_excerpt`, `context_independence_score`, `hook_score`, `payoff_score`, `editability_score`, `rule_fit_score`, `novelty_score`, `overall_score`, `features jsonb`, `selected bool`, `created_at`. Candidate rows are append-only. `transcript_id` must be a successful same-source transcript. `candidate.features.v1` carries structured nullable speaker/topic/hook/confidence provenance; null means UNKNOWN, not fabricated classification.

### `edit_plans`
`id`, `candidate_id`, `schema_version=1`, `plan_version`, `supersedes_edit_plan_id nullable`, `plan_hash`, `plan_json`, `created_by_model`, `committed_at`, `created_at`. Committed rows are immutable; a revision inserts a new version and preserves every existing clip/render reference. `plan_hash` MUST equal `plan_json.plan_fingerprint_sha256`; version >1 requires a superseded plan ID.

### `audio_assets`
`id`, `kind enum(MUSIC,SFX)`, `category`, `name`, `storage_object_key`, `sha256`, `license_name`, `license_url_or_reference`, `provenance_notes`, `render_safe bool`, `attribution_required bool`, `allowed_uses jsonb`, `active bool`.

### `audio_plans`
`id`, `edit_plan_id`, `density enum(NONE,LOW,MEDIUM,HIGH)`, `music_asset_id nullable`, `platform_native_recommendation jsonb NOT NULL`, `sfx_events jsonb`, `ducking_config jsonb`, `beat_map_object_key nullable`, `rule_override_notes nullable`, `schema_version=1`, `plan_version`, `supersedes_audio_plan_id nullable`, `plan_hash`, `committed_at`, `created_at`. Committed rows are immutable; revisions are new rows/versions. `plan_hash` is the canonical SHA-256 of material audio-plan fields; version >1 requires a superseded audio-plan ID.

### `experiments` / `experiment_arms` / `experiment_assignments`
Minimal V1 experiment tracking. `experiments`: identity, hypothesis, `feature_key`, lifecycle `DRAFT|RUNNING|STOPPED|COMPLETED|CANCELLED`, planned primary metric, start/end/stopping fields. `experiment_arms`: immutable arm identity within an experiment. `experiment_assignments`: exact arm assignment to `GENERATION_RUN|CLIP|SOCIAL_ACCOUNT`, `assigned_at`, nullable one-time `exposed_at`; assignment identity is immutable. Outcomes are joined through existing clip/post analytics/earnings lineage; no duplicate outcome store is authoritative and observational correlation is never automatically causal.

## Media/QC/posting
### `clips`
`id`, `generation_run_id`, `campaign_id`, `source_id`, `social_account_id`, `edit_plan_id`, `audio_plan_id`, `state enum(PLANNED,RENDERING,QC,READY,EJECTED,POSTED,ARCHIVED)`, `final_object_key nullable`, `thumbnail_object_key nullable`, `sha256 nullable`, `duration_ms`, `width`, `height`, `codec`, `file_size_bytes`, `caption_copy`, `title_copy`, `hashtags jsonb`, `posting_recommendation jsonb`, `rule_snapshot_id`, `rights_id`, `created_at`.

### `qc_runs`
`id`, `clip_id`, `started_at`, `finished_at NOT NULL`, `passed bool NOT NULL`, `checks jsonb`, `failure_codes text[]`, `metrics jsonb`, `qc_version`, `retry_number`. A QC row is inserted only after that attempt reaches a terminal pass/fail result and is immutable; every retry inserts a new row.

### `render_manifests`
`id`, `clip_id UNIQUE`, `edit_plan_id`, `audio_plan_id nullable`, `qc_run_id UNIQUE`, `schema_version=1`, `manifest_json` validated by `render_manifest.v1`, `manifest_hash UNIQUE`, `created_at`. Inserted only after a successful immutable QC result and never updated/deleted. `READY` is forbidden unless this manifest exists and matches the clip's edit/audio plan plus a passed QC row.

### `posts`
`id`, `clip_id`, `social_account_id`, `platform`, `published_at`, `post_url`, `platform_post_id nullable`, `native_audio_used jsonb nullable`, `owner_notes`, `idempotency_key UNIQUE`.

### `submissions`
`id`, `campaign_id`, `post_id`, `submitted_at`, `submission_reference nullable`, `status enum(NOT_REQUIRED,PENDING,SUBMITTED,ACCEPTED,REJECTED,UNKNOWN)`, `evidence_object_key nullable`, `idempotency_key UNIQUE`.

### `analytics_checkins`
`id`, `post_id`, `checkin_type enum(H2,H24,H72,FINAL,CUSTOM)`, `due_at`, `completed_at nullable`, `status enum(PENDING,DUE,COMPLETED,MISSED,NOT_APPLICABLE)`, `config_snapshot jsonb`, UNIQUE(post_id, checkin_type, due_at).

### `analytics_observations`
`id`, `post_id`, `observed_at`, `checkin_id nullable`, `views`, `qualified_views nullable`, `likes nullable`, `comments nullable`, `shares nullable`, `saves nullable`, `watch_time_ms nullable`, `avg_watch_pct nullable`, `provider_status`, `evidence_method`, `raw_payload_object_key nullable`.

## Finance/cost
### `earnings`
One logical earning record; current state is mutually exclusive.
`id`, `campaign_id`, `post_id nullable`, `external_earning_id nullable`, `amount_usd`, `state enum(ACCRUED_UNVERIFIED,APPROVED,WITHDRAWABLE,WITHDRAWN,VOIDED)`, `recognized_at`, `last_state_at`, `evidence_snapshot_id nullable`, `source`, `idempotency_key UNIQUE`.

### `earning_state_transitions`
`id`, `earning_id`, `from_state nullable`, `to_state`, `amount_usd_snapshot`, `occurred_at`, `evidence_uri/object_key nullable`, `actor`, `idempotency_key UNIQUE`.

### `cost_ledger`
`id`, `provider`, `service`, `cost_category enum(INFRASTRUCTURE,AI_REASONING,TRANSCRIPTION,POLLI_VOICE,STORAGE,GPU,MONITORING,DOMAIN,OTHER)`, `job_id nullable`, `polli_session_id nullable`, `quantity`, `unit`, `estimated_cost_usd`, `actual_cost_usd nullable`, `cost_confidence enum(HIGH,MEDIUM,LOW)`, `incurred_at`, `reconciled_at nullable`, `external_usage_id nullable`, `idempotency_key UNIQUE`.

### `provider_usage`
`id`, `provider`, `service`, `model_or_sku`, `request_id nullable`, `job_id nullable`, `input_units nullable`, `output_units nullable`, `audio_seconds nullable`, `duration_seconds nullable`, `storage_bytes nullable`, `operation_count nullable`, `raw_usage jsonb`, `captured_at`.

## Polli/audit/jobs/events
### `polli_sessions`
`id`, `user_id`, `mode enum(TEXT,VOICE)`, `started_at`, `ended_at nullable`, `openai_live_session_id_hash nullable`, `backend_model_route`, `estimated_cost_usd`, `actual_cost_usd nullable`, `retention_mode`, `status`.

### `polli_turns`
`id`, `session_id`, `role`, `text`, `fact_labels jsonb`, `created_at`. Raw audio is not stored by default.

### `polli_tool_calls`
`id`, `session_id`, `turn_id nullable`, `tool_name`, `tool_version`, `arguments_json`, `result_digest`, `result_summary_json`, `authorized_by`, `started_at`, `finished_at`, `status`, `cost_ledger_id nullable`.

### `jobs`
`id`, `job_type`, `domain_entity_type`, `domain_entity_id`, `state`, `stage`, `attempt`, `max_attempts`, `idempotency_key UNIQUE`, `dispatch_token UNIQUE`, `correlation_id`, `run_id nullable`, `queued_at`, `available_at`, `started_at nullable`, `heartbeat_at nullable`, `lease_expires_at nullable`, `finished_at nullable`, `timeout_seconds`, `cancel_requested_at nullable`, `failure_code nullable`, `failure_detail_redacted nullable`, `owner_action_id nullable`, `version`.

### `events`
Append-only outbox/event log.
`id`, `event_name`, `event_version`, `occurred_at`, `recorded_at`, `actor_type`, `actor_id nullable`, `source_service`, `correlation_id`, `run_id nullable`, `job_id nullable`, `entity_type`, `entity_id`, `idempotency_key UNIQUE`, `payload jsonb`, `published_at nullable`.

### `owner_actions`
`id`, `action_type`, `title`, `reason`, `entity_type`, `entity_id`, `status enum(OPEN,RESOLVED,CANCELLED)`, `requested_at`, `resolved_at nullable`, `resolution jsonb nullable`.

### `audit_log`
Append-only security/business audit.
`id`, `occurred_at`, `actor_type`, `actor_id nullable`, `action`, `target_type`, `target_id nullable`, `request_id`, `ip_hash nullable`, `metadata_redacted jsonb`.

### `backup_runs`
`id`, `started_at`, `finished_at`, `status`, `snapshot_reference`, `bytes`, `restic_snapshot_id nullable`, `verification_status`, `error_redacted nullable`.

## Required indexes/constraints
- FK indexes on all high-cardinality references.
- Partial unique indexes for external IDs when non-null.
- `events(event_name, occurred_at)`, `jobs(state, available_at)`, `analytics_checkins(status,due_at)`, `cost_ledger(incurred_at,provider)`, `earnings(state,recognized_at)`.
- Check constraints for non-negative money/view/duration fields except explicit correction rows.
- RLS: owner-authenticated V1 runtime through custom `honor_app`; `anon`/`authenticated` Data API roles have no HONOR business-table DML, and Supabase secret/service-role keys are not used by V1 runtime. Audit/events/finance transition tables are not directly client-writable.

## Migration rule
Schema changes require versioned SQL migrations, contract tests, and rollback/forward plan. No later builder may silently rename/drop a frozen table/enum/column used by an API/event/tool contract.

## Canonical V1 state-transition graphs
There is exactly one frozen graph for each entity below; it matches `HONOR_DATABASE_CONTRACT.sql` and `HONOR_OPENAPI_V1.json`.

- **Submission creation:** `PENDING | SUBMITTED | NOT_REQUIRED | UNKNOWN`.
- **Submission transitions:** `PENDING -> SUBMITTED | NOT_REQUIRED | UNKNOWN`; `SUBMITTED -> ACCEPTED | REJECTED | UNKNOWN`; `UNKNOWN -> PENDING | SUBMITTED | NOT_REQUIRED | ACCEPTED | REJECTED`; `ACCEPTED`, `REJECTED`, and `NOT_REQUIRED` are terminal.
- **Analytics check-in creation:** `PENDING` only.
- **Analytics check-in transitions:** `PENDING -> DUE | NOT_APPLICABLE`; `DUE -> COMPLETED | MISSED | NOT_APPLICABLE`; `MISSED -> COMPLETED`; `COMPLETED` and `NOT_APPLICABLE` are terminal.

`POST /v1/submissions` may create a row in any allowed submission creation state or move an existing row only along the graph. `POST /v1/analytics/check-ins` records an observation; when a `checkin_id` is supplied it may complete only a `DUE` or `MISSED` check-in. A `PENDING` check-in must first become `DUE` (scheduler) before an observation can complete it; `NOT_APPLICABLE` is set by rule/config resolution, not by fabricating analytics.

## Runtime DB role / grant / RLS matrix
`HONOR_DB_ACCESS_MATRIX.json` is the machine authority. `honor_app` is the only API/worker runtime login, is `NOBYPASSRLS`, owns no application object, has `USAGE` (not `CREATE`) on `public`, receives only the table privileges frozen in the matrix, and has no runtime DELETE anywhere. V1 uses UUID identifiers and requires no sequence privileges.

Owner identity is **transaction-local only**. Every request/job transaction executes `BEGIN; SELECT set_config('honor.owner_user_id', <validated-owner-uuid>, true); ...; COMMIT/ROLLBACK`. The `true` flag is equivalent to `SET LOCAL`; session-global `SET honor.owner_user_id` is forbidden. After transaction A ends, a reused pooled connection must expose no owner context in transaction B until B explicitly sets its own local context. The exact function privilege authority is `HONOR_DB_ACCESS_MATRIX.json`: every HONOR-created function has PUBLIC execute revoked; `honor_app` receives EXECUTE only for the explicit allowlist needed by RLS/trigger behavior and the narrowly scoped rights/earning transaction functions. Unlisted functions are not executable by `honor_app`.

`source_rights` and `source_rights_campaigns` are immutable/function-committed for runtime; `edit_plans`, `audio_plans`, terminal `qc_runs`, and `render_manifests` are append-only/immutable for runtime. Material changes create new versioned rows. `cost_ledger` retains its separately frozen one-time reconciliation exception. Migrations/admin/backup/restore use `DATABASE_ADMIN_URL`, not the runtime role.

## Round-5 relational integrity freeze
`source_rights.expires_at` is the **only** V1 authorization-expiration authority. `RightsEvidenceInput.expires_at` maps to it; `source_rights.authorized_uses.v1` contains no expiration. At timestamp `T`, authorization is expired iff `expires_at IS NOT NULL AND T >= expires_at`. `eligibility=UNKNOWN` remains UNKNOWN and never grants permission. The rights `record_hash` includes the relational `expires_at` plus all other material rights/evidence fields.

Every structured JSONB SQL default is schema-valid. Where no honest neutral value exists, the column has no DB default and writers must provide an explicitly schema-validated value. The retained `[]`/`{}` defaults are only those proven valid by their canonical schema and non-factual in meaning.

Clip integrity is database-enforced, not convention: composite FKs bind rights to source and campaign, and the rule snapshot to campaign; `(audio_plan_id, edit_plan_id)` binds audio to the exact edit plan. `honor_clip_cross_record_guard()` additionally binds edit plan -> candidate -> source/run, validates edit-plan JSON source/rights/hash/rule references against relational records, rejects later rights evidence as retroactive authority, and binds posting account/identity/native-audio rule snapshot to the clip. The accepted render manifest binds the same clip/source/edit/audio/output/QC chain.

`source_rights`, `edit_plans`, and `audio_plans` enforce a contiguous same-identity version chain. Version 1 has no predecessor; version N>1 must supersede exactly N-1 for the same source/candidate/edit-plan respectively; each predecessor may be superseded at most once, so chains cannot fork or skip.

After a render manifest is accepted—or once the clip is READY/POSTED/ARCHIVED—`generation_run_id`, campaign/source/account, edit/audio/rule/rights references, final object key/hash, duration, dimensions, codec, and file size are immutable. A correction creates a new clip/render lineage.

`clips.posting_recommendation` is the canonical manual-posting instruction snapshot. `caption_copy`, `title_copy`, and `hashtags` are derived mirrors set atomically from that JSON by the DB guard. The recommendation may change before posting, but becomes immutable when a post exists or the clip enters POSTED/ARCHIVED, preserving the exact historical instruction snapshot.


## Round-6 downstream lineage / rights-integrity freeze

- **Campaign terms:** `campaigns.terms_snapshot_id` is a composite same-campaign FK to `(campaign_terms_snapshots.id,campaign_id)`. `campaign_rule_items.evidence_snapshot_id` uses the same rule. Cross-campaign current/evidence snapshots are invalid.
- **Manual post lineage:** `(posts.clip_id,posts.social_account_id)` must match the clip; `(posts.social_account_id,posts.platform)` must match the social account. `honor_post_publish_guard()` additionally requires the posting-recommendation platform to match, validates `native_audio_used.platform`, accepts a new post only from `READY`, and atomically advances that clip `READY -> POSTED`. A failed post insert rolls back the clip transition; `posts.idempotency_key` is unique. V1 still performs posting manually in native social apps.
- **Submission lineage:** `honor_submission_lineage_guard()` requires `submissions.campaign_id` to equal the campaign of `posts.clip_id`.
- **Analytics lineage:** `(analytics_observations.checkin_id,post_id)` is a composite FK to `(analytics_checkins.id,post_id)`, so an observation cannot cite another post's check-in. Observations remain immutable.
- **Earning lineage:** an earning's optional post must resolve to the same campaign, and `(evidence_snapshot_id,campaign_id)` must resolve to the same campaign terms snapshot. Direct runtime `UPDATE earnings` and direct runtime `INSERT earning_state_transitions` are revoked. `honor_transition_earning(...)` is the only runtime transition path: it locks the earning, verifies the frozen graph, inserts an immutable transition whose `from_state` is the pre-update state and whose `amount_usd_snapshot` equals the earning amount, then updates `state/last_state_at` in the same transaction. Any failure rolls back both.
- **Rights applicability history:** `honor_app` has SELECT-only direct access to `source_rights` and `source_rights_campaigns`. `honor_commit_source_rights_version(...)` is the sole runtime append path and atomically inserts the new contiguous rights version plus its complete campaign-applicability set. An already-committed rights version cannot receive a campaign association later. Later rights evidence governs later work only and never retroactively authorizes existing clips/renders.
- **Authorized-use matrix:** `HONOR_RIGHTS_STAGE_MATRIX.json` is authoritative. INGEST requires `may_ingest`; PAID_TRANSCRIPTION requires `may_transcribe`; EDIT_PLAN requires `may_edit && derivative_edits`; RENDER requires `may_render && may_edit && derivative_edits`; compensated production requires `commercial_use && may_edit && derivative_edits && may_render`; publication recommendation requires `may_publish && commercial_use && derivative_edits`, target platform in `allowed_platforms`, and `platform_limits.<platform>.allowed=true`. ELIGIBILITY UNKNOWN, missing applicability, missing/false flags, expired rights, or UNKNOWN rule data never grants permission.
- **Recommendation timing:** if `recommended_publish_at` is non-null, it must be strictly before `source_rights.expires_at` when expiration exists. Equality is expired and rejected. Known campaign start/end/deadline bounds are enforced; UNKNOWN/absent timing rules for the frozen snapshot block HONOR from making a timed recommendation rather than being treated as allowed.
- **Native-audio consistency:** the committed audio-plan native recommendation is planning authority; the clip posting snapshot must exactly mirror it when an audio plan exists. Platform and rule snapshot must match the clip/posting context, and UNKNOWN/PROHIBITED campaign rule states cannot be escalated to RECOMMENDED. Platform-native audio remains outside the rendered MP4.

## Round-7 deterministic additions

- `campaign_rule_items` is append-only and scoped by `terms_snapshot_id`; the terms snapshot ID is the immutable normalized rule-set identity. KNOWN requires typed value + same-campaign evidence + verification timestamp; NOT_APPLICABLE requires null value + evidence + timestamp; UNKNOWN requires null value.
- `account_health_snapshots` adds nullable `account_region`, `follower_count`, and `posting_available`; null is UNKNOWN.
- `candidates.transcript_id` pins the exact successful same-source transcript and committed candidate rows are immutable. Transcript retries are new version rows.
- `run_campaign_allocations` pins rule snapshot, rights version, account-health snapshot, decision as-of, analysis/model/rules versions, run budget snapshot, and optional experiment assignment; committed allocation rows are immutable.
- `analytics_observations.watch_time_ms` means total cumulative watch time and adds nullable average-watch-duration, completed-view/completion-rate, and follower-delta fields.
- Minimal `experiments`, `experiment_arms`, and `experiment_assignments` freeze V1 experiment persistence/assignment; assignment identity is immutable.
- Lifecycle triggers enforce canonical creation/transition states even when callers explicitly supply enum values.

## Round-7 relational integrity additions
Campaign rules are immutable per `terms_snapshot_id`; activation of a complete 32-key snapshot atomically advances `campaigns.terms_snapshot_id` and its current scalar mirrors. `transcripts` pins `campaign_id` + `rights_id` and uses contiguous retry versions; candidates pin the exact successful transcript. Account-health snapshots carry nullable region/follower/posting-availability facts. Run allocations pin immutable rule/rights/account-health/run/version inputs. Minimal experiments/arms/assignments are frozen in `HONOR_EXPERIMENT_CONTRACT.json`. Analytics adds nullable completed views, completion-rate ppm, average-watch-duration ms and follower delta; `watch_time_ms` means total cumulative watch time.

## Round-8 sealed rule/action/experiment integrity

`campaign_rule_set_commits` is the immutable commit record keyed by `(campaign_id, terms_snapshot_id, schema_version)`. A commit exists only after exactly 32 canonical rows satisfy truth/type/cross-rule and evidence chronology checks; the DB computes `rules_sha256` from the ordered normalized rule facts. Sealing closes that tuple to later campaign-rule INSERT as well as the already-forbidden UPDATE/DELETE. Current activation requires a seal and may only advance to a later captured/committed snapshot; a superseded historical snapshot cannot become current again.

`campaign_terms_snapshots.created_at`, transcript admission time, allocation `decision_as_of`, edit/audio commit times, clip recommendation creation time and render-manifest acceptance time are database-authored on their protected paths; `captured_at`, actual `published_at`, and analytics `observed_at` remain factual external timestamps where defined. `clips.render_started_at` is set only on `PLANNED -> RENDERING`, at which point current RENDER rights are re-evaluated before render cost.

`audio_plans.rule_compliance` stores the exact render-audio compliance mirror. `earnings.rule_snapshot_id` is mandatory same-campaign sealed rule provenance. Experiments declare `unit_type`; design may change only while remaining DRAFT, DRAFT->RUNNING requires at least two arms and exactly one control, arm changes stop after DRAFT, assignments exist only while RUNNING with database-authored assignment/exposure times, and assignment unit identity is cross-checked against candidate/allocation/clip lineage.

## C00 Round-9 runtime integrity freeze

Round 9 does not add C01 behavior. It closes runtime integrity gaps in the frozen V1 model. `campaign_rule_set_commits` now has a pre-insert runtime schema guard that validates every KNOWN `campaign_rule_items.typed_value` against the exact per-key registry shape before a seal can exist, including exact keys, primitive/enum/array/object constraints, bounds, URI/date-time formats and additional-property closure. A KNOWN `last_verified_at` must equal the actual maximum verification timestamp of the sealed set and cannot exceed the DB-authored seal time.

V1 edit plans carry exactly one `campaign_rule_snapshot_ids` item. That sole snapshot must equal edit `rule_compliance.rule_snapshot_id`, audio rule/native-audio snapshot identity, `clips.rule_snapshot_id`, posting/native-audio identity, and `render_manifest.v1.campaign_rule_snapshot_id`. Changed campaign terms require a new decision lineage rather than plan reuse.

`accepted_edit_signatures` is the function/trigger-owned final-acceptance reservation table for `NO_REUSED_EDIT`, `UNIQUE_PER_ACCOUNT`, and `UNIQUE_PER_CAMPAIGN`. Its primary key over restriction code + scope + edit signature makes concurrent READY acceptance race-safe. `qc_runs.passed` is derived by `honor_qc_truth_guard()` under `HONOR_QC_POLICY.json`; caller `hard_gate=false` cannot weaken canonical checks.

Material pre-post recommendation revisions increment a DB-authored `clips.recommendation_version` and set `recommendation_revised_at` at statement time after current PUBLICATION_RECOMMENDATION rights, current activated sealed rules and rights expiration are rechecked. Experiment arm and assignment mutations lock the parent experiment row `FOR UPDATE`, serializing them with status transitions; stopping history is immutable after RUNNING terminates.

## Round-10 runtime relational guards

`restriction_proof_artifacts` is append-only immutable evidence. Its database guard recomputes `proof_sha256`, validates chronology, and for `OWNER_REVIEW` resolves the exact `owner_actions` record and restriction/campaign/candidate/target/hash context. `honor_round10_restriction_placement_guard()` independently enforces the four canonical restriction-code groups at rule-set seal and rejects duplicate semantic codes. `honor_restriction_compliance_guard()` requires one and only one compliance record for every active clause and forbids extras.

`honor_restriction_consumes_stage(code, stage)` freezes the same 12-code consuming-stage matrix used by the machine semantics artifact. Posting revision enforcement is stage-driven through that matrix and binds fresh evidence to the database-authored recommendation version/revision time and content hash. Null audio plans require null manifest audio identity and an empty render-safe asset list. Experiment arm identity is immutable and its pre-trigger locks the OLD parent for UPDATE/DELETE.

## Round-11 runtime integrity freeze

### Posting-restriction proof versioning
Every material `clips.posting_recommendation` revision produces a DB-authored `recommendation_version`/`recommendation_revised_at`. If the exact sealed rule set contains any posting-consuming restriction, the resulting recommendation version must carry exactly one valid `posting_restriction_compliance` record per active clause and no extras. V1 uses **fresh-version binding**: even when caption/title text is unchanged, proof artifacts must bind the new recommendation version; the deterministic caption/title subject hash may remain unchanged. Direct removal/replacement of compliance evidence is itself a recommendation mutation and is revalidated.

### Render-safe audio asset versions and rights
`audio_assets` rows are material-rights versions. `id`, kind, storage/binary identity, SHA-256, license identity/reference, license-evidence object/hash, provenance, `render_safe`, `attribution_required`, `allowed_uses`, and `created_at` are immutable after insertion. `active` may transition only `true -> false` to revoke future use. Changed binary/license/material rights or later reauthorization creates a new asset ID/version.

Automatic compensated rendering requires one exact predicate at audio-plan commit, `PLANNED -> RENDERING`, and render-manifest admission: `active=true`; both render-safe authorities true and equal; commercial and derivative use true; destination platform listed; `campaign_restriction=null`; `attribution_required=false`; and immutable license evidence present when `license_evidence_required=true`. Any missing/false/unknown/non-null campaign restriction blocks automatic V1 embedding.

At terminal manifest admission each `render_safe_assets[]` item must exactly mirror canonical `audio_assets` UUID, kind, SHA-256 and `license_url_or_reference`, be present in the committed audio plan, and still satisfy current eligibility. Historical manifests retain the immutable asset version after later deactivation.

### Owner-action lifecycle
`owner_actions` creation is `OPEN` only. `requested_at`/`created_at` are database-authored. An OPEN row may transition once to `RESOLVED` or `CANCELLED`; `resolved_at` or `cancelled_at` is database-authored, and canonical terminal resolution JSON is bound by immutable `resolution_sha256`. Terminal rows cannot reopen, change context, resolution or terminal time. Restriction-compliance owner review is valid only for the three owner-resolvable codes and must match exact campaign/rule/candidate/target/subject context. `restriction_proof_artifacts.owner_resolution_sha256` binds the exact human decision.

### Experiment identity
`experiments.id` and `experiments.created_at` are immutable from insertion. `experiment_assignments.id` is immutable during the one permitted exposure update; all existing assignment identity fields remain immutable and only `exposed_at: NULL -> DB timestamp` may change once while RUNNING.

### Round 12 — PRECOMMIT owner-review subject
Restriction-compliance `OWNER_REVIEW` is a PRECOMMIT decision. The owner action resolves before the future edit-plan or initial clip/recommendation row exists. Its canonical resolution binds `review_phase=PRECOMMIT`, exact campaign, sealed rule snapshot, candidate, restriction code, legal target type, reserved target UUID, `target_version`, and exact `subject_sha256`. Resolution validates all already-existing lineage and the sealed restriction clause but deliberately does **not** require the future target row. The immutable proof artifact mirrors the target version and owner-resolution hash. Consumption is authoritative: the later edit-plan/posting guard must match actual target UUID/version/hash/context and prove owner resolution, evidence, and proof creation occurred no later than the DB-authored target commit/revision time. An unused precommit review grants nothing and later review cannot retroactively legalize an earlier action.
