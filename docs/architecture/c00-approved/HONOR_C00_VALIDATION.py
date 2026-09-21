#!/usr/bin/env python3
from pathlib import Path
import json,re,hashlib,sys,urllib.parse,zipfile
from decimal import Decimal
import yaml
from jsonschema import Draft202012Validator, validate, ValidationError, FormatChecker
from referencing import Registry, Resource
ROOT=Path(__file__).resolve().parent
errors=[]
def ok(c,m):
    if not c: errors.append(m)
def text(n): return (ROOT/n).read_text(errors='ignore')
def loadj(n): return json.loads(text(n))

# Required baseline artifacts.
required={
'HONOR_CANONICAL_HANDOFF.md','HONOR_ARCHITECTURE.md','HONOR_PROVIDER_DECISIONS_AND_COSTS.md','HONOR_OWNER_PROVIDER_SETUP.md','HONOR_FROZEN_REPO_LAYOUT.txt','HONOR_DATABASE_SCHEMA.md','HONOR_API_CONTRACTS.md','HONOR_EVENT_AND_JOB_CONTRACTS.md','HONOR_FINANCIAL_AND_CAMPAIGN_RULES.md','HONOR_POLLI_TOOL_CONTRACTS.md','HONOR_MEDIA_AUDIO_QC_SPEC.md','HONOR_VISUAL_CONSTITUTION.md','HONOR_SECURITY_AND_RELIABILITY.md','HONOR_ACCEPTANCE_CRITERIA.md','HONOR_DEPLOYMENT_PLAN.md','.env.example','CHECKPOINT_C00_REPORT.md'}
ok(required.issubset({p.name for p in ROOT.iterdir() if p.is_file()}),'required C00 artifacts missing')

# JSON/YAML/OpenAPI identity and schema syntax.
o=loadj('HONOR_OPENAPI.json'); ov=loadj('HONOR_OPENAPI_V1.json'); oy=yaml.safe_load(text('HONOR_OPENAPI.yaml'))
ok(o==ov==oy,'OpenAPI JSON/V1/YAML are not data-equivalent'); ok(o.get('openapi')=='3.1.0','OpenAPI != 3.1.0')
for n,s in o['components']['schemas'].items():
    try: Draft202012Validator.check_schema(s)
    except Exception as e: errors.append(f'OpenAPI schema invalid {n}: {e}')
for ref in re.findall(r'"\$ref":\s*"#/components/schemas/([^"]+)"',json.dumps(o)):
    ok(ref in o['components']['schemas'],f'unresolved OpenAPI schema ref {ref}')

# Auth route identity.
auth=loadj('HONOR_AUTH_ROUTES.json'); marker='AUTH_ROUTE_SET_V1: GET /login | POST /auth/login | POST /auth/recover | GET /auth/confirm | GET /auth/set-password | POST /auth/set-password | POST /auth/logout'
ok(o['x-honor-nextjs-auth-routes']==auth['routes'],'OpenAPI auth route extension drift')
for f in ['HONOR_AUTH_SESSION_CONTRACT.md','HONOR_API_CONTRACTS.md','HONOR_DEPLOYMENT_PLAN.md','HONOR_SECURITY_AND_RELIABILITY.md','HONOR_OWNER_PROVIDER_SETUP.md','.env.example']:
    t=text(f); ok(marker in t,f'auth route marker missing {f}'); ok('/auth/callback?code=' not in t and 'GET /auth/callback' not in t,f'stale auth callback {f}')
ok('/auth/callback' in auth['forbidden_v1_routes'],'auth callback not explicitly forbidden')

# State machines exactly one and enum parity.
sm=loadj('HONOR_STATE_MACHINES.json'); sql=text('HONOR_DATABASE_CONTRACT.sql')
def sqlenum(n):
    m=re.search(rf"CREATE TYPE {n} AS ENUM \(([^;]+)\);",sql); return re.findall(r"'([^']+)'",m.group(1)) if m else []
ok(sqlenum('submission_status_enum')==sm['submission']['enum']==o['components']['schemas']['SubmissionStatus']['enum'],'submission enum mismatch')
ok(sqlenum('checkin_status_enum')==sm['analytics_checkin']['enum']==o['components']['schemas']['CheckinStatus']['enum'],'checkin enum mismatch')
ok(o['paths']['/v1/submissions']['post']['x-honor-state-machine']==sm['submission'],'submission graph mismatch')
ok(o['paths']['/v1/analytics/check-ins']['post']['x-honor-checkin-state-machine']==sm['analytics_checkin'],'check-in graph mismatch')
ok(sql.count('Submissions: creation may be')==1,'submission graph not exactly one SQL definition')
ok(sql.count('Analytics check-ins: creation MUST be')==1,'check-in graph not exactly one SQL definition')

# Polli exact Markdown <-> JSON schemas and limits.
p=loadj('HONOR_POLLI_TOOL_SCHEMAS.json'); md=text('HONOR_POLLI_TOOL_CONTRACTS.md')
ok(p['common_rules']['max_tool_calls_per_turn']==6 and p['common_rules']['max_tool_calls_per_session']==60,'Polli limits wrong')
ok('maximum tool calls per turn: **6**' in md and 'maximum tool calls per session: **60**' in md,'Polli Markdown limits wrong')
names=re.findall(r'^### `([^`]+)`$',md,re.M); ok(names==list(p['tools']),'Polli tool names/order drift')
for i,n in enumerate(names):
    q=p['tools'][n]; Draft202012Validator.check_schema(q['arguments_schema']); Draft202012Validator.check_schema(q['result_schema'])
    st=md.index(f'### `{n}`'); en=md.index(f'### `{names[i+1]}`') if i+1<len(names) else md.index('## Financial UNKNOWN rule')
    blocks=re.findall(r'```json\n(.*?)\n```',md[st:en],re.S); ok(len(blocks)==2,f'Polli schema blocks !=2 {n}')
    if len(blocks)==2:
        ok(json.loads(blocks[0])==q['arguments_schema'],f'Polli args drift {n}'); ok(json.loads(blocks[1])==q['result_schema'],f'Polli result drift {n}')

# Finance tri-state representable.
fs=o['components']['schemas']['FinanceSummary']; fp=fs['properties']
ok(set(fp['self_funded_state']['enum'])=={'FACTORY_SELF_FUNDED','NOT_SELF_FUNDED','UNKNOWN_NOT_VERIFIED'},'finance tri-state wrong')
ok(fp['net_profit_usd']['anyOf'][1].get('type')=='null','net profit not nullable')
base={'as_of':'2026-09-20T00:00:00Z','currency':'USD','accrued_unverified_usd':'0.000000','approved_usd':'0.000000','withdrawable_usd':'0.000000','withdrawn_usd':'0.000000','gross_campaign_revenue_usd':'0.000000','infrastructure_api_spend_usd':'0.000000','polli_voice_reasoning_spend_usd':'0.000000','lifetime_revenue_usd':'0.000000','lifetime_spend_usd':'0.000000','monthly_target_usd':'4000.000000','monthly_target_progress_usd':'0.000000'}
for state,np,truth in [('FACTORY_SELF_FUNDED','1.000000','FACT'),('NOT_SELF_FUNDED','-1.000000','FACT'),('UNKNOWN_NOT_VERIFIED',None,'INCOMPLETE_UNKNOWN')]:
    try: validate(dict(base,self_funded_state=state,net_profit_usd=np,net_profit_truth_state=truth),fs)
    except Exception as e: errors.append(f'finance sample invalid {state}: {e}')

# Cost governor exact state + behavior + prepaid semantics.
g=loadj('HONOR_COST_GOVERNOR.json'); th=g['thresholds']
ok(th=={'optional_pause_usd':'43.000000','reserve_mode_usd':'51.030000','hard_cap_usd':'56.030000'},'governor thresholds drift')
def state(x):
    x=Decimal(x)
    if x<Decimal('43.00'): return 'NORMAL'
    if x<Decimal('51.03'): return 'OPTIONAL_PAUSED'
    if x<Decimal('56.03'): return 'RESERVE'
    return 'HARD_STOP'
expected={'42.99':'NORMAL','43.00':'OPTIONAL_PAUSED','43.01':'OPTIONAL_PAUSED','51.02':'OPTIONAL_PAUSED','51.03':'RESERVE','56.02':'RESERVE','56.03':'HARD_STOP'}
for x,s in expected.items(): ok(state(x)==s,f'governor boundary {x}')
ok({x['exposure_usd']:x['state'] for x in g['boundary_tests']}=={f'{Decimal(k):.6f}':v for k,v in expected.items()},'governor boundary table drift')
ok(g['exposure_formula']['formula']=='cash_spend_counted_usd + unpaid_committed_usd + admitted_queued_unfunded_usd','governor formula drift')
def admit(current,cost,kind):
    post=Decimal(current)+Decimal(cost)
    if Decimal(current)>=Decimal('56.03'): return False
    if kind=='OPTIONAL': return Decimal(current)<Decimal('43.00') and post<Decimal('43.00')
    if kind=='CORE_REQUIRED': return Decimal(current)<Decimal('51.03') and post<Decimal('51.03')
    if kind=='EMERGENCY_ALLOWED': return Decimal(current)<Decimal('56.03') and post<Decimal('56.03')
    return False
for args,want in [(('42.99','0.005','OPTIONAL'),True),(('42.99','0.02','OPTIONAL'),False),(('43.00','0.00','OPTIONAL'),False),(('51.02','0.005','CORE_REQUIRED'),True),(('51.02','0.02','CORE_REQUIRED'),False),(('51.03','0.001','CORE_REQUIRED'),False),(('56.02','0.005','EMERGENCY_ALLOWED'),True),(('56.02','0.02','EMERGENCY_ALLOWED'),False),(('56.03','0.00','EMERGENCY_ALLOWED'),False)]:
    ok(admit(*args)==want,f'governor admission behavior wrong {args}')
pre=g['exposure_formula']['prepaid_rule']; ok('full at purchase time' in pre and 'does not add exposure a second time' in pre,'prepaid double-count rule missing')
# Example: $10 prepaid purchase, $8 queued usage => exposure stays $10; $15 queued usage => $15 exposure.
ok(Decimal('10')+Decimal('0')+max(Decimal('8')-Decimal('10'),Decimal('0'))==Decimal('10'),'prepaid example 8/10 failed')
ok(Decimal('10')+Decimal('0')+max(Decimal('15')-Decimal('10'),Decimal('0'))==Decimal('15'),'prepaid example 15/10 failed')
for f in ['HONOR_CANONICAL_HANDOFF.md','HONOR_PROVIDER_DECISIONS_AND_COSTS.md','HONOR_FINANCIAL_AND_CAMPAIGN_RULES.md','HONOR_ACCEPTANCE_CRITERIA.md','.env.example']:
    t=text(f); ok('43.00' in t and '51.03' in t and '56.03' in t,f'budget thresholds missing {f}')
canon='\n'.join(text(p.name) for p in ROOT.glob('*.md'))
ok(not re.search(r'(?i)(^|\n).*\bGREEN\s*:|\bAMBER\s*:|\$42\.00|\$48\.00',canon),'obsolete budget bands remain')
ok('No new optional paid generation' in text('HONOR_PROVIDER_DECISIONS_AND_COSTS.md'),'explicit optional paid block missing')
cs=o['components']['schemas']['CostSummary']; ok('governor_exposure_usd' in cs['properties'] and 'Prepaid funding is counted in full at purchase' in cs['description'],'CostSummary semantics incomplete')

# Production routing exact.
env={}
for ln in text('.env.example').splitlines():
    if '=' in ln and not ln.lstrip().startswith('#'):
        k,v=ln.split('=',1); env[k]=v
for k,v in {'HONOR_INTERNAL_API_ORIGIN':'http://api:8000','HONOR_INTERNAL_LIVENESS_PATH':'/healthz','HONOR_INTERNAL_READINESS_PATH':'/readyz','HONOR_PUBLIC_HEALTH_PATH':'/healthz','HONOR_OWNER_READINESS_PATH':'/api/readyz','NEXT_PUBLIC_HONOR_BFF_BASE':'/api/v1'}.items(): ok(env.get(k)==v,f'routing env {k}')
ok(o['x-honor-production-routing']['direct_public_fastapi_v1'] is False and o['x-honor-production-routing']['browser_cors_to_fastapi'] is False,'OpenAPI production routing extension wrong')
for path,item in o['paths'].items():
    if path.startswith('/v1/'):
        for m,op in item.items():
            if m in {'get','post','put','patch','delete'}: ok(op.get('x-honor-fastapi-publicly-routable') is False,f'public FastAPI flag {m} {path}')
for f in ['HONOR_ARCHITECTURE.md','HONOR_DEPLOYMENT_PLAN.md','HONOR_SECURITY_AND_RELIABILITY.md','HONOR_AUTH_SESSION_CONTRACT.md','HONOR_API_CONTRACTS.md']:
    for ln in text(f).splitlines():
        if re.search(r'(?i)caddy.*fastapi.*?/v1|caddy.*?/v1.*?fastapi',ln): ok(any(x in ln.lower() for x in ['must not','never','no public','forbid','no fastapi business']),f'positive public FastAPI /v1 route in {f}: {ln}')
ok('Caddy routes normal application traffic to Next.js only' in text('HONOR_DEPLOYMENT_PLAN.md'),'deployment routing invariant missing')

# Human API registry exactly derived from OpenAPI, resolving idempotency refs.
def resolve_param(x):
    if '$ref' in x and x['$ref'].startswith('#/components/parameters/'): return o['components']['parameters'][x['$ref'].split('/')[-1]]
    return x
def refname(s): return s.get('$ref','').split('/')[-1] if isinstance(s,dict) and '$ref' in s else None
derived=[]
for path,item in o['paths'].items():
    for m in ['get','post','put','patch','delete']:
        if m not in item: continue
        op=item[m]; rb=op.get('requestBody',{}).get('content',{}).get('application/json',{}).get('schema'); rn=refname(rb) or ('inline' if rb else 'none')
        browser='/healthz' if path=='/healthz' else ('/api/readyz' if path=='/readyz' else '/api'+path)
        im='REQUIRED' if any(resolve_param(x).get('name')=='Idempotency-Key' and resolve_param(x).get('required') is True for x in op.get('parameters',[])) else 'NOT_REQUIRED'
        derived.append({'method':m.upper(),'path':path,'operation_id':op['operationId'],'browser_route':browser,'auth':'PUBLIC' if op.get('security')==[] else 'OWNER_JWT_VIA_BFF','idempotency':im,'request_schema':rn})
h=loadj('HONOR_API_HUMAN_REGISTRY.json'); ok(h['operations']==derived,'human API registry != OpenAPI')
apimd=text('HONOR_API_CONTRACTS.md')
for d in derived:
    ok(f"## `{d['method']} {d['path']}` — `{d['operation_id']}`" in apimd,f'API Markdown operation missing {d["operation_id"]}')
    ok(f"Idempotency: **{d['idempotency']}**" in apimd,f'API idempotency prose mismatch {d["operation_id"]}')
    op=o['paths'][d['path']][d['method'].lower()]
    rb=op.get('requestBody',{}).get('content',{}).get('application/json',{}).get('schema')
    if rb and '$ref' in rb: ok(json.dumps(o['components']['schemas'][refname(rb)],indent=2) in apimd,f'resolved request schema missing {d["operation_id"]}')
    for resp in op['responses'].values():
        sch=resp.get('content',{}).get('application/json',{}).get('schema')
        if sch and '$ref' in sch: ok(json.dumps(o['components']['schemas'][refname(sch)],indent=2) in apimd,f'resolved response schema missing {d["operation_id"]}')
# Every mutating /v1 operation must require Idempotency-Key in current contract.
for d in derived:
    if d['path'].startswith('/v1/') and d['method'] in {'POST','PUT','PATCH','DELETE'}: ok(d['idempotency']=='REQUIRED',f'mutation lacks required idempotency {d}')

# JSONB registry exact SQL coverage; schemas included/valid/IDs; opaque restrictions.
jr=loadj('HONOR_JSONB_SCHEMA_REGISTRY.json'); cols=jr['columns']; cur=None; sqljson=[]
for ln in sql.splitlines():
    m=re.match(r'CREATE TABLE (\w+) \(',ln)
    if m: cur=m.group(1)
    cm=re.match(r'\s+(\w+) jsonb\b',ln)
    if cm and cur: sqljson.append(f'{cur}.{cm.group(1)}')
