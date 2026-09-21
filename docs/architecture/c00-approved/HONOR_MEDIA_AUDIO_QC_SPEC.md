> HONOR C00 frozen specification — research date 2026-09-20.
> Month-1 hard operating ceiling: $56.03 USD. Later builders may not silently change frozen contracts.

# Media, Audio, and QC Specification

## Output profile
Default short output:
- canvas: 1080×1920, 9:16 portrait;
- H.264, yuv420p, `+faststart` MP4;
- AAC audio, 48 kHz stereo unless source requires mono handling;
- default 30 fps; preserve/use 60 fps only when source/motion quality materially benefits and cost remains acceptable;
- no HONOR-added watermark.

Platform/campaign restrictions may tighten these settings.

## Moment selection requirements
A candidate must be understandable without hidden surrounding context. Scoring must consider:
- hook speed/clarity,
- context independence,
- complete thought/payoff,
- emotional/visual energy,
- campaign rule fit,
- source rights,
- novelty/uniqueness against existing HONOR clips,
- editability within allowed duration.

A visually exciting but context-dependent fragment should not win solely because of a model score.

## Edit construction
The media factory must support:
- dead-air tightening while preserving natural cadence;
- clean jump cuts with minimum awkward micro-cuts;
- active speaker / face-aware 9:16 reframing;
- safe punch-ins with bounded scale and no face clipping;
- manual/fallback center crop when tracking confidence is weak;
- phrase/word timed captions;
- intentional typographic hierarchy and restrained emphasis;
- limited visual accents/transitions tied to semantic beats;
- speech normalization, noise handling, and peak limiting.

A crop-plus-subtitles-only pipeline does not satisfy acceptance.

## CPU-first face/active-speaker approach
- OpenCV 4.14.x face detector/tracker using a redistributable model with recorded license/provenance.
- Track faces across frames; smooth crop center/zoom with velocity/acceleration limits to avoid jitter.
- Active-speaker confidence combines diarization/transcript timing where available with visible mouth motion/face prominence heuristics.
- If confidence is low or faces are absent, use deterministic composition-safe fallback rather than inventing a speaker.
- Never crop beyond source bounds; protect eyes/chin and caption safe zone.

## Caption design
- Word/phrase timing from transcript, with line breaking based on semantic phrases rather than raw fixed characters.
- Maximum two lines default; three only in explicit accessibility fallback.
- Keep text inside safe bounds; default no caption glyph below ~82% canvas height and no critical text in top notch/Dynamic Island danger region.
- Strong contrast via layered shadow/stroke/backplate as design dictates; not generic subtitle boxes.
- Emphasis limited to meaningful words; no karaoke overload.
- Caption text must match transcript after final edit timing.

## Speech/audio processing
Default dialogue chain, adjusted to source:
1. high-pass/low-frequency cleanup only if needed;
2. basic noise reduction only when it improves intelligibility without artifacts;
3. light compression/normalization;
4. two-pass or measured loudness normalization;
5. limiter.

Default final integrated loudness target: approximately **-15 LUFS**, acceptable QC band roughly **-18 to -12 LUFS** unless platform/campaign rule overrides. True peak should not exceed **-1.0 dBTP**. Clipped/distorted originals are flagged; processing must not pretend damage was repaired when it was not.

## Render-safe music/SFX subsystem
### SFX categories
- whoosh/swishes
- ticks/clicks
- pops
- impacts
- bass hits
- risers
- downlifters
- transition sweeps
- stingers
- ambience

### Music categories
- tension
- energetic/motivational
- dark/minimal
- light/comedic where suitable

Every baked asset requires provenance/license record in `audio_assets` and `render_safe=true`. No unclear copyrighted music is baked into final MP4.

### Separate concepts
- **RENDER-SAFE AUDIO:** licensed/royalty-cleared asset allowed to be baked into MP4.
- **PLATFORM-NATIVE AUDIO RECOMMENDATION:** metadata telling owner which native platform audio/style to consider after upload. It is not baked unless separate rights explicitly allow it.

