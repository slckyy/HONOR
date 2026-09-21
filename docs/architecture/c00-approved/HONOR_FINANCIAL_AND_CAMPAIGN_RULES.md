> HONOR C00 frozen specification — research date 2026-09-20.
> Month-1 hard operating ceiling: $56.03 USD. Later builders may not silently change frozen contracts.

# Financial and Campaign Rules

## Campaign rule truth model
Every rule is represented by:
- `rule_key`
- `knowledge_state = KNOWN | UNKNOWN | NOT_APPLICABLE`
- typed value when known
- confidence (0–1) where useful
- evidence snapshot/locator
- verified timestamp
- verifier/import method

`UNKNOWN` never means false, zero, unrestricted, optional, or allowed.

## Frozen canonical campaign rule keys
- `provider`
- `campaign_url`
- `external_campaign_id`
- `status`
- `compensation_model`
- `cpm_or_rate`
- `minimum_views`
- `max_payout_per_clip`
- `total_budget`
- `remaining_budget`
- `start_at`
- `end_at`
- `deadline_at`
- `eligible_platforms`
- `eligible_regions`
- `eligible_account_requirements`
- `required_tags`
- `required_mentions`
- `required_hashtags`
- `disclosure_requirements`
- `source_material_restrictions`
- `clip_length_min_seconds`
- `clip_length_max_seconds`
- `content_restrictions`
- `editing_restrictions`
- `uniqueness_rules`
- `submission_format`
- `analytics_window`
- `payout_window`
- `render_audio_rules`
- `platform_native_audio_rules`
- `last_verified_at`

Additional provider-specific fields live in namespaced metadata and may not override canonical fields silently.

## Rule evidence precedence
For the same fact at the same time, prefer:
1. official provider/campaign API response,
2. current provider/campaign terms page explicitly accessible and attributable,
3. owner-supplied campaign evidence/screenshot/document,
4. manually entered value with owner attribution.

Conflicts are preserved and surfaced; never silently pick the more profitable interpretation.

## Source eligibility
Permitted source classes only:
- campaign-authorized,
- owner-owned,
- explicitly licensed/authorized.

Publicly viewable content is not automatically reusable. Eligibility must be established for the intended campaign/platform/edit use. If rights are unknown, the paid production job blocks.

Discovery/import preference:
1. official API,
2. explicitly permitted public endpoint/page,
3. compliant web/search access,
4. owner-supplied URL,
5. manual import.

If access requires bypassing CAPTCHA, anti-bot controls, credentials, private sessions, hidden downloads, or platform restrictions, automation stops and asks for a legal/manual path.

# Financial truth
All revenue sums use one current state per earning, so amounts do not exist simultaneously in multiple revenue buckets.

## Revenue states
### Accrued / unverified revenue
Money suggested by observed performance or a provider estimate but not yet provider-approved. This is **not confirmed revenue** and does not count toward confirmed net profit, target progress, or self-funded status.

### Approved revenue
Provider/campaign evidence confirms the earning is approved, but it is not yet withdrawable.

### Withdrawable revenue
Provider/campaign evidence shows funds are currently available to withdraw.

### Withdrawn revenue
Evidence shows funds left the provider balance through a withdrawal/payout action. HONOR may separately store payout settlement metadata later, but this state is mutually exclusive with approved/withdrawable.

### Voided
Rejected/reversed/corrected earning. Excluded from revenue totals but transition history remains.

## Derived deterministic definitions
For a period P:
- `accrued_unverified(P)` = sum current-state `ACCRUED_UNVERIFIED` earnings recognized in P.
- `approved(P)` = sum current-state `APPROVED` earnings recognized in P.
- `withdrawable(P)` = sum current-state `WITHDRAWABLE` earnings recognized in P.
- `withdrawn(P)` = sum current-state `WITHDRAWN` earnings recognized in P.
- `gross_campaign_revenue_confirmed(P)` = approved + withdrawable + withdrawn.
- `lifetime_revenue` = lifetime confirmed gross campaign revenue.

No state transition creates a second earning amount. It changes the existing earning's current state and appends a transition record.

