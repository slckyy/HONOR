from honor_api.logging import redact

def test_redaction():
    x=redact({'authorization':'Bearer abc','nested':{'api_key':'secret','ok':'value'},'url':'postgresql://u:p@localhost/db'})
    assert x['authorization']=='[REDACTED]' and x['nested']['api_key']=='[REDACTED]' and x['nested']['ok']=='value' and 'u:p' not in x['url']
