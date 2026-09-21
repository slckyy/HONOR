import os,urllib.request

def ping():
    url=os.getenv('BETTERSTACK_WORKER_HEARTBEAT_URL','')
    if not url:return False
    req=urllib.request.Request(url,method='GET');
    with urllib.request.urlopen(req,timeout=5) as r:return 200<=r.status<300
