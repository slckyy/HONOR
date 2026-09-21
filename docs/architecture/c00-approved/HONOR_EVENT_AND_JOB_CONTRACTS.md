> HONOR C00 frozen specification — research date 2026-09-20.
> Month-1 hard operating ceiling: $56.03 USD. Later builders may not silently change frozen contracts.

# Event and Job Contracts

## Canonical event envelope v1
```json
{
  "event_id": "uuid",
  "event_name": "CAMPAIGN_DISCOVERED",
  "event_version": 1,
  "occurred_at": "RFC3339 UTC",
  "recorded_at": "RFC3339 UTC",
  "actor": {"type":"OWNER|SYSTEM|PROVIDER|WORKER","id":null},
  "source_service": "api|worker|media|intelligence",
  "correlation_id": "uuid",
  "run_id": null,
  "job_id": null,
  "entity": {"type":"campaign","id":"uuid"},
  "idempotency_key": "stable-string",
  "payload": {"event_name":"CAMPAIGN_DISCOVERED","subject_type":"campaign","subject_id":"uuid","state":null,"reason_code":null,"evidence_id":null,"amount_usd":null,"related_ids":[]}
}
```
Events are append-only. `events.payload` MUST validate against `jsonschema/event.payload.v1.json`; `payload.event_name` MUST equal the envelope/row `event_name`. V1 structured payloads reject unknown fields. Consumers reject unsupported event/schema versions rather than inventing semantics.

## Frozen canonical event names
- `CAMPAIGN_DISCOVERED`
- `CAMPAIGN_RULES_VERIFIED`
- `CAMPAIGN_RULES_BLOCKED_UNKNOWN`
- `SOURCE_INGESTED`
- `SOURCE_ELIGIBILITY_VERIFIED`
- `TRANSCRIPTION_COMPLETE`
- `CANDIDATES_RANKED`
- `FINALISTS_SELECTED`
- `EDIT_PLAN_CREATED`
- `AUDIO_PLAN_CREATED`
- `CLIP_RENDER_REQUESTED`
- `CLIP_RENDERED`
- `QC_PASSED`
- `QC_FAILED`
- `CLIP_READY`
- `POST_RECORDED`
- `SUBMISSION_RECORDED`
- `ANALYTICS_CHECKIN_DUE`
- `ANALYTICS_RECEIVED`
- `PAYOUT_ACCRUED_UNVERIFIED`
- `PAYOUT_APPROVED`
- `PAYOUT_WITHDRAWABLE`
- `PAYOUT_WITHDRAWN`
- `COST_RECORDED`
- `POLLI_SESSION_STARTED`
- `POLLI_TOOL_CALLED`
- `POLLI_COST_RECORDED`
- `OWNER_ACTION_REQUIRED`
- `JOB_RETRY_SCHEDULED`
- `JOB_FAILED_TERMINAL`
- `JOB_SUCCEEDED`

Renaming/removing these requires approved CHANGE REQUEST. New additive events also require contract review.

## Job states
Frozen generic states:
- `queued`
- `running`
- `retrying`
- `blocked-owner-action`
- `failed-terminal`
- `succeeded`
- `cancelled`

Domain work stage is separate from generic state. Canonical stages include:
`campaign_import`, `rules_normalization`, `source_ingest`, `rights_verification`, `transcription`, `candidate_discovery`, `candidate_scoring`, `finalist_selection`, `edit_plan`, `audio_plan`, `render`, `qc`, `schedule`, `analytics_ingest`, `payout_reconcile`, `cost_reconcile`, `backup`.

## State transitions
- `queued -> running`
- `running -> succeeded`
- `running -> retrying`
- `running -> blocked-owner-action`
- `running -> failed-terminal`
- `running -> cancelled` when cooperative cancellation succeeds
- `retrying -> queued` when `available_at` arrives
- `retrying -> failed-terminal` when attempts exhausted/nonretryable failure discovered
- `blocked-owner-action -> queued` only after audited owner/system resolution
- `queued|retrying|blocked-owner-action -> cancelled` on explicit cancellation
- terminal states `succeeded|failed-terminal|cancelled` do not transition except through an explicit repair/replay that creates a **new job** linked to the old one.

## Durable dispatch pattern
1. API transaction inserts/updates domain state, `jobs` row, and outbox `events` row.
2. Commit.
3. Dispatcher publishes `job_id + dispatch_token` to Redis/Celery.
4. Worker atomically claims only if DB state/version allows it.
5. Duplicate dispatch sees already-running/terminal claim and no-ops safely.
6. Reconciler republishes old `queued` jobs with no active lease.

Redis disappearance delays work but cannot lose canonical job truth.

