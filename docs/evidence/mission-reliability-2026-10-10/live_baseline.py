"""Read current owned development image/readiness; no sessions or race writes."""
import importlib.util
import json
import os
from pathlib import Path

import httpx

ROOT=Path(__file__).resolve().parents[2]
private=ROOT/'.tools/gcp-staging'
os.environ['CLOUDSDK_CORE_CUSTOM_CA_CERTS_FILE']=str(private/'windows-trust.pem')
os.environ['REQUESTS_CA_BUNDLE']=str(private/'windows-trust.pem')
spec=importlib.util.spec_from_file_location('stage',ROOT/'backend/deploy/gcp/staging.py')
stage=importlib.util.module_from_spec(spec);spec.loader.exec_module(stage)
config=json.loads((private/'config.json').read_text())
assert config['retain_data'] and config['project']=='beat-my-track'
service=stage.Staging(config,private/('rendered-'+config['owner']))
api=service.describe('api',service.n['api']);worker=service.describe('worker',service.n['worker'])
receipt=json.loads((service.directory/'deployment.json').read_text())
ready=httpx.get(receipt['url']+'/ready',verify=str(private/'windows-trust.pem'),timeout=30)
report={'api_image':stage.resource_image(api),'worker_image':stage.resource_image(worker),
        'readiness_status':ready.status_code,'readiness':ready.json(),'writes':False}
assert ready.status_code==200
Path(__file__).with_name('live-baseline.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report))