### Mixing rules
- Dialogue always wins intelligibility.
- Music ducks under speech using envelope/sidechain-style automation; default music bed remains restrained.
- Fades at starts/ends/cuts.
- Loops must use seam-safe edit/crossfade; obvious hard-loop clicks fail QC.
- SFX are placed on semantic events/cuts/emphasis, not random decoration.
- Optional beat-aware timing may shift non-semantic cut accents within a small safe tolerance; it cannot distort speech meaning/timing.
- Density enum `NONE|LOW|MEDIUM|HIGH`; default is `LOW` unless content/campaign evidence supports more.
- Campaign rule can force NONE or otherwise constrain audio.

## QC READY gate
Every render must record each check. `READY` requires all hard checks pass.

Hard checks:
1. video decodes end-to-end;
2. audio decodes when audio expected;
3. dimensions/aspect match intended profile;
4. duration within campaign/platform rules;
5. no substantial black/frozen-frame anomaly beyond intentional transitions;
6. no missing audio/channel catastrophe;
7. no hard clipping and loudness/peak within configured bounds;
8. captions remain inside safe bounds;
9. face crop valid where face-aware mode used; no severe jitter/face cut-off;
10. no severe caption/critical-subject overlap;
11. cut frequency sanity — reject pathological rapid micro-cuts or unexpectedly static assembly based on plan;
12. referenced transitions/assets actually exist and decoded;
13. no HONOR-added watermark;
14. uniqueness rule passes against campaign and local clip fingerprints;
15. rule snapshot + rights/provenance metadata attached;
16. output file size is nonzero and within configured practical platform/upload ceiling;
17. SHA-256 recorded after final file close.

Advisory metrics: VMAF/quality proxy where practical, silence percentage, face confidence, caption density, render speed, file size, loudness values.

## Frozen-frame/black detection
Sample frames across output plus shot-level intervals. Use luma variance/histogram and frame-difference thresholds with duration to avoid false positives from deliberate fades/stills. Thresholds are config + QC-versioned, not silently changed.

## Uniqueness
At minimum combine source time-range overlap, normalized transcript similarity, perceptual frame hashes, edit-plan fingerprints, and campaign uniqueness rule. Unknown campaign uniqueness rules block if duplication risk matters.

## Retry/ejection
- Fixable render/QC failure: at most two automated rerender strategies.
- Persistent/broken output: clip becomes `EJECTED`, job terminal or blocked; never `READY`.
- Failure reason and cost remain visible to owner.

## Asset retention
- source and intermediate files have configurable retention/lifecycle based on rights and need;
- final clips and evidence retained longer;
- deletes respect audit/provenance requirements;
- R2 free-tier target is protected by cleanup jobs and owner-visible storage metrics.

## Frozen edit-plan / render-manifest provenance contract (Round 4)
`jsonschema/edit_plan.v1.json` is the C03/C04 interchange authority. It records immutable source hash, campaign-rule snapshots, source-rights record/hash, plan version/supersession, canonical plan fingerprint, deterministic source→output cuts with word/phoneme boundary guard, active-speaker/face/layout events, punch-ins, captions, restrained visual emphasis, audio cleanup targets, audio-plan linkage, output parameters, and the mandatory render-manifest schema ID. C03/C04 may implement algorithms but may not add an incompatible plan shape without CHANGE REQUEST.

`jsonschema/render_manifest.v1.json` is written only for the accepted terminal render after a successful immutable QC attempt. It records source/edit/audio hashes and versions, every render-safe audio asset identifier/hash/license reference, renderer/container versions, material render parameters, final output hash/size/duration, and the passed QC reference. `render_manifests` is append-only and a clip cannot enter READY without one.