## Spend
- `actual_reconciled_spend(P)` = sum non-null actual provider costs for records reconciled to invoice/provider usage.
- `estimated_unreconciled_spend(P)` = sum conservative estimates for incurred costs not yet reconciled.
- `booked_spend(P)` = actual cost when known, otherwise conservative estimated cost.
- `infrastructure_api_spend(P)` = booked spend across infrastructure/API categories excluding owner personal labor and taxes not captured by provider ledger.
- `polli_voice_reasoning_spend(P)` = booked `POLLI_VOICE + AI_REASONING` associated with Polli sessions.
- `net_profit_booked(P)` = confirmed gross campaign revenue(P) - booked spend(P).

If material provider costs are known to be missing, Polli must label net profit `UNKNOWN/INCOMPLETE` rather than inventing a number.

## Month-1 cost governor accounting
The spend ledger serves two related but distinct purposes: economic operating-cost reporting and hard-cap admission. `HONOR_COST_GOVERNOR.json` is the machine authority for admission.

For admission, `governor_exposure_usd = cash_spend_counted_usd + unpaid_committed_usd + admitted_queued_unfunded_usd` using exact decimal arithmetic. A conservative reservation is created before dispatch, so provider reporting lag cannot make exposure look lower than the amount HONOR has already spent, committed, or admitted.

Prepaid provider funding is treated as cash spend for the Month-1 ceiling **when purchased**. Its later consumption is normalized as service usage for economic reporting but does not add those same cash dollars to governor exposure again. Remaining already-counted prepaid credit may offset only queued work that will consume that credit; any queued amount above the remaining credit enters `admitted_queued_unfunded_usd`. Refunds reduce cash exposure only after provider-confirmed settlement.

Admission is exact: `NORMAL <43.00`; `OPTIONAL_PAUSED >=43.00 and <51.03`; `RESERVE >=51.03 and <56.03`; `HARD_STOP >=56.03`. Optional paid work is never admitted at or above $43.00. Core-required work must remain below $51.03 after admission. Reserve expenditure is limited to emergency/recovery/security/reconciliation and must remain below $56.03 after admission. At/above $56.03 no new paid work is admitted.

Economic `booked_spend` must not double-count a prepaid cash purchase and the service consumption funded by it. The prepaid purchase is governor cash protection; service usage is the operating-cost category used for net-profit accounting. Reconciliation retains evidence linking the two.

## $4,000 target progress
`current_month_target_progress_usd` = current calendar month's **confirmed gross campaign revenue**.
Display `X / $4,000` and percent capped visually as appropriate, but never describe $4,000 as forecast/guarantee. Accrued/unverified revenue is shown separately and excluded from X.

## Factory self-funded
`FACTORY SELF-FUNDED = TRUE` only when both are true:
1. cumulative legitimate confirmed revenue (`APPROVED + WITHDRAWABLE + WITHDRAWN`, current mutually exclusive states) is greater than cumulative operating cost; and
2. material operating-cost records through the evaluation timestamp are reconciled or conservatively booked with no known missing provider category that could reverse the result.

If revenue <= cost: FALSE. If cost completeness is materially unknown: UNKNOWN/NOT VERIFIED. Never infer true from accrued/unverified money.

## Corrections/reversals
Corrections must preserve audit history. Use provider correction evidence to transition or add a distinct signed correction record; never edit historical amounts without an audit entry. Negative correction amounts are permitted only in dedicated correction pathways with evidence.

## Allocation economics
For each eligible campaign/account/source/edit option, persist:
- estimated qualified views distribution,
- probability of satisfying minimum-view threshold,
- expected payout under rate, cap, remaining budget, and compensation model,
- marginal AI/transcription/render/storage cost,
- account health,
- deadline pressure,
- source availability,
- historical hook/edit/audio performance,
- information value of the experiment,
- uncertainty/confidence.

Then apply deterministic hard constraints and rank by configurable expected-value components. The system may recommend zero clips. Model prose may explain the result but may not alter numeric sums or hard rule outcomes.

## Check-in defaults
Default scheduling anchors after `published_at`:
- +2 hours,
- +24 hours,
- +72 hours,
- final campaign/payout window.
Campaign/platform configuration can override. Missed check-ins remain visible; they are not silently backfilled with guessed analytics.

