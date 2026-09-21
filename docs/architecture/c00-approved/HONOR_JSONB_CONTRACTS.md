> HONOR C00 frozen specification — Round 8.
> Every product-significant JSONB value is schema-validated before persistence. C01 implements these schemas; C01 does not design them.

# JSONB Contract Registry

Machine authority: `HONOR_JSONB_SCHEMA_REGISTRY.json` and `jsonschema/*.json`.

## Column mapping

| DB column | Schema ID | Class |
|---|---|---|
| `account_health_snapshots.signals` | `account_health.signals.v1` | `STRUCTURED_FROZEN_V1` |
| `campaign_rule_items.typed_value` | `campaign_rule.typed_value.v1` | `STRUCTURED_FROZEN_V1` |
| `source_rights.authorized_uses` | `source_rights.authorized_uses.v1` | `STRUCTURED_FROZEN_V1` |
| `source_rights.platform_limits` | `source_rights.platform_limits.v1` | `STRUCTURED_FROZEN_V1` |
| `generation_runs.budget_snapshot` | `generation.budget_snapshot.v1` | `STRUCTURED_FROZEN_V1` |
| `generation_runs.requested_constraints` | `generation.requested_constraints.v1` | `STRUCTURED_FROZEN_V1` |
| `generation_runs.selected_plan` | `generation.selected_plan.v1` | `STRUCTURED_FROZEN_V1` |
| `run_campaign_allocations.rationale_json` | `allocation.rationale.v1` | `STRUCTURED_FROZEN_V1` |
| `candidates.features` | `candidate.features.v1` | `STRUCTURED_FROZEN_V1` |
| `edit_plans.plan_json` | `edit_plan.v1` | `STRUCTURED_FROZEN_V1` |
| `render_manifests.manifest_json` | `render_manifest.v1` | `STRUCTURED_FROZEN_V1` |
| `audio_assets.allowed_uses` | `audio_asset.allowed_uses.v1` | `STRUCTURED_FROZEN_V1` |
| `audio_plans.platform_native_recommendation` | `audio_plan.native_recommendation.v1` | `STRUCTURED_FROZEN_V1` |
| `audio_plans.sfx_events` | `audio_plan.sfx_events.v1` | `STRUCTURED_FROZEN_V1` |
| `audio_plans.ducking_config` | `audio_plan.ducking.v1` | `STRUCTURED_FROZEN_V1` |
| `audio_plans.rule_compliance` | `audio_plan.rule_compliance.v1` | `STRUCTURED_FROZEN_V1` |
| `clips.hashtags` | `clip.hashtags.v1` | `STRUCTURED_FROZEN_V1` |
| `clips.posting_recommendation` | `clip.posting_recommendation.v1` | `STRUCTURED_FROZEN_V1` |
| `qc_runs.checks` | `qc.checks.v1` | `STRUCTURED_FROZEN_V1` |
| `qc_runs.metrics` | `qc.metrics.v1` | `STRUCTURED_FROZEN_V1` |
| `posts.native_audio_used` | `post.native_audio_used.v1` | `STRUCTURED_FROZEN_V1` |
| `analytics_checkins.config_snapshot` | `analytics_checkin.config.v1` | `STRUCTURED_FROZEN_V1` |
| `provider_usage.raw_usage` | `provider_usage.raw.v1` | `INTENTIONALLY_OPAQUE_REDACTED_METADATA` |
| `polli_turns.fact_labels` | `polli.fact_labels.v1` | `STRUCTURED_FROZEN_V1` |
| `polli_tool_calls.arguments_json` | `polli.tool.arguments.v1` | `STRUCTURED_FROZEN_V1` |
| `polli_tool_calls.result_summary_json` | `polli.tool.result_summary.v1` | `STRUCTURED_FROZEN_V1` |
| `owner_actions.resolution` | `owner_action.resolution.v1` | `STRUCTURED_FROZEN_V1` |
| `events.payload` | `event.payload.v1` | `STRUCTURED_FROZEN_V1` |
| `audit_log.metadata_redacted` | `audit.metadata_redacted.v1` | `INTENTIONALLY_OPAQUE_REDACTED_METADATA` |
| `api_idempotency_records.response_body` | `api_idempotency.response_body.v1` | `STRUCTURED_FROZEN_V1` |

## Frozen validation rules

- Structured schemas reject unknown fields unless the schema explicitly permits them.
- API/worker/media/intelligence writers MUST validate against the mapped schema before INSERT/UPDATE.
- `schema_version` columns remain `1` for these V1 contracts; changing a structured schema incompatibly requires a new schema ID/version and approved CHANGE REQUEST.
- Opaque provider/audit metadata is the only extensible class. It is redacted, has bounded structure, rejects secret-like field names, and MUST NOT drive product logic without normalization into a structured contract.
- `polli.tool.arguments.v1` and `polli.tool.result_summary.v1` are generated from the same 12-tool registry frozen in `HONOR_POLLI_TOOL_SCHEMAS.json`.
- Event payloads use `event.payload.v1`; the separate event envelope remains frozen in `HONOR_EVENT_AND_JOB_CONTRACTS.md`.

