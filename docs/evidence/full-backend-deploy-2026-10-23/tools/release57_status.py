"""Read-only cloud release health details; no account payloads are printed."""
import importlib.util
import json
import sys
from pathlib import Path
import requests

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('cut57',ROOT/'.tools/release57_cutover.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
d=module.d
key=d.u.staff_key(d.service.describe('api',d.service.n['api']))
for path in sys.argv[1:]:
    assert path.startswith('/v1/admin/')
    response=requests.get(d.r['url']+path,headers={'Authorization':'Bearer '+key},timeout=(5,60))
    value=response.json()
    print(json.dumps({'path':path.split('?')[0],'status':response.status_code,'error':value if response.status_code!=200 else None,
                      'health':{k:v for k,v in value.items() if k in ('status','queue_depth','available_workers','product','discovery','telemetry')},
                      'keys':list(value)}))
