"""Prepare exact derived descriptors before races; never edits tracks or scores."""
import importlib.util
import json
from pathlib import Path
WORK=Path(__file__).resolve().parent
ROOT=WORK.parents[1]
OUT=ROOT/'docs/evidence/race-verification-speed-2026-11-07'
spec=importlib.util.spec_from_file_location('last_release',ROOT/'build/backend-compat-deploy-20261107/deploy.py')
r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
r.d.WORK=WORK;r.d.OUT=OUT;r.d.STATE=WORK/'warm-state.private.json'
r.d.state=json.loads(r.d.STATE.read_text()) if r.d.STATE.exists() else {}
code='''import json,time
from bmt_backend.app import create_app
from bmt_backend.catalog_builds import published_heads
from bmt_backend.trajectory_verifier import prepared_geometry
from bmt_backend.contracts import build_contract
a=create_app();started=time.monotonic();active=build_contract(a.state.verifier.manifest())
try:
 with a.state.session_factory() as session:
  hashes=sorted({v.content_hash for v in published_heads(session)})
 rows=[]
 for key in hashes:
  stamp=time.monotonic();geometry=prepared_geometry(a,key)
  assert build_contract(geometry['manifest'])==active
  rows.append({'gates':len(geometry['gates']),'seconds':round(time.monotonic()-stamp,4)})
 print('RELEASE_RESULT='+json.dumps({'tracks':len(rows),'seconds':round(time.monotonic()-started,4),'prepared':rows,'layout_version':24,'tracks_or_scores_modified':False}))
finally:
 a.state.verifier.close();a.state.engine.dispose()
'''
job=r.service.n['api'].removesuffix('-api')+'-catalog'
print(json.dumps(r.d.execute('warm-active-race-geometry',code,job=job,timeout=900),indent=2),flush=True)