## Intentionally opaque/redacted metadata constraints
Only `provider_usage.raw.v1` and `audit.metadata_redacted.v1` are extensible. Both enforce maximum container depth 2, at most 100 top-level properties, at most 50 nested-object properties, arrays of at most 100 items, scalar string bounds, and forbidden secret-like field names at every object level. Writers must redact before validation/persistence. `provider_usage.raw.v1` may be written only by API/worker provider adapters; `audit.metadata_redacted.v1` only by API/worker audit code. Product logic is forbidden from branching on opaque provider-specific fields; any such field must first be normalized into a structured/versioned contract.

## Round-4 provenance schemas
- `edit_plan.v1` now freezes source/rule/rights identity, canonical plan fingerprint, deterministic timeline/cut guards, face/speaker layout events, captions, visual emphasis, cleanup targets, audio-plan separation, and render-manifest requirements.
- `render_manifest.v1` is the immutable explanation of the accepted render: source/edit/audio hashes and versions, render-safe licensed assets, renderer/container versions, material parameters, output hash, and successful QC reference.
- `clip.posting_recommendation.v1` and `audio_plan.native_recommendation.v1` are the only posting/native-audio authorities. OpenAPI references these files rather than maintaining looser duplicate object definitions.

## Round-5 defaults and expiration authority
The SQL default for every mapped JSONB column is machine-validated against the registered schema. Invalid `{}` defaults were removed from account health signals, source rights authorized uses/platform limits, requested generation constraints, candidate features, posting recommendations, and QC checks/metrics. Canonical schemas were not weakened.

`source_rights.expires_at` is relational/top-level and authoritative. `source_rights.authorized_uses.v1` intentionally has no duplicate expiration field. This prevents contradictory rights-expiration decisions.

## Round-8 structured additions

`audio_plans.rule_compliance` is schema-validated by `audio_plan.rule_compliance.v1` and binds the exact rule snapshot, inner render-audio states, effective SFX density, actual music/SFX usage, and operational instructions. The posting/edit/render/QC schemas now carry disclosure placement end to end and machine-verifiable restriction/audio compliance. These fields are frozen provenance, not free-form notes.

## Round-9 runtime truth additions

`edit_plan.v1.campaign_rule_snapshot_ids` remains an array only for wire compatibility and is frozen to exactly one item in V1. `render_manifest.v1.campaign_rule_snapshot_id` mirrors that same sole sealed rule-set identity. `qc.checks.v1` now makes every canonical `hard_gate` a constant `true`; applicability and legal `NOT_APPLICABLE` states are defined by `HONOR_QC_POLICY.json`, and `qc_runs.passed` is database-derived rather than caller-authored.

The database seal boundary independently validates every KNOWN `campaign_rule_items.typed_value` against the complete per-key schema registered in `HONOR_CAMPAIGN_RULE_REGISTRY.json`; application-side JSON Schema validation is defense in depth, not the sole integrity boundary.

## Round-10 structured restriction evidence

The four restriction-rule schemas accept only their canonical three codes. `edit_plan.v1.restriction_compliance` is a unique bounded set and runtime semantics require exactly one tuple `(code,effect,scope)` per active sealed clause. `proof_reference` is no longer free-form: it identifies an immutable proof artifact by id/kind/restriction code/hash/target/content hash/evidence time/result. Posting recommendations carry `posting_restriction_compliance` using the same structured evidence model for posting-consuming restrictions.

`render_manifest.v1` now has an explicit conditional: a null `audio_plan_id` requires null audio-plan metadata and zero `render_safe_assets`. This schema rule is duplicated at the SQL/QC boundary.

## Round-11 contract notes

`audio_asset.allowed_uses.v1` now carries the exact automatic-embedding checkpoint contract. Its `render_safe` value must equal the relational `audio_assets.render_safe`; commercial/derivative/platform rights are mandatory; non-null campaign restrictions and attribution requirements are V1 automatic-render blockers; and `license_evidence_required=true` is satisfied only by immutable relational `license_evidence_object_key` plus `license_evidence_sha256`.

`render_manifest.v1` conditionally freezes null-audio internal consistency: no audio-plan identity, no render-safe assets, no planned music/SFX claims. Runtime guards additionally bind every non-null-plan manifest asset to canonical UUID/kind/SHA/license and current eligibility.

`clip.posting_recommendation.v1.posting_restriction_compliance` is version-complete evidence: every material recommendation version must contain the exact active posting-stage compliance set. Round 11 chooses fresh proof-artifact binding for every new recommendation version even when caption/title content hash is unchanged.

### Round 12 owner-action PRECOMMIT restriction resolution
`owner_action.resolution.v1.json` freezes `RESTRICTION_COMPLIANCE` as `review_phase=PRECOMMIT` with a required positive integer `target_version`. The reserved target UUID/version and subject SHA-256 are reviewed before the final edit-plan or posting-recommendation row/version is committed. The final consumer must exactly match that immutable subject; target-row existence is intentionally not a prerequisite to resolving the review.