## Canonical completeness / self-funded machine representation
The machine representation is tri-state and must preserve uncertainty:
- `FACTORY_SELF_FUNDED`: cumulative legitimate confirmed revenue > cumulative operating cost, with material cost data complete enough to verify the comparison.
- `NOT_SELF_FUNDED`: comparison is complete enough to verify and cumulative legitimate confirmed revenue <= cumulative operating cost.
- `UNKNOWN_NOT_VERIFIED`: material cost/revenue evidence is incomplete or contradictory, so the comparison cannot legitimately be verified.

`net_profit_usd` / Polli `net_profit_booked` is `null` whenever material cost data is incomplete, paired with `net_profit_truth_state=INCOMPLETE_UNKNOWN`; it is never coerced to `0.000000`. `self_funded_state` is the sole V1 machine representation; no parallel boolean is canonical.


# Cost governor accounting semantics
`HONOR_COST_GOVERNOR.json` is the machine authority. `NORMAL` is exposure `< $43.00`; `OPTIONAL_PAUSED` is `>= $43.00 and < $51.03`; `RESERVE` is `>= $51.03 and < $56.03`; `HARD_STOP` is `>= $56.03`. No optional paid work may be admitted in OPTIONAL_PAUSED or above.

`cash_spend_counted_usd` includes irreversible Month-1 cash charges and full prepaid funding purchases. `unpaid_committed_usd` includes unavoidable obligations not yet in counted cash. `admitted_queued_unfunded_usd` includes conservative pre-dispatch paid-job reservations not already covered by counted cash/commitments, reduced only by remaining prepaid credit whose original purchase is already counted. `governor_exposure_usd` is the sum of those three.

A pure prepaid funding purchase protects the hard cash cap immediately but is excluded from net-profit economic operating expense so later consumed service usage is not double-counted as both funding and usage. Provider reporting lag never releases a pre-dispatch reservation.

## Round-5 source-rights expiration rule
For source authorization, `source_rights.expires_at` is the sole V1 expiration authority. The API field `RightsEvidenceInput.expires_at` persists to that relational column; `source_rights.authorized_uses.v1` deliberately contains no second expiration field. At timestamp `T`, the authorization is expired exactly when `expires_at IS NOT NULL AND T >= expires_at`. A null expiration means no known expiration was supplied; it does not upgrade `eligibility=UNKNOWN` or any UNKNOWN campaign/source-right fact into permission. Later evidence or a later rights version may govern later work, but it never rewrites the historical rights version referenced by an existing clip/render.


## Round-6 earning lineage and atomic transition freeze

For every earning, `campaign_id` is authoritative and cannot conflict with provenance: a non-null `post_id` must resolve through post -> clip to the same campaign, and a non-null `evidence_snapshot_id` must belong to that same campaign. Cross-campaign reassignment is rejected at the database boundary.

Runtime state changes are mechanical: `honor_app` cannot directly UPDATE `earnings` and cannot directly INSERT `earning_state_transitions`. The only runtime transition path is `honor_transition_earning(...)`, which locks the current earning row, validates the frozen earning-state graph, writes one immutable transition with `from_state` equal to the locked pre-state, `to_state` equal to the requested allowed state, and `amount_usd_snapshot` equal to the earning's current `amount_usd`, then updates `earnings.state` and `last_state_at` in the same transaction. If either write fails, the whole transaction rolls back. Financial UNKNOWN/completeness semantics are unchanged.

## Round-7 campaign rule truth / registry

Machine authority is `HONOR_CAMPAIGN_RULE_REGISTRY.json`, containing exactly the 32 canonical keys. `campaign_terms_snapshots.id` is the immutable rule-set identity. KNOWN means a key-specific typed value plus attributable same-campaign evidence and verification timestamp; NOT_APPLICABLE means null value plus evidence/timestamp; UNKNOWN always has null typed value and never becomes permission. Unrepresentable provider nuance remains UNKNOWN with evidence.

`campaigns.provider/campaign_url/external_campaign_id/status/start_at/end_at/deadline_at/last_verified_at` are current-query mirrors refreshed from the active immutable rule snapshot. Historical decisions never consume those mutable mirrors; they pin `rule_snapshot_id`. Stage consumers and UNKNOWN blocking are frozen in `HONOR_CAMPAIGN_RULE_CONSUMPTION.json`.

