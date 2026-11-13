"""Final same-schema source/native/storage checks after rollout."""
import hashlib,json
from pathlib import Path
import server_release as r
assert r.s.get('complete')
code='''import hashlib,json,os
from pathlib import Path
from bmt_backend.config import Settings
from bmt_backend.cloud_smoke import check
from bmt_backend.verifier import GodotVerifier
import bmt_backend.publications as publications
module=hashlib.sha256(Path(publications.__file__).read_bytes()).hexdigest()
assert module==EXPECTED
settings=Settings.from_env();fixture=json.loads(Path('/opt/bmt/acceptance/verified_oval.json').read_text())
verifier=GodotVerifier(settings)
try:fixture['expected_manifest']=verifier.validate_track(fixture['document'])
finally:verifier.close()
path=Path('/tmp/race-speed-oval.json');path.write_text(json.dumps(fixture))
result=check(settings,os.environ['BMT_STAGING_OWNER'],fixture_path=path)
result['module_sha256']=module
print('RELEASE_RESULT='+json.dumps(result))
'''.replace('EXPECTED',repr(r.s['module_sha256']))
value=r.d.execute('race-speed-native-smoke',code,timeout=420)
assert value['status']=='passed' and value['canonical_ticks']==12757
revisions=[r.s['route_'+role]['revisionName'] for role in ('main','studio','preview')]
worker=r.service.describe('worker',r.service.n['worker'])
if worker.get('status',{}).get('latestReadyRevisionName'):revisions.append(worker['status']['latestReadyRevisionName'])
query='('+' OR '.join('resource.labels.revision_name="'+value+'"' for value in revisions)+') AND (severity>=ERROR OR httpRequest.status>=500)'
logs=json.loads(r.service.call('logging','read',query,'--limit=100','--format=json'))
r.d.write(r.WORK/'final-runtime-errors.private.json',logs)
r.d.write(r.OUT/'final-runtime-errors.json',{'revisions':revisions,'error_entries':len(logs),'messages_exported':False})
assert not logs,'New runtime errors require investigation'
r.s['live_verified']=True;r.d.save()
print(json.dumps(value),flush=True)