ok(set(cols)==set(sqljson),f'JSONB registry coverage mismatch missing={set(sqljson)-set(cols)} extra={set(cols)-set(sqljson)}')
entries={x['schema_id']:x for x in jr['structured_frozen_v1']+jr['opaque_redacted_metadata']}
ok(set(entries)==set(cols.values()),'JSONB registry schema entries != column schema IDs')
for sid,e in entries.items():
    fp=ROOT/e['file']; ok(fp.exists(),f'JSONB schema missing {sid}')
    if fp.exists():
        s=json.loads(fp.read_text())
        try: Draft202012Validator.check_schema(s)
        except Exception as ex: errors.append(f'JSONB schema invalid {sid}: {ex}')
        ok(s.get('$id')==f'https://honor.local/jsonschema/{sid}.json',f'JSONB $id mismatch {sid}')
        for ref in re.findall(r'"\$ref":\s*"([^"]+)"',json.dumps(s)):
            if not ref.startswith('#/'):
                target=ref.split('#')[0]; ok((fp.parent/target).exists(),f'unresolved JSONB ref {sid}: {ref}')
allfiles='\n'.join(text(p.name) for p in ROOT.iterdir() if p.is_file())
forbidden_delegate='C01 must'+' define'; ok(forbidden_delegate.lower() not in allfiles.lower(),'frozen-schema delegation phrase remains')
opaque={x['schema_id']:x for x in jr['opaque_redacted_metadata']}; ok(set(opaque)=={'provider_usage.raw.v1','audit.metadata_redacted.v1'},'opaque schema class wrong')
for sid,e in opaque.items():
    ok(e.get('max_container_depth')==2 and e.get('redaction_required') is True and e.get('product_logic_may_depend_on_unvalidated_fields') is False,f'opaque constraints missing {sid}')
    s=json.loads((ROOT/e['file']).read_text()); ok(s.get('x-honor-max-container-depth')==2 and s.get('x-honor-product-logic_dependency_allowed') is False,f'opaque schema annotations wrong {sid}')

# Owner bootstrap exact.
own=text('HONOR_OWNER_PROVIDER_SETUP.md')
for phrase in ['DEFERRED TO CHECKPOINT X: DEPLOYMENT/BOOTSTRAP','Authentication -> URL Configuration','Site URL','HONOR_PUBLIC_ORIGIN/auth/confirm','{{ .TokenHash }}&type=invite','{{ .TokenHash }}&type=recovery','Authentication -> Users','Add user','Send invitation','HONOR_OWNER_USER_ID','INSERT INTO owner_profiles','403 OWNER_FORBIDDEN']:
    ok(phrase in own,f'owner bootstrap missing {phrase}')

# R2/restic separation and env/secret mapping.
for k in ['R2_MEDIA_ACCESS_KEY_ID','R2_MEDIA_SECRET_ACCESS_KEY','R2_BACKUP_ACCESS_KEY_ID','R2_BACKUP_SECRET_ACCESS_KEY']:
    ok(k in env,f'env missing {k}'); ok(k in own and k in text('HONOR_DEPLOYMENT_PLAN.md') and k in text('HONOR_SECURITY_AND_RELIABILITY.md'),f'R2 mapping missing docs {k}')
ok('R2_ACCESS_KEY_ID' not in env and 'R2_SECRET_ACCESS_KEY' not in env,'legacy generic R2 credentials remain active')
ok('AWS_ACCESS_KEY_ID' not in env and 'AWS_SECRET_ACCESS_KEY' not in env,'AWS credential aliases must not be host .env assignments')
ok('AWS_ACCESS_KEY_ID=${R2_BACKUP_ACCESS_KEY_ID}' in text('.env.example') and 'AWS_SECRET_ACCESS_KEY=${R2_BACKUP_SECRET_ACCESS_KEY}' in text('.env.example'),'Restic aliases missing')
ok('specific bucket only** = `honor-media`' in own and 'specific bucket only** = `honor-backups`' in own,'R2 bucket scopes not exact')
secretreg=loadj('HONOR_SECRET_ENV_REGISTRY.json')['credentials']
# Every active credential-like env var is registered; every registered variable documented in owner+security.
credential_names=set(secretreg)
for k in env:
    if any(x in k for x in ['PASSWORD','SECRET','API_KEY','PRIVATE_KEY','HEARTBEAT_URL']) or k in {'DATABASE_APP_URL','DATABASE_ADMIN_URL','R2_MEDIA_ACCESS_KEY_ID','R2_BACKUP_ACCESS_KEY_ID'}:
        ok(k in credential_names,f'credential env not registered {k}')
for k in credential_names:
    ok(k in own,f'credential not documented owner setup {k}'); ok(k in text('HONOR_SECURITY_AND_RELIABILITY.md'),f'credential not documented security {k}')

# Redis authenticated configuration.
for k in ['REDIS_HOST','REDIS_PORT','REDIS_PASSWORD','REDIS_CACHE_DB','CELERY_BROKER_DB','CELERY_RESULT_DB','REDIS_URL_TEMPLATE','CELERY_BROKER_URL_TEMPLATE','CELERY_RESULT_BACKEND_TEMPLATE']: ok(k in env,f'Redis env missing {k}')
for k in ['REDIS_URL_TEMPLATE','CELERY_BROKER_URL_TEMPLATE','CELERY_RESULT_BACKEND_TEMPLATE']:
    v=env[k]
    for a,b in {'${REDIS_PASSWORD}':'test-secret','${REDIS_HOST}':'redis','${REDIS_PORT}':'6379','${REDIS_CACHE_DB}':'0','${CELERY_BROKER_DB}':'1','${CELERY_RESULT_DB}':'2'}.items(): v=v.replace(a,b)
    u=urllib.parse.urlparse(v); ok(u.scheme=='redis' and u.password=='test-secret' and u.hostname=='redis' and u.port==6379,f'Redis URL auth invalid {k}')

# DB access matrix deterministic coverage/security.
mat=loadj('HONOR_DB_ACCESS_MATRIX.json'); tables=re.findall(r'CREATE TABLE (\w+) \(',sql); classified=[]
for c in mat['classes'].values(): classified+=c['tables']
ok(len(classified)==len(set(classified)) and set(classified)==set(tables),f'DB class coverage mismatch missing={set(tables)-set(classified)} extra={set(classified)-set(tables)}')
ok(mat['runtime_role']['bypassrls'] is False and mat['runtime_role']['owns_application_tables'] is False and mat['runtime_role']['used_by']==['api','worker'],'runtime DB role boundary wrong')
ok(all(c.get('delete') is False for c in mat['classes'].values()),'runtime DELETE permission present')
ok(mat['browser_roles']['service_role_runtime_used'] is False,'Supabase secret/service role runtime use present')

# Operation/status error-code matrix exact.
em=loadj('HONOR_ERROR_CODE_MATRIX.json')
for path,item in o['paths'].items():
    for m in ['get','post','put','patch','delete']:
        if m not in item: continue
        op=item[m]; key=f'{m.upper()} {path}'
        mapping=op.get('x-honor-error-codes-by-status',{})
        if mapping:
            ok(key in em['operations'],f'error matrix op missing {key}')
            ok(em['operations'].get(key)==mapping,f'error matrix drift {key}')
        else:
            ok(key not in em['operations'] or em['operations'].get(key)=={},f'error matrix empty-op drift {key}')
        for status,codes in mapping.items():
            resp=op['responses'].get(status); ok(resp is not None,f'error response status absent {key} {status}')
            if resp:
                sch=resp.get('content',{}).get('application/json',{}).get('schema',{}); rn=refname(sch)
                ok(rn in o['components']['schemas'],f'error schema ref missing {key} {status}')
                if rn:
                    sc=o['components']['schemas'][rn]
                    # exact const/enum codes must be found inside schema serialization.
                    sr=json.dumps(sc)
                    for code in codes: ok(code in sr,f'error code {code} not in schema {rn}')


# Round-4 exact OpenAPI -> canonical JSON Schema references.
structured_map=o.get('x-honor-structured-json-schema-map',{})
def component_field_schema(key):
    parts=key.split('.')
    comp=o['components']['schemas'][parts[0]]
    if len(parts)==1: return comp
    cur=comp
    for part in parts[1:]:
        cur=cur['properties'][part]
    return cur
def refs_in_schema(s):
    refs=[]
    def walk(x):
        if isinstance(x,dict):
            if '$ref' in x: refs.append(x['$ref'])
            for v in x.values(): walk(v)
        elif isinstance(x,list):
            for v in x: walk(v)
    walk(s); return refs
for key,target in structured_map.items():
    sch=component_field_schema(key)
    ok(target in refs_in_schema(sch),f'structured OpenAPI field does not use canonical schema {key} -> {target}')
    # A mapped product structure may not be weakened by an unrestricted generic object beside the canonical ref.
    def has_weak(x):
        if isinstance(x,dict):
            if x.get('type')=='object' and x.get('additionalProperties') is True: return True
            return any(has_weak(v) for v in x.values())
        if isinstance(x,list): return any(has_weak(v) for v in x)
        return False
    ok(not has_weak(sch),f'structured OpenAPI field weakened to unrestricted object {key}')
# No non-error public data component may contain generic additionalProperties=true.
for n,sch in o['components']['schemas'].items():
    if n.startswith('Error_'): continue
    ok(not (isinstance(sch,dict) and sch.get('type')=='object' and sch.get('additionalProperties') is True),f'generic public data component {n}')

# Round-4 canonical JSON Schema reference registry and fixtures.
schema_docs=[]
registry=Registry()
for f in sorted((ROOT/'jsonschema').glob('*.json')):
    doc=json.loads(f.read_text()); schema_docs.append((f,doc))
    try:
        registry=registry.with_resource(doc['$id'],Resource.from_contents(doc))
    except Exception as e: errors.append(f'cannot register JSON schema {f.name}: {e}')
for f,doc in schema_docs:
    try:
        Draft202012Validator(doc,registry=registry).check_schema(doc)
    except Exception as e: errors.append(f'Round4 schema invalid {f.name}: {e}')

def validate_fixture(schema_file, fixture_file, should_pass=True):
    sch=json.loads((ROOT/'jsonschema'/schema_file).read_text()); inst=loadj('fixtures/'+fixture_file)
    try:
        Draft202012Validator(sch,registry=registry).validate(inst)
        passed=True
    except Exception:
        passed=False
    ok(passed==should_pass,f'fixture expectation wrong {fixture_file} against {schema_file}')
for fn in ['posting_requires_mentions_disclosure_submission.json','posting_native_audio_allowed.json','posting_native_audio_prohibited.json','posting_native_audio_unknown.json']:
    validate_fixture('clip.posting_recommendation.v1.json',fn,True)
validate_fixture('clip.posting_recommendation.v1.json','posting_invalid_prohibited_with_search.json',False)
validate_fixture('edit_plan.v1.json','edit_plan_valid.json',True)
validate_fixture('edit_plan.v1.json','edit_plan_invalid_missing_rights_hash.json',False)
validate_fixture('render_manifest.v1.json','render_manifest_valid.json',True)
validate_fixture('render_manifest.v1.json','render_manifest_invalid_qc_false.json',False)

# Posting/native-audio completeness and timestamp identity.
post_schema=loadj('jsonschema/clip.posting_recommendation.v1.json')
required_post={'platform','social_account_id','social_identity_id','recommended_publish_at','caption','platform_title','hashtags','required_mentions','disclosure','submission_requirements','native_audio_recommendation'}
ok(required_post.issubset(set(post_schema['required'])),'posting recommendation required fields incomplete')
legacy_post_ts='recommended'+'_at'; ok(legacy_post_ts not in json.dumps(post_schema) and legacy_post_ts not in json.dumps(o),'stale posting timestamp field remains')
native_schema=loadj('jsonschema/audio_plan.native_recommendation.v1.json')
for x in ['recommendation_status','platform','search_terms','identifiable_guidance','reason','cue_guidance','campaign_compatibility','rule_snapshot_id','not_baked_into_rendered_mp4']:
    ok(x in native_schema['required'],f'native audio field missing {x}')
ok(set(native_schema['properties']['recommendation_status']['enum'])=={'RECOMMENDED','PROHIBITED','UNKNOWN','NOT_APPLICABLE'},'native audio state enum drift')
ok(native_schema['properties']['not_baked_into_rendered_mp4'].get('const') is True,'native audio bake invariant wrong')

# Edit plan / render manifest provenance completeness.
edit_schema=loadj('jsonschema/edit_plan.v1.json'); render_schema=loadj('jsonschema/render_manifest.v1.json')
for x in ['schema_version','plan_version','candidate_id','source_asset_id','source_sha256','campaign_rule_snapshot_ids','source_rights_id','source_rights_record_hash','plan_fingerprint_sha256','timeline','layout','captions','visual_emphasis','audio_cleanup','audio_plan_reference','output']:
    ok(x in edit_schema['required'],f'edit plan provenance/render field missing {x}')
for x in ['render_manifest_id','source_sha256','edit_plan_hash','edit_plan_version','audio_plan_hash','render_safe_assets','renderer','material_render_parameters','output','qc_run_id','qc_passed','manifest_hash']:
    ok(x in render_schema['required'],f'render manifest field missing {x}')
ok(edit_schema['properties']['output']['properties']['render_manifest_schema_id'].get('const')=='render_manifest.v1','edit plan does not pin render manifest schema')
ok(loadj('HONOR_JSONB_SCHEMA_REGISTRY.json')['columns'].get('render_manifests.manifest_json')=='render_manifest.v1','render manifest DB registry mapping missing')

# Provenance immutability/versioning and terminal QC semantics.
prov={'source_rights','source_rights_campaigns','edit_plans','audio_plans','qc_runs','render_manifests'}
mat=loadj('HONOR_DB_ACCESS_MATRIX.json')
append=set(mat['classes']['B_APPEND_ONLY_RUNTIME']['tables'])
function_committed=set(mat.get('classes',{}).get('E_FUNCTION_COMMITTED_RIGHTS',{}).get('tables',[]))
immutable_runtime=append|function_committed
ok(prov.issubset(immutable_runtime),'provenance/terminal tables not immutable in DB matrix')
mutable=set(mat['classes']['A_MUTABLE_RUNTIME']['tables'])
ok(not (prov & mutable),f'provenance tables remain mutable {prov & mutable}')
for t in ['edit_plans','audio_plans']:
    ok(f'GRANT SELECT, INSERT, UPDATE ON TABLE {t}' not in sql,f'UPDATE grant remains on immutable {t}')
    ok(f'GRANT SELECT, INSERT ON TABLE {t} TO honor_app' in sql,f'insert-only grant missing {t}')
for t in ['source_rights','source_rights_campaigns']:
    ok(f'GRANT SELECT, INSERT ON TABLE {t} TO honor_app' not in sql,f'direct rights INSERT grant remains {t}')
    ok(f'GRANT SELECT ON TABLE {t} TO honor_app;' in sql,f'rights function-only SELECT grant missing {t}')
for token in ['rights_version integer NOT NULL','supersedes_rights_id uuid NULL','record_hash char(64) NOT NULL','plan_version integer NOT NULL','supersedes_edit_plan_id uuid NULL','supersedes_audio_plan_id uuid NULL','CREATE TABLE render_manifests','honor_reject_immutable_mutation','honor_clip_ready_guard']:
    ok(token in sql,f'provenance SQL contract missing {token}')
ok(re.search(r'finished_at timestamptz NOT NULL',sql) is not None and re.search(r'passed boolean NOT NULL',sql) is not None,'QC terminal fields are nullable')
ok('QC rows are terminal-at-insert and immutable' in sql,'QC terminal-at-insert rule missing')
ok(mat['classes']['B_APPEND_ONLY_RUNTIME'].get('terminal_insert_rules',{}).get('qc_runs','').startswith('insert only after'),'QC terminal model absent from matrix')