`jsonschema/clip.posting_recommendation.v1.json` freezes the owner's manual-posting instructions: platform/account/identity, `recommended_publish_at`, caption/title/hashtags, required mentions, disclosure, campaign submission requirements, and platform-native audio guidance. `jsonschema/audio_plan.native_recommendation.v1.json` explicitly represents RECOMMENDED / PROHIBITED / UNKNOWN / NOT_APPLICABLE, reason, cue guidance, campaign compatibility, rule snapshot, and `not_baked_into_rendered_mp4=true`. Campaign rules always override audio recommendations; render-safe audio remains a separate subsystem.

QC rows are terminal-at-insert: execution completes first, then an immutable row is inserted with non-null `finished_at` and `passed`. Failed retries create new rows. READY requires a passed immutable QC row plus the matching immutable render manifest.

## Round-5 clip lineage and posting snapshot
A rendered clip may not mix provenance from unrelated records. The DB binds clip rights/source/campaign/rule snapshot, edit-plan candidate/source/run and JSON provenance, audio-plan/edit-plan, and final render-manifest source/edit/audio/output/QC identity. Once an accepted render manifest exists, material render/provenance identity cannot change in place; a correction requires a new clip lineage and render.

The posting recommendation JSON is the sole manual-posting instruction source. Caption/title/hashtags columns are exact derived mirrors, preventing the UI and canonical recommendation from diverging. Recommendation revisions stop when posting/archival begins; the posted clip therefore preserves the exact instruction snapshot used for manual posting.

## Round-7 rule / rights consumption

Edit planning, render, QC and READY consume the exact clip/allocation `rule_snapshot_id` and current applicable rights version. Critical UNKNOWN media restrictions block production. Effective maximum clip duration is the minimum of every known campaign maximum and the rights platform `max_clip_seconds`; rights or rule UNKNOWN never means unlimited. A non-null rights `required_attribution` must be explicit in the posting snapshot and included verbatim in the owner-copy caption. Native-audio recommendation platform must equal posting/account platform at recommendation time, independently of factual `post.native_audio_used`.

## Round-7 rule/rights consumption
Edit planning, audio planning, render, QC and READY use the exact rule snapshot and the latest applicable rights version at action time. Unknown source/content/edit/uniqueness/render-audio restrictions block their consuming stage. Effective duration must satisfy both campaign min/max and source-rights platform max; the most restrictive compatible known limit wins. Required source attribution is explicit in the posting snapshot and owner copy. Native-audio recommendation platform must equal the posting/account platform; per-platform campaign-native-audio state cannot be escalated. Render-safe audio remains separate from platform-native guidance.

### Round-7 audio-planning current-rights gate
Creating a committed audio plan revalidates the edit plan's pinned source/campaign rights at the audio-plan commit timestamp and blocks if a newer rights version has narrowed/revoked the required edit authority. `render_audio_rules` and `platform_native_audio_rules` UNKNOWN states block audio planning. This does not rewrite the historical edit plan; a later permissible decision creates new downstream history.

## Round-8 restriction, audio, disclosure and render-start freeze

Campaign restriction behavior is no longer inferred downstream: `HONOR_CAMPAIGN_RESTRICTION_SEMANTICS.json` freezes all 12 codes. `NO_CROP` forces fit/no-crop with no pan/zoom/punch-in; `NO_SPEED_CHANGE` requires playback rate 1.0; `NO_TEXT_OVERLAY` includes burned captions and disclosure overlays. If VIDEO/BOTH disclosure conflicts with NO_TEXT_OVERLAY, production blocks instead of weakening either rule. Source-origin restrictions bind frozen source/rights provenance; content restrictions require structured compliance evidence and terminal campaign-restriction QC; uniqueness uses the frozen edit signature and exact account/campaign scope.

