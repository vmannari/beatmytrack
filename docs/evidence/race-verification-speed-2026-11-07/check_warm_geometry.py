"""Fresh-process proof that published race descriptors need no object/native IO."""
import importlib.util
import json
from pathlib import Path
WORK=Path(__file__).resolve().parent
ROOT=WORK.parents[1]
OUT=ROOT/'docs/evidence/race-verification-speed-2026-11-07'
spec=importlib.util.spec_from_file_location('last_release',ROOT/'build/backend-compat-deploy-20261107/deploy.py')
r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
r.d.WORK=WORK;r.d.OUT=OUT;r.d.STATE=WORK/'warm-check-state.private.json'
r.d.state=json.loads(r.d.STATE.read_text()) if r.d.STATE.exists() else {}
code='''import json,time,statistics
from bmt_backend.app import create_app
from bmt_backend.catalog_builds import published_heads
from bmt_backend.trajectory_verifier import prepared_geometry
from bmt_backend.contracts import build_contract
a=create_app();active=build_contract(a.state.verifier.manifest())
def forbidden(*args,**kwargs):raise RuntimeError('A prepared published track attempted object/native preparation')
a.state.verifier.race_geometry=forbidden;a.state.blobs.get_json=forbidden
try:
 with a.state.session_factory() as session:
  hashes=sorted({v.content_hash for v in published_heads(session)})
 values=[]
 for key in hashes:
  started=time.monotonic();geometry=prepared_geometry(a,key)
  assert build_contract(geometry['manifest'])==active
  values.append(time.monotonic()-started)
 print('RELEASE_RESULT='+json.dumps({'tracks':len(values),'median_seconds':statistics.median(values),'max_seconds':max(values),'native_geometry_calls':0,'object_reads':0,'fresh_process':True}))
finally:a.state.verifier.close();a.state.engine.dispose()
'''
job=r.service.n['api'].removesuffix('-api')+'-catalog'
print(json.dumps(r.d.execute('check-prepared-race-geometry',code,job=job,timeout=300),indent=2),flush=True)