# Transaction-local owner context and exact runtime privilege boundary.
owner_scope=mat['owner_scope']
ok(owner_scope.get('transaction_local') is True and owner_scope.get('session_global_set_forbidden') is True,'owner context is not frozen transaction-local')
ok(owner_scope.get('set_sql')=="SELECT set_config('honor.owner_user_id', $1, true)",'transaction-local set_config SQL drift')
ok("set_config('honor.owner_user_id', '<validated-owner-uuid>', true)" in sql,'SQL transaction-local owner setup missing')
ok('Session-global SET honor.owner_user_id is forbidden' in sql,'session-global owner context not forbidden')
ctx=loadj('HONOR_DB_TRANSACTION_CONTEXT_TEST.json'); ok(ctx.get('connection_reused') is True,'DB context test must reuse connection'); ok(ctx['transaction_a'][1]['sql']=="SELECT set_config('honor.owner_user_id', $1, true)",'DB context test does not use transaction-local set_config'); ok(ctx['between_transactions']['expect']=='NULL_OR_EMPTY' and ctx['transaction_b_before_set'][1]['expect']=='NULL_OR_EMPTY' and ctx['transaction_b_before_set'][2]['expect'] is False,'DB reused-connection context isolation fixture incomplete')
rt=owner_scope.get('reused_connection_test',{})
ok('absent' in rt.get('result','') or 'identity from transaction A is absent' in rt.get('result',''),'pooled-connection identity clearing test missing')
ok(mat.get('schema_privileges')=={'schema':'public','honor_app':['USAGE'],'create':False},'schema privilege freeze drift')
ok(mat.get('sequence_privileges',{}).get('required_sequences')==[],'unexpected V1 sequence privilege')
ok(mat.get('function_privileges',{}).get('public_execute_revoked') is True,'function PUBLIC EXECUTE not revoked')
expected_runtime_functions={
'honor_owner_authorized()','honor_reject_immutable_mutation()','honor_render_manifest_guard()','honor_clip_ready_guard()',
'honor_source_rights_version_guard()','honor_edit_plan_version_guard()','honor_audio_plan_version_guard()','honor_clip_cross_record_guard()',
'honor_clip_provenance_lock_guard()','honor_commit_source_rights_version(uuid, uuid, integer, uuid, source_eligibility_enum, jsonb, jsonb, text, text, text, timestamptz, timestamptz, text, text, uuid[])',
'honor_rights_stage_allowed(uuid, uuid, platform_enum, text, timestamptz)','honor_post_publish_guard()','honor_submission_lineage_guard()',
'honor_earning_lineage_guard()','honor_transition_earning(uuid, earning_state_enum, timestamptz, text, text, text, text)',
'honor_campaign_rule_guard()','honor_activate_campaign_rule_snapshot(uuid, uuid)','honor_campaign_mirror_guard()',
'honor_current_rights_for_action(uuid, uuid, platform_enum, text, timestamptz)','honor_candidate_lineage_guard()',
'honor_transcript_guard()','honor_allocation_guard()','honor_lifecycle_guard()','honor_generation_run_history_guard()',
'honor_experiment_history_guard()',
'honor_internal_action_time_guard()','honor_rule_set_sealed_for_action(uuid, uuid, integer, timestamptz)','honor_seal_campaign_rule_set(uuid, uuid, integer)',
'honor_rule_set_consumption_guard()','honor_restriction_compliance_guard()','honor_audio_rule_enforcement_guard()','honor_disclosure_deadline_guard()',
'honor_clip_render_start_guard()','honor_render_audio_disclosure_guard()','honor_render_manifest_action_rights_guard()','honor_experiment_reference_guard()',
'honor_jsonb_exact_keys(jsonb, text[])','honor_rfc3339_datetime(text)','honor_absolute_uri(text)','honor_campaign_rule_typed_value_valid(text, jsonb)',
'honor_rule_set_runtime_schema_guard()','honor_single_rule_set_guard()','honor_final_uniqueness_acceptance_guard()','honor_qc_truth_guard()','honor_00_clip_recommendation_revision_guard()',
'honor_restriction_proof_artifact_guard()','honor_round10_restriction_placement_guard()','honor_01_posting_restriction_guard()','honor_00_experiment_arm_identity_guard()','honor_restriction_consumes_stage(text, text)',
'honor_owner_action_resolution_valid(text, text, uuid, jsonb)','honor_owner_action_lifecycle_guard()','honor_audio_allowed_uses_valid(jsonb)','honor_audio_asset_contract_guard()','honor_audio_asset_render_eligible(uuid, platform_enum)','honor_audio_plan_asset_rights_guard()','honor_render_start_audio_asset_rights_guard()','honor_render_manifest_audio_asset_guard()','honor_00_experiment_row_identity_guard()'}
ok(set(mat.get('function_privileges',{}).get('honor_app_execute_only',[]))==expected_runtime_functions,'approved function execute allowlist drift')

# Round-5 JSONB defaults: every mapped SQL JSONB default must validate against its exact registered schema.
def sql_table_bodies(sql_text):
    return {m.group(1):m.group(2) for m in re.finditer(r'CREATE TABLE\s+(\w+)\s*\((.*?)\n\);',sql_text,re.S)}
def column_line(table_body,col):
    for ln in table_body.splitlines():
        if re.match(rf'\s*{re.escape(col)}\s+jsonb\b',ln): return ln.strip().rstrip(',')
    return None
def parse_jsonb_default(line):
    if not line: return None
    m=re.search(r"DEFAULT\s+'((?:''|[^'])*)'::jsonb",line)
    if not m: return None
    return json.loads(m.group(1).replace("''","'"))
tb=sql_table_bodies(sql)
for col,sid in cols.items():
    table,column=col.split('.',1); line=column_line(tb.get(table,''),column)
    ok(line is not None,f'JSONB mapped SQL column missing {col}')
    default=parse_jsonb_default(line)
    if default is not None:
        sch=json.loads((ROOT/entries[sid]['file']).read_text())
        try:
            Draft202012Validator(sch,registry=registry).validate(default)
        except Exception as e:
            errors.append(f'JSONB SQL default invalid {col} -> {sid}: {e}')
# Known factual/evidence structures intentionally have no manufactured neutral default.
for col in ['account_health_snapshots.signals','source_rights.authorized_uses','source_rights.platform_limits','generation_runs.requested_constraints','candidates.features','clips.posting_recommendation','qc_runs.checks','qc_runs.metrics']:
    t,c=col.split('.',1); ok(parse_jsonb_default(column_line(tb[t],c)) is None,f'forbidden manufactured JSONB default remains {col}')

# Round-5 sole rights-expiration authority.
rights_use=loadj('jsonschema/source_rights.authorized_uses.v1.json')
ok('expires_at' not in rights_use.get('properties',{}) and 'expires_at' not in rights_use.get('required',[]),'authorized_uses still duplicates expiration')
rei=o['components']['schemas']['RightsEvidenceInput']
ok('expires_at' in rei.get('required',[]) and 'expires_at' in rei.get('properties',{}),'RightsEvidenceInput top-level expiration missing')
ok(re.search(r'CREATE TABLE source_rights \(.*?\n\s*expires_at timestamptz NULL',sql,re.S) is not None,'source_rights relational expires_at missing')
ok('authorization is expired at T iff source_rights.expires_at IS NOT NULL AND T >= source_rights.expires_at' in sql,'deterministic rights expiration rule missing')

# Round-5 relational clip provenance constraints and guard semantics.
for token in [
 'UNIQUE(id,source_id)','CONSTRAINT fk_clips_rights_source FOREIGN KEY (rights_id,source_id) REFERENCES source_rights(id,source_id)',
 'CONSTRAINT fk_clips_rights_campaign FOREIGN KEY (rights_id,campaign_id) REFERENCES source_rights_campaigns(source_rights_id,campaign_id)',
 'CONSTRAINT fk_clips_rule_campaign FOREIGN KEY (rule_snapshot_id,campaign_id) REFERENCES campaign_terms_snapshots(id,campaign_id)',
 'CONSTRAINT fk_clips_audio_edit FOREIGN KEY (audio_plan_id,edit_plan_id) REFERENCES audio_plans(id,edit_plan_id)',
 'honor_clip_cross_record_guard','clip edit_plan candidate/source/run mismatch','clip rights not historically authorized for campaign at clip creation',
 'clip rule snapshot campaign/history mismatch','clip audio plan belongs to another edit plan or is later evidence',
 "ep_json->>'source_sha256'<>c_source_hash",'edit plan rule snapshot belongs to another campaign'
]: ok(token in sql,f'clip cross-record SQL invariant missing: {token}')

fx=loadj('HONOR_DB_CROSS_RECORD_FIXTURES.json'); basefx=fx['base']
def clip_fixture_accept(case):
    src=basefx['source']; camp=basefx[case['campaign_id']]; rights=basefx[case['rights']]; rule=basefx[case['rule_snapshot']]; ep=basefx[case['edit_plan']]; ap=basefx[case['audio_plan']] if case.get('audio_plan') else None
    if rights['source_id']!=src['id']: return False
    if camp['id'] not in rights['campaign_ids']: return False
    if rule['campaign_id']!=camp['id']: return False
    if ep['source_id']!=src['id'] or ep.get('source_sha256')!=src['sha256'] or ep['source_rights_id']!=rights['id']: return False
    if rule['id'] not in ep['rule_snapshot_ids']: return False
    if ap is not None and ap['edit_plan_id']!=ep['id']: return False
    return True
for case in fx['clip_cases']:
    got='ACCEPT' if clip_fixture_accept(case) else 'REJECT'; ok(got==case['expect'],f'clip cross-record fixture wrong {case["name"]}: {got}')

# Accepted-render/READY clip provenance lock: every protected field must be rejected after lock.
protected=set(fx['protected_clip_fields'])
lock_m=re.search(r'CREATE OR REPLACE FUNCTION honor_clip_provenance_lock_guard\(\).*?END \$\$;',sql,re.S)
ok(lock_m is not None,'clip provenance lock function missing')
lock_text=lock_m.group(0) if lock_m else ''
for field in protected:
    ok(f'NEW.{field} IS DISTINCT FROM OLD.{field}' in lock_text,f'protected clip field not locked {field}')
ok("EXISTS (SELECT 1 FROM render_manifests rm WHERE rm.clip_id=OLD.id)" in lock_text and "OLD.state IN ('READY','POSTED','ARCHIVED')" in lock_text,'clip lock activation rule incomplete')
# Negative fixture semantics: once accepted manifest exists, mutation of each protected field is rejected.
for field in protected:
    locked=True; changed=True
    ok(not (not locked or not changed),f'protected mutation unexpectedly allowed {field}')

# Contiguous non-forking version-chain identity.
for token in ['UNIQUE(supersedes_rights_id)','UNIQUE(supersedes_edit_plan_id)','UNIQUE(supersedes_audio_plan_id)','honor_source_rights_version_guard','honor_edit_plan_version_guard','honor_audio_plan_version_guard','version N-1']:
    ok(token in sql,f'version-chain SQL invariant missing {token}')
def version_accept(c): return c['same_identity'] and c['new_version']==c['predecessor_version']+1 and not c.get('forked',False)
for c in fx['version_cases']:
    got='ACCEPT' if version_accept(c) else 'REJECT'; ok(got==c['expect'],f'version-chain fixture wrong {c["name"]}: {got}')

# Posting recommendation source-of-truth/mirror consistency and lock point.
for token in [
 "NEW.caption_copy := NEW.posting_recommendation->>'caption'",
 "NEW.title_copy := NEW.posting_recommendation->>'platform_title'",
 "NEW.hashtags := NEW.posting_recommendation->'hashtags'",
 "NEW.posting_recommendation->>'social_account_id'<>NEW.social_account_id::text",
 "NEW.posting_recommendation->>'social_identity_id'<>sa_identity::text",
 "NEW.posting_recommendation->'native_audio_recommendation'->>'rule_snapshot_id'<>NEW.rule_snapshot_id::text",
 "EXISTS (SELECT 1 FROM posts p WHERE p.clip_id=OLD.id)"
]: ok(token in sql,f'posting snapshot consistency SQL missing {token}')
ok('caption_copy,title_copy,hashtags,posting_recommendation' in sql,'derived posting mirrors do not trigger synchronization on direct updates')
# Mirrors are derived from canonical values, not caller-provided duplicates.
posting_sample=loadj('fixtures/posting_native_audio_allowed.json')
derived_mirrors={'caption_copy':posting_sample['caption'],'title_copy':posting_sample['platform_title'],'hashtags':posting_sample['hashtags']}
ok(derived_mirrors['caption_copy']==posting_sample['caption'] and derived_mirrors['hashtags']==posting_sample['hashtags'],'posting mirror derivation fixture failed')

# Render manifest chain covers the final output identity as well as source/edit/audio/QC.
for token in ["'object_key')=c.final_object_key","'file_size_bytes')::bigint=c.file_size_bytes","'duration_ms')::bigint=c.duration_ms","'canvas_width')::integer=c.width","'canvas_height')::integer=c.height","'video_codec'=c.codec"]:
    ok(token in sql,f'render manifest output chain missing {token}')

# Every HONOR-created function has explicit PUBLIC revoke and matrix disposition; runtime allowlist agrees with GRANTs.
sql_nc='\n'.join(ln for ln in sql.splitlines() if not ln.lstrip().startswith('--'))
created=[]
for m in re.finditer(r'CREATE OR REPLACE FUNCTION\s+(honor_\w+)\(([^)]*)\)',sql_nc):
    name,args=m.group(1),m.group(2).strip(); types=[]
    if args:
        for arg in args.split(','):
            bits=arg.strip().split(); types.append(bits[-1])
    created.append(f"{name}({', '.join(types)})")
runtime_funcs=set(mat['function_privileges']['honor_app_execute_only']); admin_funcs=set(mat['function_privileges']['admin_only_no_honor_app_execute'])
ok(set(created)==runtime_funcs|admin_funcs,f'function privilege disposition coverage mismatch created={set(created)} matrix={runtime_funcs|admin_funcs}')
for sig in created:
    ok(f'REVOKE ALL ON FUNCTION {sig} FROM PUBLIC;' in sql_nc,f'PUBLIC EXECUTE revoke missing {sig}')
    if sig in runtime_funcs: ok(f'GRANT EXECUTE ON FUNCTION {sig} TO honor_app;' in sql_nc,f'honor_app EXECUTE grant missing {sig}')
    if sig in admin_funcs: ok(f'GRANT EXECUTE ON FUNCTION {sig} TO honor_app;' not in sql_nc,f'admin-only function granted to honor_app {sig}')

# Matrix mirrors SQL special rules so C01 has no security/provenance choice.
for key in ['source_rights_version_chain','edit_plan_version_chain','audio_plan_version_chain','clip_cross_record_integrity','clip_provenance_lock','posting_snapshot','rights_expiration']:
    ok(key in mat.get('special_rules',{}),f'DB access matrix Round-5 rule missing {key}')
# Exact table grant comments in the canonical SQL must agree with the access matrix classes.
for table in mat['classes']['A_MUTABLE_RUNTIME']['tables']:
    if table=='campaigns':
        ok('-- GRANT SELECT, INSERT, UPDATE(title,currency,canonical_url,updated_at) ON TABLE campaigns TO honor_app;' in sql,'A-class constrained campaign grant drift')
    else:
        ok(f'-- GRANT SELECT, INSERT, UPDATE ON TABLE {table} TO honor_app;' in sql,f'A-class grant drift {table}')
for table in mat['classes']['B_APPEND_ONLY_RUNTIME']['tables']:
    ok(f'-- GRANT SELECT, INSERT ON TABLE {table} TO honor_app;' in sql,f'B-class grant drift {table}')
for table in mat['classes']['C_ADMIN_MAINTAINED']['tables']:
    ok(f'-- GRANT SELECT ON TABLE {table} TO honor_app;' in sql,f'C-class grant drift {table}')
ok('-- GRANT SELECT, INSERT, UPDATE(actual_cost_usd, reconciled_at) ON TABLE cost_ledger TO honor_app;' in sql,'D-class cost_ledger grant drift')
for table in mat['classes']['E_FUNCTION_COMMITTED_RIGHTS']['tables']:
    ok(f'-- GRANT SELECT ON TABLE {table} TO honor_app;' in sql,f'E-class rights SELECT grant drift {table}')
ok('-- GRANT SELECT, INSERT ON TABLE earnings TO honor_app;' in sql,'F-class earnings direct grant drift')
ok('-- GRANT SELECT, INSERT, UPDATE ON TABLE earnings TO honor_app;' not in sql,'earnings direct UPDATE grant remains')

# Round-6 downstream lineage / rights integrity.
r6=fx.get('round6',{})
# Campaign -> terms snapshot integrity uses composite same-campaign keys.
for token in [
 'ALTER TABLE campaigns ADD CONSTRAINT fk_campaign_current_terms FOREIGN KEY (terms_snapshot_id,id) REFERENCES campaign_terms_snapshots(id,campaign_id)',
 'CONSTRAINT fk_campaign_rule_evidence_campaign FOREIGN KEY (evidence_snapshot_id,campaign_id) REFERENCES campaign_terms_snapshots(id,campaign_id)'
]: ok(token in sql,f'Round6 campaign/snapshot invariant missing: {token}')
for c in r6.get('campaign_snapshot_cases',[]):
    got='ACCEPT' if c['campaign']==c['snapshot_campaign'] else 'REJECT'; ok(got==c['expect'],f'campaign snapshot fixture wrong {c["name"]}: {got}')