## Round-7 campaign truth model
For every canonical rule key: `KNOWN` requires a key-compatible typed value, same-campaign evidence snapshot and verification timestamp; `NOT_APPLICABLE` requires a null value plus evidence/timestamp; `UNKNOWN` requires a null value and never grants permission. The exact 32-key registry is `HONOR_CAMPAIGN_RULE_REGISTRY.json`. Historical normalized rules are immutable. Current campaign scalar columns are derived mirrors only. Critical UNKNOWN eligibility/media/posting/submission restrictions block the consuming stage. Earnings and payout math consume the exact rule snapshot used by the decision; later rule verification creates a new snapshot and never rewrites old decisions.

### Round-7 cross-rule invariants
Activation of a current immutable rule set rejects contradictory normalized facts: when both are KNOWN, `clip_length_min_seconds <= clip_length_max_seconds`, `start_at < end_at`, `remaining_budget <= total_budget`, and `eligible_account_requirements.min_followers <= max_followers` when both follower bounds are non-null. `HONOR_CAMPAIGN_RULE_REGISTRY.json` remains the machine authority for key-specific types; `HONOR_CAMPAIGN_RULE_CONSUMPTION.json` remains the stage-consumption authority.

### Current-rights revalidation for owner recommendations
Historical clips retain their original `rights_id`, but an owner-facing schedule/recommendation is authorized only after response-time revalidation against the latest source-rights version available at that time. If a newer rights version narrows/revokes publication authority, HONOR blocks/omits the old recommendation rather than falling back to the older broader rights row. A later grant never retroactively authorizes past work.

## Round-8 sealed campaign-rule semantics

A terms/evidence snapshot may exist while normalization is incomplete, but no historical allocation/edit/audio/clip/post/submission/finance decision may consume it until `honor_seal_campaign_rule_set(...)` creates its immutable `campaign_rule_set_commits` row. The seal requires exactly 32 canonical keys, evidence `captured_at` and DB-authored evidence-record `created_at` no later than verification for KNOWN/NOT_APPLICABLE, verification no later than the DB-authored seal, and seal time no later than the consuming action. Later verification or provider-term reversion uses a new terms/rule snapshot and new seal; an older superseded snapshot cannot silently become current.

`HONOR_CAMPAIGN_RESTRICTION_SEMANTICS.json` is the exact machine authority for all 12 restriction codes, including legal effect/scope, proof, consuming stages, blocking/UNKNOWN behavior and READY gating. Nuance that cannot be represented exactly stays UNKNOWN rather than being force-fit. Disclosure placement is preserved as CAPTION, VIDEO, BOTH or PROVIDER_SUBMISSION through posting/edit/render/QC/submission. The V1 submission deadline is the sealed `deadline_at` mirror when KNOWN, null when NOT_APPLICABLE, and blocks recommendation when UNKNOWN. Earnings pin `rule_snapshot_id`; later campaign changes govern only future decisions.

## Round-9 campaign rule runtime validation

A rule set cannot be sealed merely because all 32 rows have the correct `value_type` label. Every KNOWN typed value must satisfy the complete registered per-key JSON shape at the database seal boundary. The registry remains authoritative and unchanged in strength. `last_verified_at`, when KNOWN, equals the set's actual latest verification time and cannot be later than the DB-authored seal.

Restriction compliance is also evidence-typed. Each restriction code accepts only its frozen `permitted_proof_kinds`; COMPLIANT requires a non-empty proof reference. `OWNER_REVIEW` is legal only for codes explicitly marked owner-resolvable and then requires an owner resolution id. `NONE`, UNKNOWN evidence, or a proof kind from another restriction cannot satisfy production.

## Round-10 restriction placement and evidence identity

V1 restriction placement is exact: source-origin codes live only in `source_material_restrictions`, profanity/brand-safety/claims codes only in `content_restrictions`, edit-operation codes only in `editing_restrictions`, and edit-uniqueness codes only in `uniqueness_rules`. Both JSON Schema and the seal trigger enforce this independently, and duplicate semantic codes are rejected.

For an active clause, one canonical COMPLIANT/VIOLATION/UNKNOWN record exists; only COMPLIANT can advance production. A COMPLIANT result must resolve to the exact immutable proof artifact and frozen proof kind. Owner review is referential to a RESOLVED owner action with matching restriction, campaign, rule snapshot, candidate, target and subject hash; random ids or unrelated owner actions do not satisfy campaign compliance.
