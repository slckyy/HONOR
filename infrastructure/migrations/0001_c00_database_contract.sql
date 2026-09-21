-- HONOR C00 CANONICAL DATABASE DDL CONTRACT — NOT AN EXECUTED MIGRATION.
-- C01 migrations must implement this contract faithfully. Application-generated UUIDv7 values are supplied for all `id uuid` PKs.
-- PostgreSQL/Supabase; timestamps are UTC timestamptz; USD is numeric(18,6).

-- ---------- ENUMS ----------
CREATE TYPE platform_enum AS ENUM ('TIKTOK','INSTAGRAM_REELS','YOUTUBE_SHORTS');
CREATE TYPE account_health_enum AS ENUM ('HEALTHY','CAUTION','PAUSED','UNKNOWN');
CREATE TYPE campaign_status_enum AS ENUM ('DISCOVERED','VERIFYING','ACTIVE','PAUSED','ENDED','REJECTED','UNKNOWN');
CREATE TYPE capture_method_enum AS ENUM ('API','PERMITTED_PAGE','OWNER_UPLOAD','MANUAL_ENTRY');
CREATE TYPE knowledge_state_enum AS ENUM ('KNOWN','UNKNOWN','NOT_APPLICABLE');
CREATE TYPE verified_by_enum AS ENUM ('API','IMPORTER','OWNER','BUILDER');
CREATE TYPE source_origin_enum AS ENUM ('CAMPAIGN_AUTHORIZED','OWNER_OWNED','EXPLICITLY_LICENSED');
CREATE TYPE source_ingest_status_enum AS ENUM ('PENDING_UPLOAD','QUEUED','INGESTING','READY','BLOCKED_RIGHTS','FAILED');
CREATE TYPE source_eligibility_enum AS ENUM ('ELIGIBLE','INELIGIBLE','UNKNOWN');
CREATE TYPE transcript_status_enum AS ENUM ('QUEUED','RUNNING','SUCCEEDED','FAILED');
CREATE TYPE audio_kind_enum AS ENUM ('MUSIC','SFX');
CREATE TYPE audio_density_enum AS ENUM ('NONE','LOW','MEDIUM','HIGH');
CREATE TYPE clip_state_enum AS ENUM ('PLANNED','RENDERING','QC','READY','EJECTED','POSTED','ARCHIVED');
CREATE TYPE post_status_enum AS ENUM ('PUBLISHED','INVALIDATED');
CREATE TYPE submission_status_enum AS ENUM ('NOT_REQUIRED','PENDING','SUBMITTED','ACCEPTED','REJECTED','UNKNOWN');
CREATE TYPE checkin_type_enum AS ENUM ('H2','H24','H72','FINAL','CUSTOM');
CREATE TYPE checkin_status_enum AS ENUM ('PENDING','DUE','COMPLETED','MISSED','NOT_APPLICABLE');
CREATE TYPE analytics_evidence_method_enum AS ENUM ('OWNER_MANUAL','OFFICIAL_API','COMPLIANT_IMPORT');
CREATE TYPE earning_state_enum AS ENUM ('ACCRUED_UNVERIFIED','APPROVED','WITHDRAWABLE','WITHDRAWN','VOIDED');
CREATE TYPE cost_category_enum AS ENUM ('INFRASTRUCTURE','AI_REASONING','TRANSCRIPTION','POLLI_VOICE','STORAGE','GPU','MONITORING','DOMAIN','OTHER');
CREATE TYPE confidence_enum AS ENUM ('HIGH','MEDIUM','LOW');
CREATE TYPE polli_mode_enum AS ENUM ('TEXT','VOICE');
CREATE TYPE polli_session_status_enum AS ENUM ('ACTIVE','ENDED','FAILED');
CREATE TYPE polli_retention_enum AS ENUM ('TRANSCRIPT_SUMMARY');
CREATE TYPE tool_call_status_enum AS ENUM ('SUCCEEDED','FAILED');
CREATE TYPE job_state_enum AS ENUM ('queued','running','retrying','blocked-owner-action','failed-terminal','succeeded','cancelled');
CREATE TYPE owner_action_status_enum AS ENUM ('OPEN','RESOLVED','CANCELLED');
CREATE TYPE backup_status_enum AS ENUM ('RUNNING','SUCCEEDED','FAILED');
CREATE TYPE backup_verification_enum AS ENUM ('PENDING','VERIFIED','FAILED');
CREATE TYPE upload_purpose_enum AS ENUM ('SOURCE_MEDIA','CAMPAIGN_TERMS_EVIDENCE','SOURCE_RIGHTS_EVIDENCE','SUBMISSION_EVIDENCE','ANALYTICS_EVIDENCE');
CREATE TYPE upload_state_enum AS ENUM ('INTENT_CREATED','UPLOADED','VERIFIED','REJECTED','EXPIRED');
CREATE TYPE experiment_status_enum AS ENUM ('DRAFT','RUNNING','STOPPED','COMPLETED','CANCELLED');
CREATE TYPE experiment_unit_enum AS ENUM ('GENERATION_RUN','CLIP','SOCIAL_ACCOUNT');

-- ---------- OWNER / SOCIAL ----------
CREATE TABLE owner_profiles (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  display_name text NOT NULL,
  timezone text NOT NULL DEFAULT 'America/Chicago',
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE social_identities (
  id uuid PRIMARY KEY,
  name text NOT NULL,
  slug text NOT NULL UNIQUE,
  brand_notes text NULL,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE social_accounts (
  id uuid PRIMARY KEY,
  identity_id uuid NOT NULL REFERENCES social_identities(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  platform platform_enum NOT NULL,
  handle text NOT NULL,
  external_account_id text NULL,
  status text NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','PAUSED','DISABLED','UNKNOWN')),
  posting_timezone text NOT NULL DEFAULT 'America/Chicago',
  notes text NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(identity_id, platform, handle),
  UNIQUE(id,platform),
  UNIQUE(id,identity_id)
);
CREATE INDEX idx_social_accounts_identity ON social_accounts(identity_id);
CREATE UNIQUE INDEX uq_social_accounts_platform_external ON social_accounts(platform, external_account_id) WHERE external_account_id IS NOT NULL;

CREATE TABLE account_health_snapshots (
  id uuid PRIMARY KEY,
  social_account_id uuid NOT NULL REFERENCES social_accounts(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  captured_at timestamptz NOT NULL,
  health account_health_enum NOT NULL,
  account_region text NULL CHECK (account_region IS NULL OR account_region ~ '^[A-Z]{2}(-[A-Z0-9]{1,3})?$'),
  follower_count bigint NULL CHECK (follower_count IS NULL OR follower_count >= 0),
  posting_available boolean NULL,
  signals jsonb NOT NULL CHECK (jsonb_typeof(signals)='object'),
  evidence_uri text NULL,
  source text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(id,social_account_id)
);
CREATE INDEX idx_account_health_account_time ON account_health_snapshots(social_account_id,captured_at DESC);

-- ---------- CAMPAIGNS / RULES ----------
CREATE TABLE campaigns (
  id uuid PRIMARY KEY,
  provider text NOT NULL,
  campaign_url text NULL,
  canonical_url text NULL,
  external_campaign_id text NULL,
  status campaign_status_enum NOT NULL DEFAULT 'DISCOVERED',
  title text NOT NULL,
  currency char(3) NOT NULL DEFAULT 'USD' CHECK (currency ~ '^[A-Z]{3}$'),
  start_at timestamptz NULL,
  end_at timestamptz NULL,
  deadline_at timestamptz NULL,
  last_verified_at timestamptz NULL,
  terms_snapshot_id uuid NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (end_at IS NULL OR start_at IS NULL OR end_at >= start_at)
);
CREATE UNIQUE INDEX uq_campaign_provider_external ON campaigns(provider,external_campaign_id) WHERE external_campaign_id IS NOT NULL;
CREATE UNIQUE INDEX uq_campaign_canonical_url ON campaigns(canonical_url) WHERE canonical_url IS NOT NULL AND external_campaign_id IS NULL;
CREATE INDEX idx_campaign_status_deadline ON campaigns(status,deadline_at);

CREATE TABLE campaign_terms_snapshots (
  id uuid PRIMARY KEY,
  campaign_id uuid NOT NULL REFERENCES campaigns(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  captured_at timestamptz NOT NULL,
  source_url text NULL,
  storage_object_key text NOT NULL,
  sha256 char(64) NOT NULL CHECK (sha256 ~ '^[a-f0-9]{64}$'),
  capture_method capture_method_enum NOT NULL,
  notes text NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(id,campaign_id)
);
CREATE INDEX idx_terms_campaign_time ON campaign_terms_snapshots(campaign_id,captured_at DESC);
ALTER TABLE campaigns ADD CONSTRAINT fk_campaign_current_terms FOREIGN KEY (terms_snapshot_id,id) REFERENCES campaign_terms_snapshots(id,campaign_id) ON DELETE RESTRICT ON UPDATE RESTRICT;

CREATE TABLE campaign_rule_items (
  id uuid PRIMARY KEY,
  campaign_id uuid NOT NULL REFERENCES campaigns(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  terms_snapshot_id uuid NOT NULL,
  rule_key text NOT NULL CHECK (rule_key IN ('provider','campaign_url','external_campaign_id','status','compensation_model','cpm_or_rate','minimum_views','max_payout_per_clip','total_budget','remaining_budget','start_at','end_at','deadline_at','eligible_platforms','eligible_regions','eligible_account_requirements','required_tags','required_mentions','required_hashtags','disclosure_requirements','source_material_restrictions','clip_length_min_seconds','clip_length_max_seconds','content_restrictions','editing_restrictions','uniqueness_rules','submission_format','analytics_window','payout_window','render_audio_rules','platform_native_audio_rules','last_verified_at')),
  knowledge_state knowledge_state_enum NOT NULL,
  typed_value jsonb NULL,
  confidence numeric(4,3) NULL CHECK (confidence IS NULL OR (confidence >= 0 AND confidence <= 1)),
  evidence_snapshot_id uuid NULL,
  evidence_locator text NULL,
  verified_at timestamptz NULL,
  verified_by verified_by_enum NOT NULL,
  schema_version integer NOT NULL DEFAULT 1 CHECK (schema_version = 1),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(campaign_id,terms_snapshot_id,rule_key,schema_version),
  CONSTRAINT fk_campaign_rule_set_campaign FOREIGN KEY (terms_snapshot_id,campaign_id) REFERENCES campaign_terms_snapshots(id,campaign_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_campaign_rule_evidence_campaign FOREIGN KEY (evidence_snapshot_id,campaign_id) REFERENCES campaign_terms_snapshots(id,campaign_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CHECK (updated_at = created_at),
  CHECK (
    (knowledge_state='KNOWN' AND typed_value IS NOT NULL AND evidence_snapshot_id IS NOT NULL AND verified_at IS NOT NULL)
    OR (knowledge_state='NOT_APPLICABLE' AND typed_value IS NULL AND evidence_snapshot_id IS NOT NULL AND verified_at IS NOT NULL)
    OR (knowledge_state='UNKNOWN' AND typed_value IS NULL)
  )
);
CREATE INDEX idx_campaign_rules_campaign_snapshot_state ON campaign_rule_items(campaign_id,terms_snapshot_id,knowledge_state);

-- ---------- UPLOADS / SOURCES / RIGHTS ----------
CREATE TABLE uploads (
  id uuid PRIMARY KEY,
  owner_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  purpose upload_purpose_enum NOT NULL,
  state upload_state_enum NOT NULL DEFAULT 'INTENT_CREATED',
  filename text NOT NULL,
  content_type text NOT NULL,
  object_key text NOT NULL UNIQUE,
  expected_size_bytes bigint NOT NULL CHECK (expected_size_bytes > 0 AND expected_size_bytes <= 2147483648),
  expected_sha256 char(64) NOT NULL CHECK (expected_sha256 ~ '^[a-f0-9]{64}$'),
  verified_size_bytes bigint NULL CHECK (verified_size_bytes IS NULL OR verified_size_bytes > 0),
  verified_sha256 char(64) NULL CHECK (verified_sha256 IS NULL OR verified_sha256 ~ '^[a-f0-9]{64}$'),
  expires_at timestamptz NOT NULL,
  verified_at timestamptz NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_upload_owner_state ON uploads(owner_user_id,state,expires_at);

CREATE TABLE sources (
  id uuid PRIMARY KEY,
  origin_type source_origin_enum NOT NULL,
  source_url text NULL,
  provider text NOT NULL,
  external_source_id text NULL,
  title text NULL,
  storage_object_key text NULL,
  sha256 char(64) NULL CHECK (sha256 IS NULL OR sha256 ~ '^[a-f0-9]{64}$'),
  duration_ms bigint NULL CHECK (duration_ms IS NULL OR duration_ms >= 0),
  ingest_status source_ingest_status_enum NOT NULL DEFAULT 'QUEUED',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX uq_source_provider_external ON sources(provider,external_source_id) WHERE external_source_id IS NOT NULL;
CREATE INDEX idx_sources_ingest ON sources(ingest_status,created_at);

CREATE TABLE source_rights (
  id uuid PRIMARY KEY,
  source_id uuid NOT NULL REFERENCES sources(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  rights_version integer NOT NULL CHECK (rights_version > 0),
  supersedes_rights_id uuid NULL REFERENCES source_rights(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  eligibility source_eligibility_enum NOT NULL,
  authorized_uses jsonb NOT NULL CHECK (jsonb_typeof(authorized_uses)='object'),
  platform_limits jsonb NOT NULL CHECK (jsonb_typeof(platform_limits)='object'),
  evidence_type text NOT NULL,
  evidence_uri text NULL,
  evidence_object_key text NULL,
  evidence_captured_at timestamptz NOT NULL,
  expires_at timestamptz NULL,
  notes text NULL,
  schema_version integer NOT NULL DEFAULT 1 CHECK (schema_version = 1),
  record_hash char(64) NOT NULL CHECK (record_hash ~ '^[a-f0-9]{64}$'),
  committed_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (evidence_uri IS NOT NULL OR evidence_object_key IS NOT NULL),
  UNIQUE(source_id,rights_version),
  UNIQUE(id,source_id),
  UNIQUE(supersedes_rights_id),
  UNIQUE(record_hash),
  CHECK ((rights_version = 1 AND supersedes_rights_id IS NULL) OR (rights_version > 1 AND supersedes_rights_id IS NOT NULL))
);
CREATE INDEX idx_source_rights_source_time ON source_rights(source_id,evidence_captured_at DESC);

-- Canonical immutable rights-version↔campaign applicability relation. Each row belongs to one immutable source_rights version; changes require a new source_rights version plus new relation rows. Historical rows are never updated/deleted.
CREATE TABLE source_rights_campaigns (
  source_rights_id uuid NOT NULL REFERENCES source_rights(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  campaign_id uuid NOT NULL REFERENCES campaigns(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(source_rights_id,campaign_id)
);
CREATE INDEX idx_source_rights_campaign_campaign ON source_rights_campaigns(campaign_id,source_rights_id);

CREATE TABLE transcripts (
  id uuid PRIMARY KEY,
  source_id uuid NOT NULL REFERENCES sources(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  campaign_id uuid NOT NULL REFERENCES campaigns(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  rights_id uuid NOT NULL,
  provider text NOT NULL,
  model text NOT NULL,
  language text NULL,
  duration_ms bigint NULL CHECK (duration_ms IS NULL OR duration_ms >= 0),
  text_summary text NULL,
  word_timing_object_key text NULL,
  speaker_data_object_key text NULL,
  cost_ledger_id uuid NULL,
  status transcript_status_enum NOT NULL DEFAULT 'QUEUED',
  transcript_version integer NOT NULL DEFAULT 1 CHECK (transcript_version > 0),
  supersedes_transcript_id uuid NULL REFERENCES transcripts(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  transcript_sha256 char(64) NULL CHECK (transcript_sha256 IS NULL OR transcript_sha256 ~ '^[a-f0-9]{64}$'),
  completed_at timestamptz NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(source_id,transcript_version),
  UNIQUE(supersedes_transcript_id),
  CONSTRAINT fk_transcript_rights_source FOREIGN KEY (rights_id,source_id) REFERENCES source_rights(id,source_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_transcript_rights_campaign FOREIGN KEY (rights_id,campaign_id) REFERENCES source_rights_campaigns(source_rights_id,campaign_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CHECK ((transcript_version=1 AND supersedes_transcript_id IS NULL) OR (transcript_version>1 AND supersedes_transcript_id IS NOT NULL)),
  CHECK ((status='SUCCEEDED' AND transcript_sha256 IS NOT NULL AND completed_at IS NOT NULL) OR status<>'SUCCEEDED')
);
CREATE INDEX idx_transcripts_source_status ON transcripts(source_id,status);

-- ---------- GENERATION / INTELLIGENCE ----------
CREATE TABLE generation_runs (
  id uuid PRIMARY KEY,
  target_date date NOT NULL,
  requested_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  state job_state_enum NOT NULL DEFAULT 'queued',
  stage text NOT NULL DEFAULT 'campaign_import' CHECK (stage IN ('campaign_import','rules_normalization','source_ingest','rights_verification','transcription','candidate_discovery','candidate_scoring','finalist_selection','edit_plan','audio_plan','render','qc','schedule','analytics_ingest','payout_reconcile','cost_reconcile','backup')),
  strategy_version text NOT NULL,
  budget_snapshot jsonb NOT NULL CHECK (jsonb_typeof(budget_snapshot)='object'),
  requested_constraints jsonb NOT NULL CHECK (jsonb_typeof(requested_constraints)='object'),
  selected_plan jsonb NULL CHECK (selected_plan IS NULL OR jsonb_typeof(selected_plan)='object'),
  correlation_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz NULL
);
CREATE INDEX idx_generation_runs_target_state ON generation_runs(target_date,state);
CREATE INDEX idx_generation_runs_correlation ON generation_runs(correlation_id);

CREATE TABLE run_campaign_allocations (
  id uuid PRIMARY KEY,
  generation_run_id uuid NOT NULL REFERENCES generation_runs(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  campaign_id uuid NOT NULL REFERENCES campaigns(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  social_account_id uuid NOT NULL REFERENCES social_accounts(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  source_id uuid NOT NULL REFERENCES sources(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  rule_snapshot_id uuid NOT NULL,
  rights_id uuid NOT NULL,
  account_health_snapshot_id uuid NOT NULL,
  decision_as_of timestamptz NOT NULL,
  analysis_version text NOT NULL,
  experiment_assignment_id uuid NULL,
  recommended_clip_count integer NOT NULL CHECK (recommended_clip_count >= 0),
  expected_payout_usd numeric(18,6) NULL CHECK (expected_payout_usd IS NULL OR expected_payout_usd >= 0),
  marginal_cost_usd numeric(18,6) NOT NULL CHECK (marginal_cost_usd >= 0),
  information_value numeric(18,6) NULL,
  uncertainty numeric(6,5) NOT NULL CHECK (uncertainty >= 0 AND uncertainty <= 1),
  score numeric(18,6) NULL,
  eligibility_decision text NOT NULL CHECK (eligibility_decision IN ('ELIGIBLE','INELIGIBLE','UNKNOWN')),
  rationale_json jsonb NOT NULL CHECK (jsonb_typeof(rationale_json)='object'),
  model_version text NULL,
  deterministic_rules_version text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT fk_allocation_rule_campaign FOREIGN KEY (rule_snapshot_id,campaign_id) REFERENCES campaign_terms_snapshots(id,campaign_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_allocation_rights_source FOREIGN KEY (rights_id,source_id) REFERENCES source_rights(id,source_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_allocation_rights_campaign FOREIGN KEY (rights_id,campaign_id) REFERENCES source_rights_campaigns(source_rights_id,campaign_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_allocation_account_health FOREIGN KEY (account_health_snapshot_id,social_account_id) REFERENCES account_health_snapshots(id,social_account_id) ON DELETE RESTRICT ON UPDATE RESTRICT
);
CREATE INDEX idx_allocations_run ON run_campaign_allocations(generation_run_id);
CREATE INDEX idx_allocations_campaign_account ON run_campaign_allocations(campaign_id,social_account_id);

CREATE TABLE candidates (
  id uuid PRIMARY KEY,
  generation_run_id uuid NOT NULL REFERENCES generation_runs(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  source_id uuid NOT NULL REFERENCES sources(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  transcript_id uuid NOT NULL REFERENCES transcripts(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  scoring_version text NOT NULL,
  experiment_assignment_id uuid NULL,
  start_ms bigint NOT NULL CHECK (start_ms >= 0),
  end_ms bigint NOT NULL CHECK (end_ms > start_ms),
  transcript_excerpt text NOT NULL,
  context_independence_score numeric(6,5) NOT NULL CHECK (context_independence_score BETWEEN 0 AND 1),
  hook_score numeric(6,5) NOT NULL CHECK (hook_score BETWEEN 0 AND 1),
  payoff_score numeric(6,5) NOT NULL CHECK (payoff_score BETWEEN 0 AND 1),
  editability_score numeric(6,5) NOT NULL CHECK (editability_score BETWEEN 0 AND 1),
  rule_fit_score numeric(6,5) NOT NULL CHECK (rule_fit_score BETWEEN 0 AND 1),
  novelty_score numeric(6,5) NOT NULL CHECK (novelty_score BETWEEN 0 AND 1),
  overall_score numeric(6,5) NOT NULL CHECK (overall_score BETWEEN 0 AND 1),
  features jsonb NOT NULL CHECK (jsonb_typeof(features)='object'),
  selected boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_candidates_run_selected_score ON candidates(generation_run_id,selected,overall_score DESC);
CREATE INDEX idx_candidates_source ON candidates(source_id);

CREATE TABLE edit_plans (
  id uuid PRIMARY KEY,
  candidate_id uuid NOT NULL REFERENCES candidates(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  schema_version integer NOT NULL DEFAULT 1 CHECK (schema_version = 1),
  plan_version integer NOT NULL CHECK (plan_version > 0),
  supersedes_edit_plan_id uuid NULL REFERENCES edit_plans(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  plan_hash char(64) NOT NULL CHECK (plan_hash ~ '^[a-f0-9]{64}$'),
  plan_json jsonb NOT NULL CHECK (jsonb_typeof(plan_json)='object'),
  created_by_model text NULL,
  committed_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(candidate_id,plan_version),
  UNIQUE(supersedes_edit_plan_id),
  UNIQUE(plan_hash),
  CHECK ((plan_version = 1 AND supersedes_edit_plan_id IS NULL) OR (plan_version > 1 AND supersedes_edit_plan_id IS NOT NULL))
);
CREATE INDEX idx_edit_plans_candidate ON edit_plans(candidate_id);

CREATE TABLE audio_assets (
  id uuid PRIMARY KEY,
  kind audio_kind_enum NOT NULL,
  category text NOT NULL,
  name text NOT NULL,
  storage_object_key text NOT NULL UNIQUE,
  sha256 char(64) NOT NULL CHECK (sha256 ~ '^[a-f0-9]{64}$'),
  license_name text NOT NULL,
  license_url_or_reference text NOT NULL,
  license_evidence_object_key text NULL,
  license_evidence_sha256 char(64) NULL CHECK (license_evidence_sha256 IS NULL OR license_evidence_sha256 ~ '^[a-f0-9]{64}$'),
  provenance_notes text NOT NULL,
  render_safe boolean NOT NULL,
  attribution_required boolean NOT NULL DEFAULT false,
  allowed_uses jsonb NOT NULL CHECK (jsonb_typeof(allowed_uses)='object'),
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK ((license_evidence_object_key IS NULL) = (license_evidence_sha256 IS NULL))
);
CREATE INDEX idx_audio_assets_kind_category_active ON audio_assets(kind,category,active);

CREATE TABLE audio_plans (
  id uuid PRIMARY KEY,
  edit_plan_id uuid NOT NULL REFERENCES edit_plans(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  density audio_density_enum NOT NULL DEFAULT 'LOW',
  music_asset_id uuid NULL REFERENCES audio_assets(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  platform_native_recommendation jsonb NOT NULL,
  sfx_events jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(sfx_events)='array'),
  ducking_config jsonb NOT NULL CHECK (jsonb_typeof(ducking_config)='object'),
  beat_map_object_key text NULL,
  rule_override_notes text NULL,
  rule_compliance jsonb NOT NULL CHECK (jsonb_typeof(rule_compliance)='object'),
  schema_version integer NOT NULL DEFAULT 1 CHECK (schema_version = 1),
  plan_version integer NOT NULL CHECK (plan_version > 0),
  supersedes_audio_plan_id uuid NULL REFERENCES audio_plans(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  plan_hash char(64) NOT NULL CHECK (plan_hash ~ '^[a-f0-9]{64}$'),
  committed_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(edit_plan_id,plan_version),
  UNIQUE(id,edit_plan_id),
  UNIQUE(supersedes_audio_plan_id),
  UNIQUE(plan_hash),
  CHECK ((plan_version = 1 AND supersedes_audio_plan_id IS NULL) OR (plan_version > 1 AND supersedes_audio_plan_id IS NOT NULL))
);
CREATE INDEX idx_audio_plans_edit ON audio_plans(edit_plan_id);

-- ---------- MEDIA / QC / POSTING ----------
CREATE TABLE clips (
  id uuid PRIMARY KEY,
  generation_run_id uuid NOT NULL REFERENCES generation_runs(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  campaign_id uuid NOT NULL REFERENCES campaigns(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  source_id uuid NOT NULL REFERENCES sources(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  social_account_id uuid NOT NULL REFERENCES social_accounts(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  edit_plan_id uuid NOT NULL REFERENCES edit_plans(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  audio_plan_id uuid NULL REFERENCES audio_plans(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  state clip_state_enum NOT NULL DEFAULT 'PLANNED',
  final_object_key text NULL,
  thumbnail_object_key text NULL,
  sha256 char(64) NULL CHECK (sha256 IS NULL OR sha256 ~ '^[a-f0-9]{64}$'),
  duration_ms bigint NULL CHECK (duration_ms IS NULL OR duration_ms >= 0),
  width integer NULL CHECK (width IS NULL OR width > 0),
  height integer NULL CHECK (height IS NULL OR height > 0),
  codec text NULL,
  file_size_bytes bigint NULL CHECK (file_size_bytes IS NULL OR file_size_bytes >= 0),
  caption_copy text NOT NULL,
  title_copy text NULL,
  hashtags jsonb NOT NULL CHECK (jsonb_typeof(hashtags)='array'),
  posting_recommendation jsonb NOT NULL CHECK (jsonb_typeof(posting_recommendation)='object'),
  rule_snapshot_id uuid NOT NULL REFERENCES campaign_terms_snapshots(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  rights_id uuid NOT NULL REFERENCES source_rights(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  render_started_at timestamptz NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT fk_clips_rights_source FOREIGN KEY (rights_id,source_id) REFERENCES source_rights(id,source_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_clips_rights_campaign FOREIGN KEY (rights_id,campaign_id) REFERENCES source_rights_campaigns(source_rights_id,campaign_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_clips_rule_campaign FOREIGN KEY (rule_snapshot_id,campaign_id) REFERENCES campaign_terms_snapshots(id,campaign_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_clips_audio_edit FOREIGN KEY (audio_plan_id,edit_plan_id) REFERENCES audio_plans(id,edit_plan_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  UNIQUE(id,social_account_id)
);
CREATE INDEX idx_clips_state ON clips(state,created_at);
CREATE INDEX idx_clips_run ON clips(generation_run_id);
CREATE INDEX idx_clips_campaign_account ON clips(campaign_id,social_account_id);

CREATE TABLE qc_runs (
  id uuid PRIMARY KEY,
  clip_id uuid NOT NULL REFERENCES clips(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  started_at timestamptz NOT NULL,
  finished_at timestamptz NOT NULL,
  passed boolean NOT NULL,
  checks jsonb NOT NULL CHECK (jsonb_typeof(checks)='object'),
  failure_codes text[] NOT NULL DEFAULT ARRAY[]::text[],
  metrics jsonb NOT NULL CHECK (jsonb_typeof(metrics)='object'),
  qc_version text NOT NULL,
  retry_number integer NOT NULL DEFAULT 0 CHECK (retry_number >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (finished_at >= started_at),
  UNIQUE(clip_id,retry_number)
);
CREATE INDEX idx_qc_clip ON qc_runs(clip_id,started_at DESC);

-- QC rows are terminal-at-insert and immutable. A failed attempt is inserted with passed=false; a retry is a new row with retry_number+1.
-- Only a passed immutable QC row may be referenced by a render_manifest, and READY requires that manifest.
CREATE TABLE render_manifests (
  id uuid PRIMARY KEY,
  clip_id uuid NOT NULL UNIQUE REFERENCES clips(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  edit_plan_id uuid NOT NULL REFERENCES edit_plans(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  audio_plan_id uuid NULL REFERENCES audio_plans(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  qc_run_id uuid NOT NULL UNIQUE REFERENCES qc_runs(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  schema_version integer NOT NULL DEFAULT 1 CHECK (schema_version = 1),
  manifest_json jsonb NOT NULL CHECK (jsonb_typeof(manifest_json)='object'),
  manifest_hash char(64) NOT NULL UNIQUE CHECK (manifest_hash ~ '^[a-f0-9]{64}$'),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_render_manifest_edit_audio ON render_manifests(edit_plan_id,audio_plan_id);

CREATE TABLE posts (
  id uuid PRIMARY KEY,
  clip_id uuid NOT NULL REFERENCES clips(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  social_account_id uuid NOT NULL REFERENCES social_accounts(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  platform platform_enum NOT NULL,
  published_at timestamptz NOT NULL,
  post_url text NOT NULL,
  platform_post_id text NULL,
  native_audio_used jsonb NULL,
  owner_notes text NULL,
  status post_status_enum NOT NULL DEFAULT 'PUBLISHED',
  idempotency_key text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(clip_id,social_account_id),
  CONSTRAINT fk_posts_clip_account FOREIGN KEY (clip_id,social_account_id) REFERENCES clips(id,social_account_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_posts_account_platform FOREIGN KEY (social_account_id,platform) REFERENCES social_accounts(id,platform) ON DELETE RESTRICT ON UPDATE RESTRICT
);
CREATE INDEX idx_posts_account_published ON posts(social_account_id,published_at DESC);
CREATE UNIQUE INDEX uq_posts_platform_post ON posts(platform,platform_post_id) WHERE platform_post_id IS NOT NULL;

CREATE TABLE submissions (
  id uuid PRIMARY KEY,
  campaign_id uuid NOT NULL REFERENCES campaigns(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  post_id uuid NOT NULL REFERENCES posts(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  submitted_at timestamptz NULL,
  submission_reference text NULL,
  status submission_status_enum NOT NULL DEFAULT 'PENDING',
  evidence_object_key text NULL,
  idempotency_key text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(campaign_id,post_id)
);
CREATE INDEX idx_submissions_status ON submissions(status,submitted_at);

CREATE TABLE analytics_checkins (
  id uuid PRIMARY KEY,
  post_id uuid NOT NULL REFERENCES posts(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  checkin_type checkin_type_enum NOT NULL,
  due_at timestamptz NOT NULL,
  completed_at timestamptz NULL,
  status checkin_status_enum NOT NULL DEFAULT 'PENDING',
  config_snapshot jsonb NOT NULL CHECK (jsonb_typeof(config_snapshot)='object'),
  config_schema_version integer NOT NULL DEFAULT 1 CHECK (config_schema_version > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(post_id,checkin_type,due_at),
  UNIQUE(id,post_id)
);
CREATE INDEX idx_analytics_checkins_due ON analytics_checkins(status,due_at);

CREATE TABLE analytics_observations (
  id uuid PRIMARY KEY,
  post_id uuid NOT NULL REFERENCES posts(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  observed_at timestamptz NOT NULL,
  checkin_id uuid NULL,
  views bigint NOT NULL CHECK (views >= 0),
  qualified_views bigint NULL CHECK (qualified_views IS NULL OR qualified_views >= 0),
  likes bigint NULL CHECK (likes IS NULL OR likes >= 0),
  comments bigint NULL CHECK (comments IS NULL OR comments >= 0),
  shares bigint NULL CHECK (shares IS NULL OR shares >= 0),
  saves bigint NULL CHECK (saves IS NULL OR saves >= 0),
  watch_time_ms bigint NULL CHECK (watch_time_ms IS NULL OR watch_time_ms >= 0), -- total cumulative watch time across observed views, never average
  average_watch_duration_ms bigint NULL CHECK (average_watch_duration_ms IS NULL OR average_watch_duration_ms >= 0),
  completed_views bigint NULL CHECK (completed_views IS NULL OR (completed_views >= 0 AND completed_views <= views)),
  completion_rate_ppm integer NULL CHECK (completion_rate_ppm IS NULL OR (completion_rate_ppm >= 0 AND completion_rate_ppm <= 1000000)),
  follower_delta bigint NULL,
  avg_watch_pct numeric(7,4) NULL CHECK (avg_watch_pct IS NULL OR (avg_watch_pct >= 0 AND avg_watch_pct <= 100)),
  provider_status text NOT NULL DEFAULT 'RECORDED',
  evidence_method analytics_evidence_method_enum NOT NULL,
  raw_payload_object_key text NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT fk_analytics_observation_checkin_post FOREIGN KEY (checkin_id,post_id) REFERENCES analytics_checkins(id,post_id) ON DELETE RESTRICT ON UPDATE RESTRICT
);
CREATE INDEX idx_analytics_post_time ON analytics_observations(post_id,observed_at DESC);
CREATE INDEX idx_analytics_checkin ON analytics_observations(checkin_id) WHERE checkin_id IS NOT NULL;


-- ---------- MINIMAL V1 EXPERIMENT TRACKING ----------
CREATE TABLE experiments (
  id uuid PRIMARY KEY,
  name text NOT NULL,
  hypothesis text NOT NULL,
  feature_key text NOT NULL,
  unit_type experiment_unit_enum NOT NULL,
  status experiment_status_enum NOT NULL DEFAULT 'DRAFT',
  primary_metric text NOT NULL CHECK (primary_metric IN ('QUALIFIED_VIEWS','COMPLETION_RATE','AVERAGE_WATCH_DURATION','FOLLOWER_DELTA','APPROVED_REVENUE_USD')),
  started_at timestamptz NULL,
  ended_at timestamptz NULL,
  stopping_reason text NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE experiment_arms (
  id uuid PRIMARY KEY,
  experiment_id uuid NOT NULL REFERENCES experiments(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  arm_key text NOT NULL,
  description text NOT NULL,
  is_control boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(experiment_id,arm_key),
  UNIQUE(id,experiment_id)
);
CREATE TABLE experiment_assignments (
  id uuid PRIMARY KEY,
  experiment_id uuid NOT NULL REFERENCES experiments(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  arm_id uuid NOT NULL,
  unit_type experiment_unit_enum NOT NULL,
  unit_id uuid NOT NULL,
  assigned_at timestamptz NOT NULL,
  exposed_at timestamptz NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT fk_assignment_arm_experiment FOREIGN KEY (arm_id,experiment_id) REFERENCES experiment_arms(id,experiment_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  UNIQUE(experiment_id,unit_type,unit_id)
);
CREATE INDEX idx_experiment_assignment_unit ON experiment_assignments(unit_type,unit_id);
ALTER TABLE run_campaign_allocations ADD CONSTRAINT fk_allocation_experiment_assignment FOREIGN KEY (experiment_assignment_id) REFERENCES experiment_assignments(id) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE candidates ADD CONSTRAINT fk_candidate_experiment_assignment FOREIGN KEY (experiment_assignment_id) REFERENCES experiment_assignments(id) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE clips ADD COLUMN experiment_assignment_id uuid NULL REFERENCES experiment_assignments(id) ON DELETE RESTRICT ON UPDATE RESTRICT;

-- ---------- FINANCE / COST ----------
CREATE TABLE earnings (
  id uuid PRIMARY KEY,
  campaign_id uuid NOT NULL REFERENCES campaigns(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  rule_snapshot_id uuid NOT NULL,
  post_id uuid NULL REFERENCES posts(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  external_earning_id text NULL,
  amount_usd numeric(18,6) NOT NULL CHECK (amount_usd >= 0),
  state earning_state_enum NOT NULL DEFAULT 'ACCRUED_UNVERIFIED',
  recognized_at timestamptz NOT NULL,
  last_state_at timestamptz NOT NULL,
  evidence_snapshot_id uuid NULL,
  source text NOT NULL CHECK (source IN ('OWNER_MANUAL','OFFICIAL_API','COMPLIANT_IMPORT')),
  idempotency_key text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT fk_earning_evidence_campaign FOREIGN KEY (evidence_snapshot_id,campaign_id) REFERENCES campaign_terms_snapshots(id,campaign_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_earnings_rule_campaign FOREIGN KEY (rule_snapshot_id,campaign_id) REFERENCES campaign_terms_snapshots(id,campaign_id) ON DELETE RESTRICT ON UPDATE RESTRICT
);
CREATE UNIQUE INDEX uq_earnings_external ON earnings(campaign_id,external_earning_id) WHERE external_earning_id IS NOT NULL;
CREATE INDEX idx_earnings_state_recognized ON earnings(state,recognized_at);

CREATE TABLE earning_state_transitions (
  id uuid PRIMARY KEY,
  earning_id uuid NOT NULL REFERENCES earnings(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  from_state earning_state_enum NULL,
  to_state earning_state_enum NOT NULL,
  amount_usd_snapshot numeric(18,6) NOT NULL CHECK (amount_usd_snapshot >= 0),
  occurred_at timestamptz NOT NULL,
  evidence_uri text NULL,
  evidence_object_key text NULL,
  actor text NOT NULL,
  idempotency_key text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (evidence_uri IS NOT NULL OR evidence_object_key IS NOT NULL)
);
CREATE INDEX idx_earning_transitions_earning_time ON earning_state_transitions(earning_id,occurred_at);

CREATE TABLE cost_ledger (
  id uuid PRIMARY KEY,
  provider text NOT NULL,
  service text NOT NULL,
  cost_category cost_category_enum NOT NULL,
  job_id uuid NULL,
  polli_session_id uuid NULL,
  quantity numeric(24,6) NOT NULL CHECK (quantity >= 0),
  unit text NOT NULL,
  estimated_cost_usd numeric(18,6) NOT NULL CHECK (estimated_cost_usd >= 0),
  actual_cost_usd numeric(18,6) NULL CHECK (actual_cost_usd IS NULL OR actual_cost_usd >= 0),
  cost_confidence confidence_enum NOT NULL,
  incurred_at timestamptz NOT NULL,
  reconciled_at timestamptz NULL,
  external_usage_id text NULL,
  idempotency_key text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_cost_time_provider ON cost_ledger(incurred_at,provider);
CREATE INDEX idx_cost_category_time ON cost_ledger(cost_category,incurred_at);

CREATE TABLE provider_usage (
  id uuid PRIMARY KEY,
  provider text NOT NULL,
  service text NOT NULL,
  model_or_sku text NULL,
  request_id text NULL,
  job_id uuid NULL,
  input_units bigint NULL CHECK (input_units IS NULL OR input_units >= 0),
  output_units bigint NULL CHECK (output_units IS NULL OR output_units >= 0),
  audio_seconds numeric(18,3) NULL CHECK (audio_seconds IS NULL OR audio_seconds >= 0),
  duration_seconds numeric(18,3) NULL CHECK (duration_seconds IS NULL OR duration_seconds >= 0),
  storage_bytes bigint NULL CHECK (storage_bytes IS NULL OR storage_bytes >= 0),
  operation_count bigint NULL CHECK (operation_count IS NULL OR operation_count >= 0),
  raw_usage jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(raw_usage)='object'),
  captured_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_provider_usage_provider_time ON provider_usage(provider,captured_at);
CREATE UNIQUE INDEX uq_provider_usage_request ON provider_usage(provider,request_id) WHERE request_id IS NOT NULL;


-- ---------- COST GOVERNOR LEDGER CONVENTIONS ----------
-- The governor authority is HONOR_COST_GOVERNOR.json. C01 does not invent accounting categories.
-- Before any paid job/provider call is admitted, create/update its cost_ledger reservation with conservative estimated_cost_usd; provider-reporting lag never bypasses this reservation.
-- OpenAI/other prepaid funding purchases are recorded as provider=<provider>, service='PREPAID_FUNDING', unit='USD_CASH_PURCHASE', quantity=<six-decimal USD amount>, estimated_cost_usd=<amount>, actual_cost_usd=<amount>, incurred_at=<purchase timestamp>, reconciled_at=<purchase timestamp>.
-- PREPAID_FUNDING rows count immediately in governor cash_spend_counted_usd but are excluded from net-profit economic operating expense so later consumed service cost is not double-counted.
-- Remaining already-counted prepaid credit is reconciled as purchased funding less normalized provider service usage funded by that credit; queued reservations consume that available credit before any excess enters admitted_queued_unfunded_usd.
-- Fixed postpaid obligations (for example an active monthly VPS commitment) create conservative cost_ledger estimated rows as soon as the obligation becomes unavoidable, not when the invoice arrives.

-- ---------- POLLI ----------
CREATE TABLE polli_sessions (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  mode polli_mode_enum NOT NULL,
  started_at timestamptz NOT NULL,
  ended_at timestamptz NULL,
  openai_live_session_id_hash text NULL,
  backend_model_route text NOT NULL,
  estimated_cost_usd numeric(18,6) NOT NULL DEFAULT 0 CHECK (estimated_cost_usd >= 0),
  actual_cost_usd numeric(18,6) NULL CHECK (actual_cost_usd IS NULL OR actual_cost_usd >= 0),
  retention_mode polli_retention_enum NOT NULL DEFAULT 'TRANSCRIPT_SUMMARY',
  status polli_session_status_enum NOT NULL DEFAULT 'ACTIVE',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_polli_sessions_user_time ON polli_sessions(user_id,started_at DESC);

CREATE TABLE polli_turns (
  id uuid PRIMARY KEY,
  session_id uuid NOT NULL REFERENCES polli_sessions(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  role text NOT NULL CHECK (role IN ('OWNER','POLLI','SYSTEM_SUMMARY')),
  text text NOT NULL,
  fact_labels jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(fact_labels)='array'),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_polli_turns_session_time ON polli_turns(session_id,created_at);

CREATE TABLE polli_tool_calls (
  id uuid PRIMARY KEY,
  session_id uuid NOT NULL REFERENCES polli_sessions(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  turn_id uuid NULL REFERENCES polli_turns(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  tool_name text NOT NULL,
  tool_version integer NOT NULL DEFAULT 1 CHECK (tool_version > 0),
  arguments_json jsonb NOT NULL CHECK (jsonb_typeof(arguments_json)='object'),
  result_digest char(64) NOT NULL CHECK (result_digest ~ '^[a-f0-9]{64}$'),
  result_summary_json jsonb NOT NULL CHECK (jsonb_typeof(result_summary_json)='object'),
  authorized_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  started_at timestamptz NOT NULL,
  finished_at timestamptz NULL,
  status tool_call_status_enum NOT NULL,
  cost_ledger_id uuid NULL REFERENCES cost_ledger(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_polli_tool_session_time ON polli_tool_calls(session_id,started_at);
CREATE INDEX idx_polli_tool_name_time ON polli_tool_calls(tool_name,started_at);

-- ---------- DURABLE JOBS / EVENTS / OWNER ACTIONS ----------
CREATE TABLE owner_actions (
  id uuid PRIMARY KEY,
  action_type text NOT NULL CHECK (action_type IN ('CAMPAIGN_RULE','SOURCE_RIGHTS','PROVIDER_SETUP','GENERIC_CONFIRMATION')),
  title text NOT NULL,
  reason text NOT NULL,
  entity_type text NOT NULL,
  entity_id uuid NOT NULL,
  status owner_action_status_enum NOT NULL DEFAULT 'OPEN',
  requested_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz NULL,
  cancelled_at timestamptz NULL,
  resolution jsonb NULL CHECK (resolution IS NULL OR jsonb_typeof(resolution)='object'),
  resolution_sha256 char(64) NULL CHECK (resolution_sha256 IS NULL OR resolution_sha256 ~ '^[a-f0-9]{64}$'),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK ((status='OPEN' AND resolved_at IS NULL AND cancelled_at IS NULL AND resolution IS NULL AND resolution_sha256 IS NULL)
      OR (status='RESOLVED' AND resolved_at IS NOT NULL AND cancelled_at IS NULL AND resolution IS NOT NULL AND resolution_sha256 IS NOT NULL)
      OR (status='CANCELLED' AND resolved_at IS NULL AND cancelled_at IS NOT NULL AND resolution IS NOT NULL AND resolution_sha256 IS NOT NULL))
);
CREATE INDEX idx_owner_actions_status_time ON owner_actions(status,requested_at);

CREATE TABLE jobs (
  id uuid PRIMARY KEY,
  job_type text NOT NULL,
  domain_entity_type text NOT NULL,
  domain_entity_id uuid NOT NULL,
  state job_state_enum NOT NULL DEFAULT 'queued',
  stage text NOT NULL CHECK (stage IN ('campaign_import','rules_normalization','source_ingest','rights_verification','transcription','candidate_discovery','candidate_scoring','finalist_selection','edit_plan','audio_plan','render','qc','schedule','analytics_ingest','payout_reconcile','cost_reconcile','backup')),
  attempt integer NOT NULL DEFAULT 0 CHECK (attempt >= 0),
  max_attempts integer NOT NULL CHECK (max_attempts >= 1),
  idempotency_key text NOT NULL UNIQUE,
  dispatch_token uuid NOT NULL UNIQUE,
  correlation_id uuid NOT NULL,
  run_id uuid NULL REFERENCES generation_runs(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  queued_at timestamptz NOT NULL DEFAULT now(),
  available_at timestamptz NOT NULL DEFAULT now(),
  started_at timestamptz NULL,
  heartbeat_at timestamptz NULL,
  lease_expires_at timestamptz NULL,
  finished_at timestamptz NULL,
  timeout_seconds integer NOT NULL CHECK (timeout_seconds > 0),
  cancel_requested_at timestamptz NULL,
  failure_code text NULL,
  failure_detail_redacted text NULL,
  owner_action_id uuid NULL REFERENCES owner_actions(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  version bigint NOT NULL DEFAULT 1 CHECK (version > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_jobs_state_available ON jobs(state,available_at);
CREATE INDEX idx_jobs_correlation ON jobs(correlation_id);
CREATE INDEX idx_jobs_run ON jobs(run_id) WHERE run_id IS NOT NULL;
ALTER TABLE cost_ledger ADD CONSTRAINT fk_cost_job FOREIGN KEY(job_id) REFERENCES jobs(id) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE cost_ledger ADD CONSTRAINT fk_cost_polli FOREIGN KEY(polli_session_id) REFERENCES polli_sessions(id) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE provider_usage ADD CONSTRAINT fk_usage_job FOREIGN KEY(job_id) REFERENCES jobs(id) ON DELETE RESTRICT ON UPDATE RESTRICT;
ALTER TABLE transcripts ADD CONSTRAINT fk_transcript_cost FOREIGN KEY(cost_ledger_id) REFERENCES cost_ledger(id) ON DELETE RESTRICT ON UPDATE RESTRICT;

CREATE TABLE events (
  id uuid PRIMARY KEY,
  event_name text NOT NULL CHECK (event_name IN (
    'CAMPAIGN_DISCOVERED','CAMPAIGN_RULES_VERIFIED','CAMPAIGN_RULES_BLOCKED_UNKNOWN','SOURCE_INGESTED','SOURCE_ELIGIBILITY_VERIFIED','TRANSCRIPTION_COMPLETE','CANDIDATES_RANKED','FINALISTS_SELECTED','EDIT_PLAN_CREATED','AUDIO_PLAN_CREATED','CLIP_RENDER_REQUESTED','CLIP_RENDERED','QC_PASSED','QC_FAILED','CLIP_READY','POST_RECORDED','SUBMISSION_RECORDED','ANALYTICS_CHECKIN_DUE','ANALYTICS_RECEIVED','PAYOUT_ACCRUED_UNVERIFIED','PAYOUT_APPROVED','PAYOUT_WITHDRAWABLE','PAYOUT_WITHDRAWN','COST_RECORDED','POLLI_SESSION_STARTED','POLLI_TOOL_CALLED','POLLI_COST_RECORDED','OWNER_ACTION_REQUIRED','JOB_RETRY_SCHEDULED','JOB_FAILED_TERMINAL','JOB_SUCCEEDED')),
  event_version integer NOT NULL DEFAULT 1 CHECK (event_version > 0),
  occurred_at timestamptz NOT NULL,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  actor_type text NOT NULL,
  actor_id uuid NULL,
  source_service text NOT NULL,
  correlation_id uuid NOT NULL,
  run_id uuid NULL REFERENCES generation_runs(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  job_id uuid NULL REFERENCES jobs(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  entity_type text NOT NULL,
  entity_id uuid NOT NULL,
  idempotency_key text NOT NULL UNIQUE,
  payload jsonb NOT NULL CHECK (jsonb_typeof(payload)='object'),
  CHECK (payload->>'event_name' = event_name),
  published_at timestamptz NULL
);
CREATE INDEX idx_events_name_time ON events(event_name,occurred_at);
CREATE INDEX idx_events_correlation_time ON events(correlation_id,occurred_at);
CREATE INDEX idx_events_unpublished ON events(recorded_at) WHERE published_at IS NULL;

CREATE TABLE audit_log (
  id uuid PRIMARY KEY,
  occurred_at timestamptz NOT NULL,
  actor_type text NOT NULL,
  actor_id uuid NULL,
  action text NOT NULL,
  target_type text NOT NULL,
  target_id uuid NULL,
  request_id uuid NOT NULL,
  ip_hash text NULL,
  metadata_redacted jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(metadata_redacted)='object')
);
CREATE INDEX idx_audit_time ON audit_log(occurred_at DESC);
CREATE INDEX idx_audit_request ON audit_log(request_id);

CREATE TABLE backup_runs (
  id uuid PRIMARY KEY,
  started_at timestamptz NOT NULL,
  finished_at timestamptz NULL,
  status backup_status_enum NOT NULL DEFAULT 'RUNNING',
  snapshot_reference text NULL,
  bytes bigint NULL CHECK (bytes IS NULL OR bytes >= 0),
  restic_snapshot_id text NULL,
  verification_status backup_verification_enum NOT NULL DEFAULT 'PENDING',
  error_redacted text NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_backup_runs_started ON backup_runs(started_at DESC);

-- ---------- API IDEMPOTENCY ----------
CREATE TABLE api_idempotency_records (
  id uuid PRIMARY KEY,
  owner_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  idempotency_key text NOT NULL,
  http_method text NOT NULL CHECK (http_method IN ('POST','PUT','PATCH','DELETE')),
  path text NOT NULL,
  request_sha256 char(64) NOT NULL CHECK (request_sha256 ~ '^[a-f0-9]{64}$'),
  response_status integer NOT NULL CHECK (response_status BETWEEN 100 AND 599),
  response_body jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  UNIQUE(owner_user_id,idempotency_key)
);
CREATE INDEX idx_idempotency_expiry ON api_idempotency_records(expires_at);


-- ---------- DOMAIN STATE TRANSITION EXPECTATIONS ----------
-- Exactly one canonical graph per entity. Runtime/domain code and the frozen DB transition mechanisms must enforce these exact graphs transactionally; no alternative graph is permitted.
-- and with DB trigger/function checks. No public hard-delete path exists.
-- Posts: creation MUST be PUBLISHED; PUBLISHED -> INVALIDATED; INVALIDATED terminal.
-- Submissions: creation may be PENDING | SUBMITTED | NOT_REQUIRED | UNKNOWN.
--   PENDING -> SUBMITTED | NOT_REQUIRED | UNKNOWN.
--   SUBMITTED -> ACCEPTED | REJECTED | UNKNOWN.
--   UNKNOWN -> PENDING | SUBMITTED | NOT_REQUIRED | ACCEPTED | REJECTED when authoritative evidence resolves uncertainty.
--   ACCEPTED | REJECTED | NOT_REQUIRED are terminal in V1.
-- Analytics check-ins: creation MUST be PENDING.
--   PENDING -> DUE | NOT_APPLICABLE.
--   DUE -> COMPLETED | MISSED | NOT_APPLICABLE.
--   MISSED -> COMPLETED (late owner/API observation).
--   COMPLETED | NOT_APPLICABLE are terminal in V1.
-- Source ingest: PENDING_UPLOAD -> QUEUED; QUEUED -> INGESTING | BLOCKED_RIGHTS | FAILED;
--   INGESTING -> READY | BLOCKED_RIGHTS | FAILED; BLOCKED_RIGHTS -> QUEUED only after rights evidence changes.
-- Clip: PLANNED -> RENDERING -> QC -> READY; render/QC failure may EJECT; READY -> POSTED | ARCHIVED; POSTED -> ARCHIVED.

-- Canonical transition predicates for implementation/tests. Any implementation must be data-equivalent to these exact predicates; semantic alternatives require CHANGE REQUEST.
CREATE OR REPLACE FUNCTION honor_submission_transition_allowed(old_state submission_status_enum, new_state submission_status_enum)
RETURNS boolean LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE old_state
    WHEN 'PENDING' THEN new_state IN ('SUBMITTED','NOT_REQUIRED','UNKNOWN')
    WHEN 'SUBMITTED' THEN new_state IN ('ACCEPTED','REJECTED','UNKNOWN')
    WHEN 'UNKNOWN' THEN new_state IN ('PENDING','SUBMITTED','NOT_REQUIRED','ACCEPTED','REJECTED')
    ELSE false
  END;
$$;
REVOKE ALL ON FUNCTION honor_submission_transition_allowed(submission_status_enum, submission_status_enum) FROM PUBLIC;
-- Admin/reference helper only in V1; honor_app receives no direct EXECUTE grant.
CREATE OR REPLACE FUNCTION honor_checkin_transition_allowed(old_state checkin_status_enum, new_state checkin_status_enum)
RETURNS boolean LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE old_state
    WHEN 'PENDING' THEN new_state IN ('DUE','NOT_APPLICABLE')
    WHEN 'DUE' THEN new_state IN ('COMPLETED','MISSED','NOT_APPLICABLE')
    WHEN 'MISSED' THEN new_state = 'COMPLETED'
    ELSE false
  END;
$$;
REVOKE ALL ON FUNCTION honor_checkin_transition_allowed(checkin_status_enum, checkin_status_enum) FROM PUBLIC;
-- Admin/reference helper only in V1; honor_app receives no direct EXECUTE grant.

-- ---------- APPEND-ONLY / MUTABILITY EXPECTATIONS ----------
-- The frozen database contract enforces UPDATE/DELETE denial after insert for these tables:
--   campaign_terms_snapshots, account_health_snapshots, analytics_observations,
--   earning_state_transitions, provider_usage, polli_turns, polli_tool_calls,
--   events, audit_log, qc_runs.
-- `cost_ledger` is not fully append-only because actual_cost_usd/reconciled_at may be filled once;
-- all other financial corrections require a new ledger row or earning transition, never history deletion.
-- Direct runtime UPDATE of earnings.state/last_state_at is revoked. State changes use honor_transition_earning(), which locks the row, validates the frozen graph, inserts the immutable transition with the exact pre-state and amount snapshot, and updates earnings.state/last_state_at in the same transaction. Any failure rolls back both records.


-- Earning transition graph frozen for DB trigger/function enforcement:
-- NULL -> ACCRUED_UNVERIFIED (creation only)
-- ACCRUED_UNVERIFIED -> APPROVED | VOIDED
-- APPROVED -> WITHDRAWABLE | VOIDED
-- WITHDRAWABLE -> WITHDRAWN | VOIDED
-- WITHDRAWN -> (no further transitions)
-- VOIDED -> (no further transitions)

-- ---------- JSON VERSION EXPECTATIONS ----------
-- C00 freezes every JSONB contract. Later migrations implement these exact schemas; no later checkpoint may redesign them silently.
-- Machine registry: HONOR_JSONB_SCHEMA_REGISTRY.json; canonical files: jsonschema/*.json.
-- Application writers validate the mapped schema before persistence. Opaque metadata cannot drive product logic.
-- account_health_snapshots.signals -> account_health.signals.v1
-- campaign_rule_items.typed_value -> campaign_rule.typed_value.v1; exact per-key envelope selected by HONOR_CAMPAIGN_RULE_REGISTRY.json
-- source_rights.authorized_uses -> source_rights.authorized_uses.v1
-- source_rights.platform_limits -> source_rights.platform_limits.v1
-- generation_runs.budget_snapshot -> generation.budget_snapshot.v1
-- generation_runs.requested_constraints -> generation.requested_constraints.v1
-- generation_runs.selected_plan -> generation.selected_plan.v1
-- run_campaign_allocations.rationale_json -> allocation.rationale.v1
-- candidates.features -> candidate.features.v1
-- edit_plans.plan_json -> edit_plan.v1
-- render_manifests.manifest_json -> render_manifest.v1
-- audio_assets.allowed_uses -> audio_asset.allowed_uses.v1
-- audio_plans.platform_native_recommendation -> audio_plan.native_recommendation.v1
-- audio_plans.sfx_events -> audio_plan.sfx_events.v1
-- audio_plans.ducking_config -> audio_plan.ducking.v1
-- clips.hashtags -> clip.hashtags.v1
-- clips.posting_recommendation -> clip.posting_recommendation.v1
-- qc_runs.checks -> qc.checks.v1
-- qc_runs.metrics -> qc.metrics.v1
-- posts.native_audio_used -> post.native_audio_used.v1
-- analytics_checkins.config_snapshot -> analytics_checkin.config.v1
-- provider_usage.raw_usage -> provider_usage.raw.v1
-- polli_turns.fact_labels -> polli.fact_labels.v1
-- polli_tool_calls.arguments_json -> polli.tool.arguments.v1
-- polli_tool_calls.result_summary_json -> polli.tool.result_summary.v1
-- owner_actions.resolution -> owner_action.resolution.v1
-- events.payload -> event.payload.v1
-- audit_log.metadata_redacted -> audit.metadata_redacted.v1
-- api_idempotency_records.response_body -> api_idempotency.response_body.v1
-- Structured schema changes require a new schema ID/version + approved CHANGE REQUEST.
-- Opaque schemas are limited to provider_usage.raw.v1 and audit.metadata_redacted.v1 and enforce redaction/secret-key-name prohibitions.

-- ---------- RLS / GRANT CONTRACT ----------
-- Role creation/provisioning is admin-only. No password value belongs in this reference contract.
-- honor_app MUST be LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS and MUST NOT own application schemas/tables/functions.
-- API and worker share honor_app. Owner context is TRANSACTION-LOCAL ONLY: BEGIN; SELECT set_config('honor.owner_user_id', '<validated-owner-uuid>', true); authorized SQL; COMMIT/ROLLBACK. The third argument true is mandatory (equivalent to SET LOCAL). Session-global SET honor.owner_user_id is forbidden because pooled sessions are reused; after COMMIT/ROLLBACK current_setting('honor.owner_user_id', true) MUST be absent/empty in the next transaction until explicitly set again.
-- DATABASE_ADMIN_URL is reserved for migrations, pg_dump, restore, role/grant/policy maintenance, and audited admin repair.
-- Browser anon/authenticated roles and Supabase service/secret roles receive no HONOR business-table DML path in V1.

-- owner_profiles is the one deliberate policy exception that prevents recursion:
--   USING/WITH CHECK (user_id::text = current_setting('honor.owner_user_id', true) AND active = true)
-- honor_owner_authorized() MUST NOT be used as the owner_profiles policy.
CREATE OR REPLACE FUNCTION honor_owner_authorized() RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = public, pg_catalog AS $$
  SELECT EXISTS (SELECT 1 FROM owner_profiles op WHERE op.user_id::text = current_setting('honor.owner_user_id', true) AND op.active = true);
$$;
REVOKE ALL ON FUNCTION honor_owner_authorized() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_owner_authorized() TO honor_app;

-- All HONOR tables: ENABLE ROW LEVEL SECURITY + FORCE ROW LEVEL SECURITY.
-- owner_profiles gets the direct predicate above. Every other table gets owner SELECT and, where granted, INSERT/UPDATE policies using honor_owner_authorized().
-- No DELETE policy exists on any table. No runtime DELETE grant exists.

-- Exact permission classes:
-- A_MUTABLE_RUNTIME: permissions=SELECT,INSERT,UPDATE; tables=social_identities, social_accounts, campaigns, uploads, sources, transcripts, generation_runs, clips, posts, submissions, analytics_checkins, polli_sessions, owner_actions, jobs, api_idempotency_records, experiments, experiment_arms, experiment_assignments
-- B_APPEND_ONLY_RUNTIME: permissions=SELECT,INSERT; tables=account_health_snapshots, campaign_terms_snapshots, campaign_rule_items, run_campaign_allocations, candidates, edit_plans, audio_plans, qc_runs, render_manifests, analytics_observations, provider_usage, polli_turns, polli_tool_calls, events, audit_log, restriction_proof_artifacts
-- C_ADMIN_MAINTAINED: permissions=SELECT; tables=owner_profiles, audio_assets, backup_runs
-- D_COST_LEDGER_CONSTRAINED: permissions=SELECT,INSERT,UPDATE_RECONCILIATION_FIELDS_ONLY; tables=cost_ledger
-- E_FUNCTION_COMMITTED_RIGHTS: direct permissions=SELECT only; tables=source_rights, source_rights_campaigns; runtime inserts only through honor_commit_source_rights_version(...)
-- F_EARNINGS_CONSTRAINED: direct permissions=SELECT,INSERT; tables=earnings; runtime state UPDATE only through honor_transition_earning(...)
-- G_FUNCTION_COMMITTED_EARNING_TRANSITIONS: direct permissions=SELECT only; tables=earning_state_transitions; runtime INSERT only through honor_transition_earning(...)
-- H_FUNCTION_COMMITTED_RULE_SEALS: direct permissions=SELECT only; tables=campaign_rule_set_commits; runtime INSERT only through honor_seal_campaign_rule_set(...)

-- Exact grants required for honor_app:
-- GRANT USAGE ON SCHEMA public TO honor_app;
-- REVOKE ALL ON FUNCTION honor_owner_authorized() FROM PUBLIC;
-- GRANT EXECUTE ON FUNCTION honor_owner_authorized() TO honor_app;
-- V1 uses UUID primary keys and defines no sequence-backed application columns; therefore honor_app requires NO sequence privileges in V1. Adding a sequence-backed runtime insert column requires an approved contract update.
-- GRANT SELECT, INSERT, UPDATE ON TABLE social_identities TO honor_app;
-- GRANT SELECT, INSERT, UPDATE ON TABLE social_accounts TO honor_app;
-- GRANT SELECT, INSERT, UPDATE(title,currency,canonical_url,updated_at) ON TABLE campaigns TO honor_app; -- campaign current-rule mirror columns are function-controlled by honor_activate_campaign_rule_snapshot()
-- GRANT SELECT, INSERT ON TABLE campaign_rule_items TO honor_app;
-- GRANT SELECT, INSERT, UPDATE ON TABLE uploads TO honor_app;
-- GRANT SELECT, INSERT, UPDATE ON TABLE sources TO honor_app;
-- GRANT SELECT ON TABLE source_rights TO honor_app; -- INSERT only through honor_commit_source_rights_version()
-- GRANT SELECT ON TABLE source_rights_campaigns TO honor_app; -- INSERT only through honor_commit_source_rights_version()
-- GRANT SELECT, INSERT, UPDATE ON TABLE transcripts TO honor_app;
-- GRANT SELECT, INSERT, UPDATE ON TABLE generation_runs TO honor_app;
-- GRANT SELECT, INSERT ON TABLE run_campaign_allocations TO honor_app;
-- GRANT SELECT, INSERT ON TABLE candidates TO honor_app;
-- GRANT SELECT, INSERT ON TABLE edit_plans TO honor_app;
-- GRANT SELECT, INSERT ON TABLE audio_plans TO honor_app;
-- GRANT SELECT, INSERT, UPDATE ON TABLE clips TO honor_app;
-- GRANT SELECT, INSERT, UPDATE ON TABLE posts TO honor_app;
-- GRANT SELECT, INSERT, UPDATE ON TABLE submissions TO honor_app;
-- GRANT SELECT, INSERT, UPDATE ON TABLE analytics_checkins TO honor_app;
-- GRANT SELECT, INSERT ON TABLE earnings TO honor_app; -- state UPDATE only through honor_transition_earning()
-- GRANT SELECT, INSERT, UPDATE ON TABLE polli_sessions TO honor_app;
-- GRANT SELECT, INSERT, UPDATE ON TABLE owner_actions TO honor_app;
-- GRANT SELECT, INSERT, UPDATE ON TABLE jobs TO honor_app;
-- GRANT SELECT, INSERT, UPDATE ON TABLE api_idempotency_records TO honor_app;
-- GRANT SELECT, INSERT, UPDATE ON TABLE experiments TO honor_app;
-- GRANT SELECT, INSERT, UPDATE ON TABLE experiment_arms TO honor_app;
-- GRANT SELECT, INSERT, UPDATE ON TABLE experiment_assignments TO honor_app;
-- GRANT SELECT, INSERT ON TABLE account_health_snapshots TO honor_app;
-- GRANT SELECT, INSERT ON TABLE campaign_terms_snapshots TO honor_app;
-- GRANT SELECT, INSERT ON TABLE qc_runs TO honor_app;
-- GRANT SELECT, INSERT ON TABLE render_manifests TO honor_app;
-- GRANT SELECT, INSERT ON TABLE analytics_observations TO honor_app;
-- GRANT SELECT ON TABLE earning_state_transitions TO honor_app; -- INSERT only through honor_transition_earning()
-- GRANT SELECT, INSERT ON TABLE provider_usage TO honor_app;
-- GRANT SELECT, INSERT ON TABLE polli_turns TO honor_app;
-- GRANT SELECT, INSERT ON TABLE polli_tool_calls TO honor_app;
-- GRANT SELECT, INSERT ON TABLE events TO honor_app;
-- GRANT SELECT, INSERT ON TABLE audit_log TO honor_app;
-- GRANT SELECT, INSERT ON TABLE restriction_proof_artifacts TO honor_app;
-- GRANT SELECT ON TABLE owner_profiles TO honor_app;
-- GRANT SELECT ON TABLE audio_assets TO honor_app;
-- GRANT SELECT ON TABLE backup_runs TO honor_app;
-- GRANT SELECT ON TABLE campaign_rule_set_commits TO honor_app; -- INSERT only through honor_seal_campaign_rule_set()
-- GRANT SELECT, INSERT, UPDATE(actual_cost_usd, reconciled_at) ON TABLE cost_ledger TO honor_app;
-- REVOKE DELETE ON ALL HONOR TABLES FROM honor_app;
-- REVOKE ALL HONOR business-table privileges FROM anon, authenticated;
-- Table/function ownership remains with migration/admin owner, never honor_app.

-- RLS policy implementation is mechanical:
-- 1) owner_profiles: SELECT policy direct-owner predicate; runtime INSERT/UPDATE are not granted (Class C).
-- 2) every other table: SELECT policy USING (honor_owner_authorized()).
-- 3) Class A: INSERT WITH CHECK (honor_owner_authorized()); UPDATE USING/WITH CHECK honor_owner_authorized().
-- 4) Class B: INSERT WITH CHECK honor_owner_authorized(); BEFORE UPDATE OR DELETE trigger raises SQLSTATE 42501.
-- 5) Class C: no runtime INSERT/UPDATE/DELETE policy.
-- 6) Classes E/G/H: SELECT policy only; no direct runtime INSERT/UPDATE/DELETE policy. Their SECURITY DEFINER commit/transition/seal functions require honor_owner_authorized() and are the sole runtime mutation path.
-- 7) cost_ledger: INSERT owner check; UPDATE owner check PLUS trigger allowing only one-time NULL->non-NULL actual_cost_usd/reconciled_at and requiring same-transaction audit_log insertion; DELETE raises 42501.
-- Trigger/function names and semantics are frozen below. Implementation is mechanical; architectural changes require CHANGE REQUEST.

-- ---------- ROUND-6 DOWNSTREAM LINEAGE / RIGHTS-STAGE FUNCTIONS ----------
-- Runtime rights history is committed only through this SECURITY DEFINER function. Direct INSERT on source_rights/source_rights_campaigns is not granted to honor_app.
-- The function owner is the migration/admin role, not honor_app; it explicitly requires the transaction-local owner authorization context.
CREATE OR REPLACE FUNCTION honor_commit_source_rights_version(
  p_id uuid, p_source_id uuid, p_rights_version integer, p_supersedes_rights_id uuid,
  p_eligibility source_eligibility_enum, p_authorized_uses jsonb, p_platform_limits jsonb,
  p_evidence_type text, p_evidence_uri text, p_evidence_object_key text,
  p_evidence_captured_at timestamptz, p_expires_at timestamptz, p_notes text,
  p_record_hash text, p_campaign_ids uuid[]
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_catalog AS $$
DECLARE cid uuid; distinct_count integer;
BEGIN
  IF NOT honor_owner_authorized() THEN RAISE EXCEPTION 'owner context required' USING ERRCODE='42501'; END IF;
  IF p_campaign_ids IS NULL OR cardinality(p_campaign_ids)=0 THEN RAISE EXCEPTION 'rights version requires campaign applicability at commit' USING ERRCODE='23514'; END IF;
  SELECT count(DISTINCT cid0) INTO distinct_count FROM unnest(p_campaign_ids) AS u(cid0);
  IF distinct_count<>cardinality(p_campaign_ids) THEN RAISE EXCEPTION 'duplicate campaign applicability' USING ERRCODE='23514'; END IF;
  INSERT INTO source_rights(id,source_id,rights_version,supersedes_rights_id,eligibility,authorized_uses,platform_limits,evidence_type,evidence_uri,evidence_object_key,evidence_captured_at,expires_at,notes,schema_version,record_hash,committed_at,created_at)
  VALUES(p_id,p_source_id,p_rights_version,p_supersedes_rights_id,p_eligibility,p_authorized_uses,p_platform_limits,p_evidence_type,p_evidence_uri,p_evidence_object_key,p_evidence_captured_at,p_expires_at,p_notes,1,p_record_hash,statement_timestamp(),statement_timestamp());
  FOREACH cid IN ARRAY p_campaign_ids LOOP
    INSERT INTO source_rights_campaigns(source_rights_id,campaign_id,created_at) VALUES(p_id,cid,statement_timestamp());
  END LOOP;
  RETURN p_id;
END $$;
REVOKE ALL ON FUNCTION honor_commit_source_rights_version(uuid, uuid, integer, uuid, source_eligibility_enum, jsonb, jsonb, text, text, text, timestamptz, timestamptz, text, text, uuid[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_commit_source_rights_version(uuid, uuid, integer, uuid, source_eligibility_enum, jsonb, jsonb, text, text, text, timestamptz, timestamptz, text, text, uuid[]) TO honor_app;

-- Deterministic stage authorization helper. UNKNOWN/false never grants permission.
CREATE OR REPLACE FUNCTION honor_rights_stage_allowed(p_rights_id uuid, p_campaign_id uuid, p_platform platform_enum, p_stage text, p_at timestamptz)
RETURNS boolean LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE r source_rights%ROWTYPE; platform_ok boolean;
BEGIN
  SELECT * INTO r FROM source_rights WHERE id=p_rights_id;
  IF NOT FOUND OR r.eligibility<>'ELIGIBLE' OR p_campaign_id IS NULL OR p_at IS NULL THEN RETURN false; END IF;
  IF r.evidence_captured_at>p_at OR r.committed_at>p_at THEN RETURN false; END IF;
  IF r.expires_at IS NOT NULL AND p_at>=r.expires_at THEN RETURN false; END IF;
  IF NOT EXISTS (SELECT 1 FROM source_rights_campaigns rc WHERE rc.source_rights_id=r.id AND rc.campaign_id=p_campaign_id AND rc.created_at<=p_at) THEN RETURN false; END IF;
  platform_ok := p_platform IS NOT NULL AND (r.authorized_uses->'allowed_platforms' ? p_platform::text) AND COALESCE((r.platform_limits->p_platform::text->>'allowed')::boolean,false);
  CASE p_stage
    WHEN 'INGEST' THEN RETURN COALESCE((r.authorized_uses->>'may_ingest')::boolean,false);
    WHEN 'PAID_TRANSCRIPTION' THEN RETURN COALESCE((r.authorized_uses->>'may_transcribe')::boolean,false);
    WHEN 'EDIT_PLAN' THEN RETURN COALESCE((r.authorized_uses->>'may_edit')::boolean,false) AND COALESCE((r.authorized_uses->>'derivative_edits')::boolean,false);
    WHEN 'RENDER' THEN RETURN COALESCE((r.authorized_uses->>'may_render')::boolean,false) AND COALESCE((r.authorized_uses->>'may_edit')::boolean,false) AND COALESCE((r.authorized_uses->>'derivative_edits')::boolean,false);
    WHEN 'COMPENSATED_CAMPAIGN_PRODUCTION' THEN RETURN COALESCE((r.authorized_uses->>'commercial_use')::boolean,false) AND COALESCE((r.authorized_uses->>'may_edit')::boolean,false) AND COALESCE((r.authorized_uses->>'derivative_edits')::boolean,false) AND COALESCE((r.authorized_uses->>'may_render')::boolean,false);
    WHEN 'PUBLICATION_RECOMMENDATION' THEN RETURN COALESCE((r.authorized_uses->>'may_publish')::boolean,false) AND COALESCE((r.authorized_uses->>'commercial_use')::boolean,false) AND COALESCE((r.authorized_uses->>'derivative_edits')::boolean,false) AND platform_ok;
    ELSE RETURN false;
  END CASE;
END $$;
REVOKE ALL ON FUNCTION honor_rights_stage_allowed(uuid, uuid, platform_enum, text, timestamptz) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_rights_stage_allowed(uuid, uuid, platform_enum, text, timestamptz) TO honor_app;

-- Manual publication remains owner-driven in native social apps. This trigger records the factual post only from READY and atomically advances the clip READY -> POSTED in the same DB transaction.
CREATE OR REPLACE FUNCTION honor_post_publish_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE c clips%ROWTYPE; sa_platform platform_enum; rec_platform text;
BEGIN
  SELECT * INTO c FROM clips WHERE id=NEW.clip_id FOR UPDATE;
  IF NOT FOUND OR (TG_OP='INSERT' AND c.state<>'READY') THEN RAISE EXCEPTION 'post recording requires clip READY' USING ERRCODE='23514'; END IF;
  IF NEW.social_account_id<>c.social_account_id THEN RAISE EXCEPTION 'post account differs from clip account' USING ERRCODE='23514'; END IF;
  SELECT platform INTO sa_platform FROM social_accounts WHERE id=NEW.social_account_id;
  rec_platform := c.posting_recommendation->>'platform';
  IF sa_platform IS NULL OR NEW.platform<>sa_platform OR NEW.platform::text<>rec_platform THEN RAISE EXCEPTION 'post platform/account/posting recommendation mismatch' USING ERRCODE='23514'; END IF;
  IF NEW.native_audio_used IS NOT NULL AND NEW.native_audio_used->>'platform'<>NEW.platform::text THEN RAISE EXCEPTION 'native audio used platform differs from post platform' USING ERRCODE='23514'; END IF;
  IF TG_OP='UPDATE' AND (NEW.clip_id IS DISTINCT FROM OLD.clip_id OR NEW.social_account_id IS DISTINCT FROM OLD.social_account_id OR NEW.platform IS DISTINCT FROM OLD.platform) THEN RAISE EXCEPTION 'post lineage identity is immutable' USING ERRCODE='42501'; END IF;
  IF TG_OP='INSERT' THEN
    UPDATE clips SET state='POSTED',updated_at=statement_timestamp() WHERE id=NEW.clip_id AND state='READY';
    IF NOT FOUND THEN RAISE EXCEPTION 'atomic READY to POSTED transition failed' USING ERRCODE='23514'; END IF;
  END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION honor_post_publish_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_post_publish_guard() TO honor_app;
DROP TRIGGER IF EXISTS honor_post_publish_guard_trigger ON posts;
CREATE TRIGGER honor_post_publish_guard_trigger BEFORE INSERT OR UPDATE OF clip_id,social_account_id,platform,native_audio_used ON posts FOR EACH ROW EXECUTE FUNCTION honor_post_publish_guard();

CREATE OR REPLACE FUNCTION honor_submission_lineage_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE post_campaign uuid;
BEGIN
  SELECT c.campaign_id INTO post_campaign FROM posts p JOIN clips c ON c.id=p.clip_id WHERE p.id=NEW.post_id;
  IF post_campaign IS NULL OR post_campaign<>NEW.campaign_id THEN RAISE EXCEPTION 'submission campaign differs from post clip campaign' USING ERRCODE='23514'; END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION honor_submission_lineage_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_submission_lineage_guard() TO honor_app;
DROP TRIGGER IF EXISTS honor_submission_lineage_guard_trigger ON submissions;
CREATE TRIGGER honor_submission_lineage_guard_trigger BEFORE INSERT OR UPDATE OF campaign_id,post_id ON submissions FOR EACH ROW EXECUTE FUNCTION honor_submission_lineage_guard();

CREATE OR REPLACE FUNCTION honor_earning_lineage_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE post_campaign uuid;
BEGIN
  IF NEW.post_id IS NOT NULL THEN
    SELECT c.campaign_id INTO post_campaign FROM posts p JOIN clips c ON c.id=p.clip_id WHERE p.id=NEW.post_id;
    IF post_campaign IS NULL OR post_campaign<>NEW.campaign_id THEN RAISE EXCEPTION 'earning campaign differs from post clip campaign' USING ERRCODE='23514'; END IF;
  END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION honor_earning_lineage_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_earning_lineage_guard() TO honor_app;
DROP TRIGGER IF EXISTS honor_earning_lineage_guard_trigger ON earnings;
CREATE TRIGGER honor_earning_lineage_guard_trigger BEFORE INSERT OR UPDATE OF campaign_id,post_id,evidence_snapshot_id ON earnings FOR EACH ROW EXECUTE FUNCTION honor_earning_lineage_guard();

-- Only this function may mutate an earning state or insert earning transition history at runtime.
-- Direct honor_app UPDATE on earnings and direct INSERT on earning_state_transitions are not granted; therefore transition history and current state cannot diverge through the runtime role.
CREATE OR REPLACE FUNCTION honor_transition_earning(p_earning_id uuid, p_to_state earning_state_enum, p_occurred_at timestamptz, p_evidence_uri text, p_evidence_object_key text, p_actor text, p_idempotency_key text)
RETURNS earning_state_enum LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_catalog AS $$
DECLARE e earnings%ROWTYPE; allowed boolean;
BEGIN
  IF NOT honor_owner_authorized() THEN RAISE EXCEPTION 'owner context required' USING ERRCODE='42501'; END IF;
  SELECT * INTO e FROM earnings WHERE id=p_earning_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'earning not found' USING ERRCODE='23503'; END IF;
  allowed := CASE e.state
    WHEN 'ACCRUED_UNVERIFIED' THEN p_to_state IN ('APPROVED','VOIDED')
    WHEN 'APPROVED' THEN p_to_state IN ('WITHDRAWABLE','VOIDED')
    WHEN 'WITHDRAWABLE' THEN p_to_state IN ('WITHDRAWN','VOIDED')
    ELSE false END;
  IF NOT allowed THEN RAISE EXCEPTION 'invalid earning state transition' USING ERRCODE='23514'; END IF;
  INSERT INTO earning_state_transitions(id,earning_id,from_state,to_state,amount_usd_snapshot,occurred_at,evidence_uri,evidence_object_key,actor,idempotency_key,created_at)
  VALUES(gen_random_uuid(),e.id,e.state,p_to_state,e.amount_usd,p_occurred_at,p_evidence_uri,p_evidence_object_key,p_actor,p_idempotency_key,statement_timestamp());
  UPDATE earnings SET state=p_to_state,last_state_at=p_occurred_at,updated_at=statement_timestamp() WHERE id=e.id AND state=e.state;
  IF NOT FOUND THEN RAISE EXCEPTION 'earning concurrent state change' USING ERRCODE='40001'; END IF;
  RETURN p_to_state;
END $$;
REVOKE ALL ON FUNCTION honor_transition_earning(uuid, earning_state_enum, timestamptz, text, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_transition_earning(uuid, earning_state_enum, timestamptz, text, text, text, text) TO honor_app;

-- ---------- CROSS-RECORD / VERSION / POSTING INTEGRITY (FROZEN NAMES + SEMANTICS) ----------
-- Version chains are contiguous, same-logical-record, and non-forking. UNIQUE(supersedes_*) prevents forks.
CREATE OR REPLACE FUNCTION honor_source_rights_version_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE prev_source uuid; prev_version integer;
BEGIN
  IF NEW.rights_version=1 THEN
    IF NEW.supersedes_rights_id IS NOT NULL THEN RAISE EXCEPTION 'rights v1 cannot supersede' USING ERRCODE='23514'; END IF;
  ELSE
    SELECT source_id,rights_version INTO prev_source,prev_version FROM source_rights WHERE id=NEW.supersedes_rights_id;
    IF prev_source IS NULL OR prev_source<>NEW.source_id OR prev_version<>NEW.rights_version-1 THEN
      RAISE EXCEPTION 'source_rights predecessor must be same source and version N-1' USING ERRCODE='23514';
    END IF;
  END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION honor_source_rights_version_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_source_rights_version_guard() TO honor_app;
DROP TRIGGER IF EXISTS honor_source_rights_version_guard_trigger ON source_rights;
CREATE TRIGGER honor_source_rights_version_guard_trigger BEFORE INSERT ON source_rights FOR EACH ROW EXECUTE FUNCTION honor_source_rights_version_guard();

CREATE OR REPLACE FUNCTION honor_edit_plan_version_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE prev_candidate uuid; prev_version integer; c_source uuid; c_hash char(64); rights_source uuid; rights_hash char(64); camp_id uuid; current_rights uuid; ks knowledge_state_enum; tv jsonb; min_campaign numeric; max_campaign numeric; expected_sec numeric; snap_count integer;
BEGIN
  IF NEW.plan_version=1 THEN IF NEW.supersedes_edit_plan_id IS NOT NULL THEN RAISE EXCEPTION 'edit plan v1 cannot supersede' USING ERRCODE='23514'; END IF;
  ELSE SELECT candidate_id,plan_version INTO prev_candidate,prev_version FROM edit_plans WHERE id=NEW.supersedes_edit_plan_id; IF prev_candidate IS NULL OR prev_candidate<>NEW.candidate_id OR prev_version<>NEW.plan_version-1 THEN RAISE EXCEPTION 'edit_plan predecessor must be same candidate and version N-1' USING ERRCODE='23514'; END IF; END IF;
  SELECT c.source_id,s.sha256 INTO c_source,c_hash FROM candidates c JOIN sources s ON s.id=c.source_id WHERE c.id=NEW.candidate_id;
  IF c_source IS NULL OR c_hash IS NULL THEN RAISE EXCEPTION 'edit plan requires candidate source with immutable source hash' USING ERRCODE='23514'; END IF;
  IF NEW.plan_json->>'candidate_id'<>NEW.candidate_id::text OR NEW.plan_json->>'source_asset_id'<>c_source::text OR NEW.plan_json->>'source_sha256'<>c_hash THEN RAISE EXCEPTION 'edit plan JSON candidate/source fingerprint mismatch' USING ERRCODE='23514'; END IF;
  IF (NEW.plan_json->>'plan_version')::integer<>NEW.plan_version OR NEW.plan_json->>'plan_fingerprint_sha256'<>NEW.plan_hash OR NEW.plan_json->>'supersedes_edit_plan_id' IS DISTINCT FROM CASE WHEN NEW.supersedes_edit_plan_id IS NULL THEN NULL ELSE NEW.supersedes_edit_plan_id::text END THEN RAISE EXCEPTION 'edit plan JSON version/hash/supersession mismatch' USING ERRCODE='23514'; END IF;
  SELECT source_id,record_hash INTO rights_source,rights_hash FROM source_rights WHERE id=(NEW.plan_json->>'source_rights_id')::uuid;
  IF rights_source IS NULL OR rights_source<>c_source OR NEW.plan_json->>'source_rights_record_hash'<>rights_hash THEN RAISE EXCEPTION 'edit plan source-rights provenance mismatch' USING ERRCODE='23514'; END IF;
  SELECT count(DISTINCT t.campaign_id) INTO snap_count FROM jsonb_array_elements_text(NEW.plan_json->'campaign_rule_snapshot_ids') x(id_text) JOIN campaign_terms_snapshots t ON t.id=x.id_text::uuid;
  IF snap_count<>1 THEN RAISE EXCEPTION 'edit plan must reference one campaign rule lineage' USING ERRCODE='23514'; END IF;
  SELECT t.campaign_id INTO camp_id FROM jsonb_array_elements_text(NEW.plan_json->'campaign_rule_snapshot_ids') x(id_text) JOIN campaign_terms_snapshots t ON t.id=x.id_text::uuid LIMIT 1;
  IF NEW.plan_json->'rule_compliance'->>'rule_snapshot_id' IS DISTINCT FROM (NEW.plan_json->'campaign_rule_snapshot_ids'->>0) THEN RAISE EXCEPTION 'edit plan rule compliance snapshot mismatch' USING ERRCODE='23514'; END IF;
  current_rights:=honor_current_rights_for_action(c_source,camp_id,NULL,'EDIT_PLAN',NEW.committed_at);
  IF current_rights IS DISTINCT FROM (NEW.plan_json->>'source_rights_id')::uuid THEN RAISE EXCEPTION 'edit plan must use latest applicable rights version at commit time' USING ERRCODE='23514'; END IF;
  -- Critical media restrictions must be KNOWN or explicitly NOT_APPLICABLE; UNKNOWN blocks edit planning.
  FOR ks IN SELECT knowledge_state FROM campaign_rule_items WHERE campaign_id=camp_id AND terms_snapshot_id=(NEW.plan_json->'campaign_rule_snapshot_ids'->>0)::uuid AND rule_key IN ('source_material_restrictions','clip_length_min_seconds','clip_length_max_seconds','content_restrictions','editing_restrictions','uniqueness_rules','render_audio_rules','disclosure_requirements') LOOP IF ks='UNKNOWN' THEN RAISE EXCEPTION 'UNKNOWN critical media rule blocks edit plan' USING ERRCODE='23514'; END IF; END LOOP;
  expected_sec:=(NEW.plan_json->'output'->>'expected_duration_ms')::numeric/1000.0;
  -- Platform-specific rights max duration is enforced when a target platform is known at clip/READY time; this platform-neutral plan still carries expected_duration_ms for that later deterministic check.
  SELECT CASE WHEN knowledge_state='KNOWN' THEN (typed_value->>'value')::numeric END INTO min_campaign FROM campaign_rule_items WHERE campaign_id=camp_id AND terms_snapshot_id=(NEW.plan_json->'campaign_rule_snapshot_ids'->>0)::uuid AND rule_key='clip_length_min_seconds';
  SELECT CASE WHEN knowledge_state='KNOWN' THEN (typed_value->>'value')::numeric END INTO max_campaign FROM campaign_rule_items WHERE campaign_id=camp_id AND terms_snapshot_id=(NEW.plan_json->'campaign_rule_snapshot_ids'->>0)::uuid AND rule_key='clip_length_max_seconds';
  IF min_campaign IS NOT NULL AND expected_sec<min_campaign THEN RAISE EXCEPTION 'edit plan duration below campaign minimum' USING ERRCODE='23514'; END IF;
  IF max_campaign IS NOT NULL AND expected_sec>max_campaign THEN RAISE EXCEPTION 'edit plan duration above campaign maximum' USING ERRCODE='23514'; END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION honor_edit_plan_version_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_edit_plan_version_guard() TO honor_app;
DROP TRIGGER IF EXISTS honor_edit_plan_version_guard_trigger ON edit_plans;
CREATE TRIGGER honor_edit_plan_version_guard_trigger BEFORE INSERT ON edit_plans FOR EACH ROW EXECUTE FUNCTION honor_edit_plan_version_guard();

CREATE OR REPLACE FUNCTION honor_audio_plan_version_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE prev_edit uuid; prev_version integer; src uuid; camp uuid; rights uuid; snap uuid; ks knowledge_state_enum;
BEGIN
  IF NEW.plan_version=1 THEN
    IF NEW.supersedes_audio_plan_id IS NOT NULL THEN RAISE EXCEPTION 'audio plan v1 cannot supersede' USING ERRCODE='23514'; END IF;
  ELSE
    SELECT edit_plan_id,plan_version INTO prev_edit,prev_version FROM audio_plans WHERE id=NEW.supersedes_audio_plan_id;
    IF prev_edit IS NULL OR prev_edit<>NEW.edit_plan_id OR prev_version<>NEW.plan_version-1 THEN
      RAISE EXCEPTION 'audio_plan predecessor must be same edit_plan and version N-1' USING ERRCODE='23514';
    END IF;
  END IF;
  SELECT c.source_id,(ep.plan_json->>'source_rights_id')::uuid,(ep.plan_json->'campaign_rule_snapshot_ids'->>0)::uuid INTO src,rights,snap FROM edit_plans ep JOIN candidates c ON c.id=ep.candidate_id WHERE ep.id=NEW.edit_plan_id;
  SELECT campaign_id INTO camp FROM campaign_terms_snapshots WHERE id=snap;
  IF src IS NULL OR camp IS NULL OR honor_current_rights_for_action(src,camp,NULL,'EDIT_PLAN',NEW.committed_at) IS DISTINCT FROM rights THEN RAISE EXCEPTION 'audio planning must use edit plan whose rights remain current at audio-plan commit' USING ERRCODE='23514'; END IF;
  FOR ks IN SELECT knowledge_state FROM campaign_rule_items WHERE campaign_id=camp AND terms_snapshot_id=snap AND rule_key IN ('render_audio_rules','platform_native_audio_rules') LOOP IF ks='UNKNOWN' THEN RAISE EXCEPTION 'UNKNOWN audio rule blocks audio planning' USING ERRCODE='23514'; END IF; END LOOP;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION honor_audio_plan_version_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_audio_plan_version_guard() TO honor_app;
DROP TRIGGER IF EXISTS honor_audio_plan_version_guard_trigger ON audio_plans;
CREATE TRIGGER honor_audio_plan_version_guard_trigger BEFORE INSERT ON audio_plans FOR EACH ROW EXECUTE FUNCTION honor_audio_plan_version_guard();

-- Canonical expiration answer: authorization is expired at T iff source_rights.expires_at IS NOT NULL AND T >= source_rights.expires_at.
-- authorized_uses contains no expiration field. UNKNOWN eligibility remains UNKNOWN and never becomes permission.
CREATE OR REPLACE FUNCTION honor_clip_cross_record_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE c_source uuid; c_source_hash char(64); c_run uuid; ep_json jsonb; ep_hash char(64); sr record; ts_campaign uuid; ap_edit uuid; ap_native jsonb; sa_platform platform_enum; sa_identity uuid; rec_publish timestamptz; rec_platform text; native_rule_state knowledge_state_enum; native_rule_value jsonb; native_status text; ks knowledge_state_enum; tv jsonb; bound timestamptz; req jsonb; item text;
BEGIN
  SELECT c.source_id,s.sha256,c.generation_run_id,ep.plan_json,ep.plan_hash INTO c_source,c_source_hash,c_run,ep_json,ep_hash
    FROM edit_plans ep JOIN candidates c ON c.id=ep.candidate_id JOIN sources s ON s.id=c.source_id WHERE ep.id=NEW.edit_plan_id;
  IF c_source IS NULL OR c_source<>NEW.source_id OR c_run<>NEW.generation_run_id THEN RAISE EXCEPTION 'clip edit_plan candidate/source/run mismatch' USING ERRCODE='23514'; END IF;
  SELECT * INTO sr FROM source_rights WHERE id=NEW.rights_id;
  IF sr.source_id<>NEW.source_id OR sr.eligibility<>'ELIGIBLE' OR sr.committed_at>NEW.created_at OR sr.evidence_captured_at>NEW.created_at OR (sr.expires_at IS NOT NULL AND NEW.created_at>=sr.expires_at) THEN RAISE EXCEPTION 'clip rights are not eligible/current/historically available for source' USING ERRCODE='23514'; END IF;
  IF NOT EXISTS (SELECT 1 FROM source_rights_campaigns rc WHERE rc.source_rights_id=NEW.rights_id AND rc.campaign_id=NEW.campaign_id AND rc.created_at<=NEW.created_at) THEN RAISE EXCEPTION 'clip rights not historically authorized for campaign at clip creation' USING ERRCODE='23514'; END IF;
  SELECT campaign_id INTO ts_campaign FROM campaign_terms_snapshots WHERE id=NEW.rule_snapshot_id AND captured_at<=NEW.created_at;
  IF ts_campaign IS NULL OR ts_campaign<>NEW.campaign_id THEN RAISE EXCEPTION 'clip rule snapshot campaign/history mismatch' USING ERRCODE='23514'; END IF;
  IF ep_json->>'candidate_id' IS DISTINCT FROM (SELECT ep.candidate_id::text FROM edit_plans ep WHERE ep.id=NEW.edit_plan_id)
     OR ep_json->>'source_asset_id'<>NEW.source_id::text OR c_source_hash IS NULL OR ep_json->>'source_sha256'<>c_source_hash OR ep_json->>'source_rights_id'<>NEW.rights_id::text OR ep_json->>'source_rights_record_hash'<>sr.record_hash
     OR ep_json->>'plan_fingerprint_sha256'<>ep_hash THEN RAISE EXCEPTION 'clip edit-plan JSON provenance mismatch' USING ERRCODE='23514'; END IF;
  IF NOT (ep_json->'campaign_rule_snapshot_ids' ? NEW.rule_snapshot_id::text) OR ep_json->'rule_compliance'->>'rule_snapshot_id'<>NEW.rule_snapshot_id::text THEN RAISE EXCEPTION 'clip rule snapshot absent from edit plan' USING ERRCODE='23514'; END IF;
  IF EXISTS (SELECT 1 FROM jsonb_array_elements_text(ep_json->'campaign_rule_snapshot_ids') x(id_text) LEFT JOIN campaign_terms_snapshots t ON t.id=x.id_text::uuid WHERE t.id IS NULL OR t.campaign_id<>NEW.campaign_id) THEN RAISE EXCEPTION 'edit plan rule snapshot belongs to another campaign' USING ERRCODE='23514'; END IF;
  IF NOT EXISTS (SELECT 1 FROM edit_plans ep WHERE ep.id=NEW.edit_plan_id AND ep.committed_at<=NEW.created_at) THEN RAISE EXCEPTION 'clip edit plan did not exist at clip creation' USING ERRCODE='23514'; END IF;
  IF NEW.audio_plan_id IS NOT NULL THEN
    SELECT edit_plan_id,platform_native_recommendation INTO ap_edit,ap_native FROM audio_plans WHERE id=NEW.audio_plan_id AND committed_at<=NEW.created_at;
    IF ap_edit IS NULL OR ap_edit<>NEW.edit_plan_id THEN RAISE EXCEPTION 'clip audio plan belongs to another edit plan or is later evidence' USING ERRCODE='23514'; END IF;
    IF ap_native IS NULL OR NEW.posting_recommendation->'native_audio_recommendation' IS DISTINCT FROM ap_native THEN RAISE EXCEPTION 'posting native-audio snapshot must exactly mirror committed audio plan' USING ERRCODE='23514'; END IF;
    IF ep_json->'audio_plan_reference'->>'audio_plan_id' IS DISTINCT FROM NEW.audio_plan_id::text THEN RAISE EXCEPTION 'edit plan audio reference mismatch' USING ERRCODE='23514'; END IF;
  ELSE
    IF ep_json->'audio_plan_reference'->>'audio_plan_id' IS NOT NULL THEN RAISE EXCEPTION 'clip omits audio plan but edit plan references one' USING ERRCODE='23514'; END IF;
  END IF;
  SELECT platform,identity_id INTO sa_platform,sa_identity FROM social_accounts WHERE id=NEW.social_account_id;
  IF COALESCE((sr.authorized_uses->>'may_edit')::boolean,false) IS NOT TRUE OR COALESCE((sr.authorized_uses->>'derivative_edits')::boolean,false) IS NOT TRUE OR COALESCE((sr.authorized_uses->>'may_render')::boolean,false) IS NOT TRUE OR COALESCE((sr.authorized_uses->>'may_publish')::boolean,false) IS NOT TRUE OR COALESCE((sr.authorized_uses->>'commercial_use')::boolean,false) IS NOT TRUE
     OR NOT (sr.authorized_uses->'allowed_platforms' ? sa_platform::text) OR COALESCE((sr.platform_limits->sa_platform::text->>'allowed')::boolean,false) IS NOT TRUE THEN RAISE EXCEPTION 'clip compensated production/platform/use not authorized by exact rights version' USING ERRCODE='23514'; END IF;
  rec_platform:=NEW.posting_recommendation->>'platform';
  IF rec_platform<>sa_platform::text OR NEW.posting_recommendation->>'social_account_id'<>NEW.social_account_id::text OR NEW.posting_recommendation->>'social_identity_id'<>sa_identity::text THEN RAISE EXCEPTION 'posting recommendation account/identity/platform mismatch' USING ERRCODE='23514'; END IF;
  IF NEW.posting_recommendation->'native_audio_recommendation'->>'platform' IS DISTINCT FROM rec_platform THEN RAISE EXCEPTION 'nested native-audio recommendation platform differs from posting platform' USING ERRCODE='23514'; END IF;
  IF NEW.audio_plan_id IS NOT NULL AND ap_native->>'platform' IS DISTINCT FROM rec_platform THEN RAISE EXCEPTION 'audio-plan native recommendation platform differs from posting platform' USING ERRCODE='23514'; END IF;
  IF NEW.posting_recommendation->'native_audio_recommendation'->>'rule_snapshot_id'<>NEW.rule_snapshot_id::text THEN RAISE EXCEPTION 'native-audio recommendation rule snapshot mismatch' USING ERRCODE='23514'; END IF;
  IF honor_current_rights_for_action(NEW.source_id,NEW.campaign_id,sa_platform,'PUBLICATION_RECOMMENDATION',COALESCE(NEW.created_at,statement_timestamp())) IS DISTINCT FROM NEW.rights_id THEN RAISE EXCEPTION 'clip must use latest applicable rights version at decision time' USING ERRCODE='23514'; END IF;
  -- Frozen campaign posting eligibility uses the exact historical rule snapshot, never mutable campaign mirrors.
  SELECT knowledge_state,typed_value INTO ks,tv FROM campaign_rule_items WHERE campaign_id=NEW.campaign_id AND terms_snapshot_id=NEW.rule_snapshot_id AND rule_key='eligible_platforms';
  IF ks IS DISTINCT FROM 'KNOWN' OR NOT (tv->'value' ? sa_platform::text) THEN RAISE EXCEPTION 'posting platform is not proven eligible by frozen rule snapshot' USING ERRCODE='23514'; END IF;
  -- Critical posting rules cannot be UNKNOWN/absent.
  FOREACH item IN ARRAY ARRAY['start_at','end_at','deadline_at','required_tags','required_mentions','required_hashtags','disclosure_requirements','submission_format','platform_native_audio_rules'] LOOP
    SELECT knowledge_state INTO ks FROM campaign_rule_items WHERE campaign_id=NEW.campaign_id AND terms_snapshot_id=NEW.rule_snapshot_id AND rule_key=item;
    IF ks IS NULL OR ks='UNKNOWN' THEN RAISE EXCEPTION 'UNKNOWN/absent critical posting rule blocks recommendation: %',item USING ERRCODE='23514'; END IF;
  END LOOP;
  -- Required tags are exact required subset.
  SELECT typed_value INTO tv FROM campaign_rule_items WHERE campaign_id=NEW.campaign_id AND terms_snapshot_id=NEW.rule_snapshot_id AND rule_key='required_tags' AND knowledge_state='KNOWN';
  IF tv IS NOT NULL AND EXISTS(SELECT 1 FROM jsonb_array_elements_text(tv->'value') x(v) WHERE NOT (NEW.posting_recommendation->'required_tags' ? x.v)) THEN RAISE EXCEPTION 'required campaign tag missing from posting recommendation' USING ERRCODE='23514'; END IF;
  SELECT typed_value INTO tv FROM campaign_rule_items WHERE campaign_id=NEW.campaign_id AND terms_snapshot_id=NEW.rule_snapshot_id AND rule_key='required_hashtags' AND knowledge_state='KNOWN';
  IF tv IS NOT NULL AND EXISTS(SELECT 1 FROM jsonb_array_elements_text(tv->'value') x(v) WHERE NOT (NEW.posting_recommendation->'hashtags' ? x.v)) THEN RAISE EXCEPTION 'required campaign hashtag missing from posting recommendation' USING ERRCODE='23514'; END IF;
  SELECT typed_value INTO tv FROM campaign_rule_items WHERE campaign_id=NEW.campaign_id AND terms_snapshot_id=NEW.rule_snapshot_id AND rule_key='required_mentions' AND knowledge_state='KNOWN';
  IF tv IS NOT NULL AND EXISTS(SELECT 1 FROM jsonb_array_elements_text(tv->'value') x(v) WHERE NOT EXISTS(SELECT 1 FROM jsonb_array_elements(NEW.posting_recommendation->'required_mentions') m WHERE m->>'handle'=x.v)) THEN RAISE EXCEPTION 'required campaign mention missing from posting recommendation' USING ERRCODE='23514'; END IF;
  SELECT typed_value INTO tv FROM campaign_rule_items WHERE campaign_id=NEW.campaign_id AND terms_snapshot_id=NEW.rule_snapshot_id AND rule_key='disclosure_requirements' AND knowledge_state='KNOWN';
  IF tv IS NOT NULL THEN req:=tv->'value'; IF (NEW.posting_recommendation->'disclosure'->>'required')::boolean IS DISTINCT FROM (req->>'required')::boolean OR NEW.posting_recommendation->'disclosure'->'text' IS DISTINCT FROM req->'text' OR NEW.posting_recommendation->'disclosure'->'instructions' IS DISTINCT FROM req->'instructions' THEN RAISE EXCEPTION 'posting disclosure does not mirror frozen campaign rule' USING ERRCODE='23514'; END IF; END IF;
  SELECT typed_value INTO tv FROM campaign_rule_items WHERE campaign_id=NEW.campaign_id AND terms_snapshot_id=NEW.rule_snapshot_id AND rule_key='submission_format' AND knowledge_state='KNOWN';
  IF tv IS NOT NULL THEN req:=tv->'value'; IF NEW.posting_recommendation->'submission_requirements'->>'required' IS DISTINCT FROM req->>'required' OR NEW.posting_recommendation->'submission_requirements'->'instructions' IS DISTINCT FROM req->'instructions' OR NEW.posting_recommendation->'submission_requirements'->'submission_url' IS DISTINCT FROM req->'submission_url' OR NEW.posting_recommendation->'submission_requirements'->'required_evidence' IS DISTINCT FROM req->'required_evidence' THEN RAISE EXCEPTION 'submission requirements do not mirror frozen campaign rule' USING ERRCODE='23514'; END IF; END IF;
  rec_publish:=NULLIF(NEW.posting_recommendation->>'recommended_publish_at','')::timestamptz;
  IF rec_publish IS NOT NULL THEN
    IF sr.expires_at IS NOT NULL AND rec_publish>=sr.expires_at THEN RAISE EXCEPTION 'recommended publish time is at/after rights expiration' USING ERRCODE='23514'; END IF;
    SELECT knowledge_state,typed_value INTO ks,tv FROM campaign_rule_items WHERE campaign_id=NEW.campaign_id AND terms_snapshot_id=NEW.rule_snapshot_id AND rule_key='start_at';
    IF ks='KNOWN' AND rec_publish < (tv->>'value')::timestamptz THEN RAISE EXCEPTION 'recommended publish time before campaign start' USING ERRCODE='23514'; END IF;
    SELECT knowledge_state,typed_value INTO ks,tv FROM campaign_rule_items WHERE campaign_id=NEW.campaign_id AND terms_snapshot_id=NEW.rule_snapshot_id AND rule_key='end_at';
    IF ks='KNOWN' AND rec_publish >= (tv->>'value')::timestamptz THEN RAISE EXCEPTION 'recommended publish time at/after campaign end' USING ERRCODE='23514'; END IF;
    SELECT knowledge_state,typed_value INTO ks,tv FROM campaign_rule_items WHERE campaign_id=NEW.campaign_id AND terms_snapshot_id=NEW.rule_snapshot_id AND rule_key='deadline_at';
    IF ks='KNOWN' AND rec_publish >= (tv->>'value')::timestamptz THEN RAISE EXCEPTION 'recommended publish time at/after campaign deadline' USING ERRCODE='23514'; END IF;
  END IF;
  SELECT knowledge_state,typed_value INTO native_rule_state,native_rule_value FROM campaign_rule_items WHERE campaign_id=NEW.campaign_id AND rule_key='platform_native_audio_rules' AND terms_snapshot_id=NEW.rule_snapshot_id;
  native_status:=NEW.posting_recommendation->'native_audio_recommendation'->>'recommendation_status';
  IF native_rule_state='NOT_APPLICABLE' THEN IF native_status<>'NOT_APPLICABLE' THEN RAISE EXCEPTION 'not-applicable native-audio rule mismatch' USING ERRCODE='23514'; END IF;
  ELSIF native_rule_state<>'KNOWN' THEN IF native_status<>'UNKNOWN' THEN RAISE EXCEPTION 'UNKNOWN native-audio rule cannot become recommendation' USING ERRCODE='23514'; END IF;
  ELSE
    IF native_rule_value->>'value_type'<>'PLATFORM_NATIVE_AUDIO_RULES' THEN RAISE EXCEPTION 'known platform_native_audio_rules has wrong registered type' USING ERRCODE='23514'; END IF;
    item:=native_rule_value->'value'->>sa_platform::text;
    IF item='PROHIBITED' AND native_status<>'PROHIBITED' THEN RAISE EXCEPTION 'prohibited native-audio rule cannot be escalated' USING ERRCODE='23514'; END IF;
    IF item='UNKNOWN' AND native_status<>'UNKNOWN' THEN RAISE EXCEPTION 'UNKNOWN native-audio rule cannot become recommendation' USING ERRCODE='23514'; END IF;
    IF item='NOT_APPLICABLE' AND native_status<>'NOT_APPLICABLE' THEN RAISE EXCEPTION 'not-applicable native-audio rule mismatch' USING ERRCODE='23514'; END IF;
    IF item='ALLOWED' AND native_status NOT IN ('RECOMMENDED','NOT_APPLICABLE') THEN RAISE EXCEPTION 'native-audio recommendation contradicts known allowed rule' USING ERRCODE='23514'; END IF;
  END IF;
  IF NEW.audio_plan_id IS NULL AND native_status='RECOMMENDED' THEN RAISE EXCEPTION 'RECOMMENDED native audio requires committed audio plan authority' USING ERRCODE='23514'; END IF;
  IF (sr.authorized_uses->>'required_attribution') IS NOT NULL THEN
    IF COALESCE((NEW.posting_recommendation->'source_attribution'->>'required')::boolean,false) IS NOT TRUE OR NEW.posting_recommendation->'source_attribution'->>'text' IS DISTINCT FROM sr.authorized_uses->>'required_attribution' OR position(sr.authorized_uses->>'required_attribution' in NEW.posting_recommendation->>'caption')=0 THEN RAISE EXCEPTION 'required source attribution missing from posting snapshot/caption' USING ERRCODE='23514'; END IF;
  ELSE
    IF COALESCE((NEW.posting_recommendation->'source_attribution'->>'required')::boolean,false) IS TRUE THEN RAISE EXCEPTION 'posting snapshot cannot invent mandatory source attribution' USING ERRCODE='23514'; END IF;
  END IF;
  IF TG_OP='UPDATE' AND NEW.posting_recommendation IS DISTINCT FROM OLD.posting_recommendation AND (OLD.state IN ('POSTED','ARCHIVED') OR NEW.state IN ('POSTED','ARCHIVED') OR EXISTS (SELECT 1 FROM posts p WHERE p.clip_id=OLD.id)) THEN RAISE EXCEPTION 'posting recommendation is immutable once posting/archival begins' USING ERRCODE='42501'; END IF;
  NEW.caption_copy := NEW.posting_recommendation->>'caption';
  NEW.title_copy := NEW.posting_recommendation->>'platform_title';
  NEW.hashtags := NEW.posting_recommendation->'hashtags';
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION honor_clip_cross_record_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_clip_cross_record_guard() TO honor_app;
DROP TRIGGER IF EXISTS honor_clip_cross_record_guard_trigger ON clips;
CREATE TRIGGER honor_clip_cross_record_guard_trigger BEFORE INSERT OR UPDATE OF generation_run_id,campaign_id,source_id,social_account_id,edit_plan_id,audio_plan_id,caption_copy,title_copy,hashtags,posting_recommendation,rule_snapshot_id,rights_id,state ON clips FOR EACH ROW EXECUTE FUNCTION honor_clip_cross_record_guard();

CREATE OR REPLACE FUNCTION honor_clip_provenance_lock_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE locked boolean;
BEGIN
  locked := OLD.state IN ('READY','POSTED','ARCHIVED') OR EXISTS (SELECT 1 FROM render_manifests rm WHERE rm.clip_id=OLD.id);
  IF locked AND (
    NEW.generation_run_id IS DISTINCT FROM OLD.generation_run_id OR NEW.campaign_id IS DISTINCT FROM OLD.campaign_id OR NEW.source_id IS DISTINCT FROM OLD.source_id OR
    NEW.social_account_id IS DISTINCT FROM OLD.social_account_id OR NEW.edit_plan_id IS DISTINCT FROM OLD.edit_plan_id OR NEW.audio_plan_id IS DISTINCT FROM OLD.audio_plan_id OR
    NEW.rule_snapshot_id IS DISTINCT FROM OLD.rule_snapshot_id OR NEW.rights_id IS DISTINCT FROM OLD.rights_id OR NEW.final_object_key IS DISTINCT FROM OLD.final_object_key OR
    NEW.sha256 IS DISTINCT FROM OLD.sha256 OR NEW.duration_ms IS DISTINCT FROM OLD.duration_ms OR NEW.width IS DISTINCT FROM OLD.width OR NEW.height IS DISTINCT FROM OLD.height OR
    NEW.codec IS DISTINCT FROM OLD.codec OR NEW.file_size_bytes IS DISTINCT FROM OLD.file_size_bytes
  ) THEN RAISE EXCEPTION 'accepted render/READY clip provenance is immutable; create a new clip lineage for correction' USING ERRCODE='42501'; END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION honor_clip_provenance_lock_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_clip_provenance_lock_guard() TO honor_app;
DROP TRIGGER IF EXISTS honor_clip_provenance_lock_guard_trigger ON clips;
CREATE TRIGGER honor_clip_provenance_lock_guard_trigger BEFORE UPDATE ON clips FOR EACH ROW EXECUTE FUNCTION honor_clip_provenance_lock_guard();

-- ---------- IMMUTABILITY / READY GATE FUNCTIONS (FROZEN NAMES + SEMANTICS) ----------
CREATE OR REPLACE FUNCTION honor_reject_immutable_mutation() RETURNS trigger
LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'HONOR immutable provenance row' USING ERRCODE='42501'; END $$;
REVOKE ALL ON FUNCTION honor_reject_immutable_mutation() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_reject_immutable_mutation() TO honor_app;

-- Exact immutable triggers; material revisions create new rows/versions.
DROP TRIGGER IF EXISTS honor_immutable_source_rights ON source_rights;
CREATE TRIGGER honor_immutable_source_rights BEFORE UPDATE OR DELETE ON source_rights FOR EACH ROW EXECUTE FUNCTION honor_reject_immutable_mutation();
DROP TRIGGER IF EXISTS honor_immutable_source_rights_campaigns ON source_rights_campaigns;
CREATE TRIGGER honor_immutable_source_rights_campaigns BEFORE UPDATE OR DELETE ON source_rights_campaigns FOR EACH ROW EXECUTE FUNCTION honor_reject_immutable_mutation();
DROP TRIGGER IF EXISTS honor_immutable_edit_plans ON edit_plans;
CREATE TRIGGER honor_immutable_edit_plans BEFORE UPDATE OR DELETE ON edit_plans FOR EACH ROW EXECUTE FUNCTION honor_reject_immutable_mutation();
DROP TRIGGER IF EXISTS honor_immutable_audio_plans ON audio_plans;
CREATE TRIGGER honor_immutable_audio_plans BEFORE UPDATE OR DELETE ON audio_plans FOR EACH ROW EXECUTE FUNCTION honor_reject_immutable_mutation();
DROP TRIGGER IF EXISTS honor_immutable_qc_runs ON qc_runs;
CREATE TRIGGER honor_immutable_qc_runs BEFORE UPDATE OR DELETE ON qc_runs FOR EACH ROW EXECUTE FUNCTION honor_reject_immutable_mutation();
DROP TRIGGER IF EXISTS honor_immutable_render_manifests ON render_manifests;
CREATE TRIGGER honor_immutable_render_manifests BEFORE UPDATE OR DELETE ON render_manifests FOR EACH ROW EXECUTE FUNCTION honor_reject_immutable_mutation();
DROP TRIGGER IF EXISTS honor_immutable_candidates ON candidates;
CREATE TRIGGER honor_immutable_candidates BEFORE UPDATE OR DELETE ON candidates FOR EACH ROW EXECUTE FUNCTION honor_reject_immutable_mutation();
DROP TRIGGER IF EXISTS honor_immutable_run_campaign_allocations ON run_campaign_allocations;
CREATE TRIGGER honor_immutable_run_campaign_allocations BEFORE UPDATE OR DELETE ON run_campaign_allocations FOR EACH ROW EXECUTE FUNCTION honor_reject_immutable_mutation();
DROP TRIGGER IF EXISTS honor_immutable_campaign_rule_items ON campaign_rule_items;
CREATE TRIGGER honor_immutable_campaign_rule_items BEFORE UPDATE OR DELETE ON campaign_rule_items FOR EACH ROW EXECUTE FUNCTION honor_reject_immutable_mutation();
DROP TRIGGER IF EXISTS honor_immutable_account_health_snapshots ON account_health_snapshots;
CREATE TRIGGER honor_immutable_account_health_snapshots BEFORE UPDATE OR DELETE ON account_health_snapshots FOR EACH ROW EXECUTE FUNCTION honor_reject_immutable_mutation();
DROP TRIGGER IF EXISTS honor_immutable_campaign_terms_snapshots ON campaign_terms_snapshots;
CREATE TRIGGER honor_immutable_campaign_terms_snapshots BEFORE UPDATE OR DELETE ON campaign_terms_snapshots FOR EACH ROW EXECUTE FUNCTION honor_reject_immutable_mutation();
DROP TRIGGER IF EXISTS honor_immutable_analytics_observations ON analytics_observations;
CREATE TRIGGER honor_immutable_analytics_observations BEFORE UPDATE OR DELETE ON analytics_observations FOR EACH ROW EXECUTE FUNCTION honor_reject_immutable_mutation();
DROP TRIGGER IF EXISTS honor_immutable_earning_state_transitions ON earning_state_transitions;
CREATE TRIGGER honor_immutable_earning_state_transitions BEFORE UPDATE OR DELETE ON earning_state_transitions FOR EACH ROW EXECUTE FUNCTION honor_reject_immutable_mutation();
DROP TRIGGER IF EXISTS honor_immutable_provider_usage ON provider_usage;
CREATE TRIGGER honor_immutable_provider_usage BEFORE UPDATE OR DELETE ON provider_usage FOR EACH ROW EXECUTE FUNCTION honor_reject_immutable_mutation();
DROP TRIGGER IF EXISTS honor_immutable_polli_turns ON polli_turns;
CREATE TRIGGER honor_immutable_polli_turns BEFORE UPDATE OR DELETE ON polli_turns FOR EACH ROW EXECUTE FUNCTION honor_reject_immutable_mutation();
DROP TRIGGER IF EXISTS honor_immutable_polli_tool_calls ON polli_tool_calls;
CREATE TRIGGER honor_immutable_polli_tool_calls BEFORE UPDATE OR DELETE ON polli_tool_calls FOR EACH ROW EXECUTE FUNCTION honor_reject_immutable_mutation();
DROP TRIGGER IF EXISTS honor_immutable_events ON events;
CREATE TRIGGER honor_immutable_events BEFORE UPDATE OR DELETE ON events FOR EACH ROW EXECUTE FUNCTION honor_reject_immutable_mutation();
DROP TRIGGER IF EXISTS honor_immutable_audit_log ON audit_log;
CREATE TRIGGER honor_immutable_audit_log BEFORE UPDATE OR DELETE ON audit_log FOR EACH ROW EXECUTE FUNCTION honor_reject_immutable_mutation();

CREATE OR REPLACE FUNCTION honor_render_manifest_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM clips c JOIN social_accounts sa ON sa.id=c.social_account_id WHERE c.id=NEW.clip_id AND honor_current_rights_for_action(c.source_id,c.campaign_id,sa.platform,'RENDER',NEW.created_at)=c.rights_id) THEN RAISE EXCEPTION 'render manifest cannot accept obsolete rights version' USING ERRCODE='23514'; END IF;
  IF NOT EXISTS (
    SELECT 1
    FROM qc_runs q
    JOIN clips c ON c.id=NEW.clip_id
    JOIN sources s ON s.id=c.source_id
    JOIN edit_plans ep ON ep.id=NEW.edit_plan_id
    LEFT JOIN audio_plans ap ON ap.id=NEW.audio_plan_id
    WHERE q.id=NEW.qc_run_id AND q.clip_id=NEW.clip_id AND q.passed=true
      AND NEW.edit_plan_id=c.edit_plan_id
      AND (NEW.audio_plan_id IS NOT DISTINCT FROM c.audio_plan_id)
      AND s.sha256 IS NOT NULL AND c.sha256 IS NOT NULL AND c.final_object_key IS NOT NULL AND c.file_size_bytes IS NOT NULL AND c.duration_ms IS NOT NULL AND c.width IS NOT NULL AND c.height IS NOT NULL AND c.codec IS NOT NULL
      AND NEW.manifest_json->>'render_manifest_id'=NEW.id::text
      AND NEW.manifest_json->>'clip_id'=NEW.clip_id::text
      AND NEW.manifest_json->>'source_asset_id'=c.source_id::text
      AND NEW.manifest_json->>'source_sha256'=s.sha256
      AND NEW.manifest_json->>'edit_plan_id'=ep.id::text
      AND NEW.manifest_json->>'edit_plan_hash'=ep.plan_hash
      AND (NEW.manifest_json->>'edit_plan_version')::integer=ep.plan_version
      AND NEW.manifest_json->>'qc_run_id'=q.id::text
      AND NEW.manifest_json->>'qc_version'=q.qc_version
      AND (NEW.manifest_json->'output'->>'object_key')=c.final_object_key
      AND (NEW.manifest_json->'output'->>'sha256')=c.sha256
      AND (NEW.manifest_json->'output'->>'file_size_bytes')::bigint=c.file_size_bytes
      AND (NEW.manifest_json->'output'->>'duration_ms')::bigint=c.duration_ms
      AND (NEW.manifest_json->'material_render_parameters'->>'canvas_width')::integer=c.width
      AND (NEW.manifest_json->'material_render_parameters'->>'canvas_height')::integer=c.height
      AND NEW.manifest_json->'material_render_parameters'->>'video_codec'=c.codec
      AND NEW.manifest_json->>'manifest_hash'=NEW.manifest_hash
      AND (
        (NEW.audio_plan_id IS NULL AND NEW.manifest_json->>'audio_plan_id' IS NULL)
        OR
        (NEW.audio_plan_id IS NOT NULL AND NEW.manifest_json->>'audio_plan_id'=ap.id::text
          AND NEW.manifest_json->>'audio_plan_hash'=ap.plan_hash
          AND (NEW.manifest_json->>'audio_plan_version')::integer=ap.plan_version)
      )
  ) THEN
    RAISE EXCEPTION 'render manifest requires passed terminal QC and exact source/edit/audio/output provenance' USING ERRCODE='23514';
  END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION honor_render_manifest_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_render_manifest_guard() TO honor_app;
DROP TRIGGER IF EXISTS honor_render_manifest_guard_trigger ON render_manifests;
CREATE TRIGGER honor_render_manifest_guard_trigger BEFORE INSERT ON render_manifests FOR EACH ROW EXECUTE FUNCTION honor_render_manifest_guard();

CREATE OR REPLACE FUNCTION honor_clip_ready_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE must_check boolean := false; max_rights numeric; min_campaign numeric; max_campaign numeric; ks knowledge_state_enum; p platform_enum;
BEGIN
  IF NEW.state='READY' AND NOT EXISTS (SELECT 1 FROM social_accounts sa WHERE sa.id=NEW.social_account_id AND honor_current_rights_for_action(NEW.source_id,NEW.campaign_id,sa.platform,'RENDER',statement_timestamp())=NEW.rights_id) THEN RAISE EXCEPTION 'READY blocked by superseding rights version' USING ERRCODE='23514'; END IF;
  IF NEW.state='READY' THEN
    IF TG_OP='INSERT' THEN
      must_check := true;
    ELSIF TG_OP='UPDATE' AND OLD.state IS DISTINCT FROM 'READY' THEN
      must_check := true;
    END IF;
  END IF;
  IF must_check THEN
    IF NOT EXISTS (
      SELECT 1 FROM render_manifests rm
      JOIN qc_runs q ON q.id=rm.qc_run_id AND q.clip_id=NEW.id
      WHERE rm.clip_id=NEW.id AND q.passed=true AND rm.edit_plan_id=NEW.edit_plan_id
        AND (rm.audio_plan_id IS NOT DISTINCT FROM NEW.audio_plan_id)
    ) THEN
      RAISE EXCEPTION 'READY requires successful immutable QC + render manifest' USING ERRCODE='23514';
    END IF;
  END IF;

    SELECT sa.platform INTO p FROM social_accounts sa WHERE sa.id=NEW.social_account_id;
    SELECT NULLIF(sr.platform_limits->p::text->>'max_clip_seconds','')::numeric INTO max_rights FROM source_rights sr WHERE sr.id=NEW.rights_id;
    SELECT knowledge_state,CASE WHEN knowledge_state='KNOWN' THEN (typed_value->>'value')::numeric ELSE NULL END INTO ks,min_campaign FROM campaign_rule_items WHERE campaign_id=NEW.campaign_id AND terms_snapshot_id=NEW.rule_snapshot_id AND rule_key='clip_length_min_seconds';
    IF ks='UNKNOWN' THEN RAISE EXCEPTION 'UNKNOWN clip length minimum blocks READY' USING ERRCODE='23514'; END IF;
    SELECT knowledge_state,CASE WHEN knowledge_state='KNOWN' THEN (typed_value->>'value')::numeric ELSE NULL END INTO ks,max_campaign FROM campaign_rule_items WHERE campaign_id=NEW.campaign_id AND terms_snapshot_id=NEW.rule_snapshot_id AND rule_key='clip_length_max_seconds';
    IF ks='UNKNOWN' THEN RAISE EXCEPTION 'UNKNOWN clip length maximum blocks READY' USING ERRCODE='23514'; END IF;
    IF max_rights IS NOT NULL AND NEW.duration_ms > max_rights*1000 THEN RAISE EXCEPTION 'render exceeds rights max_clip_seconds' USING ERRCODE='23514'; END IF;
    IF max_campaign IS NOT NULL AND NEW.duration_ms > max_campaign*1000 THEN RAISE EXCEPTION 'render exceeds campaign clip maximum' USING ERRCODE='23514'; END IF;
    IF min_campaign IS NOT NULL AND NEW.duration_ms < min_campaign*1000 THEN RAISE EXCEPTION 'render shorter than campaign clip minimum' USING ERRCODE='23514'; END IF;
    IF EXISTS(SELECT 1 FROM campaign_rule_items WHERE campaign_id=NEW.campaign_id AND terms_snapshot_id=NEW.rule_snapshot_id AND rule_key IN ('source_material_restrictions','content_restrictions','editing_restrictions','uniqueness_rules','render_audio_rules') AND knowledge_state='UNKNOWN') THEN RAISE EXCEPTION 'UNKNOWN critical media restriction blocks READY' USING ERRCODE='23514'; END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION honor_clip_ready_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_clip_ready_guard() TO honor_app;
DROP TRIGGER IF EXISTS honor_clip_ready_guard_trigger ON clips;
CREATE TRIGGER honor_clip_ready_guard_trigger BEFORE INSERT OR UPDATE OF state ON clips FOR EACH ROW EXECUTE FUNCTION honor_clip_ready_guard();

-- Rights/edit/audio history semantics: source_rights and source_rights_campaigns are SELECT-only to honor_app and are inserted atomically only by honor_commit_source_rights_version(); edit_plans and audio_plans remain insert-only for honor_app.
-- Hash rules: source_rights.record_hash is SHA-256 of RFC8785 canonical JSON over the material rights/evidence fields INCLUDING the sole relational expires_at value, plus source_id/rights_version/supersedes_rights_id; edit_plans.plan_hash MUST equal plan_json.plan_fingerprint_sha256; audio_plans.plan_hash is SHA-256 of RFC8785 canonical JSON over its material planning fields excluding plan_hash/created timestamps.
-- New evidence/revocation creates a new source_rights row with incremented rights_version + supersedes_rights_id; old clip rights_id remains unchanged.
-- Campaign applicability for a rights version is represented by immutable source_rights_campaigns rows tied to that rights row; never rewrite an old association.
-- Revised edit/audio decisions create new edit_plans/audio_plans rows with incremented plan_version + supersedes_*; existing clip/render references remain unchanged.
-- No workflow may infer or manufacture retroactive permission from later evidence.


-- ---------- ROUND-7 CAMPAIGN TRUTH / DECISION HISTORY / STATE-INTEGRITY FREEZE ----------
-- campaign_terms_snapshots.id is BOTH raw/evidence snapshot identity and the normalized immutable rule-set snapshot identity.
-- campaign_rule_items are immutable snapshot-scoped facts. Later verification creates a new campaign_terms_snapshots row plus a complete new 32-row rule set; old normalized rules are never updated.
CREATE OR REPLACE FUNCTION honor_campaign_rule_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE expected_type text;
BEGIN
  IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'campaign rule snapshots are immutable' USING ERRCODE='42501'; END IF;
  IF NEW.knowledge_state='KNOWN' AND (NEW.typed_value IS NULL OR NEW.evidence_snapshot_id IS NULL OR NEW.verified_at IS NULL) THEN RAISE EXCEPTION 'KNOWN rule requires typed value, evidence, verification timestamp' USING ERRCODE='23514'; END IF;
  IF NEW.knowledge_state='NOT_APPLICABLE' AND (NEW.typed_value IS NOT NULL OR NEW.evidence_snapshot_id IS NULL OR NEW.verified_at IS NULL) THEN RAISE EXCEPTION 'NOT_APPLICABLE requires null value plus evidence/timestamp' USING ERRCODE='23514'; END IF;
  IF NEW.knowledge_state='UNKNOWN' AND NEW.typed_value IS NOT NULL THEN RAISE EXCEPTION 'UNKNOWN rule must have null typed value' USING ERRCODE='23514'; END IF;
  expected_type := CASE NEW.rule_key
    WHEN 'provider' THEN 'STRING' WHEN 'campaign_url' THEN 'STRING' WHEN 'external_campaign_id' THEN 'STRING'
    WHEN 'status' THEN 'CAMPAIGN_STATUS' WHEN 'compensation_model' THEN 'COMPENSATION_MODEL' WHEN 'cpm_or_rate' THEN 'RATE'
    WHEN 'minimum_views' THEN 'INTEGER' WHEN 'max_payout_per_clip' THEN 'MONEY_USD' WHEN 'total_budget' THEN 'MONEY_USD' WHEN 'remaining_budget' THEN 'MONEY_USD'
    WHEN 'start_at' THEN 'TIMESTAMP' WHEN 'end_at' THEN 'TIMESTAMP' WHEN 'deadline_at' THEN 'TIMESTAMP'
    WHEN 'eligible_platforms' THEN 'PLATFORMS' WHEN 'eligible_regions' THEN 'REGIONS' WHEN 'eligible_account_requirements' THEN 'ACCOUNT_REQUIREMENTS'
    WHEN 'required_tags' THEN 'STRING_ARRAY' WHEN 'required_mentions' THEN 'STRING_ARRAY' WHEN 'required_hashtags' THEN 'STRING_ARRAY'
    WHEN 'disclosure_requirements' THEN 'DISCLOSURE_REQUIREMENTS' WHEN 'source_material_restrictions' THEN 'RESTRICTION_SET'
    WHEN 'clip_length_min_seconds' THEN 'DURATION_SECONDS' WHEN 'clip_length_max_seconds' THEN 'DURATION_SECONDS'
    WHEN 'content_restrictions' THEN 'RESTRICTION_SET' WHEN 'editing_restrictions' THEN 'RESTRICTION_SET' WHEN 'uniqueness_rules' THEN 'RESTRICTION_SET'
    WHEN 'submission_format' THEN 'SUBMISSION_FORMAT' WHEN 'analytics_window' THEN 'WINDOW' WHEN 'payout_window' THEN 'WINDOW'
    WHEN 'render_audio_rules' THEN 'RENDER_AUDIO_RULES' WHEN 'platform_native_audio_rules' THEN 'PLATFORM_NATIVE_AUDIO_RULES' WHEN 'last_verified_at' THEN 'TIMESTAMP'
    ELSE NULL END;
  IF expected_type IS NULL THEN RAISE EXCEPTION 'non-canonical campaign rule key' USING ERRCODE='23514'; END IF;
  IF NEW.knowledge_state='KNOWN' AND NEW.typed_value->>'value_type' IS DISTINCT FROM expected_type THEN RAISE EXCEPTION 'campaign rule typed value type mismatch' USING ERRCODE='23514'; END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION honor_campaign_rule_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_campaign_rule_guard() TO honor_app;
DROP TRIGGER IF EXISTS honor_campaign_rule_guard_trigger ON campaign_rule_items;
CREATE TRIGGER honor_campaign_rule_guard_trigger BEFORE INSERT OR UPDATE OR DELETE ON campaign_rule_items FOR EACH ROW EXECUTE FUNCTION honor_campaign_rule_guard();

-- Only this narrow function advances the current campaign rule-set pointer and atomically refreshes scalar query mirrors from the exact immutable rule snapshot.
CREATE OR REPLACE FUNCTION honor_activate_campaign_rule_snapshot(p_campaign_id uuid, p_snapshot_id uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_catalog AS $$
DECLARE cnt integer; ks knowledge_state_enum; tv jsonb; minsec numeric; maxsec numeric; startv timestamptz; endv timestamptz; totalv numeric; remainv numeric; minfollowers bigint; maxfollowers bigint;
BEGIN
  IF NOT honor_owner_authorized() THEN RAISE EXCEPTION 'owner context required' USING ERRCODE='42501'; END IF;
  IF NOT EXISTS(SELECT 1 FROM campaign_terms_snapshots WHERE id=p_snapshot_id AND campaign_id=p_campaign_id) THEN RAISE EXCEPTION 'snapshot/campaign mismatch' USING ERRCODE='23514'; END IF;
  SELECT count(*) INTO cnt FROM campaign_rule_items WHERE campaign_id=p_campaign_id AND terms_snapshot_id=p_snapshot_id AND schema_version=1;
  IF cnt<>32 THEN RAISE EXCEPTION 'current rule snapshot requires exactly 32 canonical rules' USING ERRCODE='23514'; END IF;
  -- provider is the non-null campaign identity mirror, therefore V1 activation requires a KNOWN provider fact.
  SELECT knowledge_state,typed_value INTO ks,tv FROM campaign_rule_items WHERE campaign_id=p_campaign_id AND terms_snapshot_id=p_snapshot_id AND rule_key='provider';
  IF ks IS DISTINCT FROM 'KNOWN' THEN RAISE EXCEPTION 'provider must be KNOWN before activating a current campaign rule snapshot' USING ERRCODE='23514'; END IF;
  -- frozen cross-rule range invariants.
  SELECT CASE WHEN knowledge_state='KNOWN' THEN (typed_value->>'value')::numeric END INTO minsec FROM campaign_rule_items WHERE campaign_id=p_campaign_id AND terms_snapshot_id=p_snapshot_id AND rule_key='clip_length_min_seconds';
  SELECT CASE WHEN knowledge_state='KNOWN' THEN (typed_value->>'value')::numeric END INTO maxsec FROM campaign_rule_items WHERE campaign_id=p_campaign_id AND terms_snapshot_id=p_snapshot_id AND rule_key='clip_length_max_seconds';
  IF minsec IS NOT NULL AND maxsec IS NOT NULL AND minsec>maxsec THEN RAISE EXCEPTION 'clip length min exceeds max' USING ERRCODE='23514'; END IF;
  SELECT CASE WHEN knowledge_state='KNOWN' THEN (typed_value->>'value')::timestamptz END INTO startv FROM campaign_rule_items WHERE campaign_id=p_campaign_id AND terms_snapshot_id=p_snapshot_id AND rule_key='start_at';
  SELECT CASE WHEN knowledge_state='KNOWN' THEN (typed_value->>'value')::timestamptz END INTO endv FROM campaign_rule_items WHERE campaign_id=p_campaign_id AND terms_snapshot_id=p_snapshot_id AND rule_key='end_at';
  IF startv IS NOT NULL AND endv IS NOT NULL AND startv>=endv THEN RAISE EXCEPTION 'campaign start must be before end' USING ERRCODE='23514'; END IF;
  SELECT CASE WHEN knowledge_state='KNOWN' THEN (typed_value->>'value')::numeric END INTO totalv FROM campaign_rule_items WHERE campaign_id=p_campaign_id AND terms_snapshot_id=p_snapshot_id AND rule_key='total_budget';
  SELECT CASE WHEN knowledge_state='KNOWN' THEN (typed_value->>'value')::numeric END INTO remainv FROM campaign_rule_items WHERE campaign_id=p_campaign_id AND terms_snapshot_id=p_snapshot_id AND rule_key='remaining_budget';
  IF totalv IS NOT NULL AND remainv IS NOT NULL AND remainv>totalv THEN RAISE EXCEPTION 'remaining budget exceeds total budget' USING ERRCODE='23514'; END IF;
  SELECT CASE WHEN knowledge_state='KNOWN' THEN NULLIF(typed_value->'value'->>'min_followers','')::bigint END, CASE WHEN knowledge_state='KNOWN' THEN NULLIF(typed_value->'value'->>'max_followers','')::bigint END INTO minfollowers,maxfollowers FROM campaign_rule_items WHERE campaign_id=p_campaign_id AND terms_snapshot_id=p_snapshot_id AND rule_key='eligible_account_requirements';
  IF minfollowers IS NOT NULL AND maxfollowers IS NOT NULL AND minfollowers>maxfollowers THEN RAISE EXCEPTION 'eligible account min_followers exceeds max_followers' USING ERRCODE='23514'; END IF;
  UPDATE campaigns c SET
    terms_snapshot_id=p_snapshot_id,
    provider=(SELECT typed_value->>'value' FROM campaign_rule_items WHERE campaign_id=p_campaign_id AND terms_snapshot_id=p_snapshot_id AND rule_key='provider' AND knowledge_state='KNOWN'),
    campaign_url=(SELECT typed_value->>'value' FROM campaign_rule_items WHERE campaign_id=p_campaign_id AND terms_snapshot_id=p_snapshot_id AND rule_key='campaign_url' AND knowledge_state='KNOWN'),
    external_campaign_id=(SELECT typed_value->>'value' FROM campaign_rule_items WHERE campaign_id=p_campaign_id AND terms_snapshot_id=p_snapshot_id AND rule_key='external_campaign_id' AND knowledge_state='KNOWN'),
    status=COALESCE((SELECT (typed_value->>'value')::campaign_status_enum FROM campaign_rule_items WHERE campaign_id=p_campaign_id AND terms_snapshot_id=p_snapshot_id AND rule_key='status' AND knowledge_state='KNOWN'),'UNKNOWN'),
    start_at=(SELECT (typed_value->>'value')::timestamptz FROM campaign_rule_items WHERE campaign_id=p_campaign_id AND terms_snapshot_id=p_snapshot_id AND rule_key='start_at' AND knowledge_state='KNOWN'),
    end_at=(SELECT (typed_value->>'value')::timestamptz FROM campaign_rule_items WHERE campaign_id=p_campaign_id AND terms_snapshot_id=p_snapshot_id AND rule_key='end_at' AND knowledge_state='KNOWN'),
    deadline_at=(SELECT (typed_value->>'value')::timestamptz FROM campaign_rule_items WHERE campaign_id=p_campaign_id AND terms_snapshot_id=p_snapshot_id AND rule_key='deadline_at' AND knowledge_state='KNOWN'),
    last_verified_at=(SELECT (typed_value->>'value')::timestamptz FROM campaign_rule_items WHERE campaign_id=p_campaign_id AND terms_snapshot_id=p_snapshot_id AND rule_key='last_verified_at' AND knowledge_state='KNOWN'),
    updated_at=statement_timestamp()
  WHERE c.id=p_campaign_id;
  RETURN p_snapshot_id;
END $$;
REVOKE ALL ON FUNCTION honor_activate_campaign_rule_snapshot(uuid,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_activate_campaign_rule_snapshot(uuid,uuid) TO honor_app;

CREATE OR REPLACE FUNCTION honor_campaign_mirror_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE s uuid;
BEGIN
  s:=NEW.terms_snapshot_id;
  IF s IS NULL THEN RETURN NEW; END IF;
  IF NEW.provider IS DISTINCT FROM (SELECT typed_value->>'value' FROM campaign_rule_items WHERE campaign_id=NEW.id AND terms_snapshot_id=s AND rule_key='provider' AND knowledge_state='KNOWN') THEN RAISE EXCEPTION 'campaign provider mirror mismatch' USING ERRCODE='23514'; END IF;
  IF NEW.campaign_url IS DISTINCT FROM (SELECT typed_value->>'value' FROM campaign_rule_items WHERE campaign_id=NEW.id AND terms_snapshot_id=s AND rule_key='campaign_url' AND knowledge_state='KNOWN') THEN RAISE EXCEPTION 'campaign_url mirror mismatch' USING ERRCODE='23514'; END IF;
  IF NEW.external_campaign_id IS DISTINCT FROM (SELECT typed_value->>'value' FROM campaign_rule_items WHERE campaign_id=NEW.id AND terms_snapshot_id=s AND rule_key='external_campaign_id' AND knowledge_state='KNOWN') THEN RAISE EXCEPTION 'external_campaign_id mirror mismatch' USING ERRCODE='23514'; END IF;
  IF NEW.status IS DISTINCT FROM COALESCE((SELECT (typed_value->>'value')::campaign_status_enum FROM campaign_rule_items WHERE campaign_id=NEW.id AND terms_snapshot_id=s AND rule_key='status' AND knowledge_state='KNOWN'),'UNKNOWN') THEN RAISE EXCEPTION 'campaign status mirror mismatch' USING ERRCODE='23514'; END IF;
  IF NEW.start_at IS DISTINCT FROM (SELECT (typed_value->>'value')::timestamptz FROM campaign_rule_items WHERE campaign_id=NEW.id AND terms_snapshot_id=s AND rule_key='start_at' AND knowledge_state='KNOWN') THEN RAISE EXCEPTION 'campaign start mirror mismatch' USING ERRCODE='23514'; END IF;
  IF NEW.end_at IS DISTINCT FROM (SELECT (typed_value->>'value')::timestamptz FROM campaign_rule_items WHERE campaign_id=NEW.id AND terms_snapshot_id=s AND rule_key='end_at' AND knowledge_state='KNOWN') THEN RAISE EXCEPTION 'campaign end mirror mismatch' USING ERRCODE='23514'; END IF;
  IF NEW.deadline_at IS DISTINCT FROM (SELECT (typed_value->>'value')::timestamptz FROM campaign_rule_items WHERE campaign_id=NEW.id AND terms_snapshot_id=s AND rule_key='deadline_at' AND knowledge_state='KNOWN') THEN RAISE EXCEPTION 'campaign deadline mirror mismatch' USING ERRCODE='23514'; END IF;
  IF NEW.last_verified_at IS DISTINCT FROM (SELECT (typed_value->>'value')::timestamptz FROM campaign_rule_items WHERE campaign_id=NEW.id AND terms_snapshot_id=s AND rule_key='last_verified_at' AND knowledge_state='KNOWN') THEN RAISE EXCEPTION 'campaign verification mirror mismatch' USING ERRCODE='23514'; END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION honor_campaign_mirror_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_campaign_mirror_guard() TO honor_app;
DROP TRIGGER IF EXISTS honor_campaign_mirror_guard_trigger ON campaigns;
CREATE CONSTRAINT TRIGGER honor_campaign_mirror_guard_trigger AFTER INSERT OR UPDATE ON campaigns DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION honor_campaign_mirror_guard();

-- Action-time rights: later evidence can never authorize an earlier action, and the latest committed source-rights version as of T is authoritative (no fallback to an obsolete broader version).
CREATE OR REPLACE FUNCTION honor_current_rights_for_action(p_source_id uuid,p_campaign_id uuid,p_platform platform_enum,p_stage text,p_at timestamptz)
RETURNS uuid LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE rid uuid;
BEGIN
  SELECT r.id INTO rid FROM source_rights r
   WHERE r.source_id=p_source_id AND r.evidence_captured_at<=p_at AND r.committed_at<=p_at
   ORDER BY r.rights_version DESC LIMIT 1;
  IF rid IS NULL THEN RETURN NULL; END IF;
  IF NOT honor_rights_stage_allowed(rid,p_campaign_id,p_platform,p_stage,p_at) THEN RETURN NULL; END IF;
  RETURN rid;
END $$;
REVOKE ALL ON FUNCTION honor_current_rights_for_action(uuid,uuid,platform_enum,text,timestamptz) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_current_rights_for_action(uuid,uuid,platform_enum,text,timestamptz) TO honor_app;

-- Candidate must bind the exact successful transcript used for timing/scoring and committed candidate history is insert-only.
CREATE OR REPLACE FUNCTION honor_candidate_lineage_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE ts transcript_status_enum; src uuid;
BEGIN
  SELECT status,source_id INTO ts,src FROM transcripts WHERE id=NEW.transcript_id;
  IF src IS NULL OR src<>NEW.source_id OR ts<>'SUCCEEDED' THEN RAISE EXCEPTION 'candidate requires successful transcript for same source' USING ERRCODE='23514'; END IF;
  IF (NEW.features->>'start_ms')::bigint<>NEW.start_ms OR (NEW.features->>'end_ms')::bigint<>NEW.end_ms THEN RAISE EXCEPTION 'candidate timing/features mismatch' USING ERRCODE='23514'; END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION honor_candidate_lineage_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_candidate_lineage_guard() TO honor_app;
DROP TRIGGER IF EXISTS honor_candidate_lineage_guard_trigger ON candidates;
CREATE TRIGGER honor_candidate_lineage_guard_trigger BEFORE INSERT ON candidates FOR EACH ROW EXECUTE FUNCTION honor_candidate_lineage_guard();

CREATE OR REPLACE FUNCTION honor_transcript_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE prev_source uuid; prev_version integer;
BEGIN
  IF TG_OP='INSERT' THEN
    IF NEW.status<>'QUEUED' THEN RAISE EXCEPTION 'transcript creation state must be QUEUED' USING ERRCODE='23514'; END IF;
    IF NEW.transcript_version=1 THEN
      IF NEW.supersedes_transcript_id IS NOT NULL THEN RAISE EXCEPTION 'transcript v1 cannot supersede' USING ERRCODE='23514'; END IF;
    ELSE
      SELECT source_id,transcript_version INTO prev_source,prev_version FROM transcripts WHERE id=NEW.supersedes_transcript_id;
      IF prev_source IS NULL OR prev_source<>NEW.source_id OR prev_version<>NEW.transcript_version-1 THEN RAISE EXCEPTION 'transcript predecessor must be same source and version N-1' USING ERRCODE='23514'; END IF;
    END IF;
    IF honor_current_rights_for_action(NEW.source_id,NEW.campaign_id,NULL,'PAID_TRANSCRIPTION',NEW.created_at) IS DISTINCT FROM NEW.rights_id THEN RAISE EXCEPTION 'paid transcript must use latest applicable rights version at action time' USING ERRCODE='23514'; END IF;
  END IF;
  IF TG_OP='UPDATE' THEN
    IF EXISTS(SELECT 1 FROM candidates WHERE transcript_id=OLD.id) AND (NEW.source_id,NEW.campaign_id,NEW.rights_id,NEW.provider,NEW.model,NEW.language,NEW.word_timing_object_key,NEW.speaker_data_object_key,NEW.transcript_sha256,NEW.transcript_version,NEW.supersedes_transcript_id) IS DISTINCT FROM (OLD.source_id,OLD.campaign_id,OLD.rights_id,OLD.provider,OLD.model,OLD.language,OLD.word_timing_object_key,OLD.speaker_data_object_key,OLD.transcript_sha256,OLD.transcript_version,OLD.supersedes_transcript_id) THEN RAISE EXCEPTION 'candidate-consumed transcript identity is immutable' USING ERRCODE='42501'; END IF;
    IF OLD.status='QUEUED' AND NEW.status NOT IN ('RUNNING','FAILED') THEN RAISE EXCEPTION 'invalid transcript transition' USING ERRCODE='23514'; END IF;
    IF OLD.status='RUNNING' AND NEW.status NOT IN ('SUCCEEDED','FAILED') THEN RAISE EXCEPTION 'invalid transcript transition' USING ERRCODE='23514'; END IF;
    IF OLD.status IN ('SUCCEEDED','FAILED') AND NEW.status<>OLD.status THEN RAISE EXCEPTION 'terminal transcript cannot transition; retry creates new version row' USING ERRCODE='23514'; END IF;
  END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION honor_transcript_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_transcript_guard() TO honor_app;
DROP TRIGGER IF EXISTS honor_transcript_guard_trigger ON transcripts;
CREATE TRIGGER honor_transcript_guard_trigger BEFORE INSERT OR UPDATE ON transcripts FOR EACH ROW EXECUTE FUNCTION honor_transcript_guard();

-- Allocation history stores the exact immutable decision inputs used by the learning loop.
CREATE OR REPLACE FUNCTION honor_allocation_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE p platform_enum; region text; followers bigint; healthv account_health_enum; posting boolean; ks knowledge_state_enum; tv jsonb; req jsonb; key text;
BEGIN
  IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'committed allocation history is immutable' USING ERRCODE='42501'; END IF;
  SELECT sa.platform,ahs.account_region,ahs.follower_count,ahs.health,ahs.posting_available INTO p,region,followers,healthv,posting FROM social_accounts sa JOIN account_health_snapshots ahs ON ahs.social_account_id=sa.id WHERE sa.id=NEW.social_account_id AND ahs.id=NEW.account_health_snapshot_id AND ahs.captured_at<=NEW.decision_as_of;
  IF p IS NULL THEN RAISE EXCEPTION 'allocation account snapshot mismatch or from future' USING ERRCODE='23514'; END IF;
  IF honor_current_rights_for_action(NEW.source_id,NEW.campaign_id,p,'COMPENSATED_CAMPAIGN_PRODUCTION',NEW.decision_as_of) IS DISTINCT FROM NEW.rights_id THEN RAISE EXCEPTION 'allocation must use latest applicable rights version at decision time' USING ERRCODE='23514'; END IF;
  -- Critical allocation rules may not be silently treated as unrestricted when UNKNOWN.
  FOREACH key IN ARRAY ARRAY['status','compensation_model','cpm_or_rate','minimum_views','max_payout_per_clip','remaining_budget','start_at','end_at','deadline_at','eligible_platforms','eligible_regions','eligible_account_requirements','source_material_restrictions','uniqueness_rules'] LOOP
    SELECT knowledge_state INTO ks FROM campaign_rule_items WHERE campaign_id=NEW.campaign_id AND terms_snapshot_id=NEW.rule_snapshot_id AND rule_key=key;
    IF ks IS NULL OR ks='UNKNOWN' THEN IF NEW.eligibility_decision<>'UNKNOWN' OR NEW.recommended_clip_count<>0 THEN RAISE EXCEPTION 'UNKNOWN critical allocation rule blocks allocation: %',key USING ERRCODE='23514'; END IF; END IF;
  END LOOP;
  SELECT knowledge_state,typed_value INTO ks,tv FROM campaign_rule_items WHERE campaign_id=NEW.campaign_id AND terms_snapshot_id=NEW.rule_snapshot_id AND rule_key='eligible_platforms';
  IF ks='KNOWN' AND NOT (tv->'value' ? p::text) THEN IF NEW.recommended_clip_count<>0 OR NEW.eligibility_decision='ELIGIBLE' THEN RAISE EXCEPTION 'platform eligibility blocks allocation' USING ERRCODE='23514'; END IF; END IF;
  SELECT knowledge_state,typed_value INTO ks,tv FROM campaign_rule_items WHERE campaign_id=NEW.campaign_id AND terms_snapshot_id=NEW.rule_snapshot_id AND rule_key='eligible_regions';
  IF ks='KNOWN' AND region IS NULL THEN IF NEW.eligibility_decision<>'UNKNOWN' OR NEW.recommended_clip_count<>0 THEN RAISE EXCEPTION 'unknown account region must block allocation' USING ERRCODE='23514'; END IF;
  ELSIF ks='KNOWN' AND NOT (tv->'value' ? region) THEN IF NEW.eligibility_decision<>'INELIGIBLE' OR NEW.recommended_clip_count<>0 THEN RAISE EXCEPTION 'account region not eligible' USING ERRCODE='23514'; END IF; END IF;
  SELECT knowledge_state,typed_value INTO ks,tv FROM campaign_rule_items WHERE campaign_id=NEW.campaign_id AND terms_snapshot_id=NEW.rule_snapshot_id AND rule_key='eligible_account_requirements';
  IF ks='KNOWN' THEN
    req:=tv->'value';
    IF ((req->>'min_followers') IS NOT NULL OR (req->>'max_followers') IS NOT NULL) AND followers IS NULL THEN IF NEW.eligibility_decision<>'UNKNOWN' OR NEW.recommended_clip_count<>0 THEN RAISE EXCEPTION 'missing follower fact must remain UNKNOWN/BLOCKED' USING ERRCODE='23514'; END IF; END IF;
    IF COALESCE((req->>'require_posting_available')::boolean,false) AND posting IS NULL THEN IF NEW.eligibility_decision<>'UNKNOWN' OR NEW.recommended_clip_count<>0 THEN RAISE EXCEPTION 'missing posting-availability fact must remain UNKNOWN/BLOCKED' USING ERRCODE='23514'; END IF; END IF;
    IF followers IS NOT NULL AND (req->>'min_followers') IS NOT NULL AND followers < (req->>'min_followers')::bigint THEN IF NEW.eligibility_decision<>'INELIGIBLE' OR NEW.recommended_clip_count<>0 THEN RAISE EXCEPTION 'minimum follower requirement not met' USING ERRCODE='23514'; END IF; END IF;
    IF followers IS NOT NULL AND (req->>'max_followers') IS NOT NULL AND followers > (req->>'max_followers')::bigint THEN IF NEW.eligibility_decision<>'INELIGIBLE' OR NEW.recommended_clip_count<>0 THEN RAISE EXCEPTION 'maximum follower requirement not met' USING ERRCODE='23514'; END IF; END IF;
    IF COALESCE((req->>'require_posting_available')::boolean,false) AND posting IS FALSE THEN IF NEW.eligibility_decision<>'INELIGIBLE' OR NEW.recommended_clip_count<>0 THEN RAISE EXCEPTION 'posting unavailable' USING ERRCODE='23514'; END IF; END IF;
    IF healthv IS NULL THEN IF NEW.eligibility_decision<>'UNKNOWN' OR NEW.recommended_clip_count<>0 THEN RAISE EXCEPTION 'missing account health fact must remain UNKNOWN/BLOCKED' USING ERRCODE='23514'; END IF;
    ELSIF NOT (req->'allowed_health_states' ? healthv::text) THEN IF NEW.eligibility_decision<>'INELIGIBLE' OR NEW.recommended_clip_count<>0 THEN RAISE EXCEPTION 'account health not eligible' USING ERRCODE='23514'; END IF; END IF;
  END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION honor_allocation_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_allocation_guard() TO honor_app;
DROP TRIGGER IF EXISTS honor_allocation_guard_trigger ON run_campaign_allocations;
CREATE TRIGGER honor_allocation_guard_trigger BEFORE INSERT OR UPDATE OR DELETE ON run_campaign_allocations FOR EACH ROW EXECUTE FUNCTION honor_allocation_guard();

-- Lifecycle creation/transition guards close direct-enum shortcuts. These exact graphs are canonical V1.
CREATE OR REPLACE FUNCTION honor_lifecycle_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE oldv text; newv text; allowed boolean:=false;
BEGIN
  IF TG_TABLE_NAME='earnings' THEN
    IF TG_OP='INSERT' AND NEW.state<>'ACCRUED_UNVERIFIED' THEN RAISE EXCEPTION 'earning creation must be ACCRUED_UNVERIFIED' USING ERRCODE='23514'; END IF; RETURN NEW;
  ELSIF TG_TABLE_NAME='posts' THEN
    IF TG_OP='INSERT' AND NEW.status<>'PUBLISHED' THEN RAISE EXCEPTION 'post creation must be PUBLISHED' USING ERRCODE='23514'; END IF;
    IF TG_OP='UPDATE' AND OLD.status IS DISTINCT FROM NEW.status AND NOT (OLD.status='PUBLISHED' AND NEW.status='INVALIDATED') THEN RAISE EXCEPTION 'invalid post status transition' USING ERRCODE='23514'; END IF; RETURN NEW;
  ELSIF TG_TABLE_NAME='analytics_checkins' THEN oldv:=CASE WHEN TG_OP='UPDATE' THEN OLD.status::text ELSE NULL END; newv:=NEW.status::text;
    IF TG_OP='INSERT' THEN allowed:=newv='PENDING'; ELSE allowed:=(oldv=newv) OR honor_checkin_transition_allowed(OLD.status,NEW.status); END IF;
  ELSIF TG_TABLE_NAME='submissions' THEN oldv:=CASE WHEN TG_OP='UPDATE' THEN OLD.status::text ELSE NULL END; newv:=NEW.status::text;
    IF TG_OP='INSERT' THEN allowed:=newv IN ('PENDING','SUBMITTED','NOT_REQUIRED','UNKNOWN'); ELSE allowed:=(oldv=newv) OR honor_submission_transition_allowed(OLD.status,NEW.status); END IF;
  ELSIF TG_TABLE_NAME='clips' THEN oldv:=CASE WHEN TG_OP='UPDATE' THEN OLD.state::text ELSE NULL END; newv:=NEW.state::text;
    IF TG_OP='INSERT' THEN allowed:=newv='PLANNED'; ELSE allowed:=(oldv=newv) OR (oldv='PLANNED' AND newv IN ('RENDERING','EJECTED')) OR (oldv='RENDERING' AND newv IN ('QC','EJECTED')) OR (oldv='QC' AND newv IN ('READY','EJECTED')) OR (oldv='READY' AND newv IN ('POSTED','ARCHIVED')) OR (oldv='POSTED' AND newv='ARCHIVED'); END IF;
  ELSIF TG_TABLE_NAME='sources' THEN oldv:=CASE WHEN TG_OP='UPDATE' THEN OLD.ingest_status::text ELSE NULL END; newv:=NEW.ingest_status::text;
    IF TG_OP='INSERT' THEN allowed:=newv IN ('PENDING_UPLOAD','QUEUED'); ELSE allowed:=(oldv=newv) OR (oldv='PENDING_UPLOAD' AND newv='QUEUED') OR (oldv='QUEUED' AND newv IN ('INGESTING','BLOCKED_RIGHTS','FAILED')) OR (oldv='INGESTING' AND newv IN ('READY','BLOCKED_RIGHTS','FAILED')) OR (oldv='BLOCKED_RIGHTS' AND newv='QUEUED'); END IF;
  ELSIF TG_TABLE_NAME IN ('jobs','generation_runs') THEN oldv:=CASE WHEN TG_OP='UPDATE' THEN OLD.state::text ELSE NULL END; newv:=NEW.state::text;
    IF TG_OP='INSERT' THEN allowed:=newv='queued'; ELSE allowed:=(oldv=newv) OR (oldv='queued' AND newv IN ('running','cancelled')) OR (oldv='running' AND newv IN ('succeeded','retrying','blocked-owner-action','failed-terminal','cancelled')) OR (oldv='retrying' AND newv IN ('queued','failed-terminal','cancelled')) OR (oldv='blocked-owner-action' AND newv IN ('queued','cancelled')); END IF;
  END IF;
  IF NOT allowed THEN RAISE EXCEPTION 'invalid lifecycle creation/transition for %',TG_TABLE_NAME USING ERRCODE='23514'; END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION honor_lifecycle_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_lifecycle_guard() TO honor_app;
DROP TRIGGER IF EXISTS honor_earning_creation_guard ON earnings; CREATE TRIGGER honor_earning_creation_guard BEFORE INSERT ON earnings FOR EACH ROW EXECUTE FUNCTION honor_lifecycle_guard();
DROP TRIGGER IF EXISTS honor_post_state_guard ON posts; CREATE TRIGGER honor_post_state_guard BEFORE INSERT OR UPDATE OF status ON posts FOR EACH ROW EXECUTE FUNCTION honor_lifecycle_guard();
DROP TRIGGER IF EXISTS honor_checkin_state_guard ON analytics_checkins; CREATE TRIGGER honor_checkin_state_guard BEFORE INSERT OR UPDATE OF status ON analytics_checkins FOR EACH ROW EXECUTE FUNCTION honor_lifecycle_guard();
DROP TRIGGER IF EXISTS honor_submission_state_guard ON submissions; CREATE TRIGGER honor_submission_state_guard BEFORE INSERT OR UPDATE OF status ON submissions FOR EACH ROW EXECUTE FUNCTION honor_lifecycle_guard();
DROP TRIGGER IF EXISTS honor_clip_state_guard ON clips; CREATE TRIGGER honor_clip_state_guard BEFORE INSERT OR UPDATE OF state ON clips FOR EACH ROW EXECUTE FUNCTION honor_lifecycle_guard();
DROP TRIGGER IF EXISTS honor_source_ingest_state_guard ON sources; CREATE TRIGGER honor_source_ingest_state_guard BEFORE INSERT OR UPDATE OF ingest_status ON sources FOR EACH ROW EXECUTE FUNCTION honor_lifecycle_guard();
DROP TRIGGER IF EXISTS honor_job_state_guard ON jobs; CREATE TRIGGER honor_job_state_guard BEFORE INSERT OR UPDATE OF state ON jobs FOR EACH ROW EXECUTE FUNCTION honor_lifecycle_guard();
DROP TRIGGER IF EXISTS honor_generation_run_state_guard ON generation_runs; CREATE TRIGGER honor_generation_run_state_guard BEFORE INSERT OR UPDATE OF state ON generation_runs FOR EACH ROW EXECUTE FUNCTION honor_lifecycle_guard();

-- Generation decision history: inputs immutable at creation; selected_plan is write-once; terminal history cannot be rewritten.
CREATE OR REPLACE FUNCTION honor_generation_run_history_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
BEGIN
  IF TG_OP='UPDATE' THEN
    IF NEW.budget_snapshot IS DISTINCT FROM OLD.budget_snapshot OR NEW.requested_constraints IS DISTINCT FROM OLD.requested_constraints OR NEW.strategy_version IS DISTINCT FROM OLD.strategy_version OR NEW.target_date IS DISTINCT FROM OLD.target_date OR NEW.requested_by IS DISTINCT FROM OLD.requested_by THEN RAISE EXCEPTION 'generation run creation inputs are immutable' USING ERRCODE='42501'; END IF;
    IF OLD.selected_plan IS NOT NULL AND NEW.selected_plan IS DISTINCT FROM OLD.selected_plan THEN RAISE EXCEPTION 'generation selected_plan is write-once' USING ERRCODE='42501'; END IF;
    IF OLD.completed_at IS NOT NULL AND (NEW.completed_at,NEW.selected_plan) IS DISTINCT FROM (OLD.completed_at,OLD.selected_plan) THEN RAISE EXCEPTION 'completed run decision history is immutable' USING ERRCODE='42501'; END IF;
  END IF; RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION honor_generation_run_history_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_generation_run_history_guard() TO honor_app;
DROP TRIGGER IF EXISTS honor_generation_run_history_guard_trigger ON generation_runs;
CREATE TRIGGER honor_generation_run_history_guard_trigger BEFORE UPDATE ON generation_runs FOR EACH ROW EXECUTE FUNCTION honor_generation_run_history_guard();

-- Minimal experiment assignments are immutable; exposed_at may be populated once. Arms lock when experiment starts.
CREATE OR REPLACE FUNCTION honor_experiment_history_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE valid boolean:=false;
BEGIN
  IF TG_TABLE_NAME='experiments' THEN
    IF TG_OP='INSERT' AND NEW.status<>'DRAFT' THEN RAISE EXCEPTION 'experiment creation must be DRAFT' USING ERRCODE='23514'; END IF;
    IF TG_OP='UPDATE' AND NEW.status IS DISTINCT FROM OLD.status THEN
      valid := (OLD.status='DRAFT' AND NEW.status IN ('RUNNING','CANCELLED')) OR (OLD.status='RUNNING' AND NEW.status IN ('STOPPED','COMPLETED','CANCELLED')) OR (OLD.status='STOPPED' AND NEW.status='COMPLETED');
      IF NOT valid THEN RAISE EXCEPTION 'invalid experiment status transition' USING ERRCODE='23514'; END IF;
    END IF;
    IF TG_OP='UPDATE' AND OLD.status IN ('COMPLETED','CANCELLED') AND NEW IS DISTINCT FROM OLD THEN RAISE EXCEPTION 'terminal experiment is immutable' USING ERRCODE='42501'; END IF;
  ELSIF TG_TABLE_NAME='experiment_assignments' THEN
    IF TG_OP='INSERT' THEN
      IF NOT EXISTS(SELECT 1 FROM experiment_arms a WHERE a.id=NEW.arm_id AND a.experiment_id=NEW.experiment_id) THEN RAISE EXCEPTION 'experiment arm/assignment mismatch' USING ERRCODE='23514'; END IF;
      IF NEW.unit_type='GENERATION_RUN' AND NOT EXISTS(SELECT 1 FROM generation_runs WHERE id=NEW.unit_id) THEN RAISE EXCEPTION 'unknown experiment generation unit' USING ERRCODE='23514'; END IF;
      IF NEW.unit_type='SOCIAL_ACCOUNT' AND NOT EXISTS(SELECT 1 FROM social_accounts WHERE id=NEW.unit_id) THEN RAISE EXCEPTION 'unknown experiment account unit' USING ERRCODE='23514'; END IF;
      IF NEW.unit_type='CLIP' AND NOT EXISTS(SELECT 1 FROM clips WHERE id=NEW.unit_id) THEN RAISE EXCEPTION 'unknown experiment clip unit' USING ERRCODE='23514'; END IF;
    ELSIF TG_OP='UPDATE' THEN
      IF NEW.experiment_id<>OLD.experiment_id OR NEW.arm_id<>OLD.arm_id OR NEW.unit_type<>OLD.unit_type OR NEW.unit_id<>OLD.unit_id OR NEW.assigned_at<>OLD.assigned_at OR OLD.exposed_at IS NOT NULL OR NEW.exposed_at IS NULL THEN RAISE EXCEPTION 'experiment assignment immutable after exposure/identity insert' USING ERRCODE='42501'; END IF;
    ELSE RAISE EXCEPTION 'experiment assignment history cannot be deleted' USING ERRCODE='42501'; END IF;
  ELSIF TG_TABLE_NAME='experiment_arms' AND TG_OP<>'INSERT' THEN
    IF EXISTS(SELECT 1 FROM experiments e WHERE e.id=OLD.experiment_id AND e.status<>'DRAFT') THEN RAISE EXCEPTION 'experiment arms immutable after experiment starts' USING ERRCODE='42501'; END IF;
    IF TG_OP='DELETE' THEN RAISE EXCEPTION 'experiment arm history cannot be deleted' USING ERRCODE='42501'; END IF;
  END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION honor_experiment_history_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_experiment_history_guard() TO honor_app;
DROP TRIGGER IF EXISTS honor_experiment_status_guard ON experiments; CREATE TRIGGER honor_experiment_status_guard BEFORE INSERT OR UPDATE ON experiments FOR EACH ROW EXECUTE FUNCTION honor_experiment_history_guard();
DROP TRIGGER IF EXISTS honor_experiment_assignment_guard ON experiment_assignments; CREATE TRIGGER honor_experiment_assignment_guard BEFORE INSERT OR UPDATE OR DELETE ON experiment_assignments FOR EACH ROW EXECUTE FUNCTION honor_experiment_history_guard();
DROP TRIGGER IF EXISTS honor_experiment_arm_guard ON experiment_arms; CREATE TRIGGER honor_experiment_arm_guard BEFORE UPDATE OR DELETE ON experiment_arms FOR EACH ROW EXECUTE FUNCTION honor_experiment_history_guard();

-- Rights/posting/media exactness: source attribution and most restrictive duration must survive into the owner snapshot and READY QC path.
-- honor_clip_cross_record_guard additionally requires native recommendation platform == posting platform == social account platform and latest applicable rights at clip creation.
-- honor_clip_ready_guard additionally enforces duration <= source-rights platform max and campaign clip-length max, duration >= campaign clip-length min, and blocks UNKNOWN critical media restrictions.
-- Required attribution text must equal source_rights.authorized_uses.required_attribution, source_attribution.required=true, and the exact attribution string must occur in posting_recommendation.caption.

-- ---------- DELETE POLICY ----------
-- No public API exposes hard delete. Parent FKs use ON DELETE RESTRICT deliberately.
-- Data retention/deletion, if later required, needs an approved change/migration and audited maintenance procedure.


-- ---------- ROUND-5 CROSS-RECORD FREEZE NOTES ----------
-- Sole expiration authority: source_rights.expires_at. At timestamp T, authorization is expired iff expires_at IS NOT NULL AND T >= expires_at. authorized_uses MUST NOT contain an expiration field; RightsEvidenceInput.expires_at maps exactly to source_rights.expires_at. eligibility UNKNOWN remains UNKNOWN and never grants permission.
-- Clip source of truth for manual posting is clips.posting_recommendation (clip.posting_recommendation.v1). caption_copy/title_copy/hashtags are derived mirrors overwritten atomically by honor_clip_cross_record_guard; they are never independent authorities.
-- posting_recommendation may be revised only before POSTED/ARCHIVED and before any posts row exists. After that, the exact recommendation on the clip is immutable and reconstructs the historical owner instruction snapshot.
-- Accepted-render provenance freeze: once render_manifests contains a row for a clip, and certainly at READY/POSTED/ARCHIVED, material provenance/output identity fields cannot change in place. Corrections require a new clip/render lineage.
-- Composite FKs plus honor_clip_cross_record_guard prohibit cross-source rights, rights/campaign mismatch, cross-campaign rule snapshots, edit-plan/candidate/source/run mismatch, and cross-edit-plan audio plans.
-- Version guards plus UNIQUE(supersedes_*) enforce same-chain N-1 predecessor identity, no skipping, and no forking for source_rights/edit_plans/audio_plans.

-- ---------- ROUND-6 DOWNSTREAM LINEAGE FREEZE NOTES ----------
-- Campaign current terms: campaigns(terms_snapshot_id,id) -> campaign_terms_snapshots(id,campaign_id). Campaign-rule evidence uses the same same-campaign composite FK.
-- Posts: composite FKs bind post clip/account and account/platform; honor_post_publish_guard additionally binds posting-recommendation platform/native-audio platform and atomically records manual publication only from READY while moving the clip READY -> POSTED in the same transaction. API idempotency + posts.idempotency_key UNIQUE makes retries converge on the same historical record.
-- Submissions: honor_submission_lineage_guard requires submissions.campaign_id = posts.clip.campaign_id.
-- Analytics: analytics_observations(checkin_id,post_id) -> analytics_checkins(id,post_id), so a check-in can never complete another post's observation.
-- Earnings: evidence snapshot uses same-campaign composite FK; honor_earning_lineage_guard binds optional post to the same campaign. honor_transition_earning is the only runtime state mutation path and atomically inserts the immutable transition + updates current state/last_state_at using the exact pre-state and amount snapshot.
-- Rights applicability: honor_app has no direct INSERT on source_rights/source_rights_campaigns. honor_commit_source_rights_version inserts a brand-new contiguous rights version plus its complete campaign applicability set in one transaction. Existing committed rights versions cannot gain later runtime campaign associations.
-- Authorized-use matrix is machine-frozen in HONOR_RIGHTS_STAGE_MATRIX.json and honor_rights_stage_allowed(). False/UNKNOWN never grants permission. Campaign clips require commercial_use=true and derivative_edits=true in addition to edit/render/publish permissions and platform allowance.
-- Scheduling: a non-null recommended_publish_at must be strictly before rights expiration, campaign end, and campaign deadline, not before campaign start, and all start/end/deadline rules for the frozen rule snapshot must be KNOWN or NOT_APPLICABLE. At rights expires_at exactly, authorization is expired and recommendation is rejected.
-- Native audio: when a clip has an audio plan, the posting snapshot native_audio_recommendation must be JSON-identical to audio_plans.platform_native_recommendation; UNKNOWN/PROHIBITED campaign rule states cannot be escalated. A RECOMMENDED status requires a committed audio plan. Platform-native audio is never baked into the render.


-- ---------- ROUND-7 FREEZE NOTES ----------
-- Campaign truth: campaign_terms_snapshots.id is the exact immutable rule-set identity. campaign_rule_items are append-only and unique per (campaign, snapshot, key, schema_version). KNOWN requires typed value + attributable same-campaign evidence + verified_at; NOT_APPLICABLE requires null value + evidence + verified_at; UNKNOWN requires null typed_value.
-- Campaign scalar mirror authority: provider/campaign_url/external_campaign_id/status/start_at/end_at/deadline_at/last_verified_at are current-query mirrors refreshed only by honor_activate_campaign_rule_snapshot(); historical decisions use their immutable rule_snapshot_id, never mutable campaign scalar columns.
-- Campaign rules: HONOR_CAMPAIGN_RULE_REGISTRY.json contains exactly the 32 canonical keys and exact key-specific typed-value schemas/units/consumers/blocking semantics. HONOR_CAMPAIGN_RULE_CONSUMPTION.json is the stage-consumption authority.
-- Account eligibility facts: account_health_snapshots.account_region/follower_count/posting_available are nullable authoritative facts at captured_at; NULL means UNKNOWN and blocks any requirement that needs the missing fact.
-- Rights temporal authority: an action at T requires evidence_captured_at<=T, committed_at<=T, applicability created_at<=T, not expired at T. honor_current_rights_for_action selects the newest source rights version as-of T first, then checks applicability/stage; it NEVER falls back to an older broader version when the newest version narrows/revokes rights.
-- Candidate/transcript history: each candidate pins one SUCCEEDED same-source transcript_id and is immutable after insertion. Materially different retry/transcription creates a new transcript version/row; old candidates never move.
-- Generation history: budget_snapshot/requested_constraints are immutable creation inputs; selected_plan is write-once; committed allocations are immutable and pin rule_snapshot_id, rights_id, account_health_snapshot_id, decision_as_of, analysis/rules/model versions.
-- Analytics semantics: watch_time_ms is TOTAL cumulative watch time. average_watch_duration_ms, completed_views, completion_rate_ppm, follower_delta are optional/null when provider evidence does not supply them; zero is never substituted for unavailable metrics.
-- Experiments: experiments/arms/assignments implement the minimal V1 experiment persistence contract in HONOR_EXPERIMENT_CONTRACT.json. Assignment identity is immutable; causal language requires experiment evidence, otherwise Polli labels correlation as MODEL_ANALYSIS.
-- Lifecycle creation is guarded: earnings=ACCRUED_UNVERIFIED only; posts=PUBLISHED only; analytics_checkins=PENDING only; submissions only canonical creation set; clips=PLANNED only; sources=PENDING_UPLOAD|QUEUED only; jobs/generation_runs=queued only. Later transitions must follow the frozen graph/functions.

-- Round-6 timing compatibility assertion: recommended publish time blocked by UNKNOWN/absent timing rule. Exact keys: ('start_at'),('end_at'),('deadline_at'). Round-7 enforcement reads typed values from terms_snapshot_id, not campaigns scalar mirrors.

-- ---------- ROUND-7 CANONICAL FUNCTION PRIVILEGE DISPOSITION ----------
-- Duplicate REVOKE/GRANT statements are intentional contract assertions; PostgreSQL privilege statements are idempotent.
REVOKE ALL ON FUNCTION honor_submission_transition_allowed(submission_status_enum, submission_status_enum) FROM PUBLIC;
REVOKE ALL ON FUNCTION honor_checkin_transition_allowed(checkin_status_enum, checkin_status_enum) FROM PUBLIC;
REVOKE ALL ON FUNCTION honor_owner_authorized() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_owner_authorized() TO honor_app;
REVOKE ALL ON FUNCTION honor_commit_source_rights_version(uuid, uuid, integer, uuid, source_eligibility_enum, jsonb, jsonb, text, text, text, timestamptz, timestamptz, text, text, uuid[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_commit_source_rights_version(uuid, uuid, integer, uuid, source_eligibility_enum, jsonb, jsonb, text, text, text, timestamptz, timestamptz, text, text, uuid[]) TO honor_app;
REVOKE ALL ON FUNCTION honor_rights_stage_allowed(uuid, uuid, platform_enum, text, timestamptz) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_rights_stage_allowed(uuid, uuid, platform_enum, text, timestamptz) TO honor_app;
REVOKE ALL ON FUNCTION honor_post_publish_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_post_publish_guard() TO honor_app;
REVOKE ALL ON FUNCTION honor_submission_lineage_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_submission_lineage_guard() TO honor_app;
REVOKE ALL ON FUNCTION honor_earning_lineage_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_earning_lineage_guard() TO honor_app;
REVOKE ALL ON FUNCTION honor_transition_earning(uuid, earning_state_enum, timestamptz, text, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_transition_earning(uuid, earning_state_enum, timestamptz, text, text, text, text) TO honor_app;
REVOKE ALL ON FUNCTION honor_source_rights_version_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_source_rights_version_guard() TO honor_app;
REVOKE ALL ON FUNCTION honor_edit_plan_version_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_edit_plan_version_guard() TO honor_app;
REVOKE ALL ON FUNCTION honor_audio_plan_version_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_audio_plan_version_guard() TO honor_app;
REVOKE ALL ON FUNCTION honor_clip_cross_record_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_clip_cross_record_guard() TO honor_app;
REVOKE ALL ON FUNCTION honor_clip_provenance_lock_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_clip_provenance_lock_guard() TO honor_app;
REVOKE ALL ON FUNCTION honor_reject_immutable_mutation() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_reject_immutable_mutation() TO honor_app;
REVOKE ALL ON FUNCTION honor_render_manifest_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_render_manifest_guard() TO honor_app;
REVOKE ALL ON FUNCTION honor_clip_ready_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_clip_ready_guard() TO honor_app;
REVOKE ALL ON FUNCTION honor_campaign_rule_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_campaign_rule_guard() TO honor_app;
REVOKE ALL ON FUNCTION honor_activate_campaign_rule_snapshot(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_activate_campaign_rule_snapshot(uuid, uuid) TO honor_app;
REVOKE ALL ON FUNCTION honor_campaign_mirror_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_campaign_mirror_guard() TO honor_app;
REVOKE ALL ON FUNCTION honor_current_rights_for_action(uuid, uuid, platform_enum, text, timestamptz) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_current_rights_for_action(uuid, uuid, platform_enum, text, timestamptz) TO honor_app;
REVOKE ALL ON FUNCTION honor_candidate_lineage_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_candidate_lineage_guard() TO honor_app;
REVOKE ALL ON FUNCTION honor_transcript_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_transcript_guard() TO honor_app;
REVOKE ALL ON FUNCTION honor_allocation_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_allocation_guard() TO honor_app;
REVOKE ALL ON FUNCTION honor_lifecycle_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_lifecycle_guard() TO honor_app;
REVOKE ALL ON FUNCTION honor_generation_run_history_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_generation_run_history_guard() TO honor_app;
REVOKE ALL ON FUNCTION honor_experiment_history_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_experiment_history_guard() TO honor_app;
-- ---------- END ROUND-7 CANONICAL FUNCTION PRIVILEGE DISPOSITION ----------

-- ---------- ROUND-8 RULE-SET SEAL / DB-AUTHORITATIVE ACTION TIME / RESTRICTION / EXPERIMENT FREEZE ----------
-- This section is normative and replaces any less restrictive Round-7 behavior above where the same function is CREATE OR REPLACE'd.
-- pgcrypto is migration-owned and used only to compute the immutable normalized rule-set SHA-256.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE campaign_rule_set_commits (
  campaign_id uuid NOT NULL REFERENCES campaigns(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  terms_snapshot_id uuid NOT NULL,
  schema_version integer NOT NULL DEFAULT 1 CHECK (schema_version=1),
  rule_count integer NOT NULL CHECK (rule_count=32),
  rules_sha256 char(64) NOT NULL CHECK (rules_sha256 ~ '^[a-f0-9]{64}$'),
  committed_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(campaign_id,terms_snapshot_id,schema_version),
  CONSTRAINT fk_rule_set_commit_snapshot FOREIGN KEY (terms_snapshot_id,campaign_id) REFERENCES campaign_terms_snapshots(id,campaign_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CHECK (created_at=committed_at)
);
CREATE INDEX idx_campaign_rule_set_commits_time ON campaign_rule_set_commits(campaign_id,committed_at DESC);


-- Internal HONOR action clocks are never caller-authoritative. External factual timestamps remain supplied only where explicitly frozen (rights/terms evidence capture, actual published_at, analytics observed_at).
CREATE OR REPLACE FUNCTION honor_internal_action_time_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE t timestamptz:=statement_timestamp();
BEGIN
  IF TG_OP<>'INSERT' THEN RETURN NEW; END IF;
  IF TG_TABLE_NAME='campaign_terms_snapshots' THEN NEW.created_at:=t;
  ELSIF TG_TABLE_NAME='transcripts' THEN NEW.created_at:=t; NEW.updated_at:=t;
  ELSIF TG_TABLE_NAME='run_campaign_allocations' THEN NEW.decision_as_of:=t; NEW.created_at:=t;
  ELSIF TG_TABLE_NAME='edit_plans' THEN NEW.committed_at:=t; NEW.created_at:=t;
  ELSIF TG_TABLE_NAME='audio_plans' THEN NEW.committed_at:=t; NEW.created_at:=t;
  ELSIF TG_TABLE_NAME='clips' THEN NEW.created_at:=t; NEW.updated_at:=t;
  ELSIF TG_TABLE_NAME='render_manifests' THEN NEW.created_at:=t;
  ELSIF TG_TABLE_NAME='submissions' THEN NEW.created_at:=t; NEW.updated_at:=t;
  ELSIF TG_TABLE_NAME='earnings' THEN NEW.created_at:=t; NEW.updated_at:=t;
  END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION honor_internal_action_time_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_internal_action_time_guard() TO honor_app;
DROP TRIGGER IF EXISTS honor_action_time_campaign_terms_snapshot_trigger ON campaign_terms_snapshots;
CREATE TRIGGER honor_action_time_campaign_terms_snapshot_trigger BEFORE INSERT ON campaign_terms_snapshots FOR EACH ROW EXECUTE FUNCTION honor_internal_action_time_guard();
DROP TRIGGER IF EXISTS honor_action_time_transcript_trigger ON transcripts;
CREATE TRIGGER honor_action_time_transcript_trigger BEFORE INSERT ON transcripts FOR EACH ROW EXECUTE FUNCTION honor_internal_action_time_guard();
DROP TRIGGER IF EXISTS honor_action_time_allocation_trigger ON run_campaign_allocations;
CREATE TRIGGER honor_action_time_allocation_trigger BEFORE INSERT ON run_campaign_allocations FOR EACH ROW EXECUTE FUNCTION honor_internal_action_time_guard();
DROP TRIGGER IF EXISTS honor_action_time_edit_plan_trigger ON edit_plans;
CREATE TRIGGER honor_action_time_edit_plan_trigger BEFORE INSERT ON edit_plans FOR EACH ROW EXECUTE FUNCTION honor_internal_action_time_guard();
DROP TRIGGER IF EXISTS honor_action_time_audio_plan_trigger ON audio_plans;
CREATE TRIGGER honor_action_time_audio_plan_trigger BEFORE INSERT ON audio_plans FOR EACH ROW EXECUTE FUNCTION honor_internal_action_time_guard();
DROP TRIGGER IF EXISTS honor_action_time_clip_trigger ON clips;
CREATE TRIGGER honor_action_time_clip_trigger BEFORE INSERT ON clips FOR EACH ROW EXECUTE FUNCTION honor_internal_action_time_guard();
DROP TRIGGER IF EXISTS honor_action_time_render_manifest_trigger ON render_manifests;
CREATE TRIGGER honor_action_time_render_manifest_trigger BEFORE INSERT ON render_manifests FOR EACH ROW EXECUTE FUNCTION honor_internal_action_time_guard();
DROP TRIGGER IF EXISTS honor_action_time_submission_trigger ON submissions;
CREATE TRIGGER honor_action_time_submission_trigger BEFORE INSERT ON submissions FOR EACH ROW EXECUTE FUNCTION honor_internal_action_time_guard();
DROP TRIGGER IF EXISTS honor_action_time_earning_trigger ON earnings;
CREATE TRIGGER honor_action_time_earning_trigger BEFORE INSERT ON earnings FOR EACH ROW EXECUTE FUNCTION honor_internal_action_time_guard();

CREATE OR REPLACE FUNCTION honor_rule_set_sealed_for_action(p_campaign_id uuid,p_snapshot_id uuid,p_schema_version integer,p_action_at timestamptz)
RETURNS boolean LANGUAGE sql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
  SELECT EXISTS(
    SELECT 1 FROM campaign_rule_set_commits c
    WHERE c.campaign_id=p_campaign_id AND c.terms_snapshot_id=p_snapshot_id AND c.schema_version=p_schema_version
      AND c.rule_count=32 AND c.committed_at<=p_action_at
  );
$$;
REVOKE ALL ON FUNCTION honor_rule_set_sealed_for_action(uuid, uuid, integer, timestamptz) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_rule_set_sealed_for_action(uuid, uuid, integer, timestamptz) TO honor_app;

-- Rule rows are assemblable before seal, but become append-closed at seal. Evidence chronology is validated at row insertion and again at seal.
CREATE OR REPLACE FUNCTION honor_campaign_rule_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE expected_type text; ecaptured timestamptz; ecreated timestamptz;
BEGIN
  IF TG_OP<>'INSERT' THEN RAISE EXCEPTION 'campaign rule snapshots are immutable' USING ERRCODE='42501'; END IF;
  IF EXISTS(SELECT 1 FROM campaign_rule_set_commits c WHERE c.campaign_id=NEW.campaign_id AND c.terms_snapshot_id=NEW.terms_snapshot_id AND c.schema_version=NEW.schema_version) THEN
    RAISE EXCEPTION 'sealed campaign rule set is append-closed' USING ERRCODE='42501';
  END IF;
  IF NEW.knowledge_state='KNOWN' AND (NEW.typed_value IS NULL OR NEW.evidence_snapshot_id IS NULL OR NEW.verified_at IS NULL) THEN RAISE EXCEPTION 'KNOWN rule requires typed value, evidence, verification timestamp' USING ERRCODE='23514'; END IF;
  IF NEW.knowledge_state='NOT_APPLICABLE' AND (NEW.typed_value IS NOT NULL OR NEW.evidence_snapshot_id IS NULL OR NEW.verified_at IS NULL) THEN RAISE EXCEPTION 'NOT_APPLICABLE requires null value plus evidence/timestamp' USING ERRCODE='23514'; END IF;
  IF NEW.knowledge_state='UNKNOWN' AND NEW.typed_value IS NOT NULL THEN RAISE EXCEPTION 'UNKNOWN rule must have null typed value' USING ERRCODE='23514'; END IF;
  IF NEW.knowledge_state IN ('KNOWN','NOT_APPLICABLE') THEN
    SELECT captured_at,created_at INTO ecaptured,ecreated FROM campaign_terms_snapshots WHERE id=NEW.evidence_snapshot_id AND campaign_id=NEW.campaign_id;
    IF ecaptured IS NULL OR ecaptured>NEW.verified_at OR ecreated>NEW.verified_at THEN RAISE EXCEPTION 'campaign evidence must be captured and recorded no later than rule verification' USING ERRCODE='23514'; END IF;
    IF NEW.verified_at>statement_timestamp() THEN RAISE EXCEPTION 'campaign rule may not claim verification from the future' USING ERRCODE='23514'; END IF;
  END IF;
  expected_type := CASE NEW.rule_key
    WHEN 'provider' THEN 'STRING' WHEN 'campaign_url' THEN 'STRING' WHEN 'external_campaign_id' THEN 'STRING'
    WHEN 'status' THEN 'CAMPAIGN_STATUS' WHEN 'compensation_model' THEN 'COMPENSATION_MODEL' WHEN 'cpm_or_rate' THEN 'RATE'
    WHEN 'minimum_views' THEN 'INTEGER' WHEN 'max_payout_per_clip' THEN 'MONEY_USD' WHEN 'total_budget' THEN 'MONEY_USD' WHEN 'remaining_budget' THEN 'MONEY_USD'
    WHEN 'start_at' THEN 'TIMESTAMP' WHEN 'end_at' THEN 'TIMESTAMP' WHEN 'deadline_at' THEN 'TIMESTAMP'
    WHEN 'eligible_platforms' THEN 'PLATFORMS' WHEN 'eligible_regions' THEN 'REGIONS' WHEN 'eligible_account_requirements' THEN 'ACCOUNT_REQUIREMENTS'
    WHEN 'required_tags' THEN 'STRING_ARRAY' WHEN 'required_mentions' THEN 'STRING_ARRAY' WHEN 'required_hashtags' THEN 'STRING_ARRAY'
    WHEN 'disclosure_requirements' THEN 'DISCLOSURE_REQUIREMENTS' WHEN 'source_material_restrictions' THEN 'RESTRICTION_SET'
    WHEN 'clip_length_min_seconds' THEN 'DURATION_SECONDS' WHEN 'clip_length_max_seconds' THEN 'DURATION_SECONDS'
    WHEN 'content_restrictions' THEN 'RESTRICTION_SET' WHEN 'editing_restrictions' THEN 'RESTRICTION_SET' WHEN 'uniqueness_rules' THEN 'RESTRICTION_SET'
    WHEN 'submission_format' THEN 'SUBMISSION_FORMAT' WHEN 'analytics_window' THEN 'WINDOW' WHEN 'payout_window' THEN 'WINDOW'
    WHEN 'render_audio_rules' THEN 'RENDER_AUDIO_RULES' WHEN 'platform_native_audio_rules' THEN 'PLATFORM_NATIVE_AUDIO_RULES' WHEN 'last_verified_at' THEN 'TIMESTAMP'
    ELSE NULL END;
  IF expected_type IS NULL THEN RAISE EXCEPTION 'non-canonical campaign rule key' USING ERRCODE='23514'; END IF;
  IF NEW.knowledge_state='KNOWN' AND NEW.typed_value->>'value_type' IS DISTINCT FROM expected_type THEN RAISE EXCEPTION 'campaign rule typed value type mismatch' USING ERRCODE='23514'; END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION honor_campaign_rule_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_campaign_rule_guard() TO honor_app;

CREATE OR REPLACE FUNCTION honor_seal_campaign_rule_set(p_campaign_id uuid,p_snapshot_id uuid,p_schema_version integer)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_catalog AS $$
DECLARE t timestamptz:=statement_timestamp(); cnt integer; h text; canon jsonb; minsec numeric; maxsec numeric; startv timestamptz; endv timestamptz; totalv numeric; remainv numeric; minfollowers bigint; maxfollowers bigint; bad_clause boolean;
BEGIN
  IF NOT honor_owner_authorized() THEN RAISE EXCEPTION 'owner context required' USING ERRCODE='42501'; END IF;
  IF p_schema_version<>1 THEN RAISE EXCEPTION 'unsupported campaign rule schema version' USING ERRCODE='23514'; END IF;
  IF NOT EXISTS(SELECT 1 FROM campaign_terms_snapshots WHERE id=p_snapshot_id AND campaign_id=p_campaign_id AND created_at<=t) THEN RAISE EXCEPTION 'snapshot/campaign mismatch or future snapshot record' USING ERRCODE='23514'; END IF;
  IF EXISTS(SELECT 1 FROM campaign_rule_set_commits WHERE campaign_id=p_campaign_id AND terms_snapshot_id=p_snapshot_id AND schema_version=p_schema_version) THEN RAISE EXCEPTION 'campaign rule set already sealed' USING ERRCODE='23505'; END IF;
  SELECT count(*) INTO cnt FROM campaign_rule_items WHERE campaign_id=p_campaign_id AND terms_snapshot_id=p_snapshot_id AND schema_version=p_schema_version;
  IF cnt<>32 THEN RAISE EXCEPTION 'rule-set seal requires exactly 32 canonical normalized rules' USING ERRCODE='23514'; END IF;
  IF EXISTS(
    SELECT 1 FROM campaign_rule_items r LEFT JOIN campaign_terms_snapshots e ON e.id=r.evidence_snapshot_id AND e.campaign_id=r.campaign_id
    WHERE r.campaign_id=p_campaign_id AND r.terms_snapshot_id=p_snapshot_id AND r.schema_version=p_schema_version
      AND r.knowledge_state IN ('KNOWN','NOT_APPLICABLE')
      AND (r.verified_at IS NULL OR r.verified_at>t OR e.id IS NULL OR e.captured_at>r.verified_at OR e.created_at>r.verified_at)
  ) THEN RAISE EXCEPTION 'rule verification/evidence chronology invalid at seal' USING ERRCODE='23514'; END IF;
  -- exact restriction code/effect/scope combinations are frozen; any provider nuance outside them remains UNKNOWN instead of being force-fit.
  SELECT EXISTS(
    SELECT 1 FROM campaign_rule_items r, LATERAL jsonb_array_elements(r.typed_value->'value'->'clauses') c
    WHERE r.campaign_id=p_campaign_id AND r.terms_snapshot_id=p_snapshot_id AND r.knowledge_state='KNOWN'
      AND r.rule_key IN ('source_material_restrictions','content_restrictions','editing_restrictions','uniqueness_rules')
      AND NOT (
        (c->>'code'='CAMPAIGN_AUTHORIZED_SOURCE_ONLY' AND c->>'effect'='REQUIRE' AND c->>'scope'='SOURCE') OR
        (c->>'code'='OWNER_OWNED_SOURCE_ONLY' AND c->>'effect'='REQUIRE' AND c->>'scope'='SOURCE') OR
        (c->>'code'='NO_THIRD_PARTY_SOURCE' AND c->>'effect'='PROHIBIT' AND c->>'scope'='SOURCE') OR
        (c->>'code'='NO_PROFANITY' AND c->>'effect'='PROHIBIT' AND c->>'scope'='CONTENT') OR
        (c->>'code'='BRAND_SAFE_ONLY' AND c->>'effect'='REQUIRE' AND c->>'scope'='CONTENT') OR
        (c->>'code'='NO_MISLEADING_CLAIMS' AND c->>'effect'='PROHIBIT' AND c->>'scope'='CONTENT') OR
        (c->>'code'='NO_CROP' AND c->>'effect'='PROHIBIT' AND c->>'scope'='EDIT') OR
        (c->>'code'='NO_SPEED_CHANGE' AND c->>'effect'='PROHIBIT' AND c->>'scope'='EDIT') OR
        (c->>'code'='NO_TEXT_OVERLAY' AND c->>'effect'='PROHIBIT' AND c->>'scope'='EDIT') OR
        (c->>'code'='NO_REUSED_EDIT' AND c->>'effect'='PROHIBIT' AND c->>'scope'='UNIQUENESS') OR
        (c->>'code'='UNIQUE_PER_ACCOUNT' AND c->>'effect'='REQUIRE' AND c->>'scope'='UNIQUENESS') OR
        (c->>'code'='UNIQUE_PER_CAMPAIGN' AND c->>'effect'='REQUIRE' AND c->>'scope'='UNIQUENESS')
      )
  ) INTO bad_clause;
  IF bad_clause THEN RAISE EXCEPTION 'restriction clause is not exactly representable by frozen V1 semantics' USING ERRCODE='23514'; END IF;
  SELECT CASE WHEN knowledge_state='KNOWN' THEN (typed_value->>'value')::numeric END INTO minsec FROM campaign_rule_items WHERE campaign_id=p_campaign_id AND terms_snapshot_id=p_snapshot_id AND rule_key='clip_length_min_seconds';
  SELECT CASE WHEN knowledge_state='KNOWN' THEN (typed_value->>'value')::numeric END INTO maxsec FROM campaign_rule_items WHERE campaign_id=p_campaign_id AND terms_snapshot_id=p_snapshot_id AND rule_key='clip_length_max_seconds';
  IF minsec IS NOT NULL AND maxsec IS NOT NULL AND minsec>maxsec THEN RAISE EXCEPTION 'clip length min exceeds max' USING ERRCODE='23514'; END IF;
  SELECT CASE WHEN knowledge_state='KNOWN' THEN (typed_value->>'value')::timestamptz END INTO startv FROM campaign_rule_items WHERE campaign_id=p_campaign_id AND terms_snapshot_id=p_snapshot_id AND rule_key='start_at';
  SELECT CASE WHEN knowledge_state='KNOWN' THEN (typed_value->>'value')::timestamptz END INTO endv FROM campaign_rule_items WHERE campaign_id=p_campaign_id AND terms_snapshot_id=p_snapshot_id AND rule_key='end_at';
  IF startv IS NOT NULL AND endv IS NOT NULL AND startv>=endv THEN RAISE EXCEPTION 'campaign start must be before end' USING ERRCODE='23514'; END IF;
  SELECT CASE WHEN knowledge_state='KNOWN' THEN (typed_value->>'value')::numeric END INTO totalv FROM campaign_rule_items WHERE campaign_id=p_campaign_id AND terms_snapshot_id=p_snapshot_id AND rule_key='total_budget';
  SELECT CASE WHEN knowledge_state='KNOWN' THEN (typed_value->>'value')::numeric END INTO remainv FROM campaign_rule_items WHERE campaign_id=p_campaign_id AND terms_snapshot_id=p_snapshot_id AND rule_key='remaining_budget';
  IF totalv IS NOT NULL AND remainv IS NOT NULL AND remainv>totalv THEN RAISE EXCEPTION 'remaining budget exceeds total budget' USING ERRCODE='23514'; END IF;
  SELECT CASE WHEN knowledge_state='KNOWN' THEN NULLIF(typed_value->'value'->>'min_followers','')::bigint END, CASE WHEN knowledge_state='KNOWN' THEN NULLIF(typed_value->'value'->>'max_followers','')::bigint END INTO minfollowers,maxfollowers FROM campaign_rule_items WHERE campaign_id=p_campaign_id AND terms_snapshot_id=p_snapshot_id AND rule_key='eligible_account_requirements';
  IF minfollowers IS NOT NULL AND maxfollowers IS NOT NULL AND minfollowers>maxfollowers THEN RAISE EXCEPTION 'eligible account min_followers exceeds max_followers' USING ERRCODE='23514'; END IF;
  SELECT jsonb_agg(jsonb_build_object('rule_key',rule_key,'knowledge_state',knowledge_state::text,'typed_value',typed_value,'evidence_snapshot_id',evidence_snapshot_id,'evidence_locator',evidence_locator,'verified_at',verified_at,'verified_by',verified_by::text,'schema_version',schema_version) ORDER BY rule_key)
    INTO canon FROM campaign_rule_items WHERE campaign_id=p_campaign_id AND terms_snapshot_id=p_snapshot_id AND schema_version=p_schema_version;
  h:=encode(digest(convert_to(canon::text,'UTF8'),'sha256'),'hex');
  INSERT INTO campaign_rule_set_commits(campaign_id,terms_snapshot_id,schema_version,rule_count,rules_sha256,committed_at,created_at)
    VALUES(p_campaign_id,p_snapshot_id,p_schema_version,32,h,t,t);
  RETURN h;
END $$;
REVOKE ALL ON FUNCTION honor_seal_campaign_rule_set(uuid, uuid, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_seal_campaign_rule_set(uuid, uuid, integer) TO honor_app;

DROP TRIGGER IF EXISTS honor_immutable_campaign_rule_set_commits ON campaign_rule_set_commits;
CREATE TRIGGER honor_immutable_campaign_rule_set_commits BEFORE UPDATE OR DELETE ON campaign_rule_set_commits FOR EACH ROW EXECUTE FUNCTION honor_reject_immutable_mutation();

-- Activation can only advance to a newly captured/reverified sealed set; an older superseded snapshot can never be silently made current again.
CREATE OR REPLACE FUNCTION honor_activate_campaign_rule_snapshot(p_campaign_id uuid,p_snapshot_id uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_catalog AS $$
DECLARE new_commit timestamptz; old_commit timestamptz; new_capture timestamptz; old_capture timestamptz; old_snapshot uuid; ks knowledge_state_enum; tv jsonb;
BEGIN
  IF NOT honor_owner_authorized() THEN RAISE EXCEPTION 'owner context required' USING ERRCODE='42501'; END IF;
  SELECT c.committed_at,t.captured_at INTO new_commit,new_capture FROM campaign_rule_set_commits c JOIN campaign_terms_snapshots t ON t.id=c.terms_snapshot_id AND t.campaign_id=c.campaign_id WHERE c.campaign_id=p_campaign_id AND c.terms_snapshot_id=p_snapshot_id AND c.schema_version=1;
  IF new_commit IS NULL OR new_commit>statement_timestamp() THEN RAISE EXCEPTION 'current campaign activation requires an already sealed rule set' USING ERRCODE='23514'; END IF;
  SELECT terms_snapshot_id INTO old_snapshot FROM campaigns WHERE id=p_campaign_id FOR UPDATE;
  IF old_snapshot IS NOT NULL AND old_snapshot<>p_snapshot_id THEN
    SELECT c.committed_at,t.captured_at INTO old_commit,old_capture FROM campaign_rule_set_commits c JOIN campaign_terms_snapshots t ON t.id=c.terms_snapshot_id AND t.campaign_id=c.campaign_id WHERE c.campaign_id=p_campaign_id AND c.terms_snapshot_id=old_snapshot AND c.schema_version=1;
    IF old_commit IS NOT NULL AND (new_commit<=old_commit OR new_capture<=old_capture) THEN RAISE EXCEPTION 'superseded campaign rule snapshot cannot be reactivated; reversion requires a new later snapshot/seal' USING ERRCODE='23514'; END IF;
  END IF;
  SELECT knowledge_state,typed_value INTO ks,tv FROM campaign_rule_items WHERE campaign_id=p_campaign_id AND terms_snapshot_id=p_snapshot_id AND rule_key='provider';
  IF ks IS DISTINCT FROM 'KNOWN' THEN RAISE EXCEPTION 'provider must be KNOWN before activating a current campaign rule snapshot' USING ERRCODE='23514'; END IF;
  UPDATE campaigns c SET
    terms_snapshot_id=p_snapshot_id,
    provider=(SELECT typed_value->>'value' FROM campaign_rule_items WHERE campaign_id=p_campaign_id AND terms_snapshot_id=p_snapshot_id AND rule_key='provider' AND knowledge_state='KNOWN'),
    campaign_url=(SELECT typed_value->>'value' FROM campaign_rule_items WHERE campaign_id=p_campaign_id AND terms_snapshot_id=p_snapshot_id AND rule_key='campaign_url' AND knowledge_state='KNOWN'),
    external_campaign_id=(SELECT typed_value->>'value' FROM campaign_rule_items WHERE campaign_id=p_campaign_id AND terms_snapshot_id=p_snapshot_id AND rule_key='external_campaign_id' AND knowledge_state='KNOWN'),
    status=COALESCE((SELECT (typed_value->>'value')::campaign_status_enum FROM campaign_rule_items WHERE campaign_id=p_campaign_id AND terms_snapshot_id=p_snapshot_id AND rule_key='status' AND knowledge_state='KNOWN'),'UNKNOWN'),
    start_at=(SELECT (typed_value->>'value')::timestamptz FROM campaign_rule_items WHERE campaign_id=p_campaign_id AND terms_snapshot_id=p_snapshot_id AND rule_key='start_at' AND knowledge_state='KNOWN'),
    end_at=(SELECT (typed_value->>'value')::timestamptz FROM campaign_rule_items WHERE campaign_id=p_campaign_id AND terms_snapshot_id=p_snapshot_id AND rule_key='end_at' AND knowledge_state='KNOWN'),
    deadline_at=(SELECT (typed_value->>'value')::timestamptz FROM campaign_rule_items WHERE campaign_id=p_campaign_id AND terms_snapshot_id=p_snapshot_id AND rule_key='deadline_at' AND knowledge_state='KNOWN'),
    last_verified_at=(SELECT (typed_value->>'value')::timestamptz FROM campaign_rule_items WHERE campaign_id=p_campaign_id AND terms_snapshot_id=p_snapshot_id AND rule_key='last_verified_at' AND knowledge_state='KNOWN'),
    updated_at=statement_timestamp()
  WHERE c.id=p_campaign_id;
  RETURN p_snapshot_id;
END $$;
REVOKE ALL ON FUNCTION honor_activate_campaign_rule_snapshot(uuid,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_activate_campaign_rule_snapshot(uuid,uuid) TO honor_app;

-- Every historical campaign decision/action must point to a rule set sealed no later than its DB-authoritative action time.
CREATE OR REPLACE FUNCTION honor_rule_set_consumption_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE camp uuid; snap uuid; at_time timestamptz;
BEGIN
  IF TG_TABLE_NAME='run_campaign_allocations' THEN camp:=NEW.campaign_id; snap:=NEW.rule_snapshot_id; at_time:=NEW.decision_as_of;
  ELSIF TG_TABLE_NAME='edit_plans' THEN
    SELECT t.campaign_id,(NEW.plan_json->'campaign_rule_snapshot_ids'->>0)::uuid INTO camp,snap FROM campaign_terms_snapshots t WHERE t.id=(NEW.plan_json->'campaign_rule_snapshot_ids'->>0)::uuid; at_time:=NEW.committed_at;
    IF EXISTS(
      SELECT 1 FROM jsonb_array_elements_text(NEW.plan_json->'campaign_rule_snapshot_ids') x(id_text)
      LEFT JOIN campaign_terms_snapshots t ON t.id=x.id_text::uuid
      WHERE t.id IS NULL OR t.campaign_id IS DISTINCT FROM camp OR NOT honor_rule_set_sealed_for_action(t.campaign_id,t.id,1,NEW.committed_at)
    ) THEN RAISE EXCEPTION 'every edit-plan campaign rule snapshot must exist and be sealed before edit commit' USING ERRCODE='23514'; END IF;
  ELSIF TG_TABLE_NAME='audio_plans' THEN SELECT t.campaign_id,(ep.plan_json->'campaign_rule_snapshot_ids'->>0)::uuid INTO camp,snap FROM edit_plans ep JOIN campaign_terms_snapshots t ON t.id=(ep.plan_json->'campaign_rule_snapshot_ids'->>0)::uuid WHERE ep.id=NEW.edit_plan_id; at_time:=NEW.committed_at;
  ELSIF TG_TABLE_NAME='clips' THEN camp:=NEW.campaign_id; snap:=NEW.rule_snapshot_id; at_time:=NEW.created_at;
  ELSIF TG_TABLE_NAME='posts' THEN SELECT c.campaign_id,c.rule_snapshot_id,c.created_at INTO camp,snap,at_time FROM clips c WHERE c.id=NEW.clip_id;
  ELSIF TG_TABLE_NAME='submissions' THEN SELECT c.campaign_id,c.rule_snapshot_id,NEW.created_at INTO camp,snap,at_time FROM posts p JOIN clips c ON c.id=p.clip_id WHERE p.id=NEW.post_id;
  ELSIF TG_TABLE_NAME='earnings' THEN camp:=NEW.campaign_id; snap:=NEW.rule_snapshot_id; at_time:=NEW.created_at;
  END IF;
  IF camp IS NULL OR snap IS NULL OR at_time IS NULL OR NOT honor_rule_set_sealed_for_action(camp,snap,1,at_time) THEN RAISE EXCEPTION 'historical campaign decision/action requires sealed complete rule set committed no later than action time' USING ERRCODE='23514'; END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION honor_rule_set_consumption_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_rule_set_consumption_guard() TO honor_app;
DROP TRIGGER IF EXISTS honor_sealed_rules_allocation_trigger ON run_campaign_allocations; CREATE TRIGGER honor_sealed_rules_allocation_trigger BEFORE INSERT ON run_campaign_allocations FOR EACH ROW EXECUTE FUNCTION honor_rule_set_consumption_guard();
DROP TRIGGER IF EXISTS honor_sealed_rules_edit_trigger ON edit_plans; CREATE TRIGGER honor_sealed_rules_edit_trigger BEFORE INSERT ON edit_plans FOR EACH ROW EXECUTE FUNCTION honor_rule_set_consumption_guard();
DROP TRIGGER IF EXISTS honor_sealed_rules_audio_trigger ON audio_plans; CREATE TRIGGER honor_sealed_rules_audio_trigger BEFORE INSERT ON audio_plans FOR EACH ROW EXECUTE FUNCTION honor_rule_set_consumption_guard();
DROP TRIGGER IF EXISTS honor_sealed_rules_clip_trigger ON clips; CREATE TRIGGER honor_sealed_rules_clip_trigger BEFORE INSERT ON clips FOR EACH ROW EXECUTE FUNCTION honor_rule_set_consumption_guard();
DROP TRIGGER IF EXISTS honor_sealed_rules_post_trigger ON posts; CREATE TRIGGER honor_sealed_rules_post_trigger BEFORE INSERT ON posts FOR EACH ROW EXECUTE FUNCTION honor_rule_set_consumption_guard();
DROP TRIGGER IF EXISTS honor_sealed_rules_submission_trigger ON submissions; CREATE TRIGGER honor_sealed_rules_submission_trigger BEFORE INSERT ON submissions FOR EACH ROW EXECUTE FUNCTION honor_rule_set_consumption_guard();
DROP TRIGGER IF EXISTS honor_sealed_rules_earning_trigger ON earnings; CREATE TRIGGER honor_sealed_rules_earning_trigger BEFORE INSERT ON earnings FOR EACH ROW EXECUTE FUNCTION honor_rule_set_consumption_guard();

-- Frozen restriction semantics are consumed from structured edit-plan proof; campaign rules override default HONOR editing behavior.
CREATE OR REPLACE FUNCTION honor_restriction_compliance_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE camp uuid; snap uuid; src uuid; clause jsonb; proof jsonb; code text; effect text; scope text;
BEGIN
  SELECT c.source_id,t.campaign_id,(NEW.plan_json->'campaign_rule_snapshot_ids'->>0)::uuid INTO src,camp,snap FROM candidates c JOIN campaign_terms_snapshots t ON t.id=(NEW.plan_json->'campaign_rule_snapshot_ids'->>0)::uuid WHERE c.id=NEW.candidate_id;
  FOR clause IN
    SELECT c FROM campaign_rule_items r, LATERAL jsonb_array_elements(r.typed_value->'value'->'clauses') c
    WHERE r.campaign_id=camp AND r.terms_snapshot_id=snap AND r.knowledge_state='KNOWN' AND r.rule_key IN ('source_material_restrictions','content_restrictions','editing_restrictions','uniqueness_rules')
  LOOP
    code:=clause->>'code'; effect:=clause->>'effect'; scope:=clause->>'scope';
    SELECT x INTO proof FROM jsonb_array_elements(NEW.plan_json->'restriction_compliance') x WHERE x->>'code'=code AND x->>'effect'=effect AND x->>'scope'=scope AND x->>'result'='COMPLIANT' LIMIT 1;
    IF proof IS NULL THEN RAISE EXCEPTION 'restriction compliance missing/UNKNOWN/failed for %',code USING ERRCODE='23514'; END IF;
    IF code='CAMPAIGN_AUTHORIZED_SOURCE_ONLY' AND NOT EXISTS(SELECT 1 FROM sources s JOIN source_rights r ON r.source_id=s.id JOIN source_rights_campaigns rc ON rc.source_rights_id=r.id AND rc.campaign_id=camp WHERE s.id=src AND s.origin_type='CAMPAIGN_AUTHORIZED') THEN RAISE EXCEPTION 'campaign-authorized-source-only restriction failed' USING ERRCODE='23514'; END IF;
    IF code='OWNER_OWNED_SOURCE_ONLY' AND NOT EXISTS(SELECT 1 FROM sources WHERE id=src AND origin_type='OWNER_OWNED') THEN RAISE EXCEPTION 'owner-owned-source-only restriction failed' USING ERRCODE='23514'; END IF;
    IF code='NO_THIRD_PARTY_SOURCE' AND NOT EXISTS(SELECT 1 FROM sources WHERE id=src AND origin_type IN ('CAMPAIGN_AUTHORIZED','OWNER_OWNED')) THEN RAISE EXCEPTION 'no-third-party-source restriction failed' USING ERRCODE='23514'; END IF;
    IF code='NO_CROP' AND ((NEW.plan_json->'layout'->>'reframing_mode')<>'FIT_NO_CROP' OR jsonb_array_length(NEW.plan_json->'layout'->'punch_ins')<>0 OR EXISTS(SELECT 1 FROM jsonb_array_elements(NEW.plan_json->'layout'->'events') e WHERE (e->>'scale')::numeric<>1 OR (e->>'pan_x')::numeric<>0 OR (e->>'pan_y')::numeric<>0)) THEN RAISE EXCEPTION 'NO_CROP forbids crop/reframe/pan/zoom/punch-in' USING ERRCODE='23514'; END IF;
    IF code='NO_SPEED_CHANGE' AND EXISTS(SELECT 1 FROM jsonb_array_elements(NEW.plan_json->'timeline'->'cuts') c WHERE (c->>'playback_rate')::numeric<>1) THEN RAISE EXCEPTION 'NO_SPEED_CHANGE forbids playback-rate manipulation' USING ERRCODE='23514'; END IF;
    IF code='NO_TEXT_OVERLAY' AND ((NEW.plan_json->'captions'->>'enabled')::boolean OR jsonb_array_length(NEW.plan_json->'captions'->'chunks')<>0 OR jsonb_array_length(NEW.plan_json->'disclosure_render'->'overlay_events')<>0) THEN RAISE EXCEPTION 'NO_TEXT_OVERLAY includes burned captions and disclosure overlays' USING ERRCODE='23514'; END IF;
  END LOOP;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION honor_restriction_compliance_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_restriction_compliance_guard() TO honor_app;
DROP TRIGGER IF EXISTS honor_restriction_compliance_edit_trigger ON edit_plans;
CREATE TRIGGER honor_restriction_compliance_edit_trigger BEFORE INSERT ON edit_plans FOR EACH ROW EXECUTE FUNCTION honor_restriction_compliance_guard();

-- Render-audio inner states mechanically govern the plan; UNKNOWN never grants use.
CREATE OR REPLACE FUNCTION honor_audio_rule_enforcement_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE camp uuid; snap uuid; ks knowledge_state_enum; tv jsonb; v jsonb; master text; music text; sfx text; maxd text; rank_actual integer; rank_max integer; music_allowed boolean; sfx_allowed boolean; instructions jsonb;
BEGIN
  SELECT t.campaign_id,(ep.plan_json->'campaign_rule_snapshot_ids'->>0)::uuid INTO camp,snap FROM edit_plans ep JOIN campaign_terms_snapshots t ON t.id=(ep.plan_json->'campaign_rule_snapshot_ids'->>0)::uuid WHERE ep.id=NEW.edit_plan_id;
  SELECT knowledge_state,typed_value INTO ks,tv FROM campaign_rule_items WHERE campaign_id=camp AND terms_snapshot_id=snap AND rule_key='render_audio_rules';
  IF ks='UNKNOWN' OR ks IS NULL THEN RAISE EXCEPTION 'UNKNOWN render_audio_rules blocks paid audio planning' USING ERRCODE='23514'; END IF;
  IF ks='NOT_APPLICABLE' THEN
    IF NEW.music_asset_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM audio_assets WHERE id=NEW.music_asset_id AND kind='MUSIC' AND render_safe=true AND active=true) THEN RAISE EXCEPTION 'music asset must be active render-safe MUSIC' USING ERRCODE='23514'; END IF;
    IF EXISTS(SELECT 1 FROM jsonb_array_elements(NEW.sfx_events) e WHERE e->>'asset_id' IS NOT NULL AND NOT EXISTS(SELECT 1 FROM audio_assets a WHERE a.id=(e->>'asset_id')::uuid AND a.kind='SFX' AND a.render_safe=true AND a.active=true)) THEN RAISE EXCEPTION 'SFX asset must be active render-safe SFX' USING ERRCODE='23514'; END IF;
    IF NEW.rule_compliance->>'rule_state'<>'NOT_APPLICABLE' OR NEW.rule_compliance->>'rule_snapshot_id'<>snap::text
       OR NEW.rule_compliance->>'render_safe_audio'<>'NOT_APPLICABLE' OR NEW.rule_compliance->>'music_allowed'<>'NOT_APPLICABLE' OR NEW.rule_compliance->>'sfx_allowed'<>'NOT_APPLICABLE'
       OR NEW.rule_compliance->'max_sfx_density'<>'null'::jsonb OR NEW.rule_compliance->'instructions'<>'[]'::jsonb
       OR NEW.rule_compliance->>'effective_density'<>NEW.density::text
       OR NEW.rule_compliance->>'music_asset_id' IS DISTINCT FROM CASE WHEN NEW.music_asset_id IS NULL THEN NULL ELSE NEW.music_asset_id::text END
       OR (NEW.rule_compliance->>'sfx_event_count')::integer<>jsonb_array_length(NEW.sfx_events)
       OR COALESCE((NEW.rule_compliance->>'compliant')::boolean,false) IS NOT TRUE
    THEN RAISE EXCEPTION 'audio-plan compliance evidence must exactly bind NOT_APPLICABLE rule snapshot and actual plan' USING ERRCODE='23514'; END IF;
    RETURN NEW;
  END IF;
  v:=tv->'value'; master:=v->>'render_safe_audio'; music:=v->>'music_allowed'; sfx:=v->>'sfx_allowed'; maxd:=v->>'max_sfx_density'; instructions:=v->'instructions';
  music_allowed := (master<>'UNKNOWN') AND ((master='ALLOWED' AND music IN ('ALLOWED','NOT_APPLICABLE')) OR (master='PROHIBITED' AND music='ALLOWED'));
  sfx_allowed := (master<>'UNKNOWN') AND ((master='ALLOWED' AND sfx IN ('ALLOWED','NOT_APPLICABLE')) OR (master='PROHIBITED' AND sfx='ALLOWED'));
  IF music IN ('PROHIBITED','UNKNOWN') THEN music_allowed:=false; END IF;
  IF sfx IN ('PROHIBITED','UNKNOWN') THEN sfx_allowed:=false; END IF;
  IF NOT music_allowed AND NEW.music_asset_id IS NOT NULL THEN RAISE EXCEPTION 'render audio rule forbids/unverifies music asset' USING ERRCODE='23514'; END IF;
  IF NOT sfx_allowed AND (jsonb_array_length(NEW.sfx_events)<>0 OR NEW.density<>'NONE') THEN RAISE EXCEPTION 'render audio rule forbids/unverifies SFX; events empty and density NONE required' USING ERRCODE='23514'; END IF;
  IF sfx_allowed AND maxd='NONE' AND (jsonb_array_length(NEW.sfx_events)<>0 OR NEW.density<>'NONE') THEN RAISE EXCEPTION 'max_sfx_density NONE forbids SFX' USING ERRCODE='23514'; END IF;
  IF sfx_allowed AND sfx='ALLOWED' AND maxd IS NULL THEN RAISE EXCEPTION 'ALLOWED SFX requires explicit max_sfx_density' USING ERRCODE='23514'; END IF;
  rank_actual:=CASE NEW.density WHEN 'NONE' THEN 0 WHEN 'LOW' THEN 1 WHEN 'MEDIUM' THEN 2 WHEN 'HIGH' THEN 3 END;
  rank_max:=CASE maxd WHEN 'NONE' THEN 0 WHEN 'LOW' THEN 1 WHEN 'MEDIUM' THEN 2 WHEN 'HIGH' THEN 3 ELSE 3 END;
  IF sfx_allowed AND rank_actual>rank_max THEN RAISE EXCEPTION 'audio-plan density exceeds frozen max_sfx_density' USING ERRCODE='23514'; END IF;
  IF NEW.music_asset_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM audio_assets WHERE id=NEW.music_asset_id AND kind='MUSIC' AND render_safe=true AND active=true) THEN RAISE EXCEPTION 'music asset must be active render-safe MUSIC' USING ERRCODE='23514'; END IF;
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(NEW.sfx_events) e WHERE e->>'asset_id' IS NOT NULL AND NOT EXISTS(SELECT 1 FROM audio_assets a WHERE a.id=(e->>'asset_id')::uuid AND a.kind='SFX' AND a.render_safe=true AND a.active=true)) THEN RAISE EXCEPTION 'SFX asset must be active render-safe SFX' USING ERRCODE='23514'; END IF;
  IF NEW.rule_compliance->>'rule_snapshot_id'<>snap::text OR NEW.rule_compliance->>'rule_state'<>'KNOWN' OR NEW.rule_compliance->>'render_safe_audio'<>master OR NEW.rule_compliance->>'music_allowed'<>music OR NEW.rule_compliance->>'sfx_allowed'<>sfx OR NEW.rule_compliance->'max_sfx_density' IS DISTINCT FROM v->'max_sfx_density' OR NEW.rule_compliance->'instructions' IS DISTINCT FROM instructions OR NEW.rule_compliance->>'effective_density'<>NEW.density::text OR NEW.rule_compliance->>'music_asset_id' IS DISTINCT FROM CASE WHEN NEW.music_asset_id IS NULL THEN NULL ELSE NEW.music_asset_id::text END OR (NEW.rule_compliance->>'sfx_event_count')::integer<>jsonb_array_length(NEW.sfx_events) OR COALESCE((NEW.rule_compliance->>'compliant')::boolean,false) IS NOT TRUE THEN RAISE EXCEPTION 'audio-plan rule compliance evidence does not mirror frozen rule/plan' USING ERRCODE='23514'; END IF;
  IF jsonb_array_length(instructions)>0 AND COALESCE((NEW.rule_compliance->>'instructions_acknowledged')::boolean,false) IS NOT TRUE THEN RAISE EXCEPTION 'operational render-audio instructions must be acknowledged' USING ERRCODE='23514'; END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION honor_audio_rule_enforcement_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_audio_rule_enforcement_guard() TO honor_app;
DROP TRIGGER IF EXISTS honor_audio_rule_enforcement_trigger ON audio_plans;
CREATE TRIGGER honor_audio_rule_enforcement_trigger BEFORE INSERT ON audio_plans FOR EACH ROW EXECUTE FUNCTION honor_audio_rule_enforcement_guard();

-- Disclosure placement and the V1 submission deadline mirror are preserved at clip recommendation creation.
CREATE OR REPLACE FUNCTION honor_disclosure_deadline_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE ks knowledge_state_enum; tv jsonb; req jsonb; placement text; deadline timestamptz; ep jsonb; has_no_text boolean;
BEGIN
  SELECT knowledge_state,typed_value INTO ks,tv FROM campaign_rule_items WHERE campaign_id=NEW.campaign_id AND terms_snapshot_id=NEW.rule_snapshot_id AND rule_key='disclosure_requirements';
  IF ks='UNKNOWN' OR ks IS NULL THEN RAISE EXCEPTION 'UNKNOWN disclosure placement blocks posting recommendation' USING ERRCODE='23514'; END IF;
  IF ks='NOT_APPLICABLE' THEN
    IF COALESCE((NEW.posting_recommendation->'disclosure'->>'required')::boolean,false) OR NEW.posting_recommendation->'disclosure'->'placement'<>'null'::jsonb THEN RAISE EXCEPTION 'NOT_APPLICABLE disclosure must remain absent' USING ERRCODE='23514'; END IF;
  ELSE
    req:=tv->'value'; placement:=req->>'placement';
    IF NEW.posting_recommendation->'disclosure'->'required' IS DISTINCT FROM req->'required' OR NEW.posting_recommendation->'disclosure'->'text' IS DISTINCT FROM req->'text' OR NEW.posting_recommendation->'disclosure'->'instructions' IS DISTINCT FROM req->'instructions' OR NEW.posting_recommendation->'disclosure'->'placement' IS DISTINCT FROM req->'placement' THEN RAISE EXCEPTION 'posting disclosure including placement must exactly mirror frozen campaign rule' USING ERRCODE='23514'; END IF;
    IF COALESCE((req->>'required')::boolean,false) AND placement IN ('CAPTION','BOTH') THEN
      IF req->>'text' IS NULL OR position(req->>'text' in NEW.posting_recommendation->>'caption')=0 THEN RAISE EXCEPTION 'CAPTION/BOTH disclosure requires exact disclosure text in owner caption copy' USING ERRCODE='23514'; END IF;
    END IF;
    SELECT plan_json INTO ep FROM edit_plans WHERE id=NEW.edit_plan_id;
    IF COALESCE((req->>'required')::boolean,false) AND placement IN ('VIDEO','BOTH') THEN
      SELECT EXISTS(SELECT 1 FROM campaign_rule_items r,LATERAL jsonb_array_elements(r.typed_value->'value'->'clauses') c WHERE r.campaign_id=NEW.campaign_id AND r.terms_snapshot_id=NEW.rule_snapshot_id AND r.knowledge_state='KNOWN' AND r.rule_key IN ('editing_restrictions','content_restrictions') AND c->>'code'='NO_TEXT_OVERLAY') INTO has_no_text;
      IF has_no_text THEN RAISE EXCEPTION 'VIDEO/BOTH disclosure conflicts with NO_TEXT_OVERLAY; production must block' USING ERRCODE='23514'; END IF;
      IF ep->'disclosure_render'->'required' IS DISTINCT FROM 'true'::jsonb OR ep->'disclosure_render'->>'placement' IS DISTINCT FROM placement OR ep->'disclosure_render'->'text' IS DISTINCT FROM req->'text' OR ep->'disclosure_render'->'instructions' IS DISTINCT FROM req->'instructions' OR jsonb_array_length(ep->'disclosure_render'->'overlay_events')=0 THEN RAISE EXCEPTION 'VIDEO/BOTH disclosure must be represented in edit-plan render path' USING ERRCODE='23514'; END IF;
    END IF;
    IF COALESCE((req->>'required')::boolean,false) AND placement='PROVIDER_SUBMISSION' THEN
      IF NEW.posting_recommendation->'submission_requirements'->'provider_disclosure'->'required' IS DISTINCT FROM 'true'::jsonb OR NEW.posting_recommendation->'submission_requirements'->'provider_disclosure'->'text' IS DISTINCT FROM req->'text' OR NEW.posting_recommendation->'submission_requirements'->'provider_disclosure'->'instructions' IS DISTINCT FROM req->'instructions' THEN RAISE EXCEPTION 'provider-submission disclosure missing from submission requirements' USING ERRCODE='23514'; END IF;
    END IF;
  END IF;
  SELECT knowledge_state,CASE WHEN knowledge_state='KNOWN' THEN (typed_value->>'value')::timestamptz ELSE NULL END INTO ks,deadline FROM campaign_rule_items WHERE campaign_id=NEW.campaign_id AND terms_snapshot_id=NEW.rule_snapshot_id AND rule_key='deadline_at';
  IF ks='UNKNOWN' OR ks IS NULL THEN RAISE EXCEPTION 'UNKNOWN critical submission deadline blocks recommendation' USING ERRCODE='23514'; END IF;
  IF ks='KNOWN' AND (NEW.posting_recommendation->'submission_requirements'->>'deadline_at')::timestamptz IS DISTINCT FROM deadline THEN RAISE EXCEPTION 'posting submission deadline must equal sealed campaign deadline_at' USING ERRCODE='23514'; END IF;
  IF ks='NOT_APPLICABLE' AND NEW.posting_recommendation->'submission_requirements'->'deadline_at'<>'null'::jsonb THEN RAISE EXCEPTION 'NOT_APPLICABLE campaign deadline requires null submission deadline' USING ERRCODE='23514'; END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION honor_disclosure_deadline_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_disclosure_deadline_guard() TO honor_app;
DROP TRIGGER IF EXISTS honor_disclosure_deadline_clip_trigger ON clips;
CREATE TRIGGER honor_disclosure_deadline_clip_trigger BEFORE INSERT OR UPDATE OF posting_recommendation,edit_plan_id,rule_snapshot_id ON clips FOR EACH ROW EXECUTE FUNCTION honor_disclosure_deadline_guard();

-- Before paid render cost begins, re-evaluate current RENDER rights and exact sealed-rule/uniqueness authority at DB transaction time.
CREATE OR REPLACE FUNCTION honor_clip_render_start_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE p platform_enum; sig text; code text;
BEGIN
  IF TG_OP='UPDATE' AND OLD.state='PLANNED' AND NEW.state='RENDERING' THEN
    SELECT platform INTO p FROM social_accounts WHERE id=NEW.social_account_id;
    IF honor_current_rights_for_action(NEW.source_id,NEW.campaign_id,p,'RENDER',statement_timestamp()) IS DISTINCT FROM NEW.rights_id THEN RAISE EXCEPTION 'PLANNED -> RENDERING blocked by superseding/revoked RENDER rights before cost' USING ERRCODE='23514'; END IF;
    IF NOT honor_rule_set_sealed_for_action(NEW.campaign_id,NEW.rule_snapshot_id,1,statement_timestamp()) THEN RAISE EXCEPTION 'render start requires sealed rule set' USING ERRCODE='23514'; END IF;
    NEW.render_started_at:=statement_timestamp();
    SELECT plan_json->'output'->>'edit_signature_sha256' INTO sig FROM edit_plans WHERE id=NEW.edit_plan_id;
    FOR code IN SELECT c->>'code' FROM campaign_rule_items r,LATERAL jsonb_array_elements(r.typed_value->'value'->'clauses') c WHERE r.campaign_id=NEW.campaign_id AND r.terms_snapshot_id=NEW.rule_snapshot_id AND r.knowledge_state='KNOWN' AND r.rule_key='uniqueness_rules' LOOP
      IF code='NO_REUSED_EDIT' OR code='UNIQUE_PER_CAMPAIGN' THEN
        IF EXISTS(SELECT 1 FROM clips x JOIN edit_plans ep ON ep.id=x.edit_plan_id WHERE x.id<>NEW.id AND x.campaign_id=NEW.campaign_id AND x.state IN ('READY','POSTED','ARCHIVED') AND ep.plan_json->'output'->>'edit_signature_sha256'=sig) THEN RAISE EXCEPTION 'campaign uniqueness restriction blocks reused edit signature' USING ERRCODE='23514'; END IF;
      ELSIF code='UNIQUE_PER_ACCOUNT' THEN
        IF EXISTS(SELECT 1 FROM clips x JOIN edit_plans ep ON ep.id=x.edit_plan_id WHERE x.id<>NEW.id AND x.social_account_id=NEW.social_account_id AND x.state IN ('READY','POSTED','ARCHIVED') AND ep.plan_json->'output'->>'edit_signature_sha256'=sig) THEN RAISE EXCEPTION 'account uniqueness restriction blocks reused edit signature' USING ERRCODE='23514'; END IF;
      END IF;
    END LOOP;
  ELSIF TG_OP='UPDATE' AND OLD.render_started_at IS NOT NULL AND NEW.render_started_at IS DISTINCT FROM OLD.render_started_at THEN
    RAISE EXCEPTION 'render_started_at is DB-authoritative and immutable once set' USING ERRCODE='42501';
  END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION honor_clip_render_start_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_clip_render_start_guard() TO honor_app;
DROP TRIGGER IF EXISTS honor_clip_render_start_guard_trigger ON clips;
CREATE TRIGGER honor_clip_render_start_guard_trigger BEFORE UPDATE OF state,render_started_at ON clips FOR EACH ROW EXECUTE FUNCTION honor_clip_render_start_guard();

-- Manifest/QC must verify the exact audio plan assets and rendered VIDEO/BOTH disclosure.
CREATE OR REPLACE FUNCTION honor_render_audio_disclosure_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE ap audio_plans%ROWTYPE; c clips%ROWTYPE; q qc_runs%ROWTYPE; expected_music uuid; expected_sfx uuid[]; manifest_ids uuid[]; manifest_music uuid[]; manifest_sfx uuid[]; dr jsonb;
BEGIN
  SELECT * INTO c FROM clips WHERE id=NEW.clip_id;
  SELECT * INTO q FROM qc_runs WHERE id=NEW.qc_run_id AND clip_id=NEW.clip_id;
  IF c.audio_plan_id IS NOT NULL THEN
    SELECT * INTO ap FROM audio_plans WHERE id=c.audio_plan_id;
    expected_music:=ap.music_asset_id;
    SELECT COALESCE(array_agg(DISTINCT (e->>'asset_id')::uuid) FILTER (WHERE e->>'asset_id' IS NOT NULL),ARRAY[]::uuid[]) INTO expected_sfx FROM jsonb_array_elements(ap.sfx_events) e;
    SELECT COALESCE(array_agg((a->>'audio_asset_id')::uuid) FILTER (WHERE a->>'kind'='MUSIC'),ARRAY[]::uuid[]),COALESCE(array_agg((a->>'audio_asset_id')::uuid) FILTER (WHERE a->>'kind'='SFX'),ARRAY[]::uuid[]) INTO manifest_music,manifest_sfx FROM jsonb_array_elements(NEW.manifest_json->'render_safe_assets') a;
    IF (expected_music IS NULL AND cardinality(manifest_music)<>0) OR (expected_music IS NOT NULL AND (cardinality(manifest_music)<>1 OR manifest_music[1]<>expected_music)) OR (SELECT COALESCE(array_agg(x ORDER BY x),ARRAY[]::uuid[]) FROM unnest(expected_sfx) x) IS DISTINCT FROM (SELECT COALESCE(array_agg(x ORDER BY x),ARRAY[]::uuid[]) FROM unnest(manifest_sfx) x) THEN RAISE EXCEPTION 'render manifest assets must exactly match rule-compliant audio plan' USING ERRCODE='23514'; END IF;
    IF NEW.manifest_json->'audio_rule_compliance'->>'rule_snapshot_id' IS DISTINCT FROM ap.rule_compliance->>'rule_snapshot_id' OR COALESCE((NEW.manifest_json->'audio_rule_compliance'->>'verified_exact_asset_match')::boolean,false) IS NOT TRUE THEN RAISE EXCEPTION 'render manifest missing exact audio-rule compliance proof' USING ERRCODE='23514'; END IF;
    IF jsonb_array_length(ap.rule_compliance->'instructions')>0 AND (q.checks->'render_audio_compliance'->>'status')<>'PASS' THEN RAISE EXCEPTION 'operational render-audio instructions require PASS QC' USING ERRCODE='23514'; END IF;
  END IF;
  SELECT typed_value->'value' INTO dr FROM campaign_rule_items WHERE campaign_id=c.campaign_id AND terms_snapshot_id=c.rule_snapshot_id AND rule_key='disclosure_requirements' AND knowledge_state='KNOWN';
  IF dr IS NOT NULL AND COALESCE((dr->>'required')::boolean,false) AND dr->>'placement' IN ('VIDEO','BOTH') THEN
    IF (NEW.manifest_json->'campaign_disclosure'->>'rendered_in_video')::boolean IS NOT TRUE OR NEW.manifest_json->'campaign_disclosure'->>'placement' IS DISTINCT FROM dr->>'placement' OR (q.checks->'disclosure_video'->>'status')<>'PASS' THEN RAISE EXCEPTION 'VIDEO/BOTH disclosure requires render-manifest proof and PASS QC' USING ERRCODE='23514'; END IF;
  END IF;
  IF (q.checks->'campaign_restrictions'->>'status')<>'PASS' THEN RAISE EXCEPTION 'campaign restriction QC must PASS before terminal render manifest' USING ERRCODE='23514'; END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION honor_render_audio_disclosure_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_render_audio_disclosure_guard() TO honor_app;
DROP TRIGGER IF EXISTS honor_render_audio_disclosure_guard_trigger ON render_manifests;
CREATE TRIGGER honor_render_audio_disclosure_guard_trigger BEFORE INSERT ON render_manifests FOR EACH ROW EXECUTE FUNCTION honor_render_audio_disclosure_guard();

-- Render-manifest current-rights check is tied to DB transaction time, never caller-supplied manifest timestamps.
CREATE OR REPLACE FUNCTION honor_render_manifest_action_rights_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
BEGIN
  IF NOT EXISTS(SELECT 1 FROM clips c JOIN social_accounts sa ON sa.id=c.social_account_id WHERE c.id=NEW.clip_id AND honor_current_rights_for_action(c.source_id,c.campaign_id,sa.platform,'RENDER',statement_timestamp())=c.rights_id) THEN RAISE EXCEPTION 'render manifest cannot accept obsolete rights version at DB action time' USING ERRCODE='23514'; END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION honor_render_manifest_action_rights_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_render_manifest_action_rights_guard() TO honor_app;
DROP TRIGGER IF EXISTS honor_render_manifest_action_rights_guard_trigger ON render_manifests;
CREATE TRIGGER honor_render_manifest_action_rights_guard_trigger BEFORE INSERT ON render_manifests FOR EACH ROW EXECUTE FUNCTION honor_render_manifest_action_rights_guard();

-- V1 experiment predeclaration: DRAFT design, >=2 arms, exactly one control, DB-authored start/end/assignment/exposure clocks.
CREATE OR REPLACE FUNCTION honor_experiment_history_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE valid boolean:=false; st experiment_status_enum; startt timestamptz; declared_unit experiment_unit_enum; arm_count integer; control_count integer;
BEGIN
  IF TG_TABLE_NAME='experiments' THEN
    IF TG_OP='INSERT' THEN
      IF NEW.status<>'DRAFT' THEN RAISE EXCEPTION 'experiment creation must be DRAFT' USING ERRCODE='23514'; END IF;
      NEW.started_at:=NULL; NEW.ended_at:=NULL; NEW.stopping_reason:=NULL; NEW.created_at:=statement_timestamp(); NEW.updated_at:=NEW.created_at;
      RETURN NEW;
    END IF;
    IF (OLD.status<>'DRAFT' OR NEW.status IS DISTINCT FROM OLD.status) AND (NEW.hypothesis,NEW.feature_key,NEW.primary_metric,NEW.unit_type) IS DISTINCT FROM (OLD.hypothesis,OLD.feature_key,OLD.primary_metric,OLD.unit_type) THEN RAISE EXCEPTION 'experiment predeclared hypothesis/feature/primary_metric/unit_type may change only while remaining DRAFT' USING ERRCODE='42501'; END IF;
    IF NEW.status IS DISTINCT FROM OLD.status THEN
      valid := (OLD.status='DRAFT' AND NEW.status IN ('RUNNING','CANCELLED')) OR (OLD.status='RUNNING' AND NEW.status IN ('STOPPED','COMPLETED','CANCELLED')) OR (OLD.status='STOPPED' AND NEW.status='COMPLETED');
      IF NOT valid THEN RAISE EXCEPTION 'invalid experiment status transition' USING ERRCODE='23514'; END IF;
      IF OLD.status='DRAFT' AND NEW.status='RUNNING' THEN
        SELECT count(*),count(*) FILTER (WHERE is_control) INTO arm_count,control_count FROM experiment_arms WHERE experiment_id=OLD.id;
        IF arm_count<2 OR control_count<>1 THEN RAISE EXCEPTION 'DRAFT -> RUNNING requires at least two arms and exactly one control arm' USING ERRCODE='23514'; END IF;
        NEW.started_at:=statement_timestamp(); NEW.ended_at:=NULL; NEW.stopping_reason:=NULL;
      ELSIF OLD.status='STOPPED' AND NEW.status='COMPLETED' THEN
        NEW.ended_at:=OLD.ended_at;
      ELSIF NEW.status IN ('STOPPED','COMPLETED','CANCELLED') THEN
        NEW.ended_at:=statement_timestamp();
        IF OLD.status='RUNNING' AND NEW.stopping_reason IS NULL THEN RAISE EXCEPTION 'stopping_reason required when ending/stopping RUNNING experiment' USING ERRCODE='23514'; END IF;
      END IF;
    ELSE
      IF NEW.started_at IS DISTINCT FROM OLD.started_at OR NEW.ended_at IS DISTINCT FROM OLD.ended_at THEN RAISE EXCEPTION 'experiment start/end chronology is DB-authoritative' USING ERRCODE='42501'; END IF;
    END IF;
    IF OLD.status IN ('COMPLETED','CANCELLED') AND NEW IS DISTINCT FROM OLD THEN RAISE EXCEPTION 'terminal experiment is immutable' USING ERRCODE='42501'; END IF;
    NEW.updated_at:=statement_timestamp(); RETURN NEW;
  ELSIF TG_TABLE_NAME='experiment_arms' THEN
    SELECT status INTO st FROM experiments WHERE id=COALESCE(NEW.experiment_id,OLD.experiment_id);
    IF st IS DISTINCT FROM 'DRAFT' THEN RAISE EXCEPTION 'no arm INSERT/UPDATE/DELETE after experiment leaves DRAFT' USING ERRCODE='42501'; END IF;
    IF TG_OP='DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
  ELSIF TG_TABLE_NAME='experiment_assignments' THEN
    SELECT status,started_at,unit_type INTO st,startt,declared_unit FROM experiments WHERE id=COALESCE(NEW.experiment_id,OLD.experiment_id);
    IF TG_OP='INSERT' THEN
      IF st<>'RUNNING' THEN RAISE EXCEPTION 'experiment assignments may be created only while RUNNING' USING ERRCODE='23514'; END IF;
      IF NEW.unit_type IS DISTINCT FROM declared_unit THEN RAISE EXCEPTION 'assignment unit_type must match experiment predeclared unit_type' USING ERRCODE='23514'; END IF;
      IF NOT EXISTS(SELECT 1 FROM experiment_arms a WHERE a.id=NEW.arm_id AND a.experiment_id=NEW.experiment_id) THEN RAISE EXCEPTION 'experiment arm/assignment mismatch' USING ERRCODE='23514'; END IF;
      IF NEW.unit_type='GENERATION_RUN' AND NOT EXISTS(SELECT 1 FROM generation_runs WHERE id=NEW.unit_id) THEN RAISE EXCEPTION 'unknown experiment generation unit' USING ERRCODE='23514'; END IF;
      IF NEW.unit_type='SOCIAL_ACCOUNT' AND NOT EXISTS(SELECT 1 FROM social_accounts WHERE id=NEW.unit_id) THEN RAISE EXCEPTION 'unknown experiment account unit' USING ERRCODE='23514'; END IF;
      IF NEW.unit_type='CLIP' AND NOT EXISTS(SELECT 1 FROM clips WHERE id=NEW.unit_id) THEN RAISE EXCEPTION 'unknown experiment clip unit' USING ERRCODE='23514'; END IF;
      NEW.assigned_at:=statement_timestamp(); NEW.exposed_at:=NULL; NEW.created_at:=NEW.assigned_at;
      IF NEW.assigned_at<startt THEN RAISE EXCEPTION 'assignment may not predate experiment start' USING ERRCODE='23514'; END IF;
      RETURN NEW;
    ELSIF TG_OP='UPDATE' THEN
      IF NEW.experiment_id<>OLD.experiment_id OR NEW.arm_id<>OLD.arm_id OR NEW.unit_type<>OLD.unit_type OR NEW.unit_id<>OLD.unit_id OR NEW.assigned_at<>OLD.assigned_at OR NEW.created_at<>OLD.created_at THEN RAISE EXCEPTION 'experiment assignment identity is immutable' USING ERRCODE='42501'; END IF;
      IF OLD.exposed_at IS NOT NULL OR NEW.exposed_at IS NULL OR st<>'RUNNING' THEN RAISE EXCEPTION 'exposure may transition NULL -> timestamp exactly once while RUNNING' USING ERRCODE='42501'; END IF;
      NEW.exposed_at:=statement_timestamp();
      IF NEW.exposed_at<OLD.assigned_at OR NEW.exposed_at<startt THEN RAISE EXCEPTION 'exposure may not predate assignment/start' USING ERRCODE='23514'; END IF;
      RETURN NEW;
    ELSE
      RAISE EXCEPTION 'experiment assignment history cannot be deleted' USING ERRCODE='42501';
    END IF;
  END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION honor_experiment_history_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_experiment_history_guard() TO honor_app;
DROP TRIGGER IF EXISTS honor_experiment_status_guard ON experiments; CREATE TRIGGER honor_experiment_status_guard BEFORE INSERT OR UPDATE ON experiments FOR EACH ROW EXECUTE FUNCTION honor_experiment_history_guard();
DROP TRIGGER IF EXISTS honor_experiment_assignment_guard ON experiment_assignments; CREATE TRIGGER honor_experiment_assignment_guard BEFORE INSERT OR UPDATE OR DELETE ON experiment_assignments FOR EACH ROW EXECUTE FUNCTION honor_experiment_history_guard();
DROP TRIGGER IF EXISTS honor_experiment_arm_guard ON experiment_arms; CREATE TRIGGER honor_experiment_arm_guard BEFORE INSERT OR UPDATE OR DELETE ON experiment_arms FOR EACH ROW EXECUTE FUNCTION honor_experiment_history_guard();

-- Assignment references must belong to the exact run/account/clip scope; UUID existence alone is never sufficient.
CREATE OR REPLACE FUNCTION honor_experiment_reference_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE a experiment_assignments%ROWTYPE; eut experiment_unit_enum;
BEGIN
  IF NEW.experiment_assignment_id IS NULL THEN RETURN NEW; END IF;
  SELECT * INTO a FROM experiment_assignments WHERE id=NEW.experiment_assignment_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'unknown experiment assignment reference' USING ERRCODE='23503'; END IF;
  SELECT unit_type INTO eut FROM experiments WHERE id=a.experiment_id;
  IF a.unit_type<>eut THEN RAISE EXCEPTION 'assignment unit type must equal experiment predeclared unit_type' USING ERRCODE='23514'; END IF;
  IF TG_TABLE_NAME='candidates' THEN
    IF a.unit_type<>'GENERATION_RUN' OR a.unit_id<>NEW.generation_run_id THEN RAISE EXCEPTION 'candidate assignment must be exact GENERATION_RUN assignment for candidate run' USING ERRCODE='23514'; END IF;
  ELSIF TG_TABLE_NAME='run_campaign_allocations' THEN
    IF a.unit_type='GENERATION_RUN' AND a.unit_id=NEW.generation_run_id THEN NULL;
    ELSIF a.unit_type='SOCIAL_ACCOUNT' AND a.unit_id=NEW.social_account_id THEN NULL;
    ELSE RAISE EXCEPTION 'allocation assignment must match exact predeclared run or account unit' USING ERRCODE='23514'; END IF;
  ELSIF TG_TABLE_NAME='clips' THEN
    IF TG_OP='UPDATE' AND OLD.experiment_assignment_id IS NOT NULL AND NEW.experiment_assignment_id IS DISTINCT FROM OLD.experiment_assignment_id THEN RAISE EXCEPTION 'clip experiment assignment identity is immutable once attached' USING ERRCODE='42501'; END IF;
    IF TG_OP='UPDATE' AND OLD.experiment_assignment_id IS NULL AND NEW.experiment_assignment_id IS NOT NULL AND OLD.state<>'PLANNED' THEN RAISE EXCEPTION 'clip assignment may be attached only while PLANNED' USING ERRCODE='23514'; END IF;
    IF a.unit_type='CLIP' AND a.unit_id=NEW.id THEN NULL;
    ELSIF a.unit_type='GENERATION_RUN' AND a.unit_id=NEW.generation_run_id THEN NULL;
    ELSIF a.unit_type='SOCIAL_ACCOUNT' AND a.unit_id=NEW.social_account_id THEN NULL;
    ELSE RAISE EXCEPTION 'clip assignment must match exact clip or explicitly inherited run/account unit' USING ERRCODE='23514'; END IF;
  END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION honor_experiment_reference_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_experiment_reference_guard() TO honor_app;
DROP TRIGGER IF EXISTS honor_experiment_candidate_reference_trigger ON candidates; CREATE TRIGGER honor_experiment_candidate_reference_trigger BEFORE INSERT ON candidates FOR EACH ROW EXECUTE FUNCTION honor_experiment_reference_guard();
DROP TRIGGER IF EXISTS honor_experiment_allocation_reference_trigger ON run_campaign_allocations; CREATE TRIGGER honor_experiment_allocation_reference_trigger BEFORE INSERT ON run_campaign_allocations FOR EACH ROW EXECUTE FUNCTION honor_experiment_reference_guard();
DROP TRIGGER IF EXISTS honor_experiment_clip_reference_trigger ON clips; CREATE TRIGGER honor_experiment_clip_reference_trigger BEFORE INSERT OR UPDATE OF experiment_assignment_id ON clips FOR EACH ROW EXECUTE FUNCTION honor_experiment_reference_guard();

-- V1 runtime grants for new Round-8 objects/columns remain least-privilege.
-- GRANT SELECT ON TABLE campaign_rule_set_commits TO honor_app; INSERT only through honor_seal_campaign_rule_set(); UPDATE/DELETE forbidden.
-- earnings.rule_snapshot_id is mandatory immutable finance provenance; runtime earnings INSERT still follows existing constrained class.
-- audio_plans.rule_compliance is immutable with the audio plan row; clips.render_started_at is writable only by the DB render-start trigger.

-- ---------- ROUND-9 RUNTIME TYPE / SINGLE-RULE / QC-TRUTH / SERIALIZATION FREEZE ----------
-- Normative supersession of any weaker Round-8 behavior above.
CREATE OR REPLACE FUNCTION honor_jsonb_exact_keys(p jsonb, keys text[]) RETURNS boolean
LANGUAGE sql IMMUTABLE SET search_path=pg_catalog AS $$
  SELECT jsonb_typeof(p)='object'
    AND NOT EXISTS (SELECT 1 FROM jsonb_object_keys(p) k WHERE NOT (k=ANY(keys)))
    AND NOT EXISTS (SELECT 1 FROM unnest(keys) k WHERE NOT (p ? k));
$$;

CREATE OR REPLACE FUNCTION honor_rfc3339_datetime(p text) RETURNS boolean
LANGUAGE plpgsql IMMUTABLE SET search_path=pg_catalog AS $$
BEGIN
  IF p IS NULL OR p !~ '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$' THEN RETURN false; END IF;
  PERFORM p::timestamptz; RETURN true;
EXCEPTION WHEN others THEN RETURN false;
END $$;

CREATE OR REPLACE FUNCTION honor_absolute_uri(p text) RETURNS boolean
LANGUAGE sql IMMUTABLE SET search_path=pg_catalog AS $$
  SELECT p IS NOT NULL AND p ~ '^[A-Za-z][A-Za-z0-9+.-]*:[^[:space:]]+$';
$$;

-- Explicit per-key implementation of HONOR_CAMPAIGN_RULE_REGISTRY.json typed_value_schema.
CREATE OR REPLACE FUNCTION honor_campaign_rule_typed_value_valid(k text,tv jsonb) RETURNS boolean
LANGUAGE plpgsql IMMUTABLE SET search_path=public,pg_catalog AS $$
DECLARE v jsonb; n integer; x jsonb;
BEGIN
  IF NOT honor_jsonb_exact_keys(tv,ARRAY['value_type','value']) THEN RETURN false; END IF;
  v:=tv->'value';
  CASE
  WHEN k='provider' THEN RETURN tv->>'value_type'='STRING' AND jsonb_typeof(v)='string' AND length(tv->>'value') BETWEEN 1 AND 200;
  WHEN k='campaign_url' THEN RETURN tv->>'value_type'='STRING' AND jsonb_typeof(v)='string' AND length(tv->>'value') BETWEEN 1 AND 2000 AND honor_absolute_uri(tv->>'value');
  WHEN k='external_campaign_id' THEN RETURN tv->>'value_type'='STRING' AND jsonb_typeof(v)='string' AND length(tv->>'value') BETWEEN 1 AND 500;
  WHEN k='status' THEN RETURN tv->>'value_type'='CAMPAIGN_STATUS' AND jsonb_typeof(v)='string' AND tv->>'value' IN ('DISCOVERED','VERIFYING','ACTIVE','PAUSED','ENDED','REJECTED');
  WHEN k='compensation_model' THEN RETURN tv->>'value_type'='COMPENSATION_MODEL' AND jsonb_typeof(v)='string' AND tv->>'value' IN ('CPM','FLAT_PER_CLIP','PER_QUALIFIED_ACTION','HYBRID','OTHER');
  WHEN k='minimum_views' THEN RETURN tv->>'value_type'='INTEGER' AND jsonb_typeof(v)='number' AND (v::text)::numeric>=0 AND (v::text)::numeric=trunc((v::text)::numeric);
  WHEN k IN ('max_payout_per_clip','total_budget','remaining_budget') THEN RETURN tv->>'value_type'='MONEY_USD' AND jsonb_typeof(v)='string' AND tv->>'value' ~ '^(0|[1-9][0-9]{0,11})\.[0-9]{6}$';
  WHEN k IN ('start_at','end_at','deadline_at','last_verified_at') THEN RETURN tv->>'value_type'='TIMESTAMP' AND jsonb_typeof(v)='string' AND honor_rfc3339_datetime(tv->>'value');
  WHEN k IN ('clip_length_min_seconds','clip_length_max_seconds') THEN RETURN tv->>'value_type'='DURATION_SECONDS' AND jsonb_typeof(v)='number' AND (v::text)::numeric BETWEEN 0 AND 600;
  WHEN k='eligible_platforms' THEN
    RETURN tv->>'value_type'='PLATFORMS' AND jsonb_typeof(v)='array' AND jsonb_array_length(v) BETWEEN 1 AND 3
      AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(v) e WHERE jsonb_typeof(e)<>'string' OR trim(both '"' from e::text) NOT IN ('TIKTOK','INSTAGRAM_REELS','YOUTUBE_SHORTS'))
      AND (SELECT count(*)=count(DISTINCT e) FROM jsonb_array_elements(v)e);
  WHEN k='eligible_regions' THEN
    RETURN tv->>'value_type'='REGIONS' AND jsonb_typeof(v)='array' AND jsonb_array_length(v) BETWEEN 1 AND 250
      AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(v)e WHERE jsonb_typeof(e)<>'string' OR trim(both '"' from e::text) !~ '^[A-Z]{2}(-[A-Z0-9]{1,3})?$')
      AND (SELECT count(*)=count(DISTINCT e) FROM jsonb_array_elements(v)e);
  WHEN k='required_tags' THEN
    RETURN tv->>'value_type'='STRING_ARRAY' AND jsonb_typeof(v)='array' AND jsonb_array_length(v)<=200
      AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(v)e WHERE jsonb_typeof(e)<>'string' OR length(trim(both '"' from e::text)) NOT BETWEEN 1 AND 200)
      AND (SELECT count(*)=count(DISTINCT e) FROM jsonb_array_elements(v)e);
  WHEN k='required_mentions' THEN
    RETURN tv->>'value_type'='STRING_ARRAY' AND jsonb_typeof(v)='array' AND jsonb_array_length(v)<=200
      AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(v)e WHERE jsonb_typeof(e)<>'string' OR trim(both '"' from e::text) !~ '^@?[^[:space:]@]{1,199}$')
      AND (SELECT count(*)=count(DISTINCT e) FROM jsonb_array_elements(v)e);
  WHEN k='required_hashtags' THEN
    RETURN tv->>'value_type'='STRING_ARRAY' AND jsonb_typeof(v)='array' AND jsonb_array_length(v)<=200
      AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(v)e WHERE jsonb_typeof(e)<>'string' OR trim(both '"' from e::text) !~ '^#[^[:space:]#]{1,99}$')
      AND (SELECT count(*)=count(DISTINCT e) FROM jsonb_array_elements(v)e);
  WHEN k='eligible_account_requirements' THEN
    IF tv->>'value_type'<>'ACCOUNT_REQUIREMENTS' OR NOT honor_jsonb_exact_keys(v,ARRAY['min_followers','max_followers','require_posting_available','allowed_health_states']) THEN RETURN false; END IF;
    IF jsonb_typeof(v->'min_followers') NOT IN ('number','null') OR jsonb_typeof(v->'max_followers') NOT IN ('number','null') OR jsonb_typeof(v->'require_posting_available')<>'boolean' OR jsonb_typeof(v->'allowed_health_states')<>'array' THEN RETURN false; END IF;
    IF jsonb_typeof(v->'min_followers')='number' AND (((v->>'min_followers')::numeric)<0 OR (v->>'min_followers')::numeric<>trunc((v->>'min_followers')::numeric)) THEN RETURN false; END IF;
    IF jsonb_typeof(v->'max_followers')='number' AND (((v->>'max_followers')::numeric)<0 OR (v->>'max_followers')::numeric<>trunc((v->>'max_followers')::numeric)) THEN RETURN false; END IF;
    RETURN jsonb_array_length(v->'allowed_health_states') BETWEEN 1 AND 2 AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements_text(v->'allowed_health_states') e WHERE e NOT IN ('HEALTHY','CAUTION')) AND (SELECT count(*)=count(DISTINCT e) FROM jsonb_array_elements(v->'allowed_health_states') e);
  WHEN k='cpm_or_rate' THEN
    IF tv->>'value_type'<>'RATE' OR NOT honor_jsonb_exact_keys(v,ARRAY['amount','basis','unit_description']) THEN RETURN false; END IF;
    RETURN jsonb_typeof(v->'amount')='string' AND v->>'amount' ~ '^(0|[1-9][0-9]{0,11})\.[0-9]{6}$' AND v->>'basis' IN ('FLAT','PER_1000_VIEWS','PER_QUALIFIED_ACTION','OTHER') AND (jsonb_typeof(v->'unit_description')='null' OR (jsonb_typeof(v->'unit_description')='string' AND length(v->>'unit_description')<=500));
  WHEN k='disclosure_requirements' THEN
    IF tv->>'value_type'<>'DISCLOSURE_REQUIREMENTS' OR NOT honor_jsonb_exact_keys(v,ARRAY['required','text','instructions','placement']) THEN RETURN false; END IF;
    RETURN jsonb_typeof(v->'required')='boolean' AND (jsonb_typeof(v->'text')='null' OR (jsonb_typeof(v->'text')='string' AND length(v->>'text') BETWEEN 1 AND 2000)) AND jsonb_typeof(v->'instructions')='array' AND jsonb_array_length(v->'instructions')<=20 AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(v->'instructions') e WHERE jsonb_typeof(e)<>'string' OR length(trim(both '"' from e::text)) NOT BETWEEN 1 AND 1000) AND (jsonb_typeof(v->'placement')='null' OR v->>'placement' IN ('CAPTION','VIDEO','BOTH','PROVIDER_SUBMISSION'));
  WHEN k IN ('source_material_restrictions','content_restrictions','editing_restrictions','uniqueness_rules') THEN
    IF tv->>'value_type'<>'RESTRICTION_SET' OR NOT honor_jsonb_exact_keys(v,ARRAY['clauses']) OR jsonb_typeof(v->'clauses')<>'array' OR jsonb_array_length(v->'clauses')>50 THEN RETURN false; END IF;
    FOR x IN SELECT e FROM jsonb_array_elements(v->'clauses') e LOOP
      IF NOT honor_jsonb_exact_keys(x,ARRAY['code','effect','scope']) OR x->>'code' NOT IN ('CAMPAIGN_AUTHORIZED_SOURCE_ONLY','OWNER_OWNED_SOURCE_ONLY','NO_THIRD_PARTY_SOURCE','NO_PROFANITY','BRAND_SAFE_ONLY','NO_MISLEADING_CLAIMS','NO_CROP','NO_SPEED_CHANGE','NO_TEXT_OVERLAY','NO_REUSED_EDIT','UNIQUE_PER_ACCOUNT','UNIQUE_PER_CAMPAIGN') OR x->>'effect' NOT IN ('REQUIRE','PROHIBIT') OR x->>'scope' NOT IN ('SOURCE','CONTENT','EDIT','UNIQUENESS') THEN RETURN false; END IF;
    END LOOP;
    RETURN (SELECT count(*)=count(DISTINCT e) FROM jsonb_array_elements(v->'clauses') e);
  WHEN k='submission_format' THEN
    IF tv->>'value_type'<>'SUBMISSION_FORMAT' OR NOT honor_jsonb_exact_keys(v,ARRAY['required','instructions','submission_url','required_evidence']) THEN RETURN false; END IF;
    RETURN jsonb_typeof(v->'required')='boolean' AND jsonb_typeof(v->'instructions')='array' AND jsonb_array_length(v->'instructions')<=30 AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(v->'instructions') e WHERE jsonb_typeof(e)<>'string' OR length(trim(both '"' from e::text)) NOT BETWEEN 1 AND 1500) AND (jsonb_typeof(v->'submission_url')='null' OR (jsonb_typeof(v->'submission_url')='string' AND honor_absolute_uri(v->>'submission_url'))) AND jsonb_typeof(v->'required_evidence')='array' AND jsonb_array_length(v->'required_evidence')<=5 AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements_text(v->'required_evidence') e WHERE e NOT IN ('POST_URL','PLATFORM_POST_ID','SCREENSHOT','ANALYTICS_SNAPSHOT','OTHER')) AND (SELECT count(*)=count(DISTINCT e) FROM jsonb_array_elements(v->'required_evidence')e);
  WHEN k IN ('analytics_window','payout_window') THEN
    IF tv->>'value_type'<>'WINDOW' OR NOT honor_jsonb_exact_keys(v,ARRAY['start_offset_minutes','end_offset_minutes','description']) THEN RETURN false; END IF;
    RETURN jsonb_typeof(v->'start_offset_minutes') IN ('number','null') AND jsonb_typeof(v->'end_offset_minutes') IN ('number','null') AND (jsonb_typeof(v->'description')='null' OR (jsonb_typeof(v->'description')='string' AND length(v->>'description')<=1000)) AND (jsonb_typeof(v->'start_offset_minutes')='null' OR ((v->>'start_offset_minutes')::numeric BETWEEN 0 AND 525600 AND (v->>'start_offset_minutes')::numeric=trunc((v->>'start_offset_minutes')::numeric))) AND (jsonb_typeof(v->'end_offset_minutes')='null' OR ((v->>'end_offset_minutes')::numeric BETWEEN 0 AND 525600 AND (v->>'end_offset_minutes')::numeric=trunc((v->>'end_offset_minutes')::numeric)));
  WHEN k='render_audio_rules' THEN
    IF tv->>'value_type'<>'RENDER_AUDIO_RULES' OR NOT honor_jsonb_exact_keys(v,ARRAY['render_safe_audio','music_allowed','sfx_allowed','max_sfx_density','instructions']) THEN RETURN false; END IF;
    RETURN v->>'render_safe_audio' IN ('ALLOWED','PROHIBITED','UNKNOWN','NOT_APPLICABLE') AND v->>'music_allowed' IN ('ALLOWED','PROHIBITED','UNKNOWN','NOT_APPLICABLE') AND v->>'sfx_allowed' IN ('ALLOWED','PROHIBITED','UNKNOWN','NOT_APPLICABLE') AND (jsonb_typeof(v->'max_sfx_density')='null' OR v->>'max_sfx_density' IN ('NONE','LOW','MEDIUM','HIGH')) AND jsonb_typeof(v->'instructions')='array' AND jsonb_array_length(v->'instructions')<=20 AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(v->'instructions')e WHERE jsonb_typeof(e)<>'string' OR length(trim(both '"' from e::text)) NOT BETWEEN 1 AND 1000);
  WHEN k='platform_native_audio_rules' THEN
    RETURN tv->>'value_type'='PLATFORM_NATIVE_AUDIO_RULES' AND honor_jsonb_exact_keys(v,ARRAY['TIKTOK','INSTAGRAM_REELS','YOUTUBE_SHORTS']) AND v->>'TIKTOK' IN ('ALLOWED','PROHIBITED','UNKNOWN','NOT_APPLICABLE') AND v->>'INSTAGRAM_REELS' IN ('ALLOWED','PROHIBITED','UNKNOWN','NOT_APPLICABLE') AND v->>'YOUTUBE_SHORTS' IN ('ALLOWED','PROHIBITED','UNKNOWN','NOT_APPLICABLE');
  ELSE RETURN false;
  END CASE;
END $$;
REVOKE ALL ON FUNCTION honor_campaign_rule_typed_value_valid(text, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_campaign_rule_typed_value_valid(text, jsonb) TO honor_app;

-- A malformed KNOWN body cannot cross the immutable seal boundary, even if application validation is bypassed.
CREATE OR REPLACE FUNCTION honor_rule_set_runtime_schema_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE bad text; typed_last timestamptz; actual_last timestamptz;
BEGIN
  SELECT rule_key INTO bad FROM campaign_rule_items WHERE campaign_id=NEW.campaign_id AND terms_snapshot_id=NEW.terms_snapshot_id AND schema_version=NEW.schema_version AND knowledge_state='KNOWN' AND NOT honor_campaign_rule_typed_value_valid(rule_key,typed_value) LIMIT 1;
  IF bad IS NOT NULL THEN RAISE EXCEPTION 'registered typed_value_schema validation failed before seal for %',bad USING ERRCODE='23514'; END IF;
  SELECT (typed_value->>'value')::timestamptz INTO typed_last FROM campaign_rule_items WHERE campaign_id=NEW.campaign_id AND terms_snapshot_id=NEW.terms_snapshot_id AND schema_version=NEW.schema_version AND rule_key='last_verified_at' AND knowledge_state='KNOWN';
  IF typed_last IS NOT NULL THEN
    SELECT max(verified_at) INTO actual_last FROM campaign_rule_items WHERE campaign_id=NEW.campaign_id AND terms_snapshot_id=NEW.terms_snapshot_id AND schema_version=NEW.schema_version AND knowledge_state IN ('KNOWN','NOT_APPLICABLE');
    IF typed_last>NEW.committed_at OR typed_last IS DISTINCT FROM actual_last THEN RAISE EXCEPTION 'last_verified_at must equal actual rule-set verification maximum and may not be future of seal' USING ERRCODE='23514'; END IF;
  END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION honor_rule_set_runtime_schema_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_rule_set_runtime_schema_guard() TO honor_app;
DROP TRIGGER IF EXISTS honor_rule_set_runtime_schema_guard_trigger ON campaign_rule_set_commits;
CREATE TRIGGER honor_rule_set_runtime_schema_guard_trigger BEFORE INSERT ON campaign_rule_set_commits FOR EACH ROW EXECUTE FUNCTION honor_rule_set_runtime_schema_guard();

-- Exactly one authoritative sealed rule snapshot per V1 edit/audio/clip/render lineage.
CREATE OR REPLACE FUNCTION honor_single_rule_set_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE snap uuid; epsnap uuid;
BEGIN
  IF TG_TABLE_NAME='edit_plans' THEN
    IF jsonb_typeof(NEW.plan_json->'campaign_rule_snapshot_ids')<>'array' OR jsonb_array_length(NEW.plan_json->'campaign_rule_snapshot_ids')<>1 THEN RAISE EXCEPTION 'V1 edit plan requires exactly one campaign rule snapshot' USING ERRCODE='23514'; END IF;
    snap:=(NEW.plan_json->'campaign_rule_snapshot_ids'->>0)::uuid;
    IF NEW.plan_json->'rule_compliance'->>'rule_snapshot_id' IS DISTINCT FROM snap::text THEN RAISE EXCEPTION 'edit rule-compliance identity must equal sole campaign rule snapshot' USING ERRCODE='23514'; END IF;
  ELSIF TG_TABLE_NAME='audio_plans' THEN
    SELECT (plan_json->'campaign_rule_snapshot_ids'->>0)::uuid INTO snap FROM edit_plans WHERE id=NEW.edit_plan_id;
    IF NEW.rule_compliance->>'rule_snapshot_id' IS DISTINCT FROM snap::text OR NEW.platform_native_recommendation->>'rule_snapshot_id' IS DISTINCT FROM snap::text THEN RAISE EXCEPTION 'audio plan rule identity must equal sole edit rule snapshot' USING ERRCODE='23514'; END IF;
  ELSIF TG_TABLE_NAME='clips' THEN
    SELECT (plan_json->'campaign_rule_snapshot_ids'->>0)::uuid INTO snap FROM edit_plans WHERE id=NEW.edit_plan_id;
    IF NEW.rule_snapshot_id IS DISTINCT FROM snap OR NEW.posting_recommendation->'native_audio_recommendation'->>'rule_snapshot_id' IS DISTINCT FROM snap::text THEN RAISE EXCEPTION 'clip/posting rule identity must equal sole edit rule snapshot' USING ERRCODE='23514'; END IF;
    IF NEW.audio_plan_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM audio_plans a WHERE a.id=NEW.audio_plan_id AND a.rule_compliance->>'rule_snapshot_id'=snap::text) THEN RAISE EXCEPTION 'clip audio plan uses different rule snapshot' USING ERRCODE='23514'; END IF;
  ELSIF TG_TABLE_NAME='render_manifests' THEN
    SELECT c.rule_snapshot_id INTO snap FROM clips c WHERE c.id=NEW.clip_id;
    SELECT (plan_json->'campaign_rule_snapshot_ids'->>0)::uuid INTO epsnap FROM edit_plans WHERE id=NEW.edit_plan_id;
    IF NEW.manifest_json->>'campaign_rule_snapshot_id' IS DISTINCT FROM snap::text OR epsnap IS DISTINCT FROM snap OR NEW.manifest_json->'audio_rule_compliance'->>'rule_snapshot_id' IS DISTINCT FROM snap::text THEN RAISE EXCEPTION 'render manifest rule identity must equal sole edit/audio/clip rule snapshot' USING ERRCODE='23514'; END IF;
  END IF; RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION honor_single_rule_set_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_single_rule_set_guard() TO honor_app;
DROP TRIGGER IF EXISTS honor_single_rule_edit_trigger ON edit_plans; CREATE TRIGGER honor_single_rule_edit_trigger BEFORE INSERT ON edit_plans FOR EACH ROW EXECUTE FUNCTION honor_single_rule_set_guard();
DROP TRIGGER IF EXISTS honor_single_rule_audio_trigger ON audio_plans; CREATE TRIGGER honor_single_rule_audio_trigger BEFORE INSERT ON audio_plans FOR EACH ROW EXECUTE FUNCTION honor_single_rule_set_guard();
DROP TRIGGER IF EXISTS honor_single_rule_clip_trigger ON clips; CREATE TRIGGER honor_single_rule_clip_trigger BEFORE INSERT OR UPDATE OF edit_plan_id,audio_plan_id,rule_snapshot_id,posting_recommendation ON clips FOR EACH ROW EXECUTE FUNCTION honor_single_rule_set_guard();
DROP TRIGGER IF EXISTS honor_single_rule_manifest_trigger ON render_manifests; CREATE TRIGGER honor_single_rule_manifest_trigger BEFORE INSERT ON render_manifests FOR EACH ROW EXECUTE FUNCTION honor_single_rule_set_guard();

-- Exact restriction proof kinds/references are machine-enforced from the frozen semantics artifact.
CREATE OR REPLACE FUNCTION honor_restriction_compliance_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE camp uuid; snap uuid; src uuid; clause jsonb; proof jsonb; code text; effect text; scope text; primary_kind text; owner_ok boolean;
BEGIN
  SELECT c.source_id,t.campaign_id,(NEW.plan_json->'campaign_rule_snapshot_ids'->>0)::uuid INTO src,camp,snap FROM candidates c JOIN campaign_terms_snapshots t ON t.id=(NEW.plan_json->'campaign_rule_snapshot_ids'->>0)::uuid WHERE c.id=NEW.candidate_id;
  FOR clause IN SELECT c FROM campaign_rule_items r,LATERAL jsonb_array_elements(r.typed_value->'value'->'clauses') c WHERE r.campaign_id=camp AND r.terms_snapshot_id=snap AND r.knowledge_state='KNOWN' AND r.rule_key IN ('source_material_restrictions','content_restrictions','editing_restrictions','uniqueness_rules') LOOP
    code:=clause->>'code'; effect:=clause->>'effect'; scope:=clause->>'scope';
    primary_kind:=CASE code WHEN 'CAMPAIGN_AUTHORIZED_SOURCE_ONLY' THEN 'RIGHTS_CAMPAIGN_LINK' WHEN 'OWNER_OWNED_SOURCE_ONLY' THEN 'SOURCE_ORIGIN' WHEN 'NO_THIRD_PARTY_SOURCE' THEN 'SOURCE_ORIGIN' WHEN 'NO_PROFANITY' THEN 'TRANSCRIPT_LEXICAL_SCAN' WHEN 'BRAND_SAFE_ONLY' THEN 'CONTENT_SAFETY_REVIEW' WHEN 'NO_MISLEADING_CLAIMS' THEN 'CLAIMS_EVIDENCE_REVIEW' WHEN 'NO_CROP' THEN 'EDIT_OPERATION_AUDIT' WHEN 'NO_SPEED_CHANGE' THEN 'EDIT_OPERATION_AUDIT' WHEN 'NO_TEXT_OVERLAY' THEN 'CAPTION_OVERLAY_AUDIT' ELSE 'EDIT_SIGNATURE_COMPARISON' END;
    owner_ok:=code IN ('NO_PROFANITY','BRAND_SAFE_ONLY','NO_MISLEADING_CLAIMS');
    SELECT x INTO proof FROM jsonb_array_elements(NEW.plan_json->'restriction_compliance') x WHERE x->>'code'=code AND x->>'effect'=effect AND x->>'scope'=scope AND x->>'result'='COMPLIANT' LIMIT 1;
    IF proof IS NULL THEN RAISE EXCEPTION 'restriction compliance missing/UNKNOWN/failed for %',code USING ERRCODE='23514'; END IF;
    IF proof->>'proof_kind'='NONE' OR (proof->>'proof_kind'<>primary_kind AND NOT(owner_ok AND proof->>'proof_kind'='OWNER_REVIEW')) THEN RAISE EXCEPTION 'restriction COMPLIANT uses invalid proof kind for %',code USING ERRCODE='23514'; END IF;
    IF NULLIF(proof->>'proof_reference','') IS NULL THEN RAISE EXCEPTION 'restriction COMPLIANT requires structured proof reference for %',code USING ERRCODE='23514'; END IF;
    IF proof->>'proof_kind'='OWNER_REVIEW' AND (NOT owner_ok OR proof->>'owner_review_resolution_id' IS NULL) THEN RAISE EXCEPTION 'owner review cannot resolve restriction or lacks resolution id for %',code USING ERRCODE='23514'; END IF;
    IF proof->>'proof_kind'<>'OWNER_REVIEW' AND proof->>'owner_review_resolution_id' IS NOT NULL THEN RAISE EXCEPTION 'owner review resolution id forbidden for non-owner proof' USING ERRCODE='23514'; END IF;
    IF code='CAMPAIGN_AUTHORIZED_SOURCE_ONLY' AND NOT EXISTS(SELECT 1 FROM sources s JOIN source_rights r ON r.source_id=s.id JOIN source_rights_campaigns rc ON rc.source_rights_id=r.id AND rc.campaign_id=camp WHERE s.id=src AND s.origin_type='CAMPAIGN_AUTHORIZED') THEN RAISE EXCEPTION 'campaign-authorized-source-only restriction failed' USING ERRCODE='23514'; END IF;
    IF code='OWNER_OWNED_SOURCE_ONLY' AND NOT EXISTS(SELECT 1 FROM sources WHERE id=src AND origin_type='OWNER_OWNED') THEN RAISE EXCEPTION 'owner-owned-source-only restriction failed' USING ERRCODE='23514'; END IF;
    IF code='NO_THIRD_PARTY_SOURCE' AND NOT EXISTS(SELECT 1 FROM sources WHERE id=src AND origin_type IN ('CAMPAIGN_AUTHORIZED','OWNER_OWNED')) THEN RAISE EXCEPTION 'no-third-party-source restriction failed' USING ERRCODE='23514'; END IF;
    IF code='NO_CROP' AND ((NEW.plan_json->'layout'->>'reframing_mode')<>'FIT_NO_CROP' OR jsonb_array_length(NEW.plan_json->'layout'->'punch_ins')<>0 OR EXISTS(SELECT 1 FROM jsonb_array_elements(NEW.plan_json->'layout'->'events') e WHERE (e->>'scale')::numeric<>1 OR (e->>'pan_x')::numeric<>0 OR (e->>'pan_y')::numeric<>0)) THEN RAISE EXCEPTION 'NO_CROP forbids crop/reframe/pan/zoom/punch-in' USING ERRCODE='23514'; END IF;
    IF code='NO_SPEED_CHANGE' AND EXISTS(SELECT 1 FROM jsonb_array_elements(NEW.plan_json->'timeline'->'cuts') c WHERE (c->>'playback_rate')::numeric<>1) THEN RAISE EXCEPTION 'NO_SPEED_CHANGE forbids playback-rate manipulation' USING ERRCODE='23514'; END IF;
    IF code='NO_TEXT_OVERLAY' AND ((NEW.plan_json->'captions'->>'enabled')::boolean OR jsonb_array_length(NEW.plan_json->'captions'->'chunks')<>0 OR jsonb_array_length(NEW.plan_json->'disclosure_render'->'overlay_events')<>0) THEN RAISE EXCEPTION 'NO_TEXT_OVERLAY includes burned captions and disclosure overlays' USING ERRCODE='23514'; END IF;
  END LOOP; RETURN NEW;
END $$;

-- Race-safe uniqueness final acceptance reservations. Unique PKs serialize concurrent READY attempts.
CREATE TABLE accepted_edit_signatures (
  restriction_code text NOT NULL CHECK (restriction_code IN ('NO_REUSED_EDIT','UNIQUE_PER_ACCOUNT','UNIQUE_PER_CAMPAIGN')),
  scope_id uuid NOT NULL,
  edit_signature_sha256 char(64) NOT NULL CHECK (edit_signature_sha256 ~ '^[a-f0-9]{64}$'),
  clip_id uuid NOT NULL REFERENCES clips(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  accepted_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(restriction_code,scope_id,edit_signature_sha256),
  UNIQUE(restriction_code,clip_id)
);
DROP TRIGGER IF EXISTS honor_immutable_accepted_edit_signatures ON accepted_edit_signatures;
CREATE TRIGGER honor_immutable_accepted_edit_signatures BEFORE UPDATE OR DELETE ON accepted_edit_signatures FOR EACH ROW EXECUTE FUNCTION honor_reject_immutable_mutation();
CREATE OR REPLACE FUNCTION honor_final_uniqueness_acceptance_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_catalog AS $$
DECLARE sig text; code text; scope uuid; qstat text;
BEGIN
 IF TG_OP='UPDATE' AND NEW.state='READY' AND OLD.state IS DISTINCT FROM 'READY' THEN
  SELECT plan_json->'output'->>'edit_signature_sha256' INTO sig FROM edit_plans WHERE id=NEW.edit_plan_id;
  FOR code IN SELECT c->>'code' FROM campaign_rule_items r,LATERAL jsonb_array_elements(r.typed_value->'value'->'clauses') c WHERE r.campaign_id=NEW.campaign_id AND r.terms_snapshot_id=NEW.rule_snapshot_id AND r.knowledge_state='KNOWN' AND r.rule_key='uniqueness_rules' AND c->>'code' IN ('NO_REUSED_EDIT','UNIQUE_PER_ACCOUNT','UNIQUE_PER_CAMPAIGN') LOOP
    SELECT q.checks->'uniqueness'->>'status' INTO qstat FROM render_manifests rm JOIN qc_runs q ON q.id=rm.qc_run_id WHERE rm.clip_id=NEW.id;
    IF qstat IS DISTINCT FROM 'PASS' THEN RAISE EXCEPTION 'applicable uniqueness restriction requires canonical QC uniqueness PASS' USING ERRCODE='23514'; END IF;
    scope:=CASE WHEN code='UNIQUE_PER_ACCOUNT' THEN NEW.social_account_id ELSE NEW.campaign_id END;
    INSERT INTO accepted_edit_signatures(restriction_code,scope_id,edit_signature_sha256,clip_id,accepted_at) VALUES(code,scope,sig,NEW.id,statement_timestamp());
  END LOOP;
 END IF; RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION honor_final_uniqueness_acceptance_guard() FROM PUBLIC; GRANT EXECUTE ON FUNCTION honor_final_uniqueness_acceptance_guard() TO honor_app;
DROP TRIGGER IF EXISTS honor_final_uniqueness_acceptance_trigger ON clips;
CREATE TRIGGER honor_final_uniqueness_acceptance_trigger BEFORE UPDATE OF state ON clips FOR EACH ROW EXECUTE FUNCTION honor_final_uniqueness_acceptance_guard();

-- Canonical QC truth: caller cannot downgrade hard gates or assert passed independently.
CREATE OR REPLACE FUNCTION honor_qc_truth_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE names text[]:=ARRAY['video_decode','audio_decode','dimensions_aspect','duration','black_frozen_frames','audio_presence','loudness_peak','caption_safe_bounds','face_crop','caption_overlap','cut_frequency','assets_present','watermark_absent','uniqueness','rules_rights_metadata','output_size','sha256_recorded','campaign_restrictions','disclosure_video','render_audio_compliance']; nm text; st text; derived boolean:=true; ep jsonb; c clips%ROWTYPE; uniq_required boolean; video_disc boolean;
BEGIN
 SELECT * INTO c FROM clips WHERE id=NEW.clip_id; SELECT plan_json INTO ep FROM edit_plans WHERE id=c.edit_plan_id;
 SELECT EXISTS(SELECT 1 FROM campaign_rule_items r,LATERAL jsonb_array_elements(r.typed_value->'value'->'clauses') x WHERE r.campaign_id=c.campaign_id AND r.terms_snapshot_id=c.rule_snapshot_id AND r.rule_key='uniqueness_rules' AND r.knowledge_state='KNOWN' AND x->>'code' IN ('NO_REUSED_EDIT','UNIQUE_PER_ACCOUNT','UNIQUE_PER_CAMPAIGN')) INTO uniq_required;
 SELECT COALESCE((typed_value->'value'->>'required')::boolean,false) AND typed_value->'value'->>'placement' IN ('VIDEO','BOTH') INTO video_disc FROM campaign_rule_items WHERE campaign_id=c.campaign_id AND terms_snapshot_id=c.rule_snapshot_id AND rule_key='disclosure_requirements' AND knowledge_state='KNOWN';
 FOREACH nm IN ARRAY names LOOP
   IF NEW.checks->nm IS NULL THEN RAISE EXCEPTION 'canonical QC check missing: %',nm USING ERRCODE='23514'; END IF;
   IF COALESCE((NEW.checks->nm->>'hard_gate')::boolean,false) IS NOT TRUE THEN RAISE EXCEPTION 'caller hard_gate=false cannot weaken canonical QC: %',nm USING ERRCODE='23514'; END IF;
   st:=NEW.checks->nm->>'status';
   IF st IN ('FAIL','WARN') THEN
     derived:=false; IF NULLIF(NEW.checks->nm->>'reason_code','') IS NULL OR NULLIF(NEW.checks->nm->>'detail','') IS NULL THEN RAISE EXCEPTION 'QC FAIL/WARN requires reason_code and detail: %',nm USING ERRCODE='23514'; END IF;
   ELSIF st='NOT_APPLICABLE' THEN
     IF nm IN ('caption_safe_bounds','caption_overlap') AND COALESCE((ep->'captions'->>'enabled')::boolean,false)=false AND jsonb_array_length(ep->'disclosure_render'->'overlay_events')=0 THEN NULL;
     ELSIF nm='uniqueness' AND NOT uniq_required THEN NULL;
     ELSIF nm='disclosure_video' AND NOT COALESCE(video_disc,false) THEN NULL;
     ELSIF nm='render_audio_compliance' AND c.audio_plan_id IS NULL THEN NULL;
     ELSE RAISE EXCEPTION 'QC NOT_APPLICABLE is not permitted by canonical policy: %',nm USING ERRCODE='23514'; END IF;
   ELSIF st<>'PASS' THEN RAISE EXCEPTION 'invalid canonical QC status: %',nm USING ERRCODE='23514'; END IF;
 END LOOP;
 IF NEW.passed=true AND NOT derived THEN RAISE EXCEPTION 'qc_runs.passed=true contradicts canonical derived QC result' USING ERRCODE='23514'; END IF;
 NEW.passed:=derived; RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION honor_qc_truth_guard() FROM PUBLIC; GRANT EXECUTE ON FUNCTION honor_qc_truth_guard() TO honor_app;
DROP TRIGGER IF EXISTS honor_qc_truth_guard_trigger ON qc_runs;
CREATE TRIGGER honor_qc_truth_guard_trigger BEFORE INSERT ON qc_runs FOR EACH ROW EXECUTE FUNCTION honor_qc_truth_guard();

-- Auditable recommendation revisions use current DB action time, never the clip creation time.
ALTER TABLE clips ADD COLUMN recommendation_version integer NOT NULL DEFAULT 1 CHECK (recommendation_version>=1);
ALTER TABLE clips ADD COLUMN recommendation_revised_at timestamptz NULL;
CREATE OR REPLACE FUNCTION honor_00_clip_recommendation_revision_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE t timestamptz:=statement_timestamp(); p platform_enum; current_snap uuid;
BEGIN
 IF TG_OP='INSERT' THEN NEW.recommendation_version:=1; NEW.recommendation_revised_at:=statement_timestamp(); RETURN NEW; END IF;
 IF NEW.posting_recommendation IS DISTINCT FROM OLD.posting_recommendation OR NEW.social_account_id IS DISTINCT FROM OLD.social_account_id OR NEW.rule_snapshot_id IS DISTINCT FROM OLD.rule_snapshot_id OR NEW.edit_plan_id IS DISTINCT FROM OLD.edit_plan_id OR NEW.audio_plan_id IS DISTINCT FROM OLD.audio_plan_id THEN
   IF OLD.state IN ('POSTED','ARCHIVED') OR EXISTS(SELECT 1 FROM posts WHERE clip_id=OLD.id) THEN RAISE EXCEPTION 'posting recommendation is immutable once posting/archival begins' USING ERRCODE='42501'; END IF;
   SELECT platform INTO p FROM social_accounts WHERE id=NEW.social_account_id;
   IF honor_current_rights_for_action(NEW.source_id,NEW.campaign_id,p,'PUBLICATION_RECOMMENDATION',t) IS DISTINCT FROM NEW.rights_id THEN RAISE EXCEPTION 'recommendation revision requires current publication rights at DB action time' USING ERRCODE='23514'; END IF;
   IF NOT honor_rule_set_sealed_for_action(NEW.campaign_id,NEW.rule_snapshot_id,1,t) THEN RAISE EXCEPTION 'recommendation revision requires sealed rule set at DB action time' USING ERRCODE='23514'; END IF;
   SELECT terms_snapshot_id INTO current_snap FROM campaigns WHERE id=NEW.campaign_id;
   IF current_snap IS DISTINCT FROM NEW.rule_snapshot_id THEN RAISE EXCEPTION 'recommendation revision must use current activated campaign rule snapshot; changed terms require revised lineage' USING ERRCODE='23514'; END IF;
   IF EXISTS(SELECT 1 FROM source_rights r WHERE r.id=NEW.rights_id AND r.expires_at IS NOT NULL AND t>=r.expires_at) THEN RAISE EXCEPTION 'recommendation revision after rights expiration is forbidden' USING ERRCODE='23514'; END IF;
   NEW.recommendation_version:=OLD.recommendation_version+1; NEW.recommendation_revised_at:=t;
 ELSE
   IF NEW.recommendation_version IS DISTINCT FROM OLD.recommendation_version OR NEW.recommendation_revised_at IS DISTINCT FROM OLD.recommendation_revised_at THEN RAISE EXCEPTION 'recommendation revision clock/version is DB-authoritative' USING ERRCODE='42501'; END IF;
 END IF; RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION honor_00_clip_recommendation_revision_guard() FROM PUBLIC; GRANT EXECUTE ON FUNCTION honor_00_clip_recommendation_revision_guard() TO honor_app;
DROP TRIGGER IF EXISTS honor_00_clip_recommendation_revision_trigger ON clips;
CREATE TRIGGER honor_00_clip_recommendation_revision_trigger BEFORE INSERT OR UPDATE OF posting_recommendation,social_account_id,rule_snapshot_id,edit_plan_id,audio_plan_id,recommendation_version,recommendation_revised_at ON clips FOR EACH ROW EXECUTE FUNCTION honor_00_clip_recommendation_revision_guard();

-- Child experiment mutations lock the parent row; status transitions share the same row lock.
CREATE OR REPLACE FUNCTION honor_experiment_history_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE valid boolean:=false; st experiment_status_enum; startt timestamptz; declared_unit experiment_unit_enum; arm_count integer; control_count integer; parent_id uuid;
BEGIN
 IF TG_TABLE_NAME='experiments' THEN
  IF TG_OP='INSERT' THEN IF NEW.status<>'DRAFT' THEN RAISE EXCEPTION 'experiment creation must be DRAFT' USING ERRCODE='23514'; END IF; NEW.started_at:=NULL; NEW.ended_at:=NULL; NEW.stopping_reason:=NULL; NEW.created_at:=statement_timestamp(); NEW.updated_at:=NEW.created_at; RETURN NEW; END IF;
  IF (OLD.status<>'DRAFT' OR NEW.status IS DISTINCT FROM OLD.status) AND (NEW.hypothesis,NEW.feature_key,NEW.primary_metric,NEW.unit_type) IS DISTINCT FROM (OLD.hypothesis,OLD.feature_key,OLD.primary_metric,OLD.unit_type) THEN RAISE EXCEPTION 'experiment predeclared hypothesis/feature/primary_metric/unit_type may change only while remaining DRAFT' USING ERRCODE='42501'; END IF;
  IF OLD.status<>'RUNNING' AND NEW.stopping_reason IS DISTINCT FROM OLD.stopping_reason THEN RAISE EXCEPTION 'captured experiment stopping_reason is historical and immutable' USING ERRCODE='42501'; END IF;
  IF NEW.status IS DISTINCT FROM OLD.status THEN
   valid:=(OLD.status='DRAFT' AND NEW.status IN ('RUNNING','CANCELLED')) OR (OLD.status='RUNNING' AND NEW.status IN ('STOPPED','COMPLETED','CANCELLED')) OR (OLD.status='STOPPED' AND NEW.status='COMPLETED'); IF NOT valid THEN RAISE EXCEPTION 'invalid experiment status transition' USING ERRCODE='23514'; END IF;
   IF OLD.status='DRAFT' AND NEW.status='RUNNING' THEN SELECT count(*),count(*) FILTER(WHERE is_control) INTO arm_count,control_count FROM experiment_arms WHERE experiment_id=OLD.id; IF arm_count<2 OR control_count<>1 THEN RAISE EXCEPTION 'DRAFT -> RUNNING requires at least two arms and exactly one control arm' USING ERRCODE='23514'; END IF; NEW.started_at:=statement_timestamp(); NEW.ended_at:=NULL; NEW.stopping_reason:=NULL;
   ELSIF OLD.status='RUNNING' AND NEW.status IN ('STOPPED','COMPLETED','CANCELLED') THEN IF NULLIF(NEW.stopping_reason,'') IS NULL THEN RAISE EXCEPTION 'stopping_reason required when ending/stopping RUNNING experiment' USING ERRCODE='23514'; END IF; NEW.ended_at:=statement_timestamp();
   ELSIF OLD.status='STOPPED' AND NEW.status='COMPLETED' THEN NEW.ended_at:=OLD.ended_at; NEW.stopping_reason:=OLD.stopping_reason;
   ELSIF OLD.status='DRAFT' AND NEW.status='CANCELLED' THEN NEW.ended_at:=statement_timestamp();
   END IF;
  ELSE
   IF NEW.started_at IS DISTINCT FROM OLD.started_at OR NEW.ended_at IS DISTINCT FROM OLD.ended_at THEN RAISE EXCEPTION 'experiment start/end chronology is DB-authoritative' USING ERRCODE='42501'; END IF;
  END IF;
  IF OLD.status IN ('COMPLETED','CANCELLED') AND NEW IS DISTINCT FROM OLD THEN RAISE EXCEPTION 'terminal experiment is immutable' USING ERRCODE='42501'; END IF; NEW.updated_at:=statement_timestamp(); RETURN NEW;
 ELSIF TG_TABLE_NAME='experiment_arms' THEN
  parent_id:=COALESCE(NEW.experiment_id,OLD.experiment_id); SELECT status INTO st FROM experiments WHERE id=parent_id FOR UPDATE; IF st IS DISTINCT FROM 'DRAFT' THEN RAISE EXCEPTION 'no arm INSERT/UPDATE/DELETE after experiment leaves DRAFT' USING ERRCODE='42501'; END IF; IF TG_OP='DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
 ELSIF TG_TABLE_NAME='experiment_assignments' THEN
  parent_id:=COALESCE(NEW.experiment_id,OLD.experiment_id); SELECT status,started_at,unit_type INTO st,startt,declared_unit FROM experiments WHERE id=parent_id FOR UPDATE;
  IF TG_OP='INSERT' THEN IF st<>'RUNNING' THEN RAISE EXCEPTION 'experiment assignments may be created only while RUNNING' USING ERRCODE='23514'; END IF; IF NEW.unit_type IS DISTINCT FROM declared_unit THEN RAISE EXCEPTION 'assignment unit_type must match experiment predeclared unit_type' USING ERRCODE='23514'; END IF; IF NOT EXISTS(SELECT 1 FROM experiment_arms a WHERE a.id=NEW.arm_id AND a.experiment_id=NEW.experiment_id) THEN RAISE EXCEPTION 'experiment arm/assignment mismatch' USING ERRCODE='23514'; END IF; NEW.assigned_at:=statement_timestamp(); NEW.exposed_at:=NULL; NEW.created_at:=NEW.assigned_at; RETURN NEW;
  ELSIF TG_OP='UPDATE' THEN IF NEW.experiment_id<>OLD.experiment_id OR NEW.arm_id<>OLD.arm_id OR NEW.unit_type<>OLD.unit_type OR NEW.unit_id<>OLD.unit_id OR NEW.assigned_at<>OLD.assigned_at OR NEW.created_at<>OLD.created_at THEN RAISE EXCEPTION 'experiment assignment identity is immutable' USING ERRCODE='42501'; END IF; IF OLD.exposed_at IS NOT NULL OR NEW.exposed_at IS NULL OR st<>'RUNNING' THEN RAISE EXCEPTION 'exposure may transition NULL -> timestamp exactly once while RUNNING' USING ERRCODE='42501'; END IF; NEW.exposed_at:=statement_timestamp(); RETURN NEW;
  ELSE RAISE EXCEPTION 'experiment assignment history cannot be deleted' USING ERRCODE='42501'; END IF;
 END IF; RETURN NEW;
END $$;

-- Round-9 new object/function privilege disposition.
REVOKE ALL ON TABLE accepted_edit_signatures FROM PUBLIC;
GRANT SELECT ON TABLE accepted_edit_signatures TO honor_app;
REVOKE INSERT,UPDATE,DELETE ON TABLE accepted_edit_signatures FROM honor_app;
-- accepted_edit_signatures INSERT occurs only through SECURITY INVOKER clip trigger under table-owner migration/runtime trigger privileges; direct app DML remains forbidden.
REVOKE ALL ON FUNCTION honor_jsonb_exact_keys(jsonb, text[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_jsonb_exact_keys(jsonb, text[]) TO honor_app;
REVOKE ALL ON FUNCTION honor_rfc3339_datetime(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_rfc3339_datetime(text) TO honor_app;
REVOKE ALL ON FUNCTION honor_absolute_uri(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_absolute_uri(text) TO honor_app;

-- ================================================================
-- C00 REPAIR ROUND 10 — RESTRICTION PLACEMENT / PROOF LINEAGE /
-- AUDIO-MANIFEST / POSTING-COMPLIANCE / EXPERIMENT-IDENTITY FREEZE
-- ================================================================

-- Immutable proof artifacts make restriction evidence referential rather than free-form.
CREATE TABLE restriction_proof_artifacts (
  id uuid PRIMARY KEY,
  proof_kind text NOT NULL CHECK (proof_kind IN ('RIGHTS_CAMPAIGN_LINK','SOURCE_ORIGIN','TRANSCRIPT_LEXICAL_SCAN','CONTENT_SAFETY_REVIEW','CLAIMS_EVIDENCE_REVIEW','EDIT_OPERATION_AUDIT','CAPTION_OVERLAY_AUDIT','EDIT_SIGNATURE_COMPARISON','OWNER_REVIEW')),
  restriction_code text NOT NULL CHECK (restriction_code IN ('CAMPAIGN_AUTHORIZED_SOURCE_ONLY','OWNER_OWNED_SOURCE_ONLY','NO_THIRD_PARTY_SOURCE','NO_PROFANITY','BRAND_SAFE_ONLY','NO_MISLEADING_CLAIMS','NO_CROP','NO_SPEED_CHANGE','NO_TEXT_OVERLAY','NO_REUSED_EDIT','UNIQUE_PER_ACCOUNT','UNIQUE_PER_CAMPAIGN')),
  campaign_id uuid NOT NULL REFERENCES campaigns(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  rule_snapshot_id uuid NOT NULL,
  candidate_id uuid NOT NULL REFERENCES candidates(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  source_id uuid NOT NULL REFERENCES sources(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  target_type text NOT NULL CHECK (target_type IN ('SOURCE','CANDIDATE','EDIT_PLAN','POSTING_RECOMMENDATION')),
  target_id uuid NOT NULL,
  recommendation_version integer NULL CHECK (recommendation_version IS NULL OR recommendation_version >= 1),
  subject_sha256 char(64) NOT NULL CHECK (subject_sha256 ~ '^[a-f0-9]{64}$'),
  evidence_id uuid NULL,
  evidence_sha256 char(64) NOT NULL CHECK (evidence_sha256 ~ '^[a-f0-9]{64}$'),
  result text NOT NULL CHECK (result IN ('COMPLIANT','VIOLATION','UNKNOWN')),
  owner_review_resolution_id uuid NULL REFERENCES owner_actions(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
  owner_resolution_sha256 char(64) NULL CHECK (owner_resolution_sha256 IS NULL OR owner_resolution_sha256 ~ '^[a-f0-9]{64}$'),
  evidenced_at timestamptz NOT NULL,
  proof_sha256 char(64) NOT NULL UNIQUE CHECK (proof_sha256 ~ '^[a-f0-9]{64}$'),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT fk_restriction_proof_rule_campaign FOREIGN KEY (rule_snapshot_id,campaign_id) REFERENCES campaign_terms_snapshots(id,campaign_id) ON DELETE RESTRICT ON UPDATE RESTRICT
);
CREATE INDEX idx_restriction_proof_context ON restriction_proof_artifacts(campaign_id,rule_snapshot_id,candidate_id,proof_kind,evidenced_at);

CREATE OR REPLACE FUNCTION honor_restriction_proof_artifact_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE expected_hash text; oa owner_actions%ROWTYPE; ores jsonb;
BEGIN
  NEW.created_at:=statement_timestamp();
  IF NEW.evidenced_at>NEW.created_at THEN RAISE EXCEPTION 'restriction proof evidence timestamp cannot be future of DB record creation' USING ERRCODE='23514'; END IF;
  expected_hash:=encode(digest(convert_to(jsonb_build_object(
    'id',NEW.id,'proof_kind',NEW.proof_kind,'restriction_code',NEW.restriction_code,'campaign_id',NEW.campaign_id,'rule_snapshot_id',NEW.rule_snapshot_id,
    'candidate_id',NEW.candidate_id,'source_id',NEW.source_id,'target_type',NEW.target_type,'target_id',NEW.target_id,
    'recommendation_version',NEW.recommendation_version,'subject_sha256',NEW.subject_sha256,'evidence_id',NEW.evidence_id,
    'evidence_sha256',NEW.evidence_sha256,'result',NEW.result,'owner_review_resolution_id',NEW.owner_review_resolution_id,'owner_resolution_sha256',NEW.owner_resolution_sha256,
    'evidenced_at',NEW.evidenced_at)::text,'UTF8'),'sha256'),'hex');
  IF NEW.proof_sha256 IS DISTINCT FROM expected_hash THEN RAISE EXCEPTION 'restriction proof artifact hash mismatch' USING ERRCODE='23514'; END IF;
  IF NEW.proof_kind='OWNER_REVIEW' THEN
    IF NEW.owner_review_resolution_id IS NULL OR NEW.owner_resolution_sha256 IS NULL THEN RAISE EXCEPTION 'OWNER_REVIEW proof requires owner action' USING ERRCODE='23514'; END IF;
    SELECT * INTO oa FROM owner_actions WHERE id=NEW.owner_review_resolution_id;
    IF oa.id IS NULL OR oa.status<>'RESOLVED' OR oa.resolved_at IS NULL THEN RAISE EXCEPTION 'OWNER_REVIEW proof requires existing RESOLVED owner action' USING ERRCODE='23514'; END IF;
    IF oa.resolved_at IS DISTINCT FROM NEW.evidenced_at THEN RAISE EXCEPTION 'OWNER_REVIEW proof evidence time must equal owner action resolved_at' USING ERRCODE='23514'; END IF;
    IF oa.resolution_sha256 IS NULL OR NEW.owner_resolution_sha256 IS DISTINCT FROM oa.resolution_sha256 THEN RAISE EXCEPTION 'OWNER_REVIEW proof must bind immutable owner-action resolution hash' USING ERRCODE='23514'; END IF;
    IF oa.action_type<>'CAMPAIGN_RULE' OR oa.entity_type<>'RESTRICTION_COMPLIANCE' OR oa.entity_id IS DISTINCT FROM NEW.candidate_id THEN RAISE EXCEPTION 'OWNER_REVIEW owner action entity/action context mismatch' USING ERRCODE='23514'; END IF;
    ores:=oa.resolution;
    IF ores IS NULL OR ores->>'resolution_type'<>'RESTRICTION_COMPLIANCE' OR ores->>'decision' IS DISTINCT FROM NEW.result OR ores->>'restriction_code' IS DISTINCT FROM NEW.restriction_code
       OR ores->>'campaign_id' IS DISTINCT FROM NEW.campaign_id::text OR ores->>'rule_snapshot_id' IS DISTINCT FROM NEW.rule_snapshot_id::text
       OR ores->>'candidate_id' IS DISTINCT FROM NEW.candidate_id::text OR ores->>'target_type' IS DISTINCT FROM NEW.target_type
       OR ores->>'target_id' IS DISTINCT FROM NEW.target_id::text OR ores->>'subject_sha256' IS DISTINCT FROM NEW.subject_sha256
    THEN RAISE EXCEPTION 'OWNER_REVIEW owner action resolution context mismatch' USING ERRCODE='23514'; END IF;
  ELSIF NEW.owner_review_resolution_id IS NOT NULL OR NEW.owner_resolution_sha256 IS NOT NULL THEN
    RAISE EXCEPTION 'owner review resolution id/hash forbidden for non-owner restriction proof' USING ERRCODE='23514';
  END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION honor_restriction_proof_artifact_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_restriction_proof_artifact_guard() TO honor_app;
DROP TRIGGER IF EXISTS honor_restriction_proof_artifact_guard_trigger ON restriction_proof_artifacts;
CREATE TRIGGER honor_restriction_proof_artifact_guard_trigger BEFORE INSERT ON restriction_proof_artifacts FOR EACH ROW EXECUTE FUNCTION honor_restriction_proof_artifact_guard();
DROP TRIGGER IF EXISTS honor_immutable_restriction_proof_artifacts ON restriction_proof_artifacts;
CREATE TRIGGER honor_immutable_restriction_proof_artifacts BEFORE UPDATE OR DELETE ON restriction_proof_artifacts FOR EACH ROW EXECUTE FUNCTION honor_reject_immutable_mutation();

-- Exact V1 code -> canonical rule-key placement and duplicate semantic-code rejection at seal.
CREATE OR REPLACE FUNCTION honor_round10_restriction_placement_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE r record; c jsonb; expected_key text; seen text[]:=ARRAY[]::text[];
BEGIN
  FOR r IN
    SELECT rule_key,typed_value FROM campaign_rule_items
    WHERE campaign_id=NEW.campaign_id AND terms_snapshot_id=NEW.terms_snapshot_id AND schema_version=NEW.schema_version
      AND knowledge_state='KNOWN' AND rule_key IN ('source_material_restrictions','content_restrictions','editing_restrictions','uniqueness_rules')
  LOOP
    FOR c IN SELECT x FROM jsonb_array_elements(r.typed_value->'value'->'clauses') x LOOP
      expected_key:=CASE
        WHEN c->>'code' IN ('CAMPAIGN_AUTHORIZED_SOURCE_ONLY','OWNER_OWNED_SOURCE_ONLY','NO_THIRD_PARTY_SOURCE') THEN 'source_material_restrictions'
        WHEN c->>'code' IN ('NO_PROFANITY','BRAND_SAFE_ONLY','NO_MISLEADING_CLAIMS') THEN 'content_restrictions'
        WHEN c->>'code' IN ('NO_CROP','NO_SPEED_CHANGE','NO_TEXT_OVERLAY') THEN 'editing_restrictions'
        WHEN c->>'code' IN ('NO_REUSED_EDIT','UNIQUE_PER_ACCOUNT','UNIQUE_PER_CAMPAIGN') THEN 'uniqueness_rules'
        ELSE NULL END;
      IF expected_key IS NULL OR r.rule_key IS DISTINCT FROM expected_key THEN RAISE EXCEPTION 'restriction code % is under wrong canonical rule key %',c->>'code',r.rule_key USING ERRCODE='23514'; END IF;
      IF c->>'code'=ANY(seen) THEN RAISE EXCEPTION 'duplicate semantic restriction code in sealed rule set: %',c->>'code' USING ERRCODE='23514'; END IF;
      seen:=array_append(seen,c->>'code');
    END LOOP;
  END LOOP;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION honor_round10_restriction_placement_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_round10_restriction_placement_guard() TO honor_app;
DROP TRIGGER IF EXISTS honor_round10_restriction_placement_guard_trigger ON campaign_rule_set_commits;
CREATE TRIGGER honor_round10_restriction_placement_guard_trigger BEFORE INSERT ON campaign_rule_set_commits FOR EACH ROW EXECUTE FUNCTION honor_round10_restriction_placement_guard();

-- Exactly one non-contradictory compliance record per active clause; no extras; proof reference resolves to immutable artifact.
CREATE OR REPLACE FUNCTION honor_restriction_compliance_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE camp uuid; snap uuid; src uuid; src_sha text; rights_id uuid; rights_hash text; transcript_id uuid; transcript_hash text; clause jsonb; proof jsonb; pref jsonb; pa restriction_proof_artifacts%ROWTYPE; code text; effect text; scope text; primary_kind text; owner_ok boolean; n integer; active_count integer; edit_sig text; oa_resolved timestamptz;
BEGIN
  SELECT c.source_id,s.sha256,c.transcript_id,t.transcript_sha256,(NEW.plan_json->>'source_rights_id')::uuid,NEW.plan_json->>'source_rights_record_hash',ts.campaign_id,(NEW.plan_json->'campaign_rule_snapshot_ids'->>0)::uuid
    INTO src,src_sha,transcript_id,transcript_hash,rights_id,rights_hash,camp,snap
  FROM candidates c JOIN sources s ON s.id=c.source_id JOIN transcripts t ON t.id=c.transcript_id JOIN campaign_terms_snapshots ts ON ts.id=(NEW.plan_json->'campaign_rule_snapshot_ids'->>0)::uuid
  WHERE c.id=NEW.candidate_id;
  edit_sig:=NEW.plan_json->'output'->>'edit_signature_sha256';
  SELECT count(*) INTO active_count FROM campaign_rule_items r,LATERAL jsonb_array_elements(r.typed_value->'value'->'clauses') c
    WHERE r.campaign_id=camp AND r.terms_snapshot_id=snap AND r.knowledge_state='KNOWN' AND r.rule_key IN ('source_material_restrictions','content_restrictions','editing_restrictions','uniqueness_rules');
  IF jsonb_array_length(NEW.plan_json->'restriction_compliance')<>active_count THEN RAISE EXCEPTION 'restriction compliance must contain exactly one record for each active sealed clause and no extras' USING ERRCODE='23514'; END IF;
  IF EXISTS(
    SELECT 1 FROM jsonb_array_elements(NEW.plan_json->'restriction_compliance') p
    WHERE NOT EXISTS(
      SELECT 1 FROM campaign_rule_items r,LATERAL jsonb_array_elements(r.typed_value->'value'->'clauses') c
      WHERE r.campaign_id=camp AND r.terms_snapshot_id=snap AND r.knowledge_state='KNOWN' AND r.rule_key IN ('source_material_restrictions','content_restrictions','editing_restrictions','uniqueness_rules')
        AND c->>'code'=p->>'code' AND c->>'effect'=p->>'effect' AND c->>'scope'=p->>'scope'))
  THEN RAISE EXCEPTION 'restriction compliance contains entry absent from exact sealed rule set' USING ERRCODE='23514'; END IF;
  FOR clause IN
    SELECT c FROM campaign_rule_items r,LATERAL jsonb_array_elements(r.typed_value->'value'->'clauses') c
    WHERE r.campaign_id=camp AND r.terms_snapshot_id=snap AND r.knowledge_state='KNOWN' AND r.rule_key IN ('source_material_restrictions','content_restrictions','editing_restrictions','uniqueness_rules')
  LOOP
    code:=clause->>'code'; effect:=clause->>'effect'; scope:=clause->>'scope';
    SELECT count(*),(array_agg(z.value))[1] INTO n,proof FROM jsonb_array_elements(NEW.plan_json->'restriction_compliance') AS z(value) WHERE z.value->>'code'=code AND z.value->>'effect'=effect AND z.value->>'scope'=scope;
    IF n<>1 THEN RAISE EXCEPTION 'restriction clause requires exactly one canonical compliance record: %',code USING ERRCODE='23514'; END IF;
    IF proof->>'result'<>'COMPLIANT' THEN RAISE EXCEPTION 'restriction VIOLATION/UNKNOWN blocks production: %',code USING ERRCODE='23514'; END IF;
    primary_kind:=CASE code WHEN 'CAMPAIGN_AUTHORIZED_SOURCE_ONLY' THEN 'RIGHTS_CAMPAIGN_LINK' WHEN 'OWNER_OWNED_SOURCE_ONLY' THEN 'SOURCE_ORIGIN' WHEN 'NO_THIRD_PARTY_SOURCE' THEN 'SOURCE_ORIGIN' WHEN 'NO_PROFANITY' THEN 'TRANSCRIPT_LEXICAL_SCAN' WHEN 'BRAND_SAFE_ONLY' THEN 'CONTENT_SAFETY_REVIEW' WHEN 'NO_MISLEADING_CLAIMS' THEN 'CLAIMS_EVIDENCE_REVIEW' WHEN 'NO_CROP' THEN 'EDIT_OPERATION_AUDIT' WHEN 'NO_SPEED_CHANGE' THEN 'EDIT_OPERATION_AUDIT' WHEN 'NO_TEXT_OVERLAY' THEN 'CAPTION_OVERLAY_AUDIT' ELSE 'EDIT_SIGNATURE_COMPARISON' END;
    owner_ok:=code IN ('NO_PROFANITY','BRAND_SAFE_ONLY','NO_MISLEADING_CLAIMS');
    IF proof->>'proof_kind'='NONE' OR (proof->>'proof_kind'<>primary_kind AND NOT(owner_ok AND proof->>'proof_kind'='OWNER_REVIEW')) THEN RAISE EXCEPTION 'restriction COMPLIANT uses invalid proof kind for %',code USING ERRCODE='23514'; END IF;
    pref:=proof->'proof_reference';
    IF pref IS NULL OR jsonb_typeof(pref)<>'object' OR pref->>'proof_id' IS NULL THEN RAISE EXCEPTION 'restriction COMPLIANT requires structured proof artifact reference for %',code USING ERRCODE='23514'; END IF;
    SELECT * INTO pa FROM restriction_proof_artifacts WHERE id=(pref->>'proof_id')::uuid;
    IF pa.id IS NULL THEN RAISE EXCEPTION 'restriction proof_reference does not resolve to immutable proof artifact' USING ERRCODE='23514'; END IF;
    IF pref->>'proof_kind' IS DISTINCT FROM pa.proof_kind OR pref->>'restriction_code' IS DISTINCT FROM pa.restriction_code OR pref->>'proof_sha256' IS DISTINCT FROM pa.proof_sha256 OR pref->>'target_type' IS DISTINCT FROM pa.target_type OR pref->>'target_id' IS DISTINCT FROM pa.target_id::text OR pref->>'subject_sha256' IS DISTINCT FROM pa.subject_sha256 OR (pref->>'evidenced_at')::timestamptz IS DISTINCT FROM pa.evidenced_at OR pref->>'result' IS DISTINCT FROM pa.result THEN RAISE EXCEPTION 'restriction proof_reference fields do not match immutable proof artifact' USING ERRCODE='23514'; END IF;
    IF pa.proof_kind IS DISTINCT FROM proof->>'proof_kind' OR pa.restriction_code IS DISTINCT FROM code OR pa.result<>'COMPLIANT' OR pa.campaign_id IS DISTINCT FROM camp OR pa.rule_snapshot_id IS DISTINCT FROM snap OR pa.candidate_id IS DISTINCT FROM NEW.candidate_id OR pa.source_id IS DISTINCT FROM src OR pa.evidenced_at>NEW.committed_at THEN RAISE EXCEPTION 'restriction proof artifact lineage/time/result mismatch' USING ERRCODE='23514'; END IF;
    IF pa.proof_kind='OWNER_REVIEW' THEN
      IF NOT owner_ok OR proof->>'owner_review_resolution_id' IS DISTINCT FROM pa.owner_review_resolution_id::text THEN RAISE EXCEPTION 'owner review cannot resolve this restriction or resolution id mismatch' USING ERRCODE='23514'; END IF;
      SELECT resolved_at INTO oa_resolved FROM owner_actions WHERE id=pa.owner_review_resolution_id AND status='RESOLVED';
      IF oa_resolved IS NULL OR oa_resolved>NEW.committed_at THEN RAISE EXCEPTION 'owner review unresolved or resolved after consuming edit-plan commit' USING ERRCODE='23514'; END IF;
      IF pa.target_type<>'EDIT_PLAN' OR pa.target_id IS DISTINCT FROM NEW.id OR pa.subject_sha256 IS DISTINCT FROM NEW.plan_hash THEN RAISE EXCEPTION 'OWNER_REVIEW proof target/hash mismatch' USING ERRCODE='23514'; END IF;
    ELSE
      IF proof->>'owner_review_resolution_id' IS NOT NULL THEN RAISE EXCEPTION 'owner review resolution id forbidden for non-owner proof' USING ERRCODE='23514'; END IF;
      IF pa.proof_kind='RIGHTS_CAMPAIGN_LINK' AND (pa.target_type<>'SOURCE' OR pa.target_id IS DISTINCT FROM src OR pa.evidence_id IS DISTINCT FROM rights_id OR pa.subject_sha256 IS DISTINCT FROM rights_hash OR pa.evidence_sha256 IS DISTINCT FROM rights_hash OR NOT EXISTS(SELECT 1 FROM source_rights_campaigns rc WHERE rc.source_rights_id=rights_id AND rc.campaign_id=camp)) THEN RAISE EXCEPTION 'RIGHTS_CAMPAIGN_LINK proof target/hash mismatch' USING ERRCODE='23514'; END IF;
      IF pa.proof_kind='SOURCE_ORIGIN' AND (pa.target_type<>'SOURCE' OR pa.target_id IS DISTINCT FROM src OR pa.evidence_id IS DISTINCT FROM src OR pa.subject_sha256 IS DISTINCT FROM src_sha OR pa.evidence_sha256 IS DISTINCT FROM src_sha) THEN RAISE EXCEPTION 'SOURCE_ORIGIN proof target/hash mismatch' USING ERRCODE='23514'; END IF;
      IF pa.proof_kind='TRANSCRIPT_LEXICAL_SCAN' AND (pa.target_type<>'CANDIDATE' OR pa.target_id IS DISTINCT FROM NEW.candidate_id OR pa.evidence_id IS DISTINCT FROM transcript_id OR pa.subject_sha256 IS DISTINCT FROM transcript_hash OR pa.evidence_sha256 IS DISTINCT FROM transcript_hash) THEN RAISE EXCEPTION 'TRANSCRIPT_LEXICAL_SCAN proof target/hash mismatch' USING ERRCODE='23514'; END IF;
      IF pa.proof_kind IN ('CONTENT_SAFETY_REVIEW','CLAIMS_EVIDENCE_REVIEW','EDIT_OPERATION_AUDIT','CAPTION_OVERLAY_AUDIT') AND (pa.target_type<>'EDIT_PLAN' OR pa.target_id IS DISTINCT FROM NEW.id OR pa.subject_sha256 IS DISTINCT FROM NEW.plan_hash) THEN RAISE EXCEPTION 'edit-plan restriction proof target/hash mismatch' USING ERRCODE='23514'; END IF;
      IF pa.proof_kind='EDIT_SIGNATURE_COMPARISON' AND (pa.target_type<>'EDIT_PLAN' OR pa.target_id IS DISTINCT FROM NEW.id OR pa.subject_sha256 IS DISTINCT FROM edit_sig) THEN RAISE EXCEPTION 'EDIT_SIGNATURE_COMPARISON proof target/signature mismatch' USING ERRCODE='23514'; END IF;
    END IF;
    -- Deterministic source/edit predicates remain authoritative in addition to proof lineage.
    IF code='CAMPAIGN_AUTHORIZED_SOURCE_ONLY' AND NOT EXISTS(SELECT 1 FROM sources s JOIN source_rights r ON r.source_id=s.id JOIN source_rights_campaigns rc ON rc.source_rights_id=r.id AND rc.campaign_id=camp WHERE s.id=src AND s.origin_type='CAMPAIGN_AUTHORIZED' AND r.id=rights_id) THEN RAISE EXCEPTION 'campaign-authorized-source-only restriction failed' USING ERRCODE='23514'; END IF;
    IF code='OWNER_OWNED_SOURCE_ONLY' AND NOT EXISTS(SELECT 1 FROM sources WHERE id=src AND origin_type='OWNER_OWNED') THEN RAISE EXCEPTION 'owner-owned-source-only restriction failed' USING ERRCODE='23514'; END IF;
    IF code='NO_THIRD_PARTY_SOURCE' AND NOT EXISTS(SELECT 1 FROM sources WHERE id=src AND origin_type IN ('CAMPAIGN_AUTHORIZED','OWNER_OWNED')) THEN RAISE EXCEPTION 'no-third-party-source restriction failed' USING ERRCODE='23514'; END IF;
    IF code='NO_CROP' AND ((NEW.plan_json->'layout'->>'reframing_mode')<>'FIT_NO_CROP' OR jsonb_array_length(NEW.plan_json->'layout'->'punch_ins')<>0 OR EXISTS(SELECT 1 FROM jsonb_array_elements(NEW.plan_json->'layout'->'events') e WHERE (e->>'scale')::numeric<>1 OR (e->>'pan_x')::numeric<>0 OR (e->>'pan_y')::numeric<>0)) THEN RAISE EXCEPTION 'NO_CROP forbids crop/reframe/pan/zoom/punch-in' USING ERRCODE='23514'; END IF;
    IF code='NO_SPEED_CHANGE' AND EXISTS(SELECT 1 FROM jsonb_array_elements(NEW.plan_json->'timeline'->'cuts') c WHERE (c->>'playback_rate')::numeric<>1) THEN RAISE EXCEPTION 'NO_SPEED_CHANGE forbids playback-rate manipulation' USING ERRCODE='23514'; END IF;
    IF code='NO_TEXT_OVERLAY' AND ((NEW.plan_json->'captions'->>'enabled')::boolean OR jsonb_array_length(NEW.plan_json->'captions'->'chunks')<>0 OR jsonb_array_length(NEW.plan_json->'disclosure_render'->'overlay_events')<>0) THEN RAISE EXCEPTION 'NO_TEXT_OVERLAY includes burned captions and disclosure overlays' USING ERRCODE='23514'; END IF;
  END LOOP;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION honor_restriction_compliance_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_restriction_compliance_guard() TO honor_app;
DROP TRIGGER IF EXISTS honor_restriction_compliance_edit_trigger ON edit_plans;
CREATE TRIGGER honor_restriction_compliance_edit_trigger BEFORE INSERT ON edit_plans FOR EACH ROW EXECUTE FUNCTION honor_restriction_compliance_guard();

-- A null audio plan is a strict no-render-safe-assets lineage, not an authorization bypass.
CREATE OR REPLACE FUNCTION honor_render_audio_disclosure_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE ap audio_plans%ROWTYPE; c clips%ROWTYPE; q qc_runs%ROWTYPE; expected_music uuid; expected_sfx uuid[]; manifest_music uuid[]; manifest_sfx uuid[]; dr jsonb; ra_state knowledge_state_enum; ra jsonb; has_instructions boolean:=false;
BEGIN
  SELECT * INTO c FROM clips WHERE id=NEW.clip_id;
  SELECT * INTO q FROM qc_runs WHERE id=NEW.qc_run_id AND clip_id=NEW.clip_id;
  SELECT knowledge_state,typed_value->'value' INTO ra_state,ra FROM campaign_rule_items WHERE campaign_id=c.campaign_id AND terms_snapshot_id=c.rule_snapshot_id AND rule_key='render_audio_rules';
  IF ra_state='UNKNOWN' OR ra_state IS NULL THEN RAISE EXCEPTION 'UNKNOWN render audio cannot reach terminal manifest through null-plan or QC N/A' USING ERRCODE='23514'; END IF;
  has_instructions:=ra_state='KNOWN' AND jsonb_array_length(COALESCE(ra->'instructions','[]'::jsonb))>0;
  IF c.audio_plan_id IS NULL THEN
    IF NEW.audio_plan_id IS NOT NULL OR NEW.manifest_json->'audio_plan_id'<>'null'::jsonb OR NEW.manifest_json->'audio_plan_hash'<>'null'::jsonb OR NEW.manifest_json->'audio_plan_version'<>'null'::jsonb OR NEW.manifest_json->'audio_plan_schema_version'<>'null'::jsonb THEN RAISE EXCEPTION 'null clip audio plan requires null render-manifest audio identity' USING ERRCODE='23514'; END IF;
    IF jsonb_array_length(NEW.manifest_json->'render_safe_assets')<>0 THEN RAISE EXCEPTION 'null audio plan forbids all render-safe MUSIC/SFX manifest assets' USING ERRCODE='23514'; END IF;
    IF ra_state='NOT_APPLICABLE' THEN
      IF q.checks->'render_audio_compliance'->>'status' NOT IN ('NOT_APPLICABLE','PASS') THEN RAISE EXCEPTION 'no-plan NOT_APPLICABLE render-audio QC status invalid' USING ERRCODE='23514'; END IF;
    ELSE
      -- KNOWN rules, including PROHIBITED/conditional values and material instructions, require explicit PASS proving the silent/no-extra-audio render complied.
      IF q.checks->'render_audio_compliance'->>'status'<>'PASS' THEN RAISE EXCEPTION 'KNOWN render-audio rules require PASS QC even when audio_plan_id is null' USING ERRCODE='23514'; END IF;
      IF NEW.manifest_json->'audio_rule_compliance'->>'rule_snapshot_id' IS DISTINCT FROM c.rule_snapshot_id::text OR COALESCE((NEW.manifest_json->'audio_rule_compliance'->>'verified_exact_asset_match')::boolean,false) IS NOT TRUE OR NEW.manifest_json->'audio_rule_compliance'->>'planned_music_asset_id' IS NOT NULL OR jsonb_array_length(NEW.manifest_json->'audio_rule_compliance'->'planned_sfx_asset_ids')<>0 OR (has_instructions AND COALESCE((NEW.manifest_json->'audio_rule_compliance'->>'instructions_acknowledged')::boolean,false) IS NOT TRUE) THEN RAISE EXCEPTION 'null-plan KNOWN render-audio compliance evidence must prove zero assets and instructions' USING ERRCODE='23514'; END IF;
    END IF;
  ELSE
    SELECT * INTO ap FROM audio_plans WHERE id=c.audio_plan_id;
    expected_music:=ap.music_asset_id;
    SELECT COALESCE(array_agg(DISTINCT (e->>'asset_id')::uuid) FILTER (WHERE e->>'asset_id' IS NOT NULL),ARRAY[]::uuid[]) INTO expected_sfx FROM jsonb_array_elements(ap.sfx_events) e;
    SELECT COALESCE(array_agg((a->>'audio_asset_id')::uuid) FILTER (WHERE a->>'kind'='MUSIC'),ARRAY[]::uuid[]),COALESCE(array_agg((a->>'audio_asset_id')::uuid) FILTER (WHERE a->>'kind'='SFX'),ARRAY[]::uuid[]) INTO manifest_music,manifest_sfx FROM jsonb_array_elements(NEW.manifest_json->'render_safe_assets') a;
    IF (expected_music IS NULL AND cardinality(manifest_music)<>0) OR (expected_music IS NOT NULL AND (cardinality(manifest_music)<>1 OR manifest_music[1]<>expected_music)) OR (SELECT COALESCE(array_agg(x ORDER BY x),ARRAY[]::uuid[]) FROM unnest(expected_sfx) x) IS DISTINCT FROM (SELECT COALESCE(array_agg(x ORDER BY x),ARRAY[]::uuid[]) FROM unnest(manifest_sfx) x) THEN RAISE EXCEPTION 'render manifest assets must exactly match rule-compliant audio plan' USING ERRCODE='23514'; END IF;
    IF NEW.manifest_json->'audio_rule_compliance'->>'rule_snapshot_id' IS DISTINCT FROM ap.rule_compliance->>'rule_snapshot_id' OR COALESCE((NEW.manifest_json->'audio_rule_compliance'->>'verified_exact_asset_match')::boolean,false) IS NOT TRUE THEN RAISE EXCEPTION 'render manifest missing exact audio-rule compliance proof' USING ERRCODE='23514'; END IF;
    IF jsonb_array_length(ap.rule_compliance->'instructions')>0 AND (q.checks->'render_audio_compliance'->>'status')<>'PASS' THEN RAISE EXCEPTION 'operational render-audio instructions require PASS QC' USING ERRCODE='23514'; END IF;
  END IF;
  SELECT typed_value->'value' INTO dr FROM campaign_rule_items WHERE campaign_id=c.campaign_id AND terms_snapshot_id=c.rule_snapshot_id AND rule_key='disclosure_requirements' AND knowledge_state='KNOWN';
  IF dr IS NOT NULL AND COALESCE((dr->>'required')::boolean,false) AND dr->>'placement' IN ('VIDEO','BOTH') THEN
    IF (NEW.manifest_json->'campaign_disclosure'->>'rendered_in_video')::boolean IS NOT TRUE OR NEW.manifest_json->'campaign_disclosure'->>'placement' IS DISTINCT FROM dr->>'placement' OR (q.checks->'disclosure_video'->>'status')<>'PASS' THEN RAISE EXCEPTION 'VIDEO/BOTH disclosure requires render-manifest proof and PASS QC' USING ERRCODE='23514'; END IF;
  END IF;
  IF (q.checks->'campaign_restrictions'->>'status')<>'PASS' THEN RAISE EXCEPTION 'campaign restriction QC must PASS before terminal render manifest' USING ERRCODE='23514'; END IF;
  RETURN NEW;
END $$;

-- Canonical QC N/A is rule-driven; null audio_plan_id alone is never sufficient.
CREATE OR REPLACE FUNCTION honor_qc_truth_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE names text[]:=ARRAY['video_decode','audio_decode','dimensions_aspect','duration','black_frozen_frames','audio_presence','loudness_peak','caption_safe_bounds','face_crop','caption_overlap','cut_frequency','assets_present','watermark_absent','uniqueness','rules_rights_metadata','output_size','sha256_recorded','campaign_restrictions','disclosure_video','render_audio_compliance']; nm text; st text; derived boolean:=true; ep jsonb; c clips%ROWTYPE; uniq_required boolean; video_disc boolean; ra_state knowledge_state_enum;
BEGIN
 SELECT * INTO c FROM clips WHERE id=NEW.clip_id; SELECT plan_json INTO ep FROM edit_plans WHERE id=c.edit_plan_id;
 SELECT EXISTS(SELECT 1 FROM campaign_rule_items r,LATERAL jsonb_array_elements(r.typed_value->'value'->'clauses') x WHERE r.campaign_id=c.campaign_id AND r.terms_snapshot_id=c.rule_snapshot_id AND r.rule_key='uniqueness_rules' AND r.knowledge_state='KNOWN' AND x->>'code' IN ('NO_REUSED_EDIT','UNIQUE_PER_ACCOUNT','UNIQUE_PER_CAMPAIGN')) INTO uniq_required;
 SELECT COALESCE((typed_value->'value'->>'required')::boolean,false) AND typed_value->'value'->>'placement' IN ('VIDEO','BOTH') INTO video_disc FROM campaign_rule_items WHERE campaign_id=c.campaign_id AND terms_snapshot_id=c.rule_snapshot_id AND rule_key='disclosure_requirements' AND knowledge_state='KNOWN';
 SELECT knowledge_state INTO ra_state FROM campaign_rule_items WHERE campaign_id=c.campaign_id AND terms_snapshot_id=c.rule_snapshot_id AND rule_key='render_audio_rules';
 FOREACH nm IN ARRAY names LOOP
   IF NEW.checks->nm IS NULL THEN RAISE EXCEPTION 'canonical QC check missing: %',nm USING ERRCODE='23514'; END IF;
   IF COALESCE((NEW.checks->nm->>'hard_gate')::boolean,false) IS NOT TRUE THEN RAISE EXCEPTION 'caller hard_gate=false cannot weaken canonical QC: %',nm USING ERRCODE='23514'; END IF;
   st:=NEW.checks->nm->>'status';
   IF nm='render_audio_compliance' AND ra_state='UNKNOWN' THEN RAISE EXCEPTION 'UNKNOWN render-audio rule blocks QC/READY even with null audio plan' USING ERRCODE='23514'; END IF;
   IF st IN ('FAIL','WARN') THEN
     derived:=false; IF NULLIF(NEW.checks->nm->>'reason_code','') IS NULL OR NULLIF(NEW.checks->nm->>'detail','') IS NULL THEN RAISE EXCEPTION 'QC FAIL/WARN requires reason_code and detail: %',nm USING ERRCODE='23514'; END IF;
   ELSIF st='NOT_APPLICABLE' THEN
     IF nm IN ('caption_safe_bounds','caption_overlap') AND COALESCE((ep->'captions'->>'enabled')::boolean,false)=false AND jsonb_array_length(ep->'disclosure_render'->'overlay_events')=0 THEN NULL;
     ELSIF nm='uniqueness' AND NOT uniq_required THEN NULL;
     ELSIF nm='disclosure_video' AND NOT COALESCE(video_disc,false) THEN NULL;
     ELSIF nm='render_audio_compliance' AND c.audio_plan_id IS NULL AND ra_state='NOT_APPLICABLE' THEN NULL;
     ELSE RAISE EXCEPTION 'QC NOT_APPLICABLE is not permitted by canonical policy: %',nm USING ERRCODE='23514'; END IF;
   ELSIF st<>'PASS' THEN RAISE EXCEPTION 'invalid canonical QC status: %',nm USING ERRCODE='23514'; END IF;
 END LOOP;
 IF NEW.passed=true AND NOT derived THEN RAISE EXCEPTION 'qc_runs.passed=true contradicts canonical derived QC result' USING ERRCODE='23514'; END IF;
 NEW.passed:=derived; RETURN NEW;
END $$;

-- Centralized stage-consumption matrix mirrors HONOR_CAMPAIGN_RESTRICTION_SEMANTICS.json.
CREATE OR REPLACE FUNCTION honor_restriction_consumes_stage(p_code text, p_stage text) RETURNS boolean
LANGUAGE sql IMMUTABLE SECURITY INVOKER SET search_path=public,pg_catalog AS $$
  SELECT CASE p_code
    WHEN 'CAMPAIGN_AUTHORIZED_SOURCE_ONLY' THEN p_stage=ANY(ARRAY['allocation','edit_plan','render_qc'])
    WHEN 'OWNER_OWNED_SOURCE_ONLY' THEN p_stage=ANY(ARRAY['allocation','edit_plan','render_qc'])
    WHEN 'NO_THIRD_PARTY_SOURCE' THEN p_stage=ANY(ARRAY['allocation','edit_plan','render_qc'])
    WHEN 'NO_PROFANITY' THEN p_stage=ANY(ARRAY['edit_plan','render_qc'])
    WHEN 'BRAND_SAFE_ONLY' THEN p_stage=ANY(ARRAY['edit_plan','render_qc'])
    WHEN 'NO_MISLEADING_CLAIMS' THEN p_stage=ANY(ARRAY['edit_plan','render_qc','posting'])
    WHEN 'NO_CROP' THEN p_stage=ANY(ARRAY['edit_plan','render','qc'])
    WHEN 'NO_SPEED_CHANGE' THEN p_stage=ANY(ARRAY['edit_plan','render','qc'])
    WHEN 'NO_TEXT_OVERLAY' THEN p_stage=ANY(ARRAY['edit_plan','render','qc'])
    WHEN 'NO_REUSED_EDIT' THEN p_stage=ANY(ARRAY['edit_plan','render_qc'])
    WHEN 'UNIQUE_PER_ACCOUNT' THEN p_stage=ANY(ARRAY['allocation','render_qc'])
    WHEN 'UNIQUE_PER_CAMPAIGN' THEN p_stage=ANY(ARRAY['allocation','render_qc'])
    ELSE false END;
$$;
REVOKE ALL ON FUNCTION honor_restriction_consumes_stage(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_restriction_consumes_stage(text, text) TO honor_app;

-- Posting-copy revisions require fresh posting-stage evidence bound to exact version + content hash.
CREATE OR REPLACE FUNCTION honor_01_posting_restriction_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE content_changed boolean; content_hash text; clause jsonb; p jsonb; pref jsonb; pa restriction_proof_artifacts%ROWTYPE; code text; effect text; scope text; n integer; active_count integer; owner_ok boolean; oa_resolved timestamptz; cand uuid;
BEGIN
  content_changed := TG_OP='INSERT' OR NEW.posting_recommendation->'caption' IS DISTINCT FROM OLD.posting_recommendation->'caption' OR NEW.posting_recommendation->'platform_title' IS DISTINCT FROM OLD.posting_recommendation->'platform_title';
  IF NOT content_changed THEN RETURN NEW; END IF;
  content_hash:=encode(digest(convert_to(jsonb_build_object('caption',NEW.posting_recommendation->'caption','platform_title',NEW.posting_recommendation->'platform_title')::text,'UTF8'),'sha256'),'hex');
  SELECT candidate_id INTO cand FROM edit_plans WHERE id=NEW.edit_plan_id;
  SELECT count(*) INTO active_count FROM campaign_rule_items r,LATERAL jsonb_array_elements(r.typed_value->'value'->'clauses') c
    WHERE r.campaign_id=NEW.campaign_id AND r.terms_snapshot_id=NEW.rule_snapshot_id AND r.knowledge_state='KNOWN'
      AND honor_restriction_consumes_stage(c->>'code','posting');
  IF jsonb_array_length(NEW.posting_recommendation->'posting_restriction_compliance')<>active_count THEN RAISE EXCEPTION 'posting copy requires exactly one fresh compliance record per active posting-consuming restriction and no extras' USING ERRCODE='23514'; END IF;
  FOR clause IN SELECT c FROM campaign_rule_items r,LATERAL jsonb_array_elements(r.typed_value->'value'->'clauses') c WHERE r.campaign_id=NEW.campaign_id AND r.terms_snapshot_id=NEW.rule_snapshot_id AND r.knowledge_state='KNOWN' AND honor_restriction_consumes_stage(c->>'code','posting') LOOP
    code:=clause->>'code';effect:=clause->>'effect';scope:=clause->>'scope';
    SELECT count(*),(array_agg(z.value))[1] INTO n,p FROM jsonb_array_elements(NEW.posting_recommendation->'posting_restriction_compliance') AS z(value) WHERE z.value->>'code'=code AND z.value->>'effect'=effect AND z.value->>'scope'=scope;
    IF n<>1 OR p->>'result'<>'COMPLIANT' THEN RAISE EXCEPTION 'posting-stage restriction requires exactly one COMPLIANT fresh proof' USING ERRCODE='23514'; END IF;
    IF code='NO_MISLEADING_CLAIMS' AND p->>'proof_kind' NOT IN ('CLAIMS_EVIDENCE_REVIEW','OWNER_REVIEW') THEN RAISE EXCEPTION 'posting NO_MISLEADING_CLAIMS requires CLAIMS_EVIDENCE_REVIEW or permitted OWNER_REVIEW' USING ERRCODE='23514'; END IF;
    pref:=p->'proof_reference'; IF pref IS NULL OR jsonb_typeof(pref)<>'object' THEN RAISE EXCEPTION 'posting restriction requires structured proof artifact reference' USING ERRCODE='23514'; END IF;
    SELECT * INTO pa FROM restriction_proof_artifacts WHERE id=(pref->>'proof_id')::uuid;
    IF pa.id IS NULL OR pa.proof_kind IS DISTINCT FROM p->>'proof_kind' OR pa.restriction_code IS DISTINCT FROM code OR pa.result<>'COMPLIANT' OR pa.campaign_id IS DISTINCT FROM NEW.campaign_id OR pa.rule_snapshot_id IS DISTINCT FROM NEW.rule_snapshot_id OR pa.candidate_id IS DISTINCT FROM cand OR pa.source_id IS DISTINCT FROM NEW.source_id OR pa.target_type<>'POSTING_RECOMMENDATION' OR pa.target_id IS DISTINCT FROM NEW.id OR pa.recommendation_version IS DISTINCT FROM NEW.recommendation_version OR pa.subject_sha256 IS DISTINCT FROM content_hash OR pa.evidenced_at>NEW.recommendation_revised_at THEN RAISE EXCEPTION 'posting restriction proof is stale, unrelated, late, or bound to different recommendation content/version' USING ERRCODE='23514'; END IF;
    IF pref->>'proof_kind' IS DISTINCT FROM pa.proof_kind OR pref->>'restriction_code' IS DISTINCT FROM pa.restriction_code OR pref->>'proof_sha256' IS DISTINCT FROM pa.proof_sha256 OR pref->>'target_type' IS DISTINCT FROM pa.target_type OR pref->>'target_id' IS DISTINCT FROM pa.target_id::text OR pref->>'subject_sha256' IS DISTINCT FROM pa.subject_sha256 OR (pref->>'evidenced_at')::timestamptz IS DISTINCT FROM pa.evidenced_at OR pref->>'result' IS DISTINCT FROM pa.result THEN RAISE EXCEPTION 'posting proof_reference does not mirror immutable proof artifact' USING ERRCODE='23514'; END IF;
    IF pa.proof_kind='OWNER_REVIEW' THEN
      IF p->>'owner_review_resolution_id' IS DISTINCT FROM pa.owner_review_resolution_id::text THEN RAISE EXCEPTION 'posting owner review resolution mismatch' USING ERRCODE='23514'; END IF;
      SELECT resolved_at INTO oa_resolved FROM owner_actions WHERE id=pa.owner_review_resolution_id AND status='RESOLVED';
      IF oa_resolved IS NULL OR oa_resolved>NEW.recommendation_revised_at THEN RAISE EXCEPTION 'posting owner review unresolved or resolved after recommendation revision' USING ERRCODE='23514'; END IF;
    ELSIF p->>'owner_review_resolution_id' IS NOT NULL THEN RAISE EXCEPTION 'posting non-owner proof cannot carry owner review resolution id' USING ERRCODE='23514'; END IF;
  END LOOP;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION honor_01_posting_restriction_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_01_posting_restriction_guard() TO honor_app;
DROP TRIGGER IF EXISTS honor_01_posting_restriction_guard_trigger ON clips;
CREATE TRIGGER honor_01_posting_restriction_guard_trigger BEFORE INSERT OR UPDATE OF posting_recommendation ON clips FOR EACH ROW EXECUTE FUNCTION honor_01_posting_restriction_guard();

-- Arm identity is immutable; serialization checks the OLD parent on UPDATE/DELETE.
CREATE OR REPLACE FUNCTION honor_00_experiment_arm_identity_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE st experiment_status_enum; parent_id uuid;
BEGIN
  IF TG_OP='INSERT' THEN
    parent_id:=NEW.experiment_id; SELECT status INTO st FROM experiments WHERE id=parent_id FOR UPDATE;
    IF st IS DISTINCT FROM 'DRAFT' THEN RAISE EXCEPTION 'experiment arm insert requires DRAFT parent' USING ERRCODE='42501'; END IF;
    NEW.created_at:=statement_timestamp(); RETURN NEW;
  END IF;
  parent_id:=OLD.experiment_id; SELECT status INTO st FROM experiments WHERE id=parent_id FOR UPDATE;
  IF st IS DISTINCT FROM 'DRAFT' THEN RAISE EXCEPTION 'arm UPDATE/DELETE locks and checks existing OLD parent; mutation after DRAFT is forbidden' USING ERRCODE='42501'; END IF;
  IF TG_OP='DELETE' THEN RETURN OLD; END IF;
  IF NEW.id IS DISTINCT FROM OLD.id OR NEW.experiment_id IS DISTINCT FROM OLD.experiment_id OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN RAISE EXCEPTION 'experiment arm id/experiment_id/created_at are immutable' USING ERRCODE='42501'; END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION honor_00_experiment_arm_identity_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_00_experiment_arm_identity_guard() TO honor_app;
DROP TRIGGER IF EXISTS honor_00_experiment_arm_identity_guard_trigger ON experiment_arms;
CREATE TRIGGER honor_00_experiment_arm_identity_guard_trigger BEFORE INSERT OR UPDATE OR DELETE ON experiment_arms FOR EACH ROW EXECUTE FUNCTION honor_00_experiment_arm_identity_guard();

-- Round-10 proof artifact access. Append-only runtime writer; immutable trigger forbids mutation/deletion.
REVOKE ALL ON TABLE restriction_proof_artifacts FROM PUBLIC;
GRANT SELECT,INSERT ON TABLE restriction_proof_artifacts TO honor_app;
REVOKE UPDATE,DELETE ON TABLE restriction_proof_artifacts FROM honor_app;

-- ================================================================
-- C00 REPAIR ROUND 11 — POSTING-PROOF VERSIONING / RENDER-SAFE
-- AUDIO RIGHTS / OWNER-REVIEW IMMUTABILITY / EXPERIMENT IDENTITY
-- ================================================================

-- Owner actions are DB-timed state machines. OPEN is the only creation state;
-- OPEN may terminate once as RESOLVED or CANCELLED; terminal rows are immutable.
CREATE OR REPLACE FUNCTION honor_owner_action_resolution_valid(p_action_type text,p_entity_type text,p_entity_id uuid,p_resolution jsonb) RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE rt text; cid uuid; rsid uuid; cand uuid; tid uuid; sid uuid;
BEGIN
  IF p_resolution IS NULL OR jsonb_typeof(p_resolution)<>'object' THEN RETURN false; END IF;
  rt:=p_resolution->>'resolution_type';
  IF rt='RESTRICTION_COMPLIANCE' THEN
    IF p_action_type<>'CAMPAIGN_RULE' OR p_entity_type<>'RESTRICTION_COMPLIANCE' OR NOT honor_jsonb_exact_keys(p_resolution,ARRAY['resolution_type','decision','restriction_code','campaign_id','rule_snapshot_id','candidate_id','target_type','target_id','subject_sha256','note']) THEN RETURN false; END IF;
    IF p_resolution->>'decision' NOT IN ('COMPLIANT','VIOLATION','UNKNOWN') OR p_resolution->>'restriction_code' NOT IN ('NO_PROFANITY','BRAND_SAFE_ONLY','NO_MISLEADING_CLAIMS') OR p_resolution->>'target_type' NOT IN ('EDIT_PLAN','POSTING_RECOMMENDATION') OR COALESCE(p_resolution->>'subject_sha256','') !~ '^[a-f0-9]{64}$' THEN RETURN false; END IF;
    cid:=(p_resolution->>'campaign_id')::uuid; rsid:=(p_resolution->>'rule_snapshot_id')::uuid; cand:=(p_resolution->>'candidate_id')::uuid; tid:=(p_resolution->>'target_id')::uuid;
    IF cand IS DISTINCT FROM p_entity_id OR NOT EXISTS(SELECT 1 FROM campaign_terms_snapshots t WHERE t.id=rsid AND t.campaign_id=cid) OR NOT EXISTS(SELECT 1 FROM candidates c WHERE c.id=cand) THEN RETURN false; END IF;
    IF p_resolution->>'target_type'='EDIT_PLAN' AND NOT EXISTS(SELECT 1 FROM edit_plans e WHERE e.id=tid AND e.candidate_id=cand) THEN RETURN false; END IF;
    IF p_resolution->>'target_type'='POSTING_RECOMMENDATION' AND NOT EXISTS(SELECT 1 FROM clips c JOIN edit_plans e ON e.id=c.edit_plan_id WHERE c.id=tid AND c.campaign_id=cid AND c.rule_snapshot_id=rsid AND e.candidate_id=cand) THEN RETURN false; END IF;
    IF NOT EXISTS(
      SELECT 1 FROM campaign_rule_items r,LATERAL jsonb_array_elements(r.typed_value->'value'->'clauses') x
      WHERE r.campaign_id=cid AND r.terms_snapshot_id=rsid AND r.knowledge_state='KNOWN' AND x->>'code'=p_resolution->>'restriction_code'
    ) THEN RETURN false; END IF;
    IF p_resolution->'note' IS NOT NULL AND p_resolution->'note'<>'null'::jsonb AND jsonb_typeof(p_resolution->'note')<>'string' THEN RETURN false; END IF;
    RETURN true;
  ELSIF rt='CAMPAIGN_RULE' THEN
    IF p_action_type<>'CAMPAIGN_RULE' OR NOT honor_jsonb_exact_keys(p_resolution,ARRAY['resolution_type','decision','rule_key','typed_value','evidence_upload_id','note']) THEN RETURN false; END IF;
    IF p_resolution->>'decision' NOT IN ('CONFIRM_VALUE','MARK_UNKNOWN','MARK_NOT_APPLICABLE') OR COALESCE(p_resolution->>'rule_key','')='' THEN RETURN false; END IF;
    IF p_resolution->'note'<>'null'::jsonb AND jsonb_typeof(p_resolution->'note')<>'string' THEN RETURN false; END IF;
    IF p_resolution->'evidence_upload_id'<>'null'::jsonb THEN PERFORM (p_resolution->>'evidence_upload_id')::uuid; END IF;
    IF p_resolution->>'decision'='CONFIRM_VALUE' THEN
      IF p_resolution->'typed_value'='null'::jsonb OR NOT honor_campaign_rule_typed_value_valid(p_resolution->>'rule_key',p_resolution->'typed_value') THEN RETURN false; END IF;
    ELSIF p_resolution->'typed_value'<>'null'::jsonb THEN RETURN false;
    END IF;
    RETURN true;
  ELSIF rt='SOURCE_RIGHTS' THEN
    IF p_action_type<>'SOURCE_RIGHTS' OR p_entity_type<>'SOURCE' OR NOT honor_jsonb_exact_keys(p_resolution,ARRAY['resolution_type','decision','source_id','evidence_upload_id','note']) THEN RETURN false; END IF;
    IF p_resolution->>'decision' NOT IN ('AUTHORIZED','NOT_AUTHORIZED','UNKNOWN') OR (p_resolution->'note'<>'null'::jsonb AND jsonb_typeof(p_resolution->'note')<>'string') THEN RETURN false; END IF;
    IF p_resolution->'evidence_upload_id'<>'null'::jsonb THEN PERFORM (p_resolution->>'evidence_upload_id')::uuid; END IF;
    sid:=(p_resolution->>'source_id')::uuid; RETURN sid=p_entity_id AND EXISTS(SELECT 1 FROM sources WHERE id=sid);
  ELSIF rt='PROVIDER_SETUP' THEN
    RETURN p_action_type='PROVIDER_SETUP' AND honor_jsonb_exact_keys(p_resolution,ARRAY['resolution_type','decision','provider','note']) AND p_resolution->>'decision' IN ('COMPLETED','DEFERRED','BLOCKED') AND COALESCE(p_resolution->>'provider','')<>'' AND (p_resolution->'note'='null'::jsonb OR jsonb_typeof(p_resolution->'note')='string');
  ELSIF rt='GENERIC_CONFIRMATION' THEN
    RETURN p_action_type='GENERIC_CONFIRMATION' AND honor_jsonb_exact_keys(p_resolution,ARRAY['resolution_type','decision','note']) AND p_resolution->>'decision' IN ('CONFIRMED','DECLINED') AND (p_resolution->'note'='null'::jsonb OR jsonb_typeof(p_resolution->'note')='string');
  ELSIF rt='CANCELLED' THEN
    RETURN honor_jsonb_exact_keys(p_resolution,ARRAY['resolution_type','reason']) AND jsonb_typeof(p_resolution->'reason')='string' AND COALESCE(p_resolution->>'reason','')<>'';
  END IF;
  RETURN false;
EXCEPTION WHEN others THEN RETURN false;
END $$;
REVOKE ALL ON FUNCTION honor_owner_action_resolution_valid(text,text,uuid,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_owner_action_resolution_valid(text,text,uuid,jsonb) TO honor_app;

CREATE OR REPLACE FUNCTION honor_owner_action_lifecycle_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE t timestamptz:=statement_timestamp(); h text;
BEGIN
  IF TG_OP='DELETE' THEN RAISE EXCEPTION 'owner action history cannot be deleted' USING ERRCODE='42501'; END IF;
  IF TG_OP='INSERT' THEN
    IF NEW.status<>'OPEN' THEN RAISE EXCEPTION 'owner action creation must be OPEN' USING ERRCODE='23514'; END IF;
    NEW.requested_at:=t; NEW.created_at:=t; NEW.updated_at:=t; NEW.resolved_at:=NULL; NEW.cancelled_at:=NULL; NEW.resolution:=NULL; NEW.resolution_sha256:=NULL;
    RETURN NEW;
  END IF;
  IF NEW.id IS DISTINCT FROM OLD.id OR NEW.action_type IS DISTINCT FROM OLD.action_type OR NEW.title IS DISTINCT FROM OLD.title OR NEW.reason IS DISTINCT FROM OLD.reason OR NEW.entity_type IS DISTINCT FROM OLD.entity_type OR NEW.entity_id IS DISTINCT FROM OLD.entity_id OR NEW.requested_at IS DISTINCT FROM OLD.requested_at OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
    RAISE EXCEPTION 'owner action identity/context/request time are immutable' USING ERRCODE='42501';
  END IF;
  IF OLD.status IN ('RESOLVED','CANCELLED') THEN RAISE EXCEPTION 'terminal owner action is immutable and cannot reopen or change resolution' USING ERRCODE='42501'; END IF;
  IF NEW.status='OPEN' THEN
    IF NEW IS DISTINCT FROM OLD THEN RAISE EXCEPTION 'OPEN owner action may only transition to RESOLVED or CANCELLED' USING ERRCODE='42501'; END IF;
    RETURN NEW;
  ELSIF NEW.status='RESOLVED' THEN
    IF NOT honor_owner_action_resolution_valid(NEW.action_type,NEW.entity_type,NEW.entity_id,NEW.resolution) OR NEW.resolution->>'resolution_type'='CANCELLED' THEN RAISE EXCEPTION 'owner action resolution is not canonical for its exact context' USING ERRCODE='23514'; END IF;
    NEW.resolved_at:=t; NEW.cancelled_at:=NULL; NEW.resolution_sha256:=encode(digest(convert_to(NEW.resolution::text,'UTF8'),'sha256'),'hex'); NEW.updated_at:=t; RETURN NEW;
  ELSIF NEW.status='CANCELLED' THEN
    IF NOT honor_owner_action_resolution_valid(NEW.action_type,NEW.entity_type,NEW.entity_id,NEW.resolution) OR NEW.resolution->>'resolution_type'<>'CANCELLED' THEN RAISE EXCEPTION 'owner action cancellation requires canonical CANCELLED resolution' USING ERRCODE='23514'; END IF;
    NEW.resolved_at:=NULL; NEW.cancelled_at:=t; NEW.resolution_sha256:=encode(digest(convert_to(NEW.resolution::text,'UTF8'),'sha256'),'hex'); NEW.updated_at:=t; RETURN NEW;
  END IF;
  RAISE EXCEPTION 'invalid owner action status transition' USING ERRCODE='23514';
END $$;
REVOKE ALL ON FUNCTION honor_owner_action_lifecycle_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_owner_action_lifecycle_guard() TO honor_app;
DROP TRIGGER IF EXISTS honor_owner_action_lifecycle_trigger ON owner_actions;
CREATE TRIGGER honor_owner_action_lifecycle_trigger BEFORE INSERT OR UPDATE OR DELETE ON owner_actions FOR EACH ROW EXECUTE FUNCTION honor_owner_action_lifecycle_guard();

-- audio_assets rows are immutable material-rights versions. The only material
-- post-insert state change is one-way active TRUE -> FALSE revocation.
CREATE OR REPLACE FUNCTION honor_audio_allowed_uses_valid(v jsonb) RETURNS boolean
LANGUAGE plpgsql IMMUTABLE SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE x jsonb;
BEGIN
  IF NOT honor_jsonb_exact_keys(v,ARRAY['render_safe','commercial_use','derivative_edit','platforms','campaign_restriction','license_evidence_required']) THEN RETURN false; END IF;
  IF jsonb_typeof(v->'render_safe')<>'boolean' OR jsonb_typeof(v->'commercial_use')<>'boolean' OR jsonb_typeof(v->'derivative_edit')<>'boolean' OR jsonb_typeof(v->'platforms')<>'array' OR jsonb_typeof(v->'license_evidence_required')<>'boolean' THEN RETURN false; END IF;
  IF v->'campaign_restriction'<>'null'::jsonb AND jsonb_typeof(v->'campaign_restriction')<>'string' THEN RETURN false; END IF;
  IF jsonb_array_length(v->'platforms')>3 OR EXISTS(SELECT 1 FROM jsonb_array_elements(v->'platforms') a WHERE jsonb_typeof(a)<>'string' OR a#>>'{}' NOT IN ('TIKTOK','INSTAGRAM_REELS','YOUTUBE_SHORTS')) THEN RETURN false; END IF;
  IF (SELECT count(*) FROM jsonb_array_elements_text(v->'platforms'))<>(SELECT count(DISTINCT val) FROM jsonb_array_elements_text(v->'platforms') AS z(val)) THEN RETURN false; END IF;
  RETURN true;
EXCEPTION WHEN others THEN RETURN false;
END $$;
REVOKE ALL ON FUNCTION honor_audio_allowed_uses_valid(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_audio_allowed_uses_valid(jsonb) TO honor_app;

CREATE OR REPLACE FUNCTION honor_audio_asset_contract_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE req boolean; t timestamptz:=statement_timestamp();
BEGIN
  IF TG_OP='DELETE' THEN RAISE EXCEPTION 'audio asset versions cannot be deleted' USING ERRCODE='42501'; END IF;
  IF TG_OP='UPDATE' THEN
    IF NEW.id IS DISTINCT FROM OLD.id OR NEW.kind IS DISTINCT FROM OLD.kind OR NEW.storage_object_key IS DISTINCT FROM OLD.storage_object_key OR NEW.sha256 IS DISTINCT FROM OLD.sha256 OR NEW.license_name IS DISTINCT FROM OLD.license_name OR NEW.license_url_or_reference IS DISTINCT FROM OLD.license_url_or_reference OR NEW.license_evidence_object_key IS DISTINCT FROM OLD.license_evidence_object_key OR NEW.license_evidence_sha256 IS DISTINCT FROM OLD.license_evidence_sha256 OR NEW.provenance_notes IS DISTINCT FROM OLD.provenance_notes OR NEW.render_safe IS DISTINCT FROM OLD.render_safe OR NEW.attribution_required IS DISTINCT FROM OLD.attribution_required OR NEW.allowed_uses IS DISTINCT FROM OLD.allowed_uses OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
      RAISE EXCEPTION 'material audio asset identity/provenance/rights are immutable; create a new asset id/version' USING ERRCODE='42501';
    END IF;
    IF OLD.active=false AND NEW.active=true THEN RAISE EXCEPTION 'audio asset revocation is one-way; create a new asset version to restore eligibility' USING ERRCODE='42501'; END IF;
    NEW.updated_at:=t;
  ELSE
    NEW.created_at:=t; NEW.updated_at:=t;
  END IF;
  IF NOT honor_audio_allowed_uses_valid(NEW.allowed_uses) THEN RAISE EXCEPTION 'audio asset allowed_uses does not satisfy frozen V1 contract' USING ERRCODE='23514'; END IF;
  IF NEW.render_safe IS DISTINCT FROM ((NEW.allowed_uses->>'render_safe')::boolean) THEN RAISE EXCEPTION 'audio_assets.render_safe must exactly equal allowed_uses.render_safe' USING ERRCODE='23514'; END IF;
  req:=(NEW.allowed_uses->>'license_evidence_required')::boolean;
  IF req AND (NEW.license_evidence_object_key IS NULL OR NEW.license_evidence_sha256 IS NULL) THEN RAISE EXCEPTION 'license_evidence_required requires immutable license evidence object key and SHA-256' USING ERRCODE='23514'; END IF;
  IF COALESCE(btrim(NEW.license_name),'')='' OR COALESCE(btrim(NEW.license_url_or_reference),'')='' THEN RAISE EXCEPTION 'audio asset requires canonical license name/reference' USING ERRCODE='23514'; END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION honor_audio_asset_contract_guard() FROM PUBLIC;
DROP TRIGGER IF EXISTS honor_audio_asset_contract_trigger ON audio_assets;
CREATE TRIGGER honor_audio_asset_contract_trigger BEFORE INSERT OR UPDATE OR DELETE ON audio_assets FOR EACH ROW EXECUTE FUNCTION honor_audio_asset_contract_guard();

-- Exact automatic render-safe eligibility. Non-null campaign_restriction has no
-- V1 deterministic evaluator and therefore blocks automatic embedding.
CREATE OR REPLACE FUNCTION honor_audio_asset_render_eligible(p_asset_id uuid,p_platform platform_enum) RETURNS boolean
LANGUAGE sql STABLE SECURITY INVOKER SET search_path=public,pg_catalog AS $$
  SELECT COALESCE((
    SELECT a.active=true
      AND a.render_safe=true
      AND honor_audio_allowed_uses_valid(a.allowed_uses)
      AND (a.allowed_uses->>'render_safe')::boolean=true
      AND a.render_safe IS NOT DISTINCT FROM ((a.allowed_uses->>'render_safe')::boolean)
      AND (a.allowed_uses->>'commercial_use')::boolean=true
      AND (a.allowed_uses->>'derivative_edit')::boolean=true
      AND a.allowed_uses->'platforms' ? p_platform::text
      AND a.allowed_uses->'campaign_restriction'='null'::jsonb
      AND a.attribution_required=false
      AND (NOT (a.allowed_uses->>'license_evidence_required')::boolean OR (a.license_evidence_object_key IS NOT NULL AND a.license_evidence_sha256 IS NOT NULL))
    FROM audio_assets a WHERE a.id=p_asset_id
  ),false);
$$;
REVOKE ALL ON FUNCTION honor_audio_asset_render_eligible(uuid,platform_enum) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_audio_asset_render_eligible(uuid,platform_enum) TO honor_app;

-- Audio-plan commit consumes current asset rights for the exact target platform.
CREATE OR REPLACE FUNCTION honor_audio_plan_asset_rights_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE p platform_enum; e jsonb; aid uuid;
BEGIN
  p:=(NEW.platform_native_recommendation->>'platform')::platform_enum;
  IF NEW.music_asset_id IS NOT NULL AND (NOT EXISTS(SELECT 1 FROM audio_assets a WHERE a.id=NEW.music_asset_id AND a.kind='MUSIC') OR NOT honor_audio_asset_render_eligible(NEW.music_asset_id,p)) THEN RAISE EXCEPTION 'music asset fails exact V1 render-safe rights eligibility at audio-plan commit' USING ERRCODE='23514'; END IF;
  FOR e IN SELECT val FROM jsonb_array_elements(NEW.sfx_events) AS x(val) LOOP
    IF e->>'asset_id' IS NOT NULL THEN
      aid:=(e->>'asset_id')::uuid;
      IF NOT EXISTS(SELECT 1 FROM audio_assets a WHERE a.id=aid AND a.kind='SFX') OR NOT honor_audio_asset_render_eligible(aid,p) THEN RAISE EXCEPTION 'SFX asset fails exact V1 render-safe rights eligibility at audio-plan commit' USING ERRCODE='23514'; END IF;
    END IF;
  END LOOP;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION honor_audio_plan_asset_rights_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_audio_plan_asset_rights_guard() TO honor_app;
DROP TRIGGER IF EXISTS honor_audio_plan_asset_rights_trigger ON audio_plans;
CREATE TRIGGER honor_audio_plan_asset_rights_trigger BEFORE INSERT ON audio_plans FOR EACH ROW EXECUTE FUNCTION honor_audio_plan_asset_rights_guard();

-- Revoke-after-plan is rechecked before paid rendering starts.
CREATE OR REPLACE FUNCTION honor_render_start_audio_asset_rights_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE ap audio_plans%ROWTYPE; p platform_enum; e jsonb; aid uuid;
BEGIN
  IF TG_OP='UPDATE' AND OLD.state='PLANNED' AND NEW.state='RENDERING' AND NEW.audio_plan_id IS NOT NULL THEN
    SELECT * INTO ap FROM audio_plans WHERE id=NEW.audio_plan_id;
    SELECT platform INTO p FROM social_accounts WHERE id=NEW.social_account_id;
    IF ap.id IS NULL THEN RAISE EXCEPTION 'render start references missing audio plan' USING ERRCODE='23503'; END IF;
    IF ap.music_asset_id IS NOT NULL AND NOT honor_audio_asset_render_eligible(ap.music_asset_id,p) THEN RAISE EXCEPTION 'render start blocked: planned MUSIC asset is no longer eligible' USING ERRCODE='23514'; END IF;
    FOR e IN SELECT val FROM jsonb_array_elements(ap.sfx_events) AS x(val) LOOP IF e->>'asset_id' IS NOT NULL THEN aid:=(e->>'asset_id')::uuid; IF NOT honor_audio_asset_render_eligible(aid,p) THEN RAISE EXCEPTION 'render start blocked: planned SFX asset is no longer eligible' USING ERRCODE='23514'; END IF; END IF; END LOOP;
  END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION honor_render_start_audio_asset_rights_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_render_start_audio_asset_rights_guard() TO honor_app;
DROP TRIGGER IF EXISTS honor_render_start_audio_asset_rights_trigger ON clips;
CREATE TRIGGER honor_render_start_audio_asset_rights_trigger BEFORE UPDATE OF state ON clips FOR EACH ROW EXECUTE FUNCTION honor_render_start_audio_asset_rights_guard();

-- Terminal render admission verifies current eligibility and exact immutable
-- asset UUID/kind/SHA/license provenance against the committed plan.
CREATE OR REPLACE FUNCTION honor_render_manifest_audio_asset_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE c clips%ROWTYPE; ap audio_plans%ROWTYPE; p platform_enum; m jsonb; a audio_assets%ROWTYPE; aid uuid; expected_count integer; actual_count integer; expected_sfx integer; actual_distinct integer;
BEGIN
  SELECT * INTO c FROM clips WHERE id=NEW.clip_id;
  IF c.id IS NULL THEN RAISE EXCEPTION 'render manifest clip missing' USING ERRCODE='23503'; END IF;
  SELECT platform INTO p FROM social_accounts WHERE id=c.social_account_id;
  IF c.audio_plan_id IS NULL THEN
    IF NEW.audio_plan_id IS NOT NULL OR NEW.manifest_json->'audio_plan_id'<>'null'::jsonb OR NEW.manifest_json->'audio_plan_schema_version'<>'null'::jsonb OR NEW.manifest_json->'audio_plan_version'<>'null'::jsonb OR NEW.manifest_json->'audio_plan_hash'<>'null'::jsonb OR jsonb_array_length(NEW.manifest_json->'render_safe_assets')<>0 THEN RAISE EXCEPTION 'null audio plan requires null audio identity and zero render-safe assets' USING ERRCODE='23514'; END IF;
    IF NEW.manifest_json->'audio_rule_compliance'->>'rule_snapshot_id' IS DISTINCT FROM c.rule_snapshot_id::text OR NEW.manifest_json->'audio_rule_compliance'->>'planned_music_asset_id' IS NOT NULL OR jsonb_array_length(NEW.manifest_json->'audio_rule_compliance'->'planned_sfx_asset_ids')<>0 OR COALESCE((NEW.manifest_json->'audio_rule_compliance'->>'verified_exact_asset_match')::boolean,false) IS NOT TRUE THEN RAISE EXCEPTION 'null audio manifest cannot claim planned MUSIC/SFX and must bind exact clip rule snapshot' USING ERRCODE='23514'; END IF;
    RETURN NEW;
  END IF;
  SELECT * INTO ap FROM audio_plans WHERE id=c.audio_plan_id;
  IF ap.id IS NULL OR NEW.audio_plan_id IS DISTINCT FROM ap.id OR NEW.manifest_json->>'audio_plan_id' IS DISTINCT FROM ap.id::text OR (NEW.manifest_json->>'audio_plan_schema_version')::integer IS DISTINCT FROM ap.schema_version OR (NEW.manifest_json->>'audio_plan_version')::integer IS DISTINCT FROM ap.plan_version OR NEW.manifest_json->>'audio_plan_hash' IS DISTINCT FROM ap.plan_hash THEN RAISE EXCEPTION 'render manifest audio identity must exactly match committed audio plan' USING ERRCODE='23514'; END IF;
  SELECT count(DISTINCT (e->>'asset_id')::uuid) FILTER (WHERE e->>'asset_id' IS NOT NULL) INTO expected_sfx FROM jsonb_array_elements(ap.sfx_events) e;
  expected_count:=expected_sfx + CASE WHEN ap.music_asset_id IS NULL THEN 0 ELSE 1 END;
  actual_count:=jsonb_array_length(NEW.manifest_json->'render_safe_assets');
  SELECT count(DISTINCT x->>'audio_asset_id') INTO actual_distinct FROM jsonb_array_elements(NEW.manifest_json->'render_safe_assets') x;
  IF actual_count<>expected_count OR actual_distinct<>actual_count THEN RAISE EXCEPTION 'render manifest must contain each planned render-safe asset exactly once' USING ERRCODE='23514'; END IF;
  FOR m IN SELECT val FROM jsonb_array_elements(NEW.manifest_json->'render_safe_assets') AS x(val) LOOP
    aid:=(m->>'audio_asset_id')::uuid; SELECT * INTO a FROM audio_assets WHERE id=aid;
    IF a.id IS NULL OR m->>'kind' IS DISTINCT FROM a.kind::text OR m->>'sha256' IS DISTINCT FROM a.sha256 OR m->>'license_reference' IS DISTINCT FROM a.license_url_or_reference THEN RAISE EXCEPTION 'render manifest audio asset UUID/kind/SHA/license must mirror immutable canonical asset version' USING ERRCODE='23514'; END IF;
    IF NOT honor_audio_asset_render_eligible(aid,p) THEN RAISE EXCEPTION 'render manifest blocked: baked audio asset is not currently V1 eligible' USING ERRCODE='23514'; END IF;
    IF a.kind='MUSIC' AND aid IS DISTINCT FROM ap.music_asset_id THEN RAISE EXCEPTION 'manifest MUSIC asset is not exact committed audio-plan MUSIC' USING ERRCODE='23514'; END IF;
    IF a.kind='SFX' AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(ap.sfx_events) e WHERE e->>'asset_id'=aid::text) THEN RAISE EXCEPTION 'manifest SFX asset is not present in committed audio plan' USING ERRCODE='23514'; END IF;
  END LOOP;
  IF ap.music_asset_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(NEW.manifest_json->'render_safe_assets') x WHERE x->>'kind'='MUSIC' AND x->>'audio_asset_id'=ap.music_asset_id::text) THEN RAISE EXCEPTION 'planned MUSIC missing from render manifest' USING ERRCODE='23514'; END IF;
  IF EXISTS(SELECT 1 FROM (SELECT DISTINCT e->>'asset_id' aid FROM jsonb_array_elements(ap.sfx_events) e WHERE e->>'asset_id' IS NOT NULL) q WHERE NOT EXISTS(SELECT 1 FROM jsonb_array_elements(NEW.manifest_json->'render_safe_assets') x WHERE x->>'kind'='SFX' AND x->>'audio_asset_id'=q.aid)) THEN RAISE EXCEPTION 'planned SFX missing from render manifest' USING ERRCODE='23514'; END IF;
  IF NEW.manifest_json->'audio_rule_compliance'->>'rule_snapshot_id' IS DISTINCT FROM c.rule_snapshot_id::text OR NEW.manifest_json->'audio_rule_compliance'->>'planned_music_asset_id' IS DISTINCT FROM CASE WHEN ap.music_asset_id IS NULL THEN NULL ELSE ap.music_asset_id::text END
     OR (SELECT COALESCE(array_agg(v ORDER BY v),ARRAY[]::text[]) FROM (SELECT DISTINCT e->>'asset_id' v FROM jsonb_array_elements(ap.sfx_events) e WHERE e->>'asset_id' IS NOT NULL) q) IS DISTINCT FROM (SELECT COALESCE(array_agg(v ORDER BY v),ARRAY[]::text[]) FROM jsonb_array_elements_text(NEW.manifest_json->'audio_rule_compliance'->'planned_sfx_asset_ids') z(v))
  THEN RAISE EXCEPTION 'render manifest audio_rule_compliance does not mirror committed plan/rule snapshot' USING ERRCODE='23514'; END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION honor_render_manifest_audio_asset_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_render_manifest_audio_asset_guard() TO honor_app;
DROP TRIGGER IF EXISTS honor_render_manifest_audio_asset_guard_trigger ON render_manifests;
CREATE TRIGGER honor_render_manifest_audio_asset_guard_trigger BEFORE INSERT ON render_manifests FOR EACH ROW EXECUTE FUNCTION honor_render_manifest_audio_asset_guard();

-- Option A: every material posting recommendation version gets a fresh proof
-- artifact bound to that exact DB-authored recommendation_version. If caption/title
-- did not change, the new proof binds the same canonical claim-content hash.
CREATE OR REPLACE FUNCTION honor_01_posting_restriction_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE content_hash text; clause jsonb; p jsonb; pref jsonb; pa restriction_proof_artifacts%ROWTYPE; code text; effect text; scope text; n integer; active_count integer; oa_resolved timestamptz; cand uuid;
BEGIN
  IF TG_OP='UPDATE' AND NEW.posting_recommendation IS NOT DISTINCT FROM OLD.posting_recommendation THEN RETURN NEW; END IF;
  content_hash:=encode(digest(convert_to(jsonb_build_object('caption',NEW.posting_recommendation->'caption','platform_title',NEW.posting_recommendation->'platform_title')::text,'UTF8'),'sha256'),'hex');
  SELECT candidate_id INTO cand FROM edit_plans WHERE id=NEW.edit_plan_id;
  SELECT count(*) INTO active_count FROM campaign_rule_items r,LATERAL jsonb_array_elements(r.typed_value->'value'->'clauses') c
    WHERE r.campaign_id=NEW.campaign_id AND r.terms_snapshot_id=NEW.rule_snapshot_id AND r.knowledge_state='KNOWN' AND honor_restriction_consumes_stage(c->>'code','posting');
  IF jsonb_array_length(NEW.posting_recommendation->'posting_restriction_compliance')<>active_count THEN RAISE EXCEPTION 'every recommendation version requires exactly one compliance record per active posting-consuming restriction and no extras' USING ERRCODE='23514'; END IF;
  FOR clause IN SELECT c FROM campaign_rule_items r,LATERAL jsonb_array_elements(r.typed_value->'value'->'clauses') c WHERE r.campaign_id=NEW.campaign_id AND r.terms_snapshot_id=NEW.rule_snapshot_id AND r.knowledge_state='KNOWN' AND honor_restriction_consumes_stage(c->>'code','posting') LOOP
    code:=clause->>'code';effect:=clause->>'effect';scope:=clause->>'scope';
    SELECT count(*),(array_agg(z.value))[1] INTO n,p FROM jsonb_array_elements(NEW.posting_recommendation->'posting_restriction_compliance') AS z(value) WHERE z.value->>'code'=code AND z.value->>'effect'=effect AND z.value->>'scope'=scope;
    IF n<>1 OR p->>'result'<>'COMPLIANT' THEN RAISE EXCEPTION 'posting-stage restriction requires exactly one COMPLIANT proof for exact recommendation version' USING ERRCODE='23514'; END IF;
    IF code='NO_MISLEADING_CLAIMS' AND p->>'proof_kind' NOT IN ('CLAIMS_EVIDENCE_REVIEW','OWNER_REVIEW') THEN RAISE EXCEPTION 'posting NO_MISLEADING_CLAIMS requires CLAIMS_EVIDENCE_REVIEW or permitted OWNER_REVIEW' USING ERRCODE='23514'; END IF;
    pref:=p->'proof_reference'; IF pref IS NULL OR jsonb_typeof(pref)<>'object' THEN RAISE EXCEPTION 'posting restriction requires structured proof artifact reference' USING ERRCODE='23514'; END IF;
    SELECT * INTO pa FROM restriction_proof_artifacts WHERE id=(pref->>'proof_id')::uuid;
    IF pa.id IS NULL OR pa.proof_kind IS DISTINCT FROM p->>'proof_kind' OR pa.restriction_code IS DISTINCT FROM code OR pa.result<>'COMPLIANT' OR pa.campaign_id IS DISTINCT FROM NEW.campaign_id OR pa.rule_snapshot_id IS DISTINCT FROM NEW.rule_snapshot_id OR pa.candidate_id IS DISTINCT FROM cand OR pa.source_id IS DISTINCT FROM NEW.source_id OR pa.target_type<>'POSTING_RECOMMENDATION' OR pa.target_id IS DISTINCT FROM NEW.id OR pa.recommendation_version IS DISTINCT FROM NEW.recommendation_version OR pa.subject_sha256 IS DISTINCT FROM content_hash OR pa.evidenced_at>NEW.recommendation_revised_at THEN RAISE EXCEPTION 'posting proof must bind exact current recommendation version/content hash and precede DB revision time' USING ERRCODE='23514'; END IF;
    IF pref->>'proof_kind' IS DISTINCT FROM pa.proof_kind OR pref->>'restriction_code' IS DISTINCT FROM pa.restriction_code OR pref->>'proof_sha256' IS DISTINCT FROM pa.proof_sha256 OR pref->>'target_type' IS DISTINCT FROM pa.target_type OR pref->>'target_id' IS DISTINCT FROM pa.target_id::text OR pref->>'subject_sha256' IS DISTINCT FROM pa.subject_sha256 OR (pref->>'evidenced_at')::timestamptz IS DISTINCT FROM pa.evidenced_at OR pref->>'result' IS DISTINCT FROM pa.result THEN RAISE EXCEPTION 'posting proof_reference does not mirror immutable proof artifact' USING ERRCODE='23514'; END IF;
    IF pa.proof_kind='OWNER_REVIEW' THEN
      IF p->>'owner_review_resolution_id' IS DISTINCT FROM pa.owner_review_resolution_id::text THEN RAISE EXCEPTION 'posting owner review resolution mismatch' USING ERRCODE='23514'; END IF;
      SELECT resolved_at INTO oa_resolved FROM owner_actions WHERE id=pa.owner_review_resolution_id AND status='RESOLVED';
      IF oa_resolved IS NULL OR oa_resolved>NEW.recommendation_revised_at THEN RAISE EXCEPTION 'posting owner review unresolved or resolved after recommendation revision' USING ERRCODE='23514'; END IF;
    ELSIF p->>'owner_review_resolution_id' IS NOT NULL THEN RAISE EXCEPTION 'posting non-owner proof cannot carry owner review resolution id' USING ERRCODE='23514'; END IF;
  END LOOP;
  RETURN NEW;
END $$;

-- Explicit experiment/assignment primary identity immutability; no incidental FK
-- is relied on. Existing history guard still owns DB-authored exposure time.
CREATE OR REPLACE FUNCTION honor_00_experiment_row_identity_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
BEGIN
  IF TG_TABLE_NAME='experiments' AND TG_OP='UPDATE' THEN
    IF NEW.id IS DISTINCT FROM OLD.id OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN RAISE EXCEPTION 'experiments.id and experiments.created_at are immutable' USING ERRCODE='42501'; END IF;
  ELSIF TG_TABLE_NAME='experiment_assignments' AND TG_OP='UPDATE' THEN
    IF NEW.id IS DISTINCT FROM OLD.id THEN RAISE EXCEPTION 'experiment_assignments.id is immutable; exposure may not rewrite assignment identity' USING ERRCODE='42501'; END IF;
  END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION honor_00_experiment_row_identity_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_00_experiment_row_identity_guard() TO honor_app;
DROP TRIGGER IF EXISTS honor_00_experiment_row_identity_guard_experiments ON experiments;
CREATE TRIGGER honor_00_experiment_row_identity_guard_experiments BEFORE UPDATE ON experiments FOR EACH ROW EXECUTE FUNCTION honor_00_experiment_row_identity_guard();
DROP TRIGGER IF EXISTS honor_00_experiment_row_identity_guard_assignments ON experiment_assignments;
CREATE TRIGGER honor_00_experiment_row_identity_guard_assignments BEFORE UPDATE ON experiment_assignments FOR EACH ROW EXECUTE FUNCTION honor_00_experiment_row_identity_guard();

-- Round-11 function privilege normalization (canonical signature formatting used by validator).
REVOKE ALL ON FUNCTION honor_owner_action_resolution_valid(text, text, uuid, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_owner_action_resolution_valid(text, text, uuid, jsonb) TO honor_app;
REVOKE ALL ON FUNCTION honor_owner_action_lifecycle_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_owner_action_lifecycle_guard() TO honor_app;
REVOKE ALL ON FUNCTION honor_audio_allowed_uses_valid(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_audio_allowed_uses_valid(jsonb) TO honor_app;
REVOKE ALL ON FUNCTION honor_audio_asset_contract_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_audio_asset_contract_guard() TO honor_app;
REVOKE ALL ON FUNCTION honor_audio_asset_render_eligible(uuid, platform_enum) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_audio_asset_render_eligible(uuid, platform_enum) TO honor_app;
REVOKE ALL ON FUNCTION honor_audio_plan_asset_rights_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_audio_plan_asset_rights_guard() TO honor_app;
REVOKE ALL ON FUNCTION honor_render_start_audio_asset_rights_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_render_start_audio_asset_rights_guard() TO honor_app;
REVOKE ALL ON FUNCTION honor_render_manifest_audio_asset_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_render_manifest_audio_asset_guard() TO honor_app;
REVOKE ALL ON FUNCTION honor_00_experiment_row_identity_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_00_experiment_row_identity_guard() TO honor_app;

-- ============================================================================
-- ROUND 12: PRECOMMIT OWNER-REVIEW SATISFIABILITY / ARCHIVE-INVENTORY FREEZE
-- ============================================================================
-- OWNER_REVIEW restriction evidence binds a reserved future target UUID/version/hash.
-- The target row does not need to exist at resolution; final consumption is exact and non-retroactive.
ALTER TABLE restriction_proof_artifacts ADD COLUMN target_version integer NULL CHECK (target_version IS NULL OR target_version>=1);

CREATE OR REPLACE FUNCTION honor_owner_action_resolution_valid(p_action_type text,p_entity_type text,p_entity_id uuid,p_resolution jsonb) RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE rt text; cid uuid; rsid uuid; cand uuid; tid uuid; sid uuid; tv integer; code text; stage text;
BEGIN
  IF p_resolution IS NULL OR jsonb_typeof(p_resolution)<>'object' THEN RETURN false; END IF;
  rt:=p_resolution->>'resolution_type';
  IF rt='RESTRICTION_COMPLIANCE' THEN
    IF p_action_type<>'CAMPAIGN_RULE' OR p_entity_type<>'RESTRICTION_COMPLIANCE' OR NOT honor_jsonb_exact_keys(p_resolution,ARRAY['resolution_type','review_phase','decision','restriction_code','campaign_id','rule_snapshot_id','candidate_id','target_type','target_id','target_version','subject_sha256','note']) THEN RETURN false; END IF;
    IF p_resolution->>'review_phase'<>'PRECOMMIT' OR p_resolution->>'decision' NOT IN ('COMPLIANT','VIOLATION','UNKNOWN') OR p_resolution->>'restriction_code' NOT IN ('NO_PROFANITY','BRAND_SAFE_ONLY','NO_MISLEADING_CLAIMS') OR p_resolution->>'target_type' NOT IN ('EDIT_PLAN','POSTING_RECOMMENDATION') OR COALESCE(p_resolution->>'subject_sha256','') !~ '^[a-f0-9]{64}$' OR jsonb_typeof(p_resolution->'target_version')<>'number' THEN RETURN false; END IF;
    cid:=(p_resolution->>'campaign_id')::uuid; rsid:=(p_resolution->>'rule_snapshot_id')::uuid; cand:=(p_resolution->>'candidate_id')::uuid; tid:=(p_resolution->>'target_id')::uuid; tv:=(p_resolution->>'target_version')::integer; code:=p_resolution->>'restriction_code';
    IF tv<1 OR cand IS DISTINCT FROM p_entity_id THEN RETURN false; END IF;
    SELECT c.source_id INTO sid FROM candidates c JOIN sources s ON s.id=c.source_id WHERE c.id=cand;
    IF sid IS NULL OR NOT EXISTS(SELECT 1 FROM campaigns c WHERE c.id=cid) OR NOT EXISTS(SELECT 1 FROM campaign_terms_snapshots t WHERE t.id=rsid AND t.campaign_id=cid) OR NOT EXISTS(SELECT 1 FROM campaign_rule_set_commits sc WHERE sc.campaign_id=cid AND sc.terms_snapshot_id=rsid AND sc.schema_version=1 AND sc.rule_count=32) THEN RETURN false; END IF;
    IF NOT EXISTS(SELECT 1 FROM campaign_rule_items r,LATERAL jsonb_array_elements(r.typed_value->'value'->'clauses') x WHERE r.campaign_id=cid AND r.terms_snapshot_id=rsid AND r.rule_key='content_restrictions' AND r.knowledge_state='KNOWN' AND x->>'code'=code) THEN RETURN false; END IF;
    stage:=CASE p_resolution->>'target_type' WHEN 'EDIT_PLAN' THEN 'edit_plan' WHEN 'POSTING_RECOMMENDATION' THEN 'posting' ELSE NULL END;
    IF stage IS NULL OR NOT honor_restriction_consumes_stage(code,stage) THEN RETURN false; END IF;
    -- PRECOMMIT intentionally does NOT query edit_plans/clips by target_id. The UUID is reserved and consumption later proves exact target/version/hash.
    IF p_resolution->'note' IS NOT NULL AND p_resolution->'note'<>'null'::jsonb AND jsonb_typeof(p_resolution->'note')<>'string' THEN RETURN false; END IF;
    RETURN true;
  ELSIF rt='CAMPAIGN_RULE' THEN
    IF p_action_type<>'CAMPAIGN_RULE' OR NOT honor_jsonb_exact_keys(p_resolution,ARRAY['resolution_type','decision','rule_key','typed_value','evidence_upload_id','note']) THEN RETURN false; END IF;
    IF p_resolution->>'decision' NOT IN ('CONFIRM_VALUE','MARK_UNKNOWN','MARK_NOT_APPLICABLE') OR COALESCE(p_resolution->>'rule_key','')='' THEN RETURN false; END IF;
    IF p_resolution->'note'<>'null'::jsonb AND jsonb_typeof(p_resolution->'note')<>'string' THEN RETURN false; END IF;
    IF p_resolution->'evidence_upload_id'<>'null'::jsonb THEN PERFORM (p_resolution->>'evidence_upload_id')::uuid; END IF;
    IF p_resolution->>'decision'='CONFIRM_VALUE' THEN IF p_resolution->'typed_value'='null'::jsonb OR NOT honor_campaign_rule_typed_value_valid(p_resolution->>'rule_key',p_resolution->'typed_value') THEN RETURN false; END IF;
    ELSIF p_resolution->'typed_value'<>'null'::jsonb THEN RETURN false; END IF;
    RETURN true;
  ELSIF rt='SOURCE_RIGHTS' THEN
    IF p_action_type<>'SOURCE_RIGHTS' OR p_entity_type<>'SOURCE' OR NOT honor_jsonb_exact_keys(p_resolution,ARRAY['resolution_type','decision','source_id','evidence_upload_id','note']) THEN RETURN false; END IF;
    IF p_resolution->>'decision' NOT IN ('AUTHORIZED','NOT_AUTHORIZED','UNKNOWN') OR (p_resolution->'note'<>'null'::jsonb AND jsonb_typeof(p_resolution->'note')<>'string') THEN RETURN false; END IF;
    IF p_resolution->'evidence_upload_id'<>'null'::jsonb THEN PERFORM (p_resolution->>'evidence_upload_id')::uuid; END IF;
    sid:=(p_resolution->>'source_id')::uuid; RETURN sid=p_entity_id AND EXISTS(SELECT 1 FROM sources WHERE id=sid);
  ELSIF rt='PROVIDER_SETUP' THEN
    RETURN p_action_type='PROVIDER_SETUP' AND honor_jsonb_exact_keys(p_resolution,ARRAY['resolution_type','decision','provider','note']) AND p_resolution->>'decision' IN ('COMPLETED','DEFERRED','BLOCKED') AND COALESCE(p_resolution->>'provider','')<>'' AND (p_resolution->'note'='null'::jsonb OR jsonb_typeof(p_resolution->'note')='string');
  ELSIF rt='GENERIC_CONFIRMATION' THEN
    RETURN p_action_type='GENERIC_CONFIRMATION' AND honor_jsonb_exact_keys(p_resolution,ARRAY['resolution_type','decision','note']) AND p_resolution->>'decision' IN ('CONFIRMED','DECLINED') AND (p_resolution->'note'='null'::jsonb OR jsonb_typeof(p_resolution->'note')='string');
  ELSIF rt='CANCELLED' THEN
    RETURN honor_jsonb_exact_keys(p_resolution,ARRAY['resolution_type','reason']) AND jsonb_typeof(p_resolution->'reason')='string' AND COALESCE(p_resolution->>'reason','')<>'';
  END IF;
  RETURN false;
EXCEPTION WHEN others THEN RETURN false;
END $$;
REVOKE ALL ON FUNCTION honor_owner_action_resolution_valid(text, text, uuid, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_owner_action_resolution_valid(text, text, uuid, jsonb) TO honor_app;

CREATE OR REPLACE FUNCTION honor_restriction_proof_artifact_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE expected_hash text; oa owner_actions%ROWTYPE; ores jsonb;
BEGIN
  NEW.created_at:=statement_timestamp();
  IF NEW.evidenced_at>NEW.created_at THEN RAISE EXCEPTION 'restriction proof evidence timestamp cannot be future of DB record creation' USING ERRCODE='23514'; END IF;
  expected_hash:=encode(digest(convert_to(jsonb_build_object(
    'id',NEW.id,'proof_kind',NEW.proof_kind,'restriction_code',NEW.restriction_code,'campaign_id',NEW.campaign_id,'rule_snapshot_id',NEW.rule_snapshot_id,
    'candidate_id',NEW.candidate_id,'source_id',NEW.source_id,'target_type',NEW.target_type,'target_id',NEW.target_id,'target_version',NEW.target_version,
    'recommendation_version',NEW.recommendation_version,'subject_sha256',NEW.subject_sha256,'evidence_id',NEW.evidence_id,
    'evidence_sha256',NEW.evidence_sha256,'result',NEW.result,'owner_review_resolution_id',NEW.owner_review_resolution_id,'owner_resolution_sha256',NEW.owner_resolution_sha256,
    'evidenced_at',NEW.evidenced_at)::text,'UTF8'),'sha256'),'hex');
  IF NEW.proof_sha256 IS DISTINCT FROM expected_hash THEN RAISE EXCEPTION 'restriction proof artifact hash mismatch' USING ERRCODE='23514'; END IF;
  IF NEW.proof_kind='OWNER_REVIEW' THEN
    IF NEW.owner_review_resolution_id IS NULL OR NEW.owner_resolution_sha256 IS NULL OR NEW.target_version IS NULL OR NEW.target_version<1 THEN RAISE EXCEPTION 'OWNER_REVIEW proof requires immutable owner action and PRECOMMIT target_version' USING ERRCODE='23514'; END IF;
    SELECT * INTO oa FROM owner_actions WHERE id=NEW.owner_review_resolution_id;
    IF oa.id IS NULL OR oa.status<>'RESOLVED' OR oa.resolved_at IS NULL THEN RAISE EXCEPTION 'OWNER_REVIEW proof requires existing RESOLVED owner action' USING ERRCODE='23514'; END IF;
    IF oa.resolved_at IS DISTINCT FROM NEW.evidenced_at THEN RAISE EXCEPTION 'OWNER_REVIEW proof evidence time must equal owner action resolved_at' USING ERRCODE='23514'; END IF;
    IF oa.resolution_sha256 IS NULL OR NEW.owner_resolution_sha256 IS DISTINCT FROM oa.resolution_sha256 THEN RAISE EXCEPTION 'OWNER_REVIEW proof must bind immutable owner-action resolution hash' USING ERRCODE='23514'; END IF;
    IF oa.action_type<>'CAMPAIGN_RULE' OR oa.entity_type<>'RESTRICTION_COMPLIANCE' OR oa.entity_id IS DISTINCT FROM NEW.candidate_id THEN RAISE EXCEPTION 'OWNER_REVIEW owner action entity/action context mismatch' USING ERRCODE='23514'; END IF;
    ores:=oa.resolution;
    IF ores IS NULL OR ores->>'resolution_type'<>'RESTRICTION_COMPLIANCE' OR ores->>'review_phase'<>'PRECOMMIT' OR ores->>'decision' IS DISTINCT FROM NEW.result OR ores->>'restriction_code' IS DISTINCT FROM NEW.restriction_code
       OR ores->>'campaign_id' IS DISTINCT FROM NEW.campaign_id::text OR ores->>'rule_snapshot_id' IS DISTINCT FROM NEW.rule_snapshot_id::text
       OR ores->>'candidate_id' IS DISTINCT FROM NEW.candidate_id::text OR ores->>'target_type' IS DISTINCT FROM NEW.target_type
       OR ores->>'target_id' IS DISTINCT FROM NEW.target_id::text OR (ores->>'target_version')::integer IS DISTINCT FROM NEW.target_version OR ores->>'subject_sha256' IS DISTINCT FROM NEW.subject_sha256
    THEN RAISE EXCEPTION 'OWNER_REVIEW owner action PRECOMMIT resolution context/version/hash mismatch' USING ERRCODE='23514'; END IF;
    IF NEW.target_type='POSTING_RECOMMENDATION' AND NEW.recommendation_version IS DISTINCT FROM NEW.target_version THEN RAISE EXCEPTION 'posting OWNER_REVIEW proof target_version must equal recommendation_version' USING ERRCODE='23514'; END IF;
    IF NEW.target_type='EDIT_PLAN' AND NEW.recommendation_version IS NOT NULL THEN RAISE EXCEPTION 'edit-plan OWNER_REVIEW proof cannot claim recommendation_version' USING ERRCODE='23514'; END IF;
  ELSE
    IF NEW.target_version IS NOT NULL THEN RAISE EXCEPTION 'target_version is reserved for OWNER_REVIEW proof artifacts in V1' USING ERRCODE='23514'; END IF;
    IF NEW.owner_review_resolution_id IS NOT NULL OR NEW.owner_resolution_sha256 IS NOT NULL THEN RAISE EXCEPTION 'owner review resolution id/hash forbidden for non-owner restriction proof' USING ERRCODE='23514'; END IF;
  END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION honor_restriction_proof_artifact_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_restriction_proof_artifact_guard() TO honor_app;

CREATE OR REPLACE FUNCTION honor_restriction_compliance_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE camp uuid; snap uuid; src uuid; src_sha text; rights_id uuid; rights_hash text; transcript_id uuid; transcript_hash text; clause jsonb; proof jsonb; pref jsonb; pa restriction_proof_artifacts%ROWTYPE; code text; effect text; scope text; primary_kind text; owner_ok boolean; n integer; active_count integer; edit_sig text; oa_resolved timestamptz; oa owner_actions%ROWTYPE; ores jsonb;
BEGIN
  SELECT c.source_id,s.sha256,c.transcript_id,t.transcript_sha256,(NEW.plan_json->>'source_rights_id')::uuid,NEW.plan_json->>'source_rights_record_hash',ts.campaign_id,(NEW.plan_json->'campaign_rule_snapshot_ids'->>0)::uuid
    INTO src,src_sha,transcript_id,transcript_hash,rights_id,rights_hash,camp,snap
  FROM candidates c JOIN sources s ON s.id=c.source_id JOIN transcripts t ON t.id=c.transcript_id JOIN campaign_terms_snapshots ts ON ts.id=(NEW.plan_json->'campaign_rule_snapshot_ids'->>0)::uuid
  WHERE c.id=NEW.candidate_id;
  edit_sig:=NEW.plan_json->'output'->>'edit_signature_sha256';
  SELECT count(*) INTO active_count FROM campaign_rule_items r,LATERAL jsonb_array_elements(r.typed_value->'value'->'clauses') c
    WHERE r.campaign_id=camp AND r.terms_snapshot_id=snap AND r.knowledge_state='KNOWN' AND r.rule_key IN ('source_material_restrictions','content_restrictions','editing_restrictions','uniqueness_rules');
  IF jsonb_array_length(NEW.plan_json->'restriction_compliance')<>active_count THEN RAISE EXCEPTION 'restriction compliance must contain exactly one record for each active sealed clause and no extras' USING ERRCODE='23514'; END IF;
  IF EXISTS(
    SELECT 1 FROM jsonb_array_elements(NEW.plan_json->'restriction_compliance') p
    WHERE NOT EXISTS(
      SELECT 1 FROM campaign_rule_items r,LATERAL jsonb_array_elements(r.typed_value->'value'->'clauses') c
      WHERE r.campaign_id=camp AND r.terms_snapshot_id=snap AND r.knowledge_state='KNOWN' AND r.rule_key IN ('source_material_restrictions','content_restrictions','editing_restrictions','uniqueness_rules')
        AND c->>'code'=p->>'code' AND c->>'effect'=p->>'effect' AND c->>'scope'=p->>'scope'))
  THEN RAISE EXCEPTION 'restriction compliance contains entry absent from exact sealed rule set' USING ERRCODE='23514'; END IF;
  FOR clause IN
    SELECT c FROM campaign_rule_items r,LATERAL jsonb_array_elements(r.typed_value->'value'->'clauses') c
    WHERE r.campaign_id=camp AND r.terms_snapshot_id=snap AND r.knowledge_state='KNOWN' AND r.rule_key IN ('source_material_restrictions','content_restrictions','editing_restrictions','uniqueness_rules')
  LOOP
    code:=clause->>'code'; effect:=clause->>'effect'; scope:=clause->>'scope';
    SELECT count(*),(array_agg(z.value))[1] INTO n,proof FROM jsonb_array_elements(NEW.plan_json->'restriction_compliance') AS z(value) WHERE z.value->>'code'=code AND z.value->>'effect'=effect AND z.value->>'scope'=scope;
    IF n<>1 THEN RAISE EXCEPTION 'restriction clause requires exactly one canonical compliance record: %',code USING ERRCODE='23514'; END IF;
    IF proof->>'result'<>'COMPLIANT' THEN RAISE EXCEPTION 'restriction VIOLATION/UNKNOWN blocks production: %',code USING ERRCODE='23514'; END IF;
    primary_kind:=CASE code WHEN 'CAMPAIGN_AUTHORIZED_SOURCE_ONLY' THEN 'RIGHTS_CAMPAIGN_LINK' WHEN 'OWNER_OWNED_SOURCE_ONLY' THEN 'SOURCE_ORIGIN' WHEN 'NO_THIRD_PARTY_SOURCE' THEN 'SOURCE_ORIGIN' WHEN 'NO_PROFANITY' THEN 'TRANSCRIPT_LEXICAL_SCAN' WHEN 'BRAND_SAFE_ONLY' THEN 'CONTENT_SAFETY_REVIEW' WHEN 'NO_MISLEADING_CLAIMS' THEN 'CLAIMS_EVIDENCE_REVIEW' WHEN 'NO_CROP' THEN 'EDIT_OPERATION_AUDIT' WHEN 'NO_SPEED_CHANGE' THEN 'EDIT_OPERATION_AUDIT' WHEN 'NO_TEXT_OVERLAY' THEN 'CAPTION_OVERLAY_AUDIT' ELSE 'EDIT_SIGNATURE_COMPARISON' END;
    owner_ok:=code IN ('NO_PROFANITY','BRAND_SAFE_ONLY','NO_MISLEADING_CLAIMS');
    IF proof->>'proof_kind'='NONE' OR (proof->>'proof_kind'<>primary_kind AND NOT(owner_ok AND proof->>'proof_kind'='OWNER_REVIEW')) THEN RAISE EXCEPTION 'restriction COMPLIANT uses invalid proof kind for %',code USING ERRCODE='23514'; END IF;
    pref:=proof->'proof_reference';
    IF pref IS NULL OR jsonb_typeof(pref)<>'object' OR pref->>'proof_id' IS NULL THEN RAISE EXCEPTION 'restriction COMPLIANT requires structured proof artifact reference for %',code USING ERRCODE='23514'; END IF;
    SELECT * INTO pa FROM restriction_proof_artifacts WHERE id=(pref->>'proof_id')::uuid;
    IF pa.id IS NULL THEN RAISE EXCEPTION 'restriction proof_reference does not resolve to immutable proof artifact' USING ERRCODE='23514'; END IF;
    IF pref->>'proof_kind' IS DISTINCT FROM pa.proof_kind OR pref->>'restriction_code' IS DISTINCT FROM pa.restriction_code OR pref->>'proof_sha256' IS DISTINCT FROM pa.proof_sha256 OR pref->>'target_type' IS DISTINCT FROM pa.target_type OR pref->>'target_id' IS DISTINCT FROM pa.target_id::text OR pref->>'subject_sha256' IS DISTINCT FROM pa.subject_sha256 OR (pref->>'evidenced_at')::timestamptz IS DISTINCT FROM pa.evidenced_at OR pref->>'result' IS DISTINCT FROM pa.result THEN RAISE EXCEPTION 'restriction proof_reference fields do not match immutable proof artifact' USING ERRCODE='23514'; END IF;
    IF pa.proof_kind='OWNER_REVIEW' AND (pref->>'target_version')::integer IS DISTINCT FROM pa.target_version THEN RAISE EXCEPTION 'OWNER_REVIEW proof_reference target_version mismatch' USING ERRCODE='23514'; END IF;
    IF pa.proof_kind IS DISTINCT FROM proof->>'proof_kind' OR pa.restriction_code IS DISTINCT FROM code OR pa.result<>'COMPLIANT' OR pa.campaign_id IS DISTINCT FROM camp OR pa.rule_snapshot_id IS DISTINCT FROM snap OR pa.candidate_id IS DISTINCT FROM NEW.candidate_id OR pa.source_id IS DISTINCT FROM src OR pa.evidenced_at>NEW.committed_at THEN RAISE EXCEPTION 'restriction proof artifact lineage/time/result mismatch' USING ERRCODE='23514'; END IF;
    IF pa.proof_kind='OWNER_REVIEW' THEN
      IF NOT owner_ok OR proof->>'owner_review_resolution_id' IS DISTINCT FROM pa.owner_review_resolution_id::text THEN RAISE EXCEPTION 'owner review cannot resolve this restriction or resolution id mismatch' USING ERRCODE='23514'; END IF;
      SELECT * INTO oa FROM owner_actions WHERE id=pa.owner_review_resolution_id AND status='RESOLVED'; ores:=oa.resolution; oa_resolved:=oa.resolved_at;
      IF oa.id IS NULL OR oa_resolved IS NULL OR oa_resolved>NEW.committed_at OR pa.created_at>NEW.committed_at THEN RAISE EXCEPTION 'owner review/proof unresolved, retroactive, or created after consuming edit-plan commit' USING ERRCODE='23514'; END IF;
      IF pa.target_type<>'EDIT_PLAN' OR pa.target_id IS DISTINCT FROM NEW.id OR pa.target_version IS DISTINCT FROM NEW.plan_version OR pa.subject_sha256 IS DISTINCT FROM NEW.plan_hash THEN RAISE EXCEPTION 'PRECOMMIT OWNER_REVIEW does not match exact edit-plan target/version/hash/context or was resolved after commit' USING ERRCODE='23514'; END IF;
      IF ores IS NULL OR ores->>'review_phase'<>'PRECOMMIT' OR ores->>'target_type'<>'EDIT_PLAN' OR ores->>'target_id' IS DISTINCT FROM NEW.id::text OR (ores->>'target_version')::integer IS DISTINCT FROM NEW.plan_version OR ores->>'subject_sha256' IS DISTINCT FROM NEW.plan_hash OR ores->>'campaign_id' IS DISTINCT FROM camp::text OR ores->>'rule_snapshot_id' IS DISTINCT FROM snap::text OR ores->>'candidate_id' IS DISTINCT FROM NEW.candidate_id::text OR ores->>'restriction_code' IS DISTINCT FROM code OR ores->>'decision'<>'COMPLIANT' OR pa.owner_resolution_sha256 IS DISTINCT FROM oa.resolution_sha256 THEN RAISE EXCEPTION 'PRECOMMIT OWNER_REVIEW owner resolution does not match exact edit-plan consumption context' USING ERRCODE='23514'; END IF;
    ELSE
      IF proof->>'owner_review_resolution_id' IS NOT NULL THEN RAISE EXCEPTION 'owner review resolution id forbidden for non-owner proof' USING ERRCODE='23514'; END IF;
      IF pa.proof_kind='RIGHTS_CAMPAIGN_LINK' AND (pa.target_type<>'SOURCE' OR pa.target_id IS DISTINCT FROM src OR pa.evidence_id IS DISTINCT FROM rights_id OR pa.subject_sha256 IS DISTINCT FROM rights_hash OR pa.evidence_sha256 IS DISTINCT FROM rights_hash OR NOT EXISTS(SELECT 1 FROM source_rights_campaigns rc WHERE rc.source_rights_id=rights_id AND rc.campaign_id=camp)) THEN RAISE EXCEPTION 'RIGHTS_CAMPAIGN_LINK proof target/hash mismatch' USING ERRCODE='23514'; END IF;
      IF pa.proof_kind='SOURCE_ORIGIN' AND (pa.target_type<>'SOURCE' OR pa.target_id IS DISTINCT FROM src OR pa.evidence_id IS DISTINCT FROM src OR pa.subject_sha256 IS DISTINCT FROM src_sha OR pa.evidence_sha256 IS DISTINCT FROM src_sha) THEN RAISE EXCEPTION 'SOURCE_ORIGIN proof target/hash mismatch' USING ERRCODE='23514'; END IF;
      IF pa.proof_kind='TRANSCRIPT_LEXICAL_SCAN' AND (pa.target_type<>'CANDIDATE' OR pa.target_id IS DISTINCT FROM NEW.candidate_id OR pa.evidence_id IS DISTINCT FROM transcript_id OR pa.subject_sha256 IS DISTINCT FROM transcript_hash OR pa.evidence_sha256 IS DISTINCT FROM transcript_hash) THEN RAISE EXCEPTION 'TRANSCRIPT_LEXICAL_SCAN proof target/hash mismatch' USING ERRCODE='23514'; END IF;
      IF pa.proof_kind IN ('CONTENT_SAFETY_REVIEW','CLAIMS_EVIDENCE_REVIEW','EDIT_OPERATION_AUDIT','CAPTION_OVERLAY_AUDIT') AND (pa.target_type<>'EDIT_PLAN' OR pa.target_id IS DISTINCT FROM NEW.id OR pa.subject_sha256 IS DISTINCT FROM NEW.plan_hash) THEN RAISE EXCEPTION 'edit-plan restriction proof target/hash mismatch' USING ERRCODE='23514'; END IF;
      IF pa.proof_kind='EDIT_SIGNATURE_COMPARISON' AND (pa.target_type<>'EDIT_PLAN' OR pa.target_id IS DISTINCT FROM NEW.id OR pa.subject_sha256 IS DISTINCT FROM edit_sig) THEN RAISE EXCEPTION 'EDIT_SIGNATURE_COMPARISON proof target/signature mismatch' USING ERRCODE='23514'; END IF;
    END IF;
    -- Deterministic source/edit predicates remain authoritative in addition to proof lineage.
    IF code='CAMPAIGN_AUTHORIZED_SOURCE_ONLY' AND NOT EXISTS(SELECT 1 FROM sources s JOIN source_rights r ON r.source_id=s.id JOIN source_rights_campaigns rc ON rc.source_rights_id=r.id AND rc.campaign_id=camp WHERE s.id=src AND s.origin_type='CAMPAIGN_AUTHORIZED' AND r.id=rights_id) THEN RAISE EXCEPTION 'campaign-authorized-source-only restriction failed' USING ERRCODE='23514'; END IF;
    IF code='OWNER_OWNED_SOURCE_ONLY' AND NOT EXISTS(SELECT 1 FROM sources WHERE id=src AND origin_type='OWNER_OWNED') THEN RAISE EXCEPTION 'owner-owned-source-only restriction failed' USING ERRCODE='23514'; END IF;
    IF code='NO_THIRD_PARTY_SOURCE' AND NOT EXISTS(SELECT 1 FROM sources WHERE id=src AND origin_type IN ('CAMPAIGN_AUTHORIZED','OWNER_OWNED')) THEN RAISE EXCEPTION 'no-third-party-source restriction failed' USING ERRCODE='23514'; END IF;
    IF code='NO_CROP' AND ((NEW.plan_json->'layout'->>'reframing_mode')<>'FIT_NO_CROP' OR jsonb_array_length(NEW.plan_json->'layout'->'punch_ins')<>0 OR EXISTS(SELECT 1 FROM jsonb_array_elements(NEW.plan_json->'layout'->'events') e WHERE (e->>'scale')::numeric<>1 OR (e->>'pan_x')::numeric<>0 OR (e->>'pan_y')::numeric<>0)) THEN RAISE EXCEPTION 'NO_CROP forbids crop/reframe/pan/zoom/punch-in' USING ERRCODE='23514'; END IF;
    IF code='NO_SPEED_CHANGE' AND EXISTS(SELECT 1 FROM jsonb_array_elements(NEW.plan_json->'timeline'->'cuts') c WHERE (c->>'playback_rate')::numeric<>1) THEN RAISE EXCEPTION 'NO_SPEED_CHANGE forbids playback-rate manipulation' USING ERRCODE='23514'; END IF;
    IF code='NO_TEXT_OVERLAY' AND ((NEW.plan_json->'captions'->>'enabled')::boolean OR jsonb_array_length(NEW.plan_json->'captions'->'chunks')<>0 OR jsonb_array_length(NEW.plan_json->'disclosure_render'->'overlay_events')<>0) THEN RAISE EXCEPTION 'NO_TEXT_OVERLAY includes burned captions and disclosure overlays' USING ERRCODE='23514'; END IF;
  END LOOP;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION honor_restriction_compliance_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_restriction_compliance_guard() TO honor_app;

CREATE OR REPLACE FUNCTION honor_01_posting_restriction_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=public,pg_catalog AS $$
DECLARE content_hash text; clause jsonb; p jsonb; pref jsonb; pa restriction_proof_artifacts%ROWTYPE; code text; effect text; scope text; n integer; active_count integer; oa_resolved timestamptz; cand uuid; oa owner_actions%ROWTYPE; ores jsonb;
BEGIN
  IF TG_OP='UPDATE' AND NEW.posting_recommendation IS NOT DISTINCT FROM OLD.posting_recommendation THEN RETURN NEW; END IF;
  content_hash:=encode(digest(convert_to(jsonb_build_object('caption',NEW.posting_recommendation->'caption','platform_title',NEW.posting_recommendation->'platform_title')::text,'UTF8'),'sha256'),'hex');
  SELECT candidate_id INTO cand FROM edit_plans WHERE id=NEW.edit_plan_id;
  SELECT count(*) INTO active_count FROM campaign_rule_items r,LATERAL jsonb_array_elements(r.typed_value->'value'->'clauses') c
    WHERE r.campaign_id=NEW.campaign_id AND r.terms_snapshot_id=NEW.rule_snapshot_id AND r.knowledge_state='KNOWN' AND honor_restriction_consumes_stage(c->>'code','posting');
  IF jsonb_array_length(NEW.posting_recommendation->'posting_restriction_compliance')<>active_count THEN RAISE EXCEPTION 'every recommendation version requires exactly one compliance record per active posting-consuming restriction and no extras' USING ERRCODE='23514'; END IF;
  FOR clause IN SELECT c FROM campaign_rule_items r,LATERAL jsonb_array_elements(r.typed_value->'value'->'clauses') c WHERE r.campaign_id=NEW.campaign_id AND r.terms_snapshot_id=NEW.rule_snapshot_id AND r.knowledge_state='KNOWN' AND honor_restriction_consumes_stage(c->>'code','posting') LOOP
    code:=clause->>'code';effect:=clause->>'effect';scope:=clause->>'scope';
    SELECT count(*),(array_agg(z.value))[1] INTO n,p FROM jsonb_array_elements(NEW.posting_recommendation->'posting_restriction_compliance') AS z(value) WHERE z.value->>'code'=code AND z.value->>'effect'=effect AND z.value->>'scope'=scope;
    IF n<>1 OR p->>'result'<>'COMPLIANT' THEN RAISE EXCEPTION 'posting-stage restriction requires exactly one COMPLIANT proof for exact recommendation version' USING ERRCODE='23514'; END IF;
    IF code='NO_MISLEADING_CLAIMS' AND p->>'proof_kind' NOT IN ('CLAIMS_EVIDENCE_REVIEW','OWNER_REVIEW') THEN RAISE EXCEPTION 'posting NO_MISLEADING_CLAIMS requires CLAIMS_EVIDENCE_REVIEW or permitted OWNER_REVIEW' USING ERRCODE='23514'; END IF;
    pref:=p->'proof_reference'; IF pref IS NULL OR jsonb_typeof(pref)<>'object' THEN RAISE EXCEPTION 'posting restriction requires structured proof artifact reference' USING ERRCODE='23514'; END IF;
    SELECT * INTO pa FROM restriction_proof_artifacts WHERE id=(pref->>'proof_id')::uuid;
    IF pa.id IS NULL OR pa.proof_kind IS DISTINCT FROM p->>'proof_kind' OR pa.restriction_code IS DISTINCT FROM code OR pa.result<>'COMPLIANT' OR pa.campaign_id IS DISTINCT FROM NEW.campaign_id OR pa.rule_snapshot_id IS DISTINCT FROM NEW.rule_snapshot_id OR pa.candidate_id IS DISTINCT FROM cand OR pa.source_id IS DISTINCT FROM NEW.source_id OR pa.target_type<>'POSTING_RECOMMENDATION' OR pa.target_id IS DISTINCT FROM NEW.id OR pa.target_version IS DISTINCT FROM NEW.recommendation_version OR pa.recommendation_version IS DISTINCT FROM NEW.recommendation_version OR pa.subject_sha256 IS DISTINCT FROM content_hash OR pa.evidenced_at>NEW.recommendation_revised_at OR pa.created_at>NEW.recommendation_revised_at THEN RAISE EXCEPTION 'posting proof must bind exact current recommendation target/version/content hash and predate DB revision time' USING ERRCODE='23514'; END IF;
    IF pref->>'proof_kind' IS DISTINCT FROM pa.proof_kind OR pref->>'restriction_code' IS DISTINCT FROM pa.restriction_code OR pref->>'proof_sha256' IS DISTINCT FROM pa.proof_sha256 OR pref->>'target_type' IS DISTINCT FROM pa.target_type OR pref->>'target_id' IS DISTINCT FROM pa.target_id::text OR pref->>'subject_sha256' IS DISTINCT FROM pa.subject_sha256 OR (pref->>'evidenced_at')::timestamptz IS DISTINCT FROM pa.evidenced_at OR pref->>'result' IS DISTINCT FROM pa.result THEN RAISE EXCEPTION 'posting proof_reference does not mirror immutable proof artifact' USING ERRCODE='23514'; END IF;
    IF pa.proof_kind='OWNER_REVIEW' AND (pref->>'target_version')::integer IS DISTINCT FROM pa.target_version THEN RAISE EXCEPTION 'posting OWNER_REVIEW proof_reference target_version mismatch' USING ERRCODE='23514'; END IF;
    IF pa.proof_kind='OWNER_REVIEW' THEN
      IF p->>'owner_review_resolution_id' IS DISTINCT FROM pa.owner_review_resolution_id::text THEN RAISE EXCEPTION 'posting owner review resolution mismatch' USING ERRCODE='23514'; END IF;
      SELECT * INTO oa FROM owner_actions WHERE id=pa.owner_review_resolution_id AND status='RESOLVED'; ores:=oa.resolution; oa_resolved:=oa.resolved_at;
      IF oa.id IS NULL OR oa_resolved IS NULL OR oa_resolved>NEW.recommendation_revised_at THEN RAISE EXCEPTION 'posting owner review unresolved or resolved after recommendation revision' USING ERRCODE='23514'; END IF;
      IF ores IS NULL OR ores->>'review_phase'<>'PRECOMMIT' OR ores->>'target_type'<>'POSTING_RECOMMENDATION' OR ores->>'target_id' IS DISTINCT FROM NEW.id::text OR (ores->>'target_version')::integer IS DISTINCT FROM NEW.recommendation_version OR ores->>'subject_sha256' IS DISTINCT FROM content_hash OR ores->>'campaign_id' IS DISTINCT FROM NEW.campaign_id::text OR ores->>'rule_snapshot_id' IS DISTINCT FROM NEW.rule_snapshot_id::text OR ores->>'candidate_id' IS DISTINCT FROM cand::text OR ores->>'restriction_code' IS DISTINCT FROM code OR ores->>'decision'<>'COMPLIANT' OR pa.owner_resolution_sha256 IS DISTINCT FROM oa.resolution_sha256 THEN RAISE EXCEPTION 'PRECOMMIT OWNER_REVIEW does not match exact posting target/version/hash/context or was resolved after recommendation revision' USING ERRCODE='23514'; END IF;
    ELSIF p->>'owner_review_resolution_id' IS NOT NULL THEN RAISE EXCEPTION 'posting non-owner proof cannot carry owner review resolution id' USING ERRCODE='23514'; END IF;
  END LOOP;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION honor_01_posting_restriction_guard() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION honor_01_posting_restriction_guard() TO honor_app;