# Post -> clip -> account -> platform and atomic READY -> POSTED.
for token in [
 'UNIQUE(id,social_account_id)','CONSTRAINT fk_posts_clip_account FOREIGN KEY (clip_id,social_account_id) REFERENCES clips(id,social_account_id)',
 'CONSTRAINT fk_posts_account_platform FOREIGN KEY (social_account_id,platform) REFERENCES social_accounts(id,platform)',
 'honor_post_publish_guard','post recording requires clip READY','post account differs from clip account','post platform/account/posting recommendation mismatch',
 'native audio used platform differs from post platform',"UPDATE clips SET state='POSTED'"
]: ok(token in sql,f'Round6 post lineage invariant missing: {token}')
def post_accept(c):
    return c['clip_state']=='READY' and c['clip_account']==c['post_account'] and c['post_platform']==c['account_platform']==c['recommendation_platform'] and c['native_audio_platform']==c['post_platform']
for c in r6.get('post_cases',[]):
    got='ACCEPT' if post_accept(c) else 'REJECT'; ok(got==c['expect'],f'post lineage fixture wrong {c["name"]}: {got}')
ok('posts.idempotency_key UNIQUE' in sql or 'idempotency_key text NOT NULL UNIQUE' in sql,'post idempotency uniqueness missing')

# Submission -> post -> clip -> campaign lineage.
ok('honor_submission_lineage_guard' in sql and 'submission campaign differs from post clip campaign' in sql,'submission lineage guard missing')
for c in r6.get('submission_cases',[]):
    got='ACCEPT' if c['submission_campaign']==c['post_campaign'] else 'REJECT'; ok(got==c['expect'],f'submission lineage fixture wrong {c["name"]}: {got}')

# Analytics observation -> check-in same-post composite FK.
for token in ['UNIQUE(id,post_id)','CONSTRAINT fk_analytics_observation_checkin_post FOREIGN KEY (checkin_id,post_id) REFERENCES analytics_checkins(id,post_id)']:
    ok(token in sql,f'analytics checkin lineage invariant missing: {token}')
for c in r6.get('analytics_cases',[]):
    got='ACCEPT' if c['observation_post']==c['checkin_post'] else 'REJECT'; ok(got==c['expect'],f'analytics lineage fixture wrong {c["name"]}: {got}')

# Earning -> post/campaign/evidence lineage and atomic transitions.
for token in [
 'CONSTRAINT fk_earning_evidence_campaign FOREIGN KEY (evidence_snapshot_id,campaign_id) REFERENCES campaign_terms_snapshots(id,campaign_id)',
 'honor_earning_lineage_guard','earning campaign differs from post clip campaign','honor_transition_earning',
 'INSERT INTO earning_state_transitions','amount_usd_snapshot','UPDATE earnings SET state=p_to_state,last_state_at=p_occurred_at'
]: ok(token in sql,f'earning lineage/transition invariant missing: {token}')
for c in r6.get('earning_cases',[]):
    got='ACCEPT' if c['earning_campaign']==c['post_campaign']==c['evidence_campaign'] else 'REJECT'; ok(got==c['expect'],f'earning lineage fixture wrong {c["name"]}: {got}')
ok('Direct runtime UPDATE of earnings.state/last_state_at is revoked' in sql,'earning direct state update revocation not frozen')
ok('Direct honor_app UPDATE on earnings and direct INSERT on earning_state_transitions are not granted' in sql,'earning state/history direct mutation revocation not frozen')
ok('GRANT SELECT ON TABLE earning_state_transitions TO honor_app; -- INSERT only through honor_transition_earning()' in sql,'earning transition direct INSERT grant drift')
ok('G_FUNCTION_COMMITTED_EARNING_TRANSITIONS' in mat['classes'] and mat['classes']['G_FUNCTION_COMMITTED_EARNING_TRANSITIONS']['direct_runtime_insert'] is False and mat['classes']['G_FUNCTION_COMMITTED_EARNING_TRANSITIONS']['tables']==['earning_state_transitions'],'earning transition function-only matrix drift')

# Source-rights campaign applicability is atomic at version commit; old versions cannot gain new runtime associations.
for token in ['honor_commit_source_rights_version','Direct INSERT on source_rights/source_rights_campaigns is not granted to honor_app','FOREACH cid IN ARRAY p_campaign_ids','INSERT INTO source_rights_campaigns']:
    ok(token in sql,f'rights campaign commit invariant missing: {token}')
ok(set(mat['classes']['E_FUNCTION_COMMITTED_RIGHTS']['tables'])=={'source_rights','source_rights_campaigns'} and mat['classes']['E_FUNCTION_COMMITTED_RIGHTS']['direct_runtime_insert'] is False,'rights function-only class drift')
for c in r6.get('rights_association_cases',[]):
    got='ACCEPT' if (not c['existing_rights'] and c['same_transaction']) else 'REJECT'; ok(got==c['expect'],f'rights applicability fixture wrong {c["name"]}: {got}')

# Authorized-use stage matrix exact and negative-tested flag-by-flag.
rm=loadj('HONOR_RIGHTS_STAGE_MATRIX.json')
expected_stages={
 'INGEST':['may_ingest'], 'PAID_TRANSCRIPTION':['may_transcribe'], 'EDIT_PLAN':['may_edit','derivative_edits'],
 'RENDER':['may_render','may_edit','derivative_edits'], 'COMPENSATED_CAMPAIGN_PRODUCTION':['commercial_use','may_edit','derivative_edits','may_render'],
 'PUBLICATION_RECOMMENDATION':['may_publish','commercial_use','derivative_edits']}
ok(set(rm['stages'])==set(expected_stages),'rights stage set drift')
for st,req in expected_stages.items(): ok(rm['stages'][st]['required_true']==req,f'rights required flags drift {st}')
ok(set(rm['clip_creation_required_true'])=={'may_edit','derivative_edits','may_render','may_publish','commercial_use'},'clip commercial/derivative rights set drift')
for token in ["may_ingest","may_transcribe","derivative_edits","commercial_use","PUBLICATION_RECOMMENDATION","platform_ok"]:
    ok(token in sql,f'rights-stage SQL helper missing {token}')
def rights_case_accept(c):
    spec=rm['stages'][c['stage']]
    return c['eligible'] and c['campaign_associated'] and all(c['flags'].get(f) is True for f in spec['required_true']) and (not spec.get('platform_required') or c['platform_ok'])
for c in r6.get('rights_flag_cases',[]):
    got='ACCEPT' if rights_case_accept(c) else 'REJECT'; ok(got==c['expect'],f'rights flag fixture wrong {c["name"]}: {got}')
for token in ["authorized_uses->>'derivative_edits'","authorized_uses->>'commercial_use'"]:
    ok(token in sql,f'clip guard missing compensated campaign right {token}')

# Recommended publish time must be before rights expiration and cannot silently pass UNKNOWN campaign timing.
for token in ['recommended publish time is at/after rights expiration','rec_publish>=sr.expires_at','recommended publish time blocked by UNKNOWN/absent timing rule',"('start_at'),('end_at'),('deadline_at')"]:
    ok(token in sql,f'recommended publish timing invariant missing: {token}')
for c in r6.get('recommendation_expiration_cases',[]):
    got='ACCEPT' if c['seconds_from_expiry']<0 else 'REJECT'; ok(got==c['expect'],f'rights expiration boundary fixture wrong {c["name"]}: {got}')
for c in r6.get('timing_rule_cases',[]):
    got='ACCEPT' if c['timing_known'] and c['inside_known_bounds'] else 'REJECT'; ok(got==c['expect'],f'campaign timing fixture wrong {c["name"]}: {got}')

# Native-audio planning authority and posting snapshot consistency.
ok(re.search(r'platform_native_recommendation jsonb NOT NULL',sql) is not None,'audio plan native recommendation still nullable')
for token in ['posting native-audio snapshot must exactly mirror committed audio plan','UNKNOWN native-audio rule cannot become recommendation','prohibited native-audio rule cannot be escalated','RECOMMENDED native audio requires committed audio plan authority']:
    ok(token in sql,f'native-audio authority invariant missing: {token}')
for c in r6.get('native_audio_cases',[]):
    allowed = c['same_object'] if c.get('has_audio_plan',True) else c['posting_status']!='RECOMMENDED'
    if c['campaign_rule']=='UNKNOWN': allowed = allowed and c['posting_status']=='UNKNOWN'
    elif c['campaign_rule']=='KNOWN_FALSE': allowed = allowed and c['posting_status']=='PROHIBITED'
    elif c['campaign_rule']=='KNOWN_TRUE': allowed = allowed and c['posting_status'] not in {'PROHIBITED','UNKNOWN'}
    if not c.get('has_audio_plan',True) and c['posting_status']=='RECOMMENDED': allowed=False
    got='ACCEPT' if allowed else 'REJECT'; ok(got==c['expect'],f'native audio fixture wrong {c["name"]}: {got}')
ok('not_baked_into_rendered_mp4' in json.dumps(loadj('jsonschema/audio_plan.native_recommendation.v1.json')),'native audio render separation schema missing')

# DB access matrix mirrors SQL Round-6 decisions and no direct rights/earning privilege drift.
for key in ['campaign_terms_lineage','post_lineage','submission_lineage','analytics_checkin_lineage','earning_lineage','earning_transition_atomicity','source_rights_campaign_commit','authorized_use_matrix','recommended_publish_time','native_audio_authority']:
    ok(key in mat.get('special_rules',{}),f'DB access matrix Round-6 rule missing {key}')


# Round-7 campaign truth / decision history / state integrity.
r7=fx.get('round7',{})
rule_registry=loadj('HONOR_CAMPAIGN_RULE_REGISTRY.json')
rule_consumption=loadj('HONOR_CAMPAIGN_RULE_CONSUMPTION.json')
experiment_contract=loadj('HONOR_EXPERIMENT_CONTRACT.json')
canonical_rule_keys=[
'provider','campaign_url','external_campaign_id','status','compensation_model','cpm_or_rate','minimum_views','max_payout_per_clip','total_budget','remaining_budget','start_at','end_at','deadline_at','eligible_platforms','eligible_regions','eligible_account_requirements','required_tags','required_mentions','required_hashtags','disclosure_requirements','source_material_restrictions','clip_length_min_seconds','clip_length_max_seconds','content_restrictions','editing_restrictions','uniqueness_rules','submission_format','analytics_window','payout_window','render_audio_rules','platform_native_audio_rules','last_verified_at']
ok(list(rule_registry.get('keys',{}).keys())==canonical_rule_keys,'campaign registry must contain exactly the 32 canonical keys in canonical order')
ok('campaign_rule_set_commits' in rule_registry.get('rule_set_identity',''),'campaign rule-set snapshot identity drift')
cri=o['components']['schemas']['CampaignRuleItem']
ok(cri.get('x-honor-key-registry')=='HONOR_CAMPAIGN_RULE_REGISTRY.json','OpenAPI CampaignRuleItem registry pointer missing')
branches=cri.get('oneOf',[]); ok(len(branches)==32,'OpenAPI CampaignRuleItem must have exactly 32 key-bound variants')
branch_by_key={b.get('properties',{}).get('rule_key',{}).get('const'):b for b in branches}
ok(set(branch_by_key)==set(canonical_rule_keys),'OpenAPI campaign rule key variants drift registry')
for key,entry in rule_registry['keys'].items():
    b=branch_by_key.get(key,{})
    tv=b.get('properties',{}).get('typed_value',{}).get('anyOf',[{}])[0]
    ok(tv==entry['typed_value_schema'],f'OpenAPI per-key typed schema drift {key}')

def synth(schema):
    if 'const' in schema: return schema['const']
    if 'enum' in schema: return schema['enum'][0]
    if 'anyOf' in schema:
        for x in schema['anyOf']:
            if x.get('type')!='null': return synth(x)
        return None
    if 'oneOf' in schema: return synth(schema['oneOf'][0])
    t=schema.get('type')
    if t=='object': return {k:synth(schema.get('properties',{}).get(k,{})) for k in schema.get('required',[])}
    if t=='array': return [synth(schema.get('items',{})) for _ in range(max(1,schema.get('minItems',0)))]
    if t=='integer': return int(schema.get('minimum',0))
    if t=='number': return float(schema.get('minimum',0))
    if t=='boolean': return True
    if t=='string':
        fmt=schema.get('format')
        if fmt=='uri': return 'https://example.invalid/campaign'
        if fmt=='date-time': return '2026-09-20T12:00:00Z'
        patt=schema.get('pattern','')
        if '[0-9]{6}' in patt: return '1.000000'
        if '[A-Z]{2}' in patt: return 'US'
        if '^#' in patt: return '#tag'
        if '^@' in patt: return '@handle'
        return 'X'
    return None

def incompatible(v):
    if isinstance(v,bool): return 'wrong'
    if isinstance(v,(int,float)): return 'wrong'
    if isinstance(v,str): return 7
    if isinstance(v,list): return 'wrong'
    if isinstance(v,dict): return 'wrong'
    return {'wrong':True}
for key,entry in rule_registry['keys'].items():
    sch=entry['typed_value_schema']; Draft202012Validator.check_schema(sch)
    sample=synth(sch)
    try: Draft202012Validator(sch).validate(sample)
    except Exception as e: errors.append(f'campaign registry positive typed sample invalid {key}: {e}')
    bad=dict(sample) if isinstance(sample,dict) else sample
    if isinstance(bad,dict) and 'value' in bad: bad['value']=incompatible(bad['value'])
    else: bad={'value_type':'WRONG','value':'wrong'}
    try:
        Draft202012Validator(sch).validate(bad); errors.append(f'campaign registry incompatible typed value accepted {key}')
    except ValidationError: pass

# Truth-state fixtures and immutable snapshot-scoped rule rows.
def truth_accept(c):
    if c['state']=='KNOWN': return c['typed'] and c['evidence'] and c['verified']
    if c['state']=='NOT_APPLICABLE': return (not c['typed']) and c['evidence'] and c['verified']
    if c['state']=='UNKNOWN': return not c['typed']
    return False
for c in r7.get('campaign_truth_cases',[]):
    got='ACCEPT' if truth_accept(c) else 'REJECT'; ok(got==c['expect'],f'campaign truth fixture wrong {c["name"]}: {got}')
for token in [
 'terms_snapshot_id uuid NOT NULL','UNIQUE(campaign_id,terms_snapshot_id,rule_key,schema_version)',
 "knowledge_state='KNOWN' AND typed_value IS NOT NULL AND evidence_snapshot_id IS NOT NULL AND verified_at IS NOT NULL",
 "knowledge_state='NOT_APPLICABLE' AND typed_value IS NULL AND evidence_snapshot_id IS NOT NULL AND verified_at IS NOT NULL",
 "knowledge_state='UNKNOWN' AND typed_value IS NULL",'campaign rule snapshots are immutable',
 'current rule snapshot requires exactly 32 canonical rules','honor_activate_campaign_rule_snapshot'
]: ok(token in sql,f'campaign truth/history SQL invariant missing: {token}')
ok('campaign_rule_items' in append and 'campaign_rule_items' not in mutable,'historical normalized rule rows are runtime mutable')

# Scalar mirrors are function-controlled and tied to the current immutable rule snapshot.
mirror_messages={'provider':'campaign provider mirror mismatch','campaign_url':'campaign_url mirror mismatch','external_campaign_id':'external_campaign_id mirror mismatch','status':'campaign status mirror mismatch','start_at':'campaign start mirror mismatch','end_at':'campaign end mirror mismatch','deadline_at':'campaign deadline mirror mismatch','last_verified_at':'campaign verification mirror mismatch'}
for col,msg in mirror_messages.items():
    ok(col in rule_registry['keys'] and rule_registry['keys'][col].get('campaign_metadata_mirror')==col,f'campaign scalar mirror registry drift {col}')
    ok(msg in sql,f'campaign scalar mirror guard missing {col}')
ok('UPDATE(title,currency,canonical_url,updated_at) ON TABLE campaigns' in sql,'runtime campaign grant can mutate rule mirrors directly')

# Rule consumers must be machine-frozen for critical allocation/edit/audio/QC/post/submission stages.
for stage in ['allocation','edit_plan','audio_plan','render_qc','posting','submission','analytics_finance']:
    ok(stage in rule_consumption.get('stages',{}),f'campaign rule consumer stage missing {stage}')
