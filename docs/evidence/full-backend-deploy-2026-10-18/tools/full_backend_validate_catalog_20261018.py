"""Read public immutable documents and validate them on the exact local release image."""
import importlib.util
import json
import subprocess
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from urllib.parse import urlencode

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('full_release',ROOT/'.tools/full_backend_deploy_20261018.py')
release=importlib.util.module_from_spec(spec);spec.loader.exec_module(release)
d=release.d
path='/v1/tracks?limit=20';items=[];pages=0
while path:
    value=d.u.fetch(d.r['url'],path).json();items.extend(value['items']);pages+=1
    path='/v1/tracks?'+urlencode({'limit':20,'cursor':value['next_cursor']}) if value.get('next_cursor') else None
    assert pages<=10

def fetch(row):
    response=d.u.fetch(d.r['url'],'/v1/track-versions/'+row['version_id']+'/document')
    assert d.digest(response.content)==row['content_hash']
    return {**row,'document':response.json()}

with ThreadPoolExecutor(max_workers=3) as pool:
    inputs=list(pool.map(fetch,items))
destination=d.WORK/'offline-catalog-input.json'
destination.write_text(json.dumps(inputs),encoding='utf-8')
code='''import hashlib,json
from pathlib import Path
from bmt_backend.config import Settings
from bmt_backend.verifier import GodotVerifier
from bmt_backend.storage import canonical_json
v=GodotVerifier(Settings.from_env());results=[]
try:
 for row in json.loads(Path('/validation/input.json').read_text()):
  assert hashlib.sha256(canonical_json(row['document'])).hexdigest()==row['content_hash']
  manifest=v.validate_track(row['document'])
  assert manifest['rules_key']=='standing-5-road-gates-v23'
  results.append({k:row[k] for k in ['track_id','version_id','name','content_hash']})
 print(json.dumps({'tracks':results,'manifest':v.manifest(),'all_documents_exact':True,'local_native_validation':True}))
finally:v.close()
'''
source='/mnt/'+destination.drive[0].lower()+destination.as_posix()[2:]
command=['wsl.exe','-d','Ubuntu','--','docker','run','--rm','-i','--network=none','--entrypoint=python',
    '--mount=type=bind,source='+source+',target=/validation/input.json,readonly',d.r['local_tag'],'-']
result=subprocess.run(command,input=code,capture_output=True,text=True,encoding='utf-8',timeout=900)
if result.returncode:
    (d.WORK/'offline-catalog-error.private.log').write_text(result.stdout+result.stderr,encoding='utf-8')
    raise RuntimeError('Native catalog validation failed; see private error log')
value=json.loads(result.stdout)
assert value['manifest']==d.r['expected_manifest']
(d.OUTPUT/'offline-catalog-validation.json').write_text(json.dumps(value,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'public_documents':len(value['tracks']),'exact_hashes':True,'native_rules23':True,'cloud_writes':0}))