## Retry/backoff
Default transient retry schedule after failed attempt: about 30s, 2m, 10m, 30m, 2h with randomized jitter. Max 5 attempts unless stage overrides below.
- Provider network/5xx/rate limit: max 5, honor `Retry-After` where present.
- Transcription provider failure: max 4; model escalation is a recorded strategy change, not silent.
- Render deterministic input error: max 1 automatic retry after cleanup; then terminal/eject.
- Render transient resource failure: max 3 with cleanup and lower concurrency.
- QC failure caused by fixable render parameters: max 2 rerenders.
- Rights/rule unknown: no timed retry; `blocked-owner-action`.
- Authentication/permission provider errors: block, do not hammer.

## Timeouts/leases
Each job stores `timeout_seconds`. Worker updates heartbeat at least every 30 seconds for long jobs. Lease expiry marks work suspect; reconciler verifies process/DB state before retrying. Provider calls always have connect/read total timeouts. A timeout is a failure with a stable code, never success.

## Cancellation
Cancellation is cooperative. If external provider call/render cannot be safely interrupted, worker records `cancel_requested_at`, finishes/terminates at the next safe boundary, suppresses downstream events, and logs any cost already incurred.

## Failure storage
Store stable `failure_code`, redacted human detail, provider request ID where safe, attempt, last stage, and cost incurred. Never store raw secrets or signed URLs in failure fields.

## Idempotency keys
Examples:
- generation run create: caller key.
- render: `render:{clip_id}:{edit_plan_version}:{audio_plan_version}`.
- post: owner request key plus unique platform URL.
- analytics: `analytics:{post_id}:{observed_at}:{source}`.
- payout transition: provider external event ID or deterministic digest.
- Polli tool: session/turn/tool/argument digest for read retries only.

## Ordering
Events are not assumed globally ordered. Consumers use `occurred_at`, entity version, and idempotency. A single entity's versioned state transition must reject stale updates.

## Submission / analytics event-state alignment
`SUBMISSION_RECORDED` is emitted after a valid submission create/transition in the canonical graph; it does not imply acceptance unless the persisted new state is `ACCEPTED`. `ANALYTICS_CHECKIN_DUE` corresponds to a valid `PENDING -> DUE` transition. `ANALYTICS_RECEIVED` is emitted when an observation is persisted and, when linked to a check-in, the check-in validly transitions `DUE|MISSED -> COMPLETED`; no event authorizes `PENDING -> COMPLETED`.

## Submission/check-in event-state authority
`HONOR_STATE_MACHINES.json` is the machine authority for submission and analytics-check-in creation/transition graphs. `SUBMISSION_RECORDED` is emitted only after a valid create/transition; `ANALYTICS_CHECKIN_DUE` only for `PENDING -> DUE`; `ANALYTICS_RECEIVED` only after observation persistence and, when linked, `DUE|MISSED -> COMPLETED`.

Event payload schema authority: `HONOR_JSONB_SCHEMA_REGISTRY.json` -> `event.payload.v1`.

## Provenance immutability
Events that reference rights, edit plans, audio plans, QC, or renders MUST carry/stably reference the immutable row IDs applicable at occurrence time. Later rights evidence/revocation never rewrites prior events or clip provenance. `CLIP_RENDERED` identifies the committed edit/audio plan versions used; `QC_PASSED` identifies the terminal immutable QC attempt; `CLIP_READY` is emitted only after the immutable `render_manifests` row exists.

## Round-5 provenance event invariant
Events that identify a clip/render use the immutable lineage already frozen on the clip and render manifest. Later source-rights evidence, rule snapshots, edit-plan revisions, or audio-plan revisions do not rewrite the entity references carried by earlier events. A corrected material render/provenance lineage requires a new clip/render identity and new events rather than historical mutation.


## Round-6 transactional lineage semantics
Event names are unchanged. Domain events may be emitted/outboxed only from transactions whose relational lineage has passed the frozen DB guards. `POST_RECORDED` corresponds to the same successful transaction that inserts the idempotent post record and advances the clip `READY -> POSTED`; no post event may describe a rolled-back insert. Earning-state events/analysis consume the immutable transition inserted atomically by `honor_transition_earning(...)`; current earning state must never be advanced without that transition row. Later source-rights evidence/version events cannot retroactively change the rights/version referenced by existing clip/render provenance.

## Round-7 history rule

Durable jobs and generation runs are created `queued` and may move only through the frozen job graph. Historical decisions are append/write-once: campaign rule snapshots, committed candidates, allocations and experiment assignments are never rewritten after outcomes arrive. New evidence/outcomes influence a new generation decision rather than editing the old one.

## Round-7 historical decision rule
Events/jobs may reference newer facts on later runs but MUST NOT mutate prior candidate scores, allocations, campaign rule snapshots, transcript lineage, rights lineage, experiment assignments after exposure, or completed generation-run decision inputs. A materially different transcript/retry, rule verification, rights decision or allocation creates a new version/row/run and corresponding new events.