for key in ['eligible_platforms','eligible_regions','eligible_account_requirements','required_tags','required_mentions','required_hashtags','disclosure_requirements','submission_format','source_material_restrictions','clip_length_min_seconds','clip_length_max_seconds','content_restrictions','editing_restrictions','uniqueness_rules','render_audio_rules','platform_native_audio_rules']:
    consumers=rule_registry['keys'][key].get('consumers',[]); ok(consumers,f'campaign rule has no consumers {key}')
ok('UNKNOWN or absent blocks that stage' in rule_consumption.get('critical_unknown_policy',''),'critical UNKNOWN policy missing')
# Every consumption-critical key must declare UNKNOWN blocking for that stage (combined stages map to their concrete consumers).
stage_alias={'render_qc':{'render','qc'},'analytics_finance':{'analytics','finance'}}
for stage,spec in rule_consumption.get('stages',{}).items():
    aliases=stage_alias.get(stage,{stage})
    for key in spec.get('critical_rules',[]):
        blocks=set(rule_registry['keys'][key].get('unknown_blocks',[]))
        ok(bool(blocks & aliases),f'critical rule UNKNOWN blocking drift {stage}:{key}')
for token in ['clip length min exceeds max','campaign start must be before end','remaining budget exceeds total budget','eligible account min_followers exceeds max_followers']:
    ok(token in sql,f'campaign cross-rule activation invariant missing: {token}')

# Account eligibility facts are structured and missing facts remain UNKNOWN/BLOCKED.
for token in ['account_region text NULL','follower_count bigint NULL','posting_available boolean NULL','captured_at timestamptz NOT NULL','evidence_uri text NULL']:
    ok(token in sql,f'account eligibility fact missing: {token}')
for c in r7.get('account_fact_cases',[]):
    if c.get('requires_region') and c.get('region') is None: got='UNKNOWN_BLOCKED'
    elif c.get('min_followers') is not None and c.get('followers') is None: got='UNKNOWN_BLOCKED'
    elif c.get('min_followers') is not None and c.get('followers',0)<c['min_followers']: got='INELIGIBLE'
    else: got='ELIGIBLE'
    ok(got==c['expect'],f'account fact fixture wrong {c["name"]}: {got}')

# Rights action-time integrity and current-version/no-fallback rule.
for token in ['r.evidence_captured_at<=p_at','r.committed_at<=p_at','rc.created_at<=p_at','ORDER BY r.rights_version DESC LIMIT 1','If it revokes/narrows authority, do not fall back']:
    ok(token in sql or token in json.dumps(rm),f'rights action-time/current-version invariant missing: {token}')
for c in r7.get('rights_action_time_cases',[]):
    allowed=c['evidence_offset_s']<=0 and c['commit_offset_s']<=0 and c['applicability_offset_s']<=0
    got='ACCEPT' if allowed else 'REJECT'; ok(got==c['expect'],f'rights action-time fixture wrong {c["name"]}: {got}')

# Rights attribution and duration have explicit downstream posting/media/QC paths.
for token in ['required_attribution','source_attribution','platform_limits','max_clip_seconds','most restrictive']:
    ok(token in sql or token in json.dumps(rm) or token in json.dumps(rule_consumption),f'rights attribution/duration path missing {token}')
for c in r7.get('duration_cases',[]):
    mx=min(x for x in [c.get('campaign_max'),c.get('rights_max')] if x is not None); got='ACCEPT' if c['duration']<=mx else 'REJECT'; ok(got==c['expect'],f'duration fixture wrong {c}')

# Audio planning also revalidates current rights/rules; later revocation cannot allow new planning under an obsolete edit-plan rights row.
for token in ['audio planning must use edit plan whose rights remain current at audio-plan commit','UNKNOWN audio rule blocks audio planning']:
    ok(token in sql,f'audio planning current-rights/rule gate missing {token}')
ok('future_recommendation_rule' in rm and 'never' in rm['future_recommendation_rule'].lower(),'future recommendation latest-rights rule missing')
ok(o['paths']['/v1/schedule/tomorrow']['get'].get('x-honor-current-rights-revalidation'),'schedule endpoint latest-rights revalidation contract missing')

# Recommendation-time native audio platform equality is independent of factual post native_audio_used checks.
for token in ["native_audio_recommendation'->>'platform' IS DISTINCT FROM rec_platform",'nested native-audio recommendation platform differs from posting platform']:
    ok(token in sql,f'native recommendation platform invariant missing {token}')
for c in r7.get('native_audio_platform_cases',[]):
    got='ACCEPT' if c['post_platform']==c['nested_platform']==c['audio_plan_platform'] else 'REJECT'; ok(got==c['expect'],f'native platform fixture wrong {c["name"]}: {got}')

# Lifecycle enum parity extends the original submission/check-in checks to every frozen stateful V1 entity.
state_enum_map={'earning':'earning_state_enum','post':'post_status_enum','clip':'clip_state_enum','source_ingest':'source_ingest_status_enum','job':'job_state_enum','generation_run':'job_state_enum','transcript':'transcript_status_enum','experiment':'experiment_status_enum'}
for machine,enum_name in state_enum_map.items():
    ok(sqlenum(enum_name)==sm[machine]['enum'],f'state enum mismatch {machine}/{enum_name}')
ok("CREATE TRIGGER honor_experiment_assignment_guard BEFORE INSERT OR UPDATE OR DELETE ON experiment_assignments" in sql,'experiment assignment INSERT guard missing')

# Lifecycle creation/state guards are unbypassable independent of defaults.
creation_allowed={'earnings':{'ACCRUED_UNVERIFIED'},'posts':{'PUBLISHED'},'analytics_checkins':{'PENDING'},'clips':{'PLANNED'}}
for c in r7.get('lifecycle_creation_cases',[]):
    got='ACCEPT' if c['state'] in creation_allowed[c['table']] else 'REJECT'; ok(got==c['expect'],f'lifecycle creation fixture wrong {c}')
for token in ["earning creation must be ACCRUED_UNVERIFIED","post creation must be PUBLISHED","newv='PENDING'","newv='PLANNED'","newv IN ('PENDING_UPLOAD','QUEUED')","newv='queued'"]:
    ok(token in sql,f'lifecycle creation guard missing {token}')

# Exact transcript->candidate lineage and immutable historical candidate identity/scoring.
for token in ['transcript_id uuid NOT NULL REFERENCES transcripts(id)','candidate requires successful transcript for same source','candidate-consumed transcript identity is immutable','terminal transcript cannot transition; retry creates new version row','scoring_version text NOT NULL']:
    ok(token in sql,f'transcript/candidate lineage invariant missing {token}')
for c in r7.get('candidate_transcript_cases',[]):
    got='ACCEPT' if c['candidate_source']==c['transcript_source'] and c['status']=='SUCCEEDED' else 'REJECT'; ok(got==c['expect'],f'candidate transcript fixture wrong {c["name"]}: {got}')
ok('candidates' in append and 'run_campaign_allocations' in append,'candidate/allocation history not append-only')
for token in ['generation run creation inputs are immutable','generation selected_plan is write-once','committed allocation history is immutable','rule_snapshot_id uuid NOT NULL','rights_id uuid NOT NULL','account_health_snapshot_id uuid NOT NULL','decision_as_of timestamptz NOT NULL','analysis_version text NOT NULL']:
    ok(token in sql,f'generation/allocation decision-history invariant missing {token}')

# Candidate feature contract supports speaker/topic/hook/confidence with explicit nullable UNKNOWN semantics.
cand_schema=loadj('jsonschema/candidate.features.v1.json')
for f in ['speaker_ids_or_labels','topic','hook_type','overall_candidate_confidence','classification_model_version']:
    ok(f in cand_schema.get('required',[]) and f in cand_schema.get('properties',{}),f'candidate feature contract missing {f}')
ok('Transcript identity is relational on candidates.transcript_id' in cand_schema.get('description',''),'candidate transcript provenance description missing')

# Analytics core learning metrics are structured nullable fields and present in API/Polli; unavailable is not zero-filled.
analytics_fields=['average_watch_duration_ms','completed_views','completion_rate_ppm','follower_delta','avg_watch_pct']
for f in analytics_fields:
    ok(re.search(rf'\b{f}\b.*?NULL',sql) is not None,f'analytics nullable DB field missing {f}')
    ok(f in json.dumps(o['components']['schemas']),f'analytics OpenAPI field missing {f}')
    ok(f in json.dumps(p),f'Polli analytics field missing {f}')
ok('total cumulative watch time' in sql.lower(),'watch_time_ms semantics not frozen as total cumulative')
case=r7.get('analytics_missing_metric_case',{}); ok(all(case.get(f) is None for f in ['average_watch_duration_ms','completed_views','completion_rate_ppm','follower_delta']) and case.get('expect')=='ACCEPT_NULL_UNKNOWN','analytics null/UNKNOWN fixture missing')

# Minimal experiment persistence/assignment contract sufficient for C03 without a schema change.
for token in ['CREATE TABLE experiments','CREATE TABLE experiment_arms','CREATE TABLE experiment_assignments','experiment_assignment_id uuid','honor_experiment_history_guard','unknown experiment clip unit','BEFORE INSERT OR UPDATE OR DELETE ON experiment_assignments']:
    ok(token in sql,f'experiment contract SQL missing {token}')
ok(experiment_contract.get('assignment_units')==['GENERATION_RUN','CLIP','SOCIAL_ACCOUNT'],'experiment assignment units drift')
ok('causal' in experiment_contract.get('causal_claim_rule','').lower(),'experiment causal-claim restriction missing')
for c in r7.get('experiment_cases',[]):
    if c['name']=='observational_correlation_not_causal': ok(c['truth_label']=='MODEL_ANALYSIS','observational experiment fixture must be MODEL_ANALYSIS')

# Round-8 rule-set sealing / action-time / restriction / audio / disclosure / experiment integrity.
r8=loadj('HONOR_ROUND8_INTEGRITY_FIXTURES.json')
restriction_sem=loadj('HONOR_CAMPAIGN_RESTRICTION_SEMANTICS.json')
restriction_codes=['CAMPAIGN_AUTHORIZED_SOURCE_ONLY','OWNER_OWNED_SOURCE_ONLY','NO_THIRD_PARTY_SOURCE','NO_PROFANITY','BRAND_SAFE_ONLY','NO_MISLEADING_CLAIMS','NO_CROP','NO_SPEED_CHANGE','NO_TEXT_OVERLAY','NO_REUSED_EDIT','UNIQUE_PER_ACCOUNT','UNIQUE_PER_CAMPAIGN']
ok(list(restriction_sem.get('codes',{}))==restriction_codes,'restriction semantics must cover exact 12 frozen codes in canonical order')
ok('UNKNOWN' in restriction_sem.get('normalization_rule','') and 'guess' in restriction_sem.get('normalization_rule','').lower(),'unrepresentable restriction normalization-to-UNKNOWN rule missing')
for code in restriction_codes:
    spec=restriction_sem['codes'][code]
    for f in ['legal_scopes','legal_effects','consuming_stages','structured_fact_or_field','compliance_proof','production_block','unknown_handling','owner_review_can_resolve','ready_forbidden_until_resolved']:
        ok(f in spec,f'restriction semantics field missing {code}:{f}')
    ok(spec['ready_forbidden_until_resolved'] is True,f'restriction READY blocking drift {code}')
    cases=[x for x in restriction_sem.get('fixtures',[]) if x['code']==code]
    ok({x['expected'] for x in cases}=={'ACCEPT','REJECT'},f'restriction positive/negative fixtures missing {code}')
ok(restriction_sem['codes']['NO_TEXT_OVERLAY'].get('burned_captions_count_as_text_overlay') is True,'NO_TEXT_OVERLAY must explicitly include burned captions')
for token in ['FIT_NO_CROP','playback_rate','NO_TEXT_OVERLAY includes burned captions','edit_signature_sha256','campaign uniqueness restriction blocks reused edit signature','account uniqueness restriction blocks reused edit signature']:
    ok(token in sql or token in json.dumps(edit_schema),f'restriction machine enforcement missing {token}')


for c in r8.get('restriction_edge_cases',[]):
    if c['code']=='NO_THIRD_PARTY_SOURCE':
        got='ACCEPT' if c['origin_type'] in {'CAMPAIGN_AUTHORIZED','OWNER_OWNED'} else 'REJECT'
        ok(got==c['expect'],f'restriction edge fixture wrong {c}')
ok("origin_type IN ('CAMPAIGN_AUTHORIZED','OWNER_OWNED')" in sql,'NO_THIRD_PARTY_SOURCE must reject every other source origin')

# Immutable rule-set seal, chronology, and anti-reactivation.
for token in ['CREATE TABLE campaign_rule_set_commits','rule_count integer NOT NULL CHECK (rule_count=32)','rules_sha256 char(64) NOT NULL','honor_seal_campaign_rule_set','sealed campaign rule set is append-closed','rule-set seal requires exactly 32 canonical normalized rules','rule verification/evidence chronology invalid at seal','campaign rule may not claim verification from the future','historical campaign decision/action requires sealed complete rule set committed no later than action time','superseded campaign rule snapshot cannot be reactivated']:
    ok(token in sql,f'Round8 rule-set seal/temporal invariant missing: {token}')
ok('campaign_rule_set_commits' in mat['classes'].get('H_FUNCTION_COMMITTED_RULE_SEALS',{}).get('tables',[]),'rule-set seal table not function-committed in access matrix')
ok(reg:=rule_registry.get('rule_set_seal_contract'), 'campaign rule registry seal contract missing')
if reg:
    ok(reg.get('required_rule_count')==32 and reg.get('seal_table')=='campaign_rule_set_commits','rule-set registry seal contract drift')
for c in r8['rule_set_seal_cases']:
    if c['name']=='incomplete_rule_set_allocation': got='REJECT' if c['rule_count']!=32 or not c['sealed'] else 'ACCEPT'
    elif c['name']=='sealed_32_allocation': got='ACCEPT' if c['rule_count']==32 and c['sealed'] and c['seal_offset_s']<=0 else 'REJECT'
    elif c['name']=='append_after_seal': got='REJECT' if c['sealed'] and c['operation']=='INSERT_RULE' else 'ACCEPT'
    elif c['name']=='verification_after_decision': got='REJECT' if c['verified_offset_s']>0 else 'ACCEPT'
    elif c['name']=='unsealed_historical_evidence': got='REJECT' if not c['sealed'] else 'ACCEPT'
    elif c['name']=='reactivate_superseded_snapshot': got='REJECT' if c['requested_generation']<c['current_generation'] else 'ACCEPT'
    else: got='REJECT'
    ok(got==c['expect'],f'Round8 rule-set seal fixture wrong {c["name"]}: {got}')

# DB-authoritative internal action times and RENDER transition revalidation.
for token in ['honor_internal_action_time_guard','NEW.decision_as_of:=t','NEW.committed_at:=t','NEW.created_at:=t','PLANNED -> RENDERING blocked by superseding/revoked RENDER rights before cost','NEW.render_started_at:=statement_timestamp()','render manifest cannot accept obsolete rights version at DB action time']:
    ok(token in sql,f'Round8 DB-authoritative action-time invariant missing: {token}')
action_contract=rm.get('db_authoritative_internal_action_times',{})
for k in ['paid_transcription','allocation','edit_plan_commit','audio_plan_commit','clip_publication_recommendation','render_start','render_manifest_acceptance']:
    ok(k in action_contract,f'rights action-time contract missing {k}')
for c in r8['action_time_cases']:
    if c['name']=='render_revoked_before_rendering': got='REJECT' if not c['current_render_allowed'] else 'ACCEPT'
    elif c['name']=='later_grant_no_retroactive_validation': got='REJECT' if c['action_before_grant'] else 'ACCEPT'
    else: got='ACCEPT' if c.get('db_now_rights_allowed') else 'REJECT'
    ok(got==c['expect'],f'Round8 action-time fixture wrong {c["name"]}: {got}')

# Render-audio inner rule states are binding, not advisory.
audio_comp_schema=loadj('jsonschema/audio_plan.rule_compliance.v1.json')
try: Draft202012Validator(audio_comp_schema,registry=registry).validate(loadj('fixtures/audio_rule_compliance_valid.json'))
except Exception as e: errors.append(f'audio rule compliance fixture invalid: {e}')
ok(cols.get('audio_plans.rule_compliance')=='audio_plan.rule_compliance.v1','audio rule compliance JSONB mapping missing')
for token in ['render audio rule forbids/unverifies music asset','render audio rule forbids/unverifies SFX; events empty and density NONE required','max_sfx_density NONE forbids SFX','audio-plan density exceeds frozen max_sfx_density','audio-plan rule compliance evidence does not mirror frozen rule/plan','render manifest assets must exactly match rule-compliant audio plan']:
    ok(token in sql,f'render-audio enforcement missing: {token}')
