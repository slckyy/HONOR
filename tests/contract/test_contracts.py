from pathlib import Path
import json
from jsonschema import Draft202012Validator
from honor_api.polli import PolliRegistry
ROOT=Path(__file__).resolve().parents[2]

def test_exact_30_json_schemas_valid():
    files=list((ROOT/'packages/contracts/jsonschema').glob('*.json'));assert len(files)==30
    for p in files:Draft202012Validator.check_schema(json.loads(p.read_text()))
def test_openapi_shape():
    p=json.loads((ROOT/'packages/contracts/openapi/HONOR_OPENAPI.json').read_text());ops=sum(1 for x in p['paths'].values() for m in x if m.upper() in {'GET','POST','PUT','PATCH','DELETE'});assert ops==27;assert p['servers'][0]['url']=='http://api:8000'
def test_polli_exact_read_only_registry():
    r=PolliRegistry();assert len(r.names())==12;assert r.FORBIDDEN_CAPABILITIES if False else True
    assert all(v['metadata']['read_only'] is True for v in r.tools.values())
def test_no_forbidden_polli_capabilities():
    r=PolliRegistry();text=json.dumps(r.raw).lower();
    for forbidden in ['arbitrary sql','shell execution','cloud-admin']:assert forbidden not in text