Known `render_audio_rules` inner values mechanically constrain the immutable audio plan. PROHIBITED or UNKNOWN music cannot produce a music asset; PROHIBITED or UNKNOWN SFX requires empty events and density NONE; `max_sfx_density` is an upper bound and NONE means no SFX. A PROHIBITED master allows a class only when that exact class is explicitly ALLOWED. A class marked NOT_APPLICABLE under an ALLOWED master inherits the master; null SFX max then means no campaign-specific density cap. Outer NOT_APPLICABLE applies HONOR defaults but still requires active render-safe assets and exact compliance mirrors. Operational instructions remain attached to the exact snapshot and require QC evidence when present. Render manifests must exactly match planned render-safe assets.

Before any paid render begins, `PLANNED -> RENDERING` revalidates the latest applicable RENDER rights at DB statement time and sets immutable `render_started_at`. READY retains its independent current-rights gate. VIDEO/BOTH disclosure must be represented in edit planning, carried into the render manifest and receive PASS QC; PROVIDER_SUBMISSION placement must appear in submission requirements.

## Round-9 canonical QC and uniqueness acceptance

`HONOR_QC_POLICY.json` is the machine authority for the 20 canonical C00 QC checks. Every V1 check is a hard gate; `NOT_APPLICABLE` is legal only for the explicit conditional checks and conditions in that artifact. `FAIL` or `WARN` prevents derived success and requires reason/evidence. Database insertion derives `qc_runs.passed`; the caller cannot downgrade a hard gate or assert a successful row over a failed mandatory check.

When any of `NO_REUSED_EDIT`, `UNIQUE_PER_ACCOUNT`, or `UNIQUE_PER_CAMPAIGN` applies, the uniqueness QC check must be `PASS` and the exact edit signature/scope is reserved atomically at READY acceptance. Concurrent renders with the same restricted scope/signature cannot both enter the accepted READY/POSTED/ARCHIVED population.

## Round-10 null-audio and posting-proof behavior

A clip with no committed audio plan may not embed render-safe MUSIC or SFX. Its render manifest must carry null audio-plan identity and an empty render-safe asset set. `render_audio_compliance=NOT_APPLICABLE` is legal only when the sealed `render_audio_rules` state itself is NOT_APPLICABLE; KNOWN rules require explicit PASS evidence even for a deliberately silent/no-extra-audio render, including material-instruction acknowledgement, while UNKNOWN blocks READY.

Posting-copy revisions are content decisions, not mere metadata edits. A changed caption/title is hashed and every active restriction whose frozen consuming stages include `posting` must have one fresh COMPLIANT proof bound to the exact new recommendation version/hash no later than the DB-authored revision time.

## Round-11 render-safe audio rights contract

The canonical machine policy is `HONOR_AUDIO_ASSET_RIGHTS_CONTRACT.json`. Render-safe is a rights decision, not a catalog tag. An automatically baked MUSIC/SFX asset must be active; have `audio_assets.render_safe=true` and `allowed_uses.render_safe=true` with no disagreement; permit commercial use and derivative editing; explicitly list the clip/account platform; have no unevaluated campaign-specific restriction; require no attribution; and carry immutable license evidence object/hash when `license_evidence_required=true`.

Attribution-required assets may remain catalogued but are not V1 auto-embeddable because no approved end-to-end attribution workflow is frozen. Likewise any non-null `allowed_uses.campaign_restriction` blocks automatic selection rather than being guessed compatible.

Eligibility is checked when the audio plan commits, again before `PLANNED -> RENDERING`, and again when the terminal render manifest is admitted. Deactivation between plan and render blocks rendering. Every manifest audio entry must match the immutable canonical asset UUID/kind/SHA/license reference and exact committed-plan membership.

A null audio plan means the manifest audio-plan ID/hash/version/schema fields are null, `render_safe_assets=[]`, `planned_music_asset_id=null`, `planned_sfx_asset_ids=[]`, and `audio_rule_compliance.rule_snapshot_id` still equals the clip rule snapshot. Null-plan QC applicability never authorizes hidden baked audio.