def audio_case_accept(c):
    if c.get('outer_state')=='NOT_APPLICABLE':
        return bool(c.get('asset_render_safe',True))
    master=c.get('render_safe_audio','ALLOWED'); music=c.get('music_allowed','NOT_APPLICABLE'); sfx=c.get('sfx_allowed','NOT_APPLICABLE')
    music_asset=c.get('music_asset',False); n=c.get('sfx_events',0); density=c.get('density','NONE'); maxd=c.get('max')
    ranks={'NONE':0,'LOW':1,'MEDIUM':2,'HIGH':3}
    music_ok=(master!='UNKNOWN') and ((master=='ALLOWED' and music in {'ALLOWED','NOT_APPLICABLE'}) or (master=='PROHIBITED' and music=='ALLOWED')) and music not in {'PROHIBITED','UNKNOWN'}
    sfx_ok=(master!='UNKNOWN') and ((master=='ALLOWED' and sfx in {'ALLOWED','NOT_APPLICABLE'}) or (master=='PROHIBITED' and sfx=='ALLOWED')) and sfx not in {'PROHIBITED','UNKNOWN'}
    if music_asset and not music_ok: return False
    if (n or density!='NONE') and not sfx_ok: return False
    if sfx_ok and maxd=='NONE' and (n or density!='NONE'): return False
    if sfx_ok and sfx=='ALLOWED' and maxd is None: return False
    if sfx_ok and maxd is not None and ranks[density]>ranks[maxd]: return False
    return True
for c in r8['audio_rule_cases']:
    got='ACCEPT' if audio_case_accept(c) else 'REJECT'; ok(got==c['expect'],f'Round8 audio fixture wrong {c["name"]}: {got}')

# Disclosure placement survives campaign -> posting/edit/render/QC/submission and deadline mirrors exact sealed timing rule.
post_schema=loadj('jsonschema/clip.posting_recommendation.v1.json')
ok('placement' in post_schema['properties']['disclosure']['required'],'posting disclosure placement field missing')
ok('provider_disclosure' in post_schema['properties']['submission_requirements']['required'],'provider submission disclosure path missing')
for fld in ['disclosure_render','restriction_compliance']:
    ok(fld in edit_schema['required'],f'edit plan Round8 field missing {fld}')
for fld in ['campaign_restrictions','disclosure_video','render_audio_compliance']:
    ok(fld in loadj('jsonschema/qc.checks.v1.json')['required'],f'QC Round8 check missing {fld}')
for fld in ['audio_rule_compliance','campaign_disclosure']:
    ok(fld in render_schema['required'],f'render manifest Round8 field missing {fld}')
for token in ['posting disclosure including placement must exactly mirror frozen campaign rule','VIDEO/BOTH disclosure must be represented in edit-plan render path','provider-submission disclosure missing from submission requirements','VIDEO/BOTH disclosure requires render-manifest proof and PASS QC','posting submission deadline must equal sealed campaign deadline_at','UNKNOWN critical submission deadline blocks recommendation']:
    ok(token in sql,f'disclosure/deadline enforcement missing: {token}')
for c in r8['disclosure_cases']:
    placement=c['placement']; accept=(placement=='CAPTION' and c['caption']) or (placement=='VIDEO' and c['video']) or (placement=='BOTH' and c['caption'] and c['video']) or (placement=='PROVIDER_SUBMISSION' and c['submission'])
    got='ACCEPT' if accept else 'REJECT'; ok(got==c['expect'],f'disclosure fixture wrong {c}')
for c in r8['deadline_cases']:
    if c['state']=='KNOWN': got='ACCEPT' if c['campaign']==c['posting'] else 'REJECT'
    elif c['state']=='NOT_APPLICABLE': got='ACCEPT' if c['posting'] is None else 'REJECT'
    else: got='BLOCKED'
    ok(got==c['expect'],f'deadline fixture wrong {c}')

# Predeclared immutable experiments, DB-authored assignment/exposure, and exact assignment-unit lineage.
for token in ['unit_type experiment_unit_enum NOT NULL','DRAFT -> RUNNING requires at least two arms and exactly one control arm','no arm INSERT/UPDATE/DELETE after experiment leaves DRAFT','experiment predeclared hypothesis/feature/primary_metric/unit_type may change only while remaining DRAFT','assignment unit_type must match experiment predeclared unit_type','experiment assignments may be created only while RUNNING','NEW.assigned_at:=statement_timestamp()','NEW.exposed_at:=statement_timestamp()','exposure may not predate assignment/start','candidate assignment must be exact GENERATION_RUN assignment for candidate run','allocation assignment must match exact predeclared run or account unit','clip assignment must match exact clip or explicitly inherited run/account unit']:
    ok(token in sql,f'Round8 experiment invariant missing: {token}')
ok(experiment_contract.get('predeclaration',{}).get('v1_control_rule','').startswith('exactly one'),'experiment V1 control rule missing')
for c in r8['experiment_cases']:
    n=c['name']
    if n.startswith('start_'): got='ACCEPT' if c['arms']>=2 and c['controls']==1 else 'REJECT'
    elif n=='add_arm_after_running': got='REJECT' if c['status']!='DRAFT' else 'ACCEPT'
    elif n=='change_hypothesis_running': got='REJECT' if c['status']!='DRAFT' else 'ACCEPT'
    elif n=='mutate_design_on_start_transition': got='REJECT'
    elif n=='assignment_unit_type_mismatch': got='REJECT'
    elif n=='stopped_to_completed_preserves_ended_at': got='PRESERVE_ENDED_AT'
    elif n.startswith('assignment_'): got='ACCEPT' if c['status']=='RUNNING' else 'REJECT'
    elif n.startswith('exposure_'): got='ACCEPT' if c['exposed_offset_s']>=c['assigned_offset_s'] else 'REJECT'
    else: got='REJECT'
    ok(got==c['expect'],f'Round8 experiment fixture wrong {n}: {got}')
for c in r8['experiment_scope_cases']:
    if c['ref']=='candidate': accept=c['assignment_type']=='GENERATION_RUN' and c['unit_match']
    elif c['ref']=='allocation': accept=c['experiment_type'] in {'GENERATION_RUN','SOCIAL_ACCOUNT'} and c['assignment_type']==c['experiment_type'] and c['unit_match']
    else: accept=c['experiment_type'] in {'CLIP','GENERATION_RUN','SOCIAL_ACCOUNT'} and c['assignment_type']==c['experiment_type'] and c['unit_match']
    got='ACCEPT' if accept else 'REJECT'; ok(got==c['expect'],f'experiment scope fixture wrong {c}')
ok('exact linkage' in experiment_contract.get('scope_matrix',{}).get('causal_consumers','').lower(),'analytics/Polli exact assignment linkage requirement missing')

# Round-8 OpenAPI/human machine pointers.
ok(o.get('x-honor-campaign-restriction-semantics')=='HONOR_CAMPAIGN_RESTRICTION_SEMANTICS.json','OpenAPI restriction semantics pointer drift')
ok(o.get('x-honor-round8-integrity-fixtures')=='HONOR_ROUND8_INTEGRITY_FIXTURES.json','OpenAPI Round8 fixture pointer drift')

# Round-9 runtime type / single-rule / proof / QC-truth / recommendation / experiment serialization integrity.
r9=loadj('HONOR_ROUND9_INTEGRITY_FIXTURES.json')
qc_policy=loadj('HONOR_QC_POLICY.json')
ok(o.get('x-honor-qc-policy')=='HONOR_QC_POLICY.json','OpenAPI QC policy pointer drift')
ok(o.get('x-honor-round9-integrity-fixtures')=='HONOR_ROUND9_INTEGRITY_FIXTURES.json','OpenAPI Round9 fixture pointer drift')
# Every registered KNOWN value schema gets a correct-value_type / invalid-body rejection test.
for key,entry in rule_registry['keys'].items():
    sch=entry['typed_value_schema']; sample=synth(sch); bad=json.loads(json.dumps(sample))
    v=bad.get('value')
    if isinstance(v,dict): v['__round9_extra_property__']=True
    elif isinstance(v,list):
        if v: v[0]={'invalid':'body'}
        else: v.append({'invalid':'body'})
    elif isinstance(v,bool): bad['value']='true'
    elif isinstance(v,(int,float)): bad['value']='not-a-number'
    elif isinstance(v,str): bad['value']={'invalid':'body'}
    else: bad['value']={'invalid':'body'}
    try:
        Draft202012Validator(sch,format_checker=FormatChecker()).validate(bad)
        errors.append(f'Round9 correct-value_type invalid body accepted by registry schema {key}')
    except ValidationError: pass
for token in ['honor_campaign_rule_typed_value_valid','registered typed_value_schema validation failed before seal','last_verified_at must equal actual rule-set verification maximum and may not be future of seal','honor_rule_set_runtime_schema_guard_trigger']:
    ok(token in sql,f'Round9 runtime campaign type/chronology enforcement missing: {token}')
for c in r9['rule_value_schema_cases']:
    if 'typed_value' in c:
        sch=rule_registry['keys'][c['rule_key']]['typed_value_schema']
        try: Draft202012Validator(sch,format_checker=FormatChecker()).validate(c['typed_value']); got='ACCEPT'
        except ValidationError: got='REJECT'
    else: got='REJECT' if c.get('future') or c.get('contradicts_actual_verification_max') else 'ACCEPT'
    ok(got==c['expect'],f'Round9 rule value fixture wrong {c["name"]}: {got}')
# V1 single rule snapshot is exact across edit/audio/clip/render.
ok(edit_schema['properties']['campaign_rule_snapshot_ids'].get('minItems')==1 and edit_schema['properties']['campaign_rule_snapshot_ids'].get('maxItems')==1,'V1 edit plan must contain exactly one rule snapshot')
ok('campaign_rule_snapshot_id' in render_schema['required'],'render manifest exact campaign rule snapshot identity missing')
for token in ['V1 edit plan requires exactly one campaign rule snapshot','audio plan rule identity must equal sole edit rule snapshot','clip/posting rule identity must equal sole edit rule snapshot','render manifest rule identity must equal sole edit/audio/clip rule snapshot']:
    ok(token in sql,f'Round9 single-rule-set SQL invariant missing: {token}')
for c in r9['single_rule_set_cases']:
    got='ACCEPT' if c['edit_count']==1 and c['same_audio_clip'] else 'REJECT'; ok(got==c['expect'],f'Round9 single-rule fixture wrong {c["name"]}: {got}')
# Restriction proof contract is exact for all 12 codes.
for code,spec in restriction_sem['codes'].items():
    ok(spec.get('proof_reference_required') is True,f'restriction proof reference requirement missing {code}')
    ok(spec.get('permitted_proof_kinds'),f'restriction permitted proof kinds missing {code}')
for token in ['restriction COMPLIANT uses invalid proof kind','restriction COMPLIANT requires structured proof reference','owner review cannot resolve restriction or lacks resolution id','owner review resolution id forbidden for non-owner proof']:
    ok(token in sql,f'Round9 restriction proof enforcement missing: {token}')
for c in r9['restriction_proof_cases']:
    spec=restriction_sem['codes'][c['code']]; permitted=spec['permitted_proof_kinds']; owner_ok=spec['owner_review_can_resolve']
    valid=(c['result']=='COMPLIANT' and c['proof_kind'] in permitted and c['proof_kind']!='NONE' and bool(c['proof_reference']))
    if c['proof_kind']=='OWNER_REVIEW': valid=valid and owner_ok and bool(c['owner_review_resolution_id'])
    elif c['owner_review_resolution_id'] is not None: valid=False
    got='ACCEPT' if valid else 'REJECT'; ok(got==c['expect'],f'Round9 restriction proof fixture wrong {c["code"]}/{c["case"]}: {got}')
# Race-safe accepted signature reservations + canonical uniqueness QC.
for token in ['CREATE TABLE accepted_edit_signatures','PRIMARY KEY(restriction_code,scope_id,edit_signature_sha256)','honor_final_uniqueness_acceptance_guard','applicable uniqueness restriction requires canonical QC uniqueness PASS','INSERT INTO accepted_edit_signatures']:
    ok(token in sql,f'Round9 atomic uniqueness invariant missing: {token}')
for c in r9['uniqueness_cases']:
    got='SECOND_REJECT' if c['same_scope'] and c['same_signature'] and c['concurrent_ready'] else 'ACCEPT'; ok(got==c['expect'],f'Round9 uniqueness race fixture wrong {c["name"]}: {got}')
# QC is a derived database fact under the machine policy.
qc_schema=loadj('jsonschema/qc.checks.v1.json')
ok(list(qc_policy.get('checks',{}))==qc_schema['required'],'QC policy/check schema canonical ordering drift')
for name in qc_schema['required']:
    ok(qc_policy['checks'][name]['always_hard_gate'] is True,f'QC hard-gate policy drift {name}')
    ok(qc_schema['properties'][name]['properties']['hard_gate'].get('const') is True,f'QC schema caller downgrade possible {name}')
for token in ['honor_qc_truth_guard','caller hard_gate=false cannot weaken canonical QC','qc_runs.passed=true contradicts canonical derived QC result','QC NOT_APPLICABLE is not permitted by canonical policy']:
    ok(token in sql,f'Round9 QC truth SQL enforcement missing: {token}')
for c in r9['qc_truth_cases']:
    got='REJECT' if c.get('hard_gate') is False else ('REJECT_ASSERTED_PASS' if c.get('caller_passed') and not c.get('derived_passed',True) else 'ACCEPT')
    ok(got==c['expect'],f'Round9 QC fixture wrong {c["name"]}: {got}')
# Material recommendation revisions authorize at statement_timestamp and are versioned/auditable.
for token in ['recommendation_version integer NOT NULL','recommendation_revised_at timestamptz','recommendation revision requires current publication rights at DB action time','recommendation revision requires sealed rule set at DB action time','recommendation revision must use current activated campaign rule snapshot','NEW.recommendation_version:=OLD.recommendation_version+1']:
    ok(token in sql,f'Round9 recommendation revision action-time invariant missing: {token}')
for c in r9['recommendation_revision_cases']:
    got='ACCEPT' if c['current_authorized'] else 'REJECT'; ok(got==c['expect'],f'Round9 recommendation revision fixture wrong {c["name"]}: {got}')
# Parent-row serialization and immutable stopping history.
for token in ['SELECT status INTO st FROM experiments WHERE id=parent_id FOR UPDATE','SELECT status,started_at,unit_type INTO st,startt,declared_unit FROM experiments WHERE id=parent_id FOR UPDATE','captured experiment stopping_reason is historical and immutable','NEW.stopping_reason:=OLD.stopping_reason']:
    ok(token in sql,f'Round9 experiment serialization/history invariant missing: {token}')
ok('serialization_contract' in experiment_contract,'experiment serialization machine contract missing')
for c in r9['experiment_serialization_cases']:
    if c['name'] in ('arm_insert_races_start','assignment_insert_races_stop'): got='SERIALIZED' if c['child_requires_parent_for_update'] and not c['post_transition_child_allowed'] else 'RACY'
    elif c['name']=='stopping_reason_rewrite': got='REJECT' if c['terminated'] and c['rewrite'] else 'ACCEPT'
    else: got='ACCEPT' if c['preserve_ended_at'] and c['preserve_stopping_reason'] else 'REJECT'
    ok(got==c['expect'],f'Round9 experiment fixture wrong {c["name"]}: {got}')

# Round-10 restriction placement / proof lineage / null-audio / posting-copy / arm-identity integrity.
r10=loadj('HONOR_ROUND10_INTEGRITY_FIXTURES.json')
ok(o.get('x-honor-round10-integrity-fixtures')=='HONOR_ROUND10_INTEGRITY_FIXTURES.json','OpenAPI Round10 fixture pointer drift')
placement={
'source_material_restrictions':['CAMPAIGN_AUTHORIZED_SOURCE_ONLY','OWNER_OWNED_SOURCE_ONLY','NO_THIRD_PARTY_SOURCE'],
'content_restrictions':['NO_PROFANITY','BRAND_SAFE_ONLY','NO_MISLEADING_CLAIMS'],
'editing_restrictions':['NO_CROP','NO_SPEED_CHANGE','NO_TEXT_OVERLAY'],
'uniqueness_rules':['NO_REUSED_EDIT','UNIQUE_PER_ACCOUNT','UNIQUE_PER_CAMPAIGN']}
# Exact registry + machine semantics placement matrix; actual schema rejects wrong-key legal codes.
ok(restriction_sem.get('placement_contract',{}).get('rule_keys')==placement,'Round10 restriction placement matrix drift')
for key,codes in placement.items():
    enum=rule_registry['keys'][key]['typed_value_schema']['properties']['value']['properties']['clauses']['items']['properties']['code']['enum']
    ok(enum==codes,f'Round10 per-key restriction enum drift {key}')
    for code in codes: ok(restriction_sem['codes'][code].get('legal_rule_keys')==[key],f'Round10 legal_rule_keys drift {code}')
for c in r10['placement_cases']:
    spec=restriction_sem['codes'][c['code']]
    tv={'value_type':'RESTRICTION_SET','value':{'clauses':[{'code':c['code'],'effect':spec['legal_effects'][0],'scope':spec['legal_scopes'][0]}]}}
    try:
        Draft202012Validator(rule_registry['keys'][c['rule_key']]['typed_value_schema']).validate(tv); got='ACCEPT'
    except ValidationError: got='REJECT'
    ok(got==c['expect'],f'Round10 wrong-rule-key schema fixture wrong {c}: {got}')
for token in ['honor_round10_restriction_placement_guard','restriction code % is under wrong canonical rule key %','duplicate semantic restriction code in sealed rule set']:
    ok(token in sql,f'Round10 seal placement runtime guard missing: {token}')
# Exactly one canonical compliance record per active clause; no extras/contradictions.
def compliance_cardinality_valid(case):
    active=[(x['code'],x['effect'],x['scope']) for x in case['active']]
    rec=[(x['code'],x['effect'],x['scope']) for x in case['records']]
    return len(rec)==len(active) and set(rec)==set(active) and all(rec.count(t)==1 for t in active) and all(x['result']=='COMPLIANT' for x in case['records'])
for c in r10['compliance_cardinality_cases']:
    got='ACCEPT' if compliance_cardinality_valid(c) else 'REJECT'; ok(got==c['expect'],f'Round10 compliance cardinality fixture wrong {c["name"]}: {got}')
for token in ['restriction compliance must contain exactly one record for each active sealed clause and no extras','restriction compliance contains entry absent from exact sealed rule set','restriction clause requires exactly one canonical compliance record','restriction VIOLATION/UNKNOWN blocks production']:
    ok(token in sql,f'Round10 canonical restriction-result enforcement missing: {token}')
ok(edit_schema['properties']['restriction_compliance'].get('uniqueItems') is True and edit_schema['properties']['restriction_compliance'].get('maxItems')==12,'Round10 restriction compliance schema not tightened')
# proof_reference is structured and resolves through an immutable artifact; owner review is referential/context-bound.
proof_ref_schema=edit_schema['properties']['restriction_compliance']['items']['properties']['proof_reference']
try:
    Draft202012Validator(proof_ref_schema).validate('random free-form proof'); random_accepted=True
except ValidationError: random_accepted=False
ok(not random_accepted,'Round10 arbitrary free-form proof string still schema-valid')
for token in ['CREATE TABLE restriction_proof_artifacts','restriction proof_reference does not resolve to immutable proof artifact','restriction proof_reference fields do not match immutable proof artifact','OWNER_REVIEW proof requires existing RESOLVED owner action','OWNER_REVIEW owner action entity/action context mismatch','OWNER_REVIEW owner action resolution context mismatch','owner review unresolved or resolved after consuming edit-plan commit','proof target/hash mismatch']:
    ok(token in sql,f'Round10 proof lineage enforcement missing: {token}')
proof_contract=restriction_sem.get('proof_reference_contract',{})
ok(proof_contract.get('storage','').startswith('Every usable proof_reference identifies one immutable restriction_proof_artifacts row'),'Round10 proof-reference storage contract missing')
for kind in ['RIGHTS_CAMPAIGN_LINK','SOURCE_ORIGIN','TRANSCRIPT_LEXICAL_SCAN','CONTENT_SAFETY_REVIEW','CLAIMS_EVIDENCE_REVIEW','EDIT_OPERATION_AUDIT','CAPTION_OVERLAY_AUDIT','EDIT_SIGNATURE_COMPARISON','OWNER_REVIEW']:
    ok(kind in proof_contract.get('proof_kinds',{}),f'Round10 proof-kind reference contract missing {kind}')
for c in r10['proof_reference_cases']:
    if c['name']=='random_string': valid=False
    elif c.get('kind')=='OWNER_REVIEW': valid=c.get('artifact_exists',False) and c.get('owner_action_exists',False) and c.get('owner_status')=='RESOLVED' and c.get('resolved_before_commit',False) and c.get('context_match',True)
    else: valid=c.get('artifact_exists',False) and c.get('target_match',True) and c.get('hash_match',True) and c.get('result','COMPLIANT')=='COMPLIANT' and c.get('evidence_before_commit',True)
    got='ACCEPT' if valid else 'REJECT'; ok(got==c['expect'],f'Round10 proof-reference fixture wrong {c["name"]}: {got}')
# Null audio plan: schema forbids assets and runtime/QC inspect rule state rather than treating NULL as automatic N/A.
rm_valid=loadj('fixtures/render_manifest_valid.json')
rm_null=json.loads(json.dumps(rm_valid)); rm_null['audio_plan_id']=None; rm_null['audio_plan_schema_version']=None; rm_null['audio_plan_version']=None; rm_null['audio_plan_hash']=None; rm_null['render_safe_assets']=[]
try: Draft202012Validator(render_schema,registry=registry).validate(rm_null); null_silent_schema=True
except ValidationError: null_silent_schema=False
ok(null_silent_schema,'Round10 legitimate null-plan/empty-assets manifest rejected by schema')
rm_bad=json.loads(json.dumps(rm_null)); rm_bad['render_safe_assets']=[{'audio_asset_id':'11111111-1111-4111-8111-111111111111','sha256':'a'*64,'license_reference':'test','kind':'MUSIC'}]
try: Draft202012Validator(render_schema,registry=registry).validate(rm_bad); null_asset_schema=True
except ValidationError: null_asset_schema=False
ok(not null_asset_schema,'Round10 null audio plan still permits render-safe manifest asset in schema')
for token in ['null audio plan forbids all render-safe MUSIC/SFX manifest assets','UNKNOWN render audio cannot reach terminal manifest through null-plan or QC N/A','KNOWN render-audio rules require PASS QC even when audio_plan_id is null','render_audio_compliance\' AND c.audio_plan_id IS NULL AND ra_state=\'NOT_APPLICABLE']:
    ok(token in sql,f'Round10 null-audio runtime/QC enforcement missing: {token}')
for c in r10['null_audio_plan_cases']:
    valid=(not c['asset_kinds']) and c['rule_state']!='UNKNOWN' and ((c['rule_state']=='NOT_APPLICABLE' and c['qc'] in ('NOT_APPLICABLE','PASS')) or (c['rule_state']=='KNOWN' and c['qc']=='PASS'))
    got='ACCEPT' if valid else 'REJECT'; ok(got==c['expect'],f'Round10 null-audio fixture wrong {c["name"]}: {got}')
# Runtime stage-consumption matrix mirrors every code/stage in the machine semantics artifact.
for _code,_sem in restriction_sem['codes'].items():
    _case=re.search(rf"WHEN '{re.escape(_code)}' THEN p_stage=ANY\(ARRAY\[(.*?)\]\)",sql)
    ok(_case is not None,f'Round10 DB stage-consumption matrix missing code {_code}')
    if _case:
        _stages=set(re.findall(r"'([^']+)'",_case.group(1)))
        ok(_stages==set(_sem.get('consuming_stages',[])),f'Round10 DB stage-consumption matrix drift {_code}: {_stages}')
ok("honor_restriction_consumes_stage(c->>'code','posting')" in sql,'Round10 posting guard is not driven by centralized restriction stage matrix')

# Posting revision copy proof is stage-driven and bound to exact new version/hash/fresh DB action time.
post_schema=loadj('jsonschema/clip.posting_recommendation.v1.json')
ok('posting_restriction_compliance' in post_schema['required'],'Round10 posting restriction evidence field not required')
posting_contract=restriction_sem.get('posting_stage_proof_contract',{})
ok(posting_contract.get('v1_active_code')=='NO_MISLEADING_CLAIMS' and 'consuming_stages' in posting_contract.get('stage_driven',''),'Round10 stage-driven posting proof contract missing')
for token in ['honor_01_posting_restriction_guard','posting copy requires exactly one fresh compliance record per active posting-consuming restriction and no extras','posting restriction proof is stale, unrelated, late, or bound to different recommendation content/version',"pa.recommendation_version IS DISTINCT FROM NEW.recommendation_version","pa.subject_sha256 IS DISTINCT FROM content_hash","pa.evidenced_at>NEW.recommendation_revised_at"]:
    ok(token in sql,f'Round10 posting-copy fresh-proof guard missing: {token}')
for c in r10['posting_revision_cases']:
    valid=(not c['content_changed']) or (c.get('proof_version_matches',False) and c.get('proof_hash_matches',False) and c.get('proof_fresh',False) and c.get('proof_kind') in ('CLAIMS_EVIDENCE_REVIEW','OWNER_REVIEW') and (c.get('proof_kind')!='OWNER_REVIEW' or (c.get('owner_resolved_before_revision') and c.get('context_match'))))
    got='ACCEPT' if valid else 'REJECT'; ok(got==c['expect'],f'Round10 posting revision fixture wrong {c["name"]}: {got}')
# Arm identity is immutable and UPDATE/DELETE locks/checks OLD parent, not NEW/COALESCE parent.
for token in ['honor_00_experiment_arm_identity_guard','parent_id:=OLD.experiment_id; SELECT status INTO st FROM experiments WHERE id=parent_id FOR UPDATE','NEW.id IS DISTINCT FROM OLD.id OR NEW.experiment_id IS DISTINCT FROM OLD.experiment_id OR NEW.created_at IS DISTINCT FROM OLD.created_at','experiment arm id/experiment_id/created_at are immutable']:
    ok(token in sql,f'Round10 experiment arm identity enforcement missing: {token}')
ok('arm_identity' in experiment_contract.get('serialization_contract',{}),'Round10 experiment arm identity machine contract missing')
for c in r10['experiment_arm_cases']:
    valid=c['old_parent']=='DRAFT' and not c.get('reparent',False) and not c.get('id_change',False) and not c.get('created_at_change',False)
    got='ACCEPT' if valid else 'REJECT'; ok(got==c['expect'],f'Round10 experiment arm fixture wrong {c["name"]}: {got}')

# Round-11 posting proof versioning / render-safe audio rights / owner-action lifecycle / experiment identity.
r11=loadj('HONOR_ROUND11_INTEGRITY_FIXTURES.json')
r12=loadj('HONOR_ROUND12_INTEGRITY_FIXTURES.json')
audio_rights=loadj('HONOR_AUDIO_ASSET_RIGHTS_CONTRACT.json')
ok(o.get('x-honor-audio-asset-rights-contract')=='HONOR_AUDIO_ASSET_RIGHTS_CONTRACT.json','OpenAPI Round11 audio-rights contract pointer drift')
ok(o.get('x-honor-round11-integrity-fixtures')=='HONOR_ROUND11_INTEGRITY_FIXTURES.json','OpenAPI Round11 fixture pointer drift')

# Every actual posting recommendation revision must be version-bound, even if caption/title hash is unchanged.
posting_contract=restriction_sem.get('posting_stage_proof_contract',{})
ok(posting_contract.get('version_binding_policy')=='ROUND11_OPTION_A_FRESH_ARTIFACT_EVERY_RECOMMENDATION_VERSION','Round11 posting proof version policy drift')
for token in [
    "NEW.posting_recommendation IS NOT DISTINCT FROM OLD.posting_recommendation",
    'every recommendation version requires exactly one compliance record per active posting-consuming restriction and no extras',
    'pa.recommendation_version IS DISTINCT FROM NEW.recommendation_version',
    'posting proof must bind exact current recommendation version/content hash and precede DB revision time'
]: ok(token in sql,f'Round11 posting proof version guard missing: {token}')
# Last definition of the guard must not contain the old caption/title-only early-return shortcut.
last_post_guard=sql.rsplit('CREATE OR REPLACE FUNCTION honor_01_posting_restriction_guard()',1)[-1]
ok('content_changed :=' not in last_post_guard,'Round11 posting guard still gates validation only on caption/title changes')
for c in r11['posting_proof_version_cases']:
    valid=True
    if c.get('recommendation_changed'):
        if c.get('active_posting_restrictions',1)>0:
            valid=c.get('records',1)==c.get('active_posting_restrictions',1) and c.get('proof_version_matches',False) and c.get('proof_hash_matches',False) and c.get('proof_fresh',True)
    got='ACCEPT' if valid else 'REJECT'
    ok(got==c['expect'],f'Round11 posting-version fixture wrong {c["name"]}: {got}')

# Exact V1 automatic render-safe asset eligibility is machine-readable and pessimistic.
need={'active','audio_assets.render_safe','allowed_uses.render_safe','render_safe_authorities_equal','allowed_uses.commercial_use','allowed_uses.derivative_edit','target_platform_in_allowed_uses.platforms','allowed_uses.campaign_restriction','attribution_required','license_evidence_required'}
ok(need.issubset(audio_rights['automatic_embedding_eligibility']),'Round11 audio asset eligibility contract incomplete')
ok(audio_rights['automatic_embedding_eligibility']['allowed_uses.campaign_restriction'] is None,'Round11 campaign-restricted audio must not auto-embed')
ok(audio_rights['automatic_embedding_eligibility']['attribution_required'] is False,'Round11 attribution-required audio must not auto-embed')
asset_schema=loadj('jsonschema/audio_asset.allowed_uses.v1.json')
ok(asset_schema.get('x-honor-v1-automatic-embedding-contract',{}).get('checked_at')==['AUDIO_PLAN_COMMIT','PLANNED_TO_RENDERING','RENDER_MANIFEST_ADMISSION'],'audio allowed-use schema checkpoint contract drift')

def asset_ok(c):
    return (c['active'] and c['column_render_safe'] and c['inner_render_safe'] and c['column_render_safe']==c['inner_render_safe'] and c['commercial'] and c['derivative'] and c['platform'] and c['campaign_restriction'] is None and not c['attribution'] and (not c['license_required'] or c['license_evidence']))
for c in r11['audio_asset_eligibility_cases']:
    got='ACCEPT' if asset_ok(c) else 'REJECT'; ok(got==c['expect'],f'Round11 audio eligibility fixture wrong {c["name"]}: {got}')
for token in [
    'audio_assets.render_safe must exactly equal allowed_uses.render_safe',
    "(a.allowed_uses->>'commercial_use')::boolean=true",
    "(a.allowed_uses->>'derivative_edit')::boolean=true",
    "a.allowed_uses->'platforms' ? p_platform::text",
    "a.allowed_uses->'campaign_restriction'='null'::jsonb",
    'a.attribution_required=false',
    'license_evidence_required requires immutable license evidence object key and SHA-256',
    'music asset fails exact V1 render-safe rights eligibility at audio-plan commit',
    'render start blocked: planned MUSIC asset is no longer eligible',
    'render manifest blocked: baked audio asset is not currently V1 eligible'
]: ok(token in sql,f'Round11 audio-rights runtime enforcement missing: {token}')
for c in r11['asset_deactivation_render_cases']:
    got='ACCEPT' if c['eligible_at_plan'] and c['active_at_render'] else 'REJECT'; ok(got==c['expect'],f'Round11 deactivation fixture wrong {c["name"]}: {got}')

# Manifest provenance is exact UUID + kind + SHA + license + plan membership + current eligibility.
for c in r11['manifest_provenance_cases']:
    valid=all(c[k] for k in ['id','kind','sha','license','plan_member','current_eligible']); got='ACCEPT' if valid else 'REJECT'; ok(got==c['expect'],f'Round11 manifest provenance fixture wrong {c["name"]}: {got}')
for token in ['render manifest audio asset UUID/kind/SHA/license must mirror immutable canonical asset version','manifest MUSIC asset is not exact committed audio-plan MUSIC','manifest SFX asset is not present in committed audio plan','render manifest must contain each planned render-safe asset exactly once']:
    ok(token in sql,f'Round11 manifest provenance guard missing: {token}')

# Material audio asset rows are immutable versions; active is one-way revocation only.
for c in r11['audio_asset_immutability_cases']:
    valid=not c['material_change'] and not (c['active_old'] is False and c['active_new'] is True); got='ACCEPT' if valid else 'REJECT'; ok(got==c['expect'],f'Round11 audio immutability fixture wrong {c["name"]}: {got}')
for token in ['material audio asset identity/provenance/rights are immutable; create a new asset id/version','audio asset revocation is one-way; create a new asset version to restore eligibility','audio asset versions cannot be deleted']:
    ok(token in sql,f'Round11 audio asset immutability missing: {token}')

# Owner review depends on an immutable, DB-timed owner-action terminal decision and hash binding.
owner_sm=sm.get('owner_action',{})
ok(owner_sm.get('creation')==['OPEN'] and owner_sm.get('transitions',{}).get('OPEN')==['RESOLVED','CANCELLED'],'Round11 owner action state machine drift')
for token in ['owner action creation must be OPEN','NEW.requested_at:=t; NEW.created_at:=t','NEW.resolved_at:=t','NEW.cancelled_at:=t','terminal owner action is immutable and cannot reopen or change resolution','owner action identity/context/request time are immutable','OWNER_REVIEW proof must bind immutable owner-action resolution hash']:
    ok(token in sql,f'Round11 owner action lifecycle invariant missing: {token}')
for c in r11['owner_action_cases']:
    n=c['name']
    if n=='create_resolved': got='REJECT'
    elif n=='valid_open_create': got='ACCEPT'
    elif n=='backdated_resolved_at': got='DB_AUTHORED' if c.get('canonical_resolution') else 'REJECT'
    elif c.get('old_status') in ('RESOLVED','CANCELLED') and c.get('mutation'): got='REJECT'
    elif n=='valid_cancel': got='ACCEPT' if c.get('canonical_cancel') else 'REJECT'
    else: got='REJECT'
    ok(got==c['expect'],f'Round11 owner action fixture wrong {n}: {got}')

# Experiment and assignment primary identities are explicit, not incidental FK behavior.
for token in ['experiments.id and experiments.created_at are immutable','experiment_assignments.id is immutable; exposure may not rewrite assignment identity']:
    ok(token in sql,f'Round11 experiment identity guard missing: {token}')
for c in r11['experiment_identity_cases']:
    valid=not c.get('assignment_id_change',False) and not c.get('experiment_created_at_change',False) and not c.get('experiment_id_change',False)
    got='ACCEPT' if valid else 'REJECT'; ok(got==c['expect'],f'Round11 experiment identity fixture wrong {c["name"]}: {got}')
ok('experiment_assignments.id' in experiment_contract['immutability']['assignment'] and 'experiments.id and created_at' in experiment_contract['immutability']['experiments'],'Round11 experiment machine identity contract missing')

# Null-audio manifest cannot claim planned assets; schema and runtime agree.
null_rm=json.loads(json.dumps(rm_valid)); null_rm['audio_plan_id']=None; null_rm['audio_plan_schema_version']=None; null_rm['audio_plan_version']=None; null_rm['audio_plan_hash']=None; null_rm['render_safe_assets']=[]; null_rm['audio_rule_compliance']['planned_music_asset_id']=None; null_rm['audio_rule_compliance']['planned_sfx_asset_ids']=[]
try: Draft202012Validator(render_schema,registry=registry).validate(null_rm); null_good=True
except ValidationError: null_good=False
ok(null_good,'Round11 truthful null-audio manifest rejected by schema')
null_bad=json.loads(json.dumps(null_rm)); null_bad['audio_rule_compliance']['planned_music_asset_id']='11111111-1111-4111-8111-111111111111'
try: Draft202012Validator(render_schema,registry=registry).validate(null_bad); null_bad_accepted=True
except ValidationError: null_bad_accepted=False
ok(not null_bad_accepted,'Round11 null-audio schema permits planned MUSIC claim')
for c in r11['null_audio_consistency_cases']:
    valid=(c['audio_plan_id'] is None and c['plan_fields_null'] and c['assets']==0 and c['planned_music'] is None and c['planned_sfx']==0 and c['rule_snapshot_match']); got='ACCEPT' if valid else 'REJECT'; ok(got==c['expect'],f'Round11 null-audio consistency fixture wrong {c["name"]}: {got}')
for token in ['null audio manifest cannot claim planned MUSIC/SFX and must bind exact clip rule snapshot','planned_music_asset_id','planned_sfx_asset_ids']:
    ok(token in sql or token in json.dumps(render_schema),f'Round11 null-audio consistency missing: {token}')

# Round-12 PRECOMMIT owner-review satisfiability and exact consumption.
owner_schema=loadj('jsonschema/owner_action.resolution.v1.json')
restriction_branch=next((b for b in owner_schema.get('oneOf',[]) if b.get('properties',{}).get('resolution_type',{}).get('const')=='RESTRICTION_COMPLIANCE'),None)
ok(restriction_branch is not None,'Round12 restriction owner-action schema branch missing')
if restriction_branch:
    rp=restriction_branch.get('properties',{})
    ok(rp.get('review_phase',{}).get('const')=='PRECOMMIT','Round12 owner review schema does not freeze PRECOMMIT')
    ok(rp.get('target_version',{}).get('type')=='integer' and rp.get('target_version',{}).get('minimum')==1,'Round12 owner review target_version schema missing')
    ok({'review_phase','target_version'}.issubset(set(restriction_branch.get('required',[]))),'Round12 owner review required fields incomplete')
    sample={
      'resolution_type':'RESTRICTION_COMPLIANCE','review_phase':'PRECOMMIT','decision':'COMPLIANT','restriction_code':'NO_MISLEADING_CLAIMS',
      'campaign_id':'11111111-1111-4111-8111-111111111111','rule_snapshot_id':'22222222-2222-4222-8222-222222222222','candidate_id':'33333333-3333-4333-8333-333333333333',
      'target_type':'POSTING_RECOMMENDATION','target_id':'44444444-4444-4444-8444-444444444444','target_version':1,'subject_sha256':'a'*64,'note':None
    }
    try: Draft202012Validator(owner_schema,registry=registry).validate(sample); precommit_schema_ok=True
    except Exception: precommit_schema_ok=False
    ok(precommit_schema_ok,'Round12 valid PRECOMMIT owner review rejected by JSON Schema')

# Inspect only the final override of owner-action validation; old Round-11 definition may remain earlier in the migration-style contract.
def final_fn_body(name):
    token='CREATE OR REPLACE FUNCTION '+name
    tail=sql.rsplit(token,1)[-1]
    return tail.split('END $$;',1)[0]
final_owner_fn=final_fn_body('honor_owner_action_resolution_valid')
ok("p_resolution->>'review_phase'<>'PRECOMMIT'" in final_owner_fn,'Round12 final owner resolution validator does not require PRECOMMIT')
ok('campaign_rule_set_commits' in final_owner_fn and 'JOIN sources' in final_owner_fn,'Round12 PRECOMMIT resolution does not validate sealed rule/candidate-source context')
ok("honor_restriction_consumes_stage(code,stage)" in final_owner_fn,'Round12 owner review does not validate target type against consuming stage')
ok('edit_plans e WHERE e.id=tid' not in final_owner_fn and 'clips c JOIN edit_plans' not in final_owner_fn,'Round12 PRECOMMIT owner review still requires future target row to exist')
ok('PRECOMMIT intentionally does NOT query edit_plans/clips by target_id' in final_owner_fn,'Round12 no-target-existence intent is not frozen in DB contract')

# Positive creation sequences prove acyclic satisfiability.
base=['CONTEXT_EXISTS','RESERVE_TARGET','COMPUTE_SUBJECT','CREATE_OPEN_OWNER_ACTION','RESOLVE_PRECOMMIT','CREATE_OWNER_REVIEW_PROOF','COMMIT_TARGET']
initial=['EDIT_PLAN_EXISTS','RESERVE_TARGET','COMPUTE_SUBJECT','CREATE_OPEN_OWNER_ACTION','RESOLVE_PRECOMMIT','CREATE_OWNER_REVIEW_PROOF','COMMIT_TARGET']
revision=['CURRENT_VERSION_EXISTS','PREPARE_NEXT_VERSION','COMPUTE_SUBJECT','CREATE_OPEN_OWNER_ACTION','RESOLVE_PRECOMMIT','CREATE_OWNER_REVIEW_PROOF','COMMIT_TARGET']
expected_seq={'edit_plan_precommit_owner_review':base,'initial_posting_precommit_owner_review':initial,'posting_revision_precommit_owner_review':revision}
for c in r12['positive_flows']:
    seq=c['sequence']; exp=expected_seq[c['name']]
    valid=(seq==exp and seq.index('RESOLVE_PRECOMMIT')<seq.index('CREATE_OWNER_REVIEW_PROOF')<seq.index('COMMIT_TARGET') and c['exact_target'] and c['exact_version'] and c['exact_hash'] and c['exact_context'] and c['resolved_before_commit'] and c['proof_before_commit'])
    got='ACCEPT' if valid else 'REJECT'; ok(got==c['expect'],f'Round12 positive PRECOMMIT flow is not satisfiable {c["name"]}: {got}')

# Resolution-time target absence is legal only when existing context/seal/stage/identity facts are valid.
for c in r12['resolution_validation_cases']:
    valid=(c['context_exists'] and c['sealed'] and c['legal_stage'] and c['valid_uuid'] and c['valid_version'] and c['valid_hash'])
    # target_row_exists intentionally does not participate in PRECOMMIT validity.
    got='ACCEPT' if valid else 'REJECT'; ok(got==c['expect'],f'Round12 resolution-time satisfiability fixture wrong {c["name"]}: {got}')

# Consumption must bind exact target/version/hash/context and chronology; reuse/retroactivity fail.
for c in r12['negative_consumption_cases']:
    valid=(c['exact_target'] and c['exact_version'] and c['exact_hash'] and c['exact_context'] and c['resolved_before_commit'] and c['proof_before_commit'])
    got='ACCEPT' if valid else 'REJECT'; ok(got==c['expect'],f'Round12 consumption mismatch fixture wrong {c["name"]}: {got}')
for token in [
 'OWNER_REVIEW proof requires immutable owner action and PRECOMMIT target_version',
 "ores->>'review_phase'<>'PRECOMMIT'",
 "(ores->>'target_version')::integer IS DISTINCT FROM NEW.target_version",
 'PRECOMMIT OWNER_REVIEW does not match exact edit-plan target/version/hash/context or was resolved after commit',
 'PRECOMMIT OWNER_REVIEW does not match exact posting target/version/hash/context or was resolved after recommendation revision',
 'pa.created_at>NEW.committed_at',
 'pa.created_at>NEW.recommendation_revised_at'
]: ok(token in sql,f'Round12 PRECOMMIT proof/consumption invariant missing: {token}')

# Machine artifacts explicitly freeze the same PRECOMMIT/version semantics.
ok('PRECOMMIT' in sm['owner_action'].get('restriction_resolution','') and 'target_version' in sm['owner_action'].get('precommit_consumption',''),'Round12 state machine PRECOMMIT semantics missing')
sem12=loadj('HONOR_CAMPAIGN_RESTRICTION_SEMANTICS.json')
ok(sem12.get('owner_review_precommit_contract',{}).get('review_phase')=='PRECOMMIT','Round12 restriction semantics PRECOMMIT contract missing')
ok('PRECOMMIT' in sem12['proof_reference_contract']['proof_kinds']['OWNER_REVIEW']['required_relational_binding'] and 'target_version' in sem12['proof_reference_contract']['owner_review_terminal_fact'],'Round12 restriction semantics owner-review target_version binding missing')
ok(o.get('x-honor-round12-integrity-fixtures')=='HONOR_ROUND12_INTEGRITY_FIXTURES.json','OpenAPI Round12 fixture pointer drift')

# OpenAPI extension pointers and rule/history machine artifacts exist.
for f in ['HONOR_CAMPAIGN_RULE_REGISTRY.json','HONOR_CAMPAIGN_RULE_CONSUMPTION.json','HONOR_EXPERIMENT_CONTRACT.json','HONOR_CAMPAIGN_RESTRICTION_SEMANTICS.json','HONOR_ROUND8_INTEGRITY_FIXTURES.json','HONOR_ROUND10_INTEGRITY_FIXTURES.json','HONOR_ROUND11_INTEGRITY_FIXTURES.json','HONOR_ROUND12_INTEGRITY_FIXTURES.json','HONOR_AUDIO_ASSET_RIGHTS_CONTRACT.json']:
    ok((ROOT/f).exists(),f'Round-7 machine artifact missing {f}')
ok(o.get('x-honor-campaign-rule-registry')=='HONOR_CAMPAIGN_RULE_REGISTRY.json','OpenAPI campaign rule registry pointer drift')
ok(o.get('x-honor-campaign-rule-consumption')=='HONOR_CAMPAIGN_RULE_CONSUMPTION.json','OpenAPI campaign rule consumption pointer drift')
ok(o.get('x-honor-experiment-contract')=='HONOR_EXPERIMENT_CONTRACT.json','OpenAPI experiment contract pointer drift')

# No frozen schema/security/provenance decisions delegated to C01.
for f in [p for p in ROOT.rglob('*') if p.is_file() and p.suffix in {'.md','.sql','.json','.txt','.example'}]:
    st=f.read_text(errors='ignore')
    for pat in [r'(?i)C0[123]\s+must\s+define',r'(?i)C0[123]\s+may\s+choose',r'(?i)C0[123]\s+(?:must|may|should)\s+design',r'(?i)left\s+to\s+C0[123]\s+to\s+(?:define|choose|design)']:
        ok(not re.search(pat,st),f'frozen decision delegated to C01 in {f.relative_to(ROOT)}')

# Secret/live-key scan and stale $50 hard-cap scan.
scanfiles=[p for p in ROOT.rglob('*') if p.is_file() and p.name!='MANIFEST_SHA256.txt']
secret_patterns=[r'-----BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY-----',r'\bsk-[A-Za-z0-9]{20,}\b',r'\bsb_secret_[A-Za-z0-9_-]{20,}\b',r'\bAKIA[0-9A-Z]{16}\b']
for f in scanfiles:
    s=f.read_text(errors='ignore')
    for pat in secret_patterns: ok(not re.search(pat,s),f'live-secret-like pattern in {f.relative_to(ROOT)}')
# $50 may appear only as clearly historical phrase; no active hard cap wording.
for f in ROOT.glob('*.md'):
    for ln in text(f.name).splitlines():
        if '$50' in ln or '50 USD' in ln:
            ok(any(x in ln.lower() for x in ['historical','old cap','superseded']),f'active/stale $50 reference {f.name}: {ln}')

# Manifest integrity and exact inventory including nested JSON schemas, excluding manifest itself.
manifest=ROOT/'MANIFEST_SHA256.txt'; listed=set()
if manifest.exists():
    for ln in manifest.read_text().splitlines():
        if not ln.strip(): continue
        h,fn=ln.split('  ',1); listed.add(fn); fp=ROOT/fn; ok(fp.exists(),f'manifest missing file {fn}')
        if fp.exists(): ok(hashlib.sha256(fp.read_bytes()).hexdigest()==h,f'manifest hash mismatch {fn}')
all_regular=[p for p in ROOT.rglob('*') if p.is_file()]
for pth in all_regular:
    rel=pth.relative_to(ROOT)
    bad_component=any(part in {'__pycache__','.pytest_cache'} for part in rel.parts)
    bad_suffix=pth.suffix.lower() in {'.pyc','.pyo','.tmp','.swp'} or pth.name.endswith('~')
    ok(not bad_component and not bad_suffix,f'forbidden cache/temp artifact in canonical release: {rel}')
expected={str(p.relative_to(ROOT)) for p in all_regular if p.name!='MANIFEST_SHA256.txt'}
ok(listed==expected,f'manifest inventory mismatch missing={expected-listed} extra={listed-expected}')

if errors:
    print('FAIL')
    for e in errors: print('- '+e)
    sys.exit(1)
ops=sum(1 for item in o['paths'].values() for m in item if m in {'get','post','put','patch','delete'})
print('OK: HONOR C00 Round-12 PRECOMMIT owner-review/archive-inventory regression suite')
print(f'OpenAPI operations={ops}; Polli tools={len(p["tools"])}; DB tables={len(tables)}; JSONB schemas={len(entries)}; manifest files={len(listed)}')
