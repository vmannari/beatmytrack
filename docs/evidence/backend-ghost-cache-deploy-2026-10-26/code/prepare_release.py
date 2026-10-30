"""Freeze a six-file ghost-download overlay on the exact deployed API."""
import ast
import difflib
import hashlib
import json
from pathlib import Path
import shutil

WORK=Path(__file__).resolve().parent
ROOT=WORK.parents[1]
OUT=ROOT/'docs/evidence/backend-ghost-cache-deploy-2026-10-26'
OUT.mkdir(parents=True,exist_ok=True)
baseline=WORK/'baseline/bmt_backend'
release=WORK/'release'
if release.exists():
 assert release.resolve()==WORK/'release' and not (release/'Dockerfile').exists()
 failed=WORK/'release-initial-anchor-failure'
 assert not failed.exists()
 release.rename(failed)
package=release/'bmt_backend'
shutil.copytree(baseline,package,ignore=shutil.ignore_patterns('__pycache__','*.pyc'))

def replace_once(source,before,after):
 assert source.count(before)==1, 'Patch anchor missing or ambiguous: '+before[:70]
 return source.replace(before,after,1)

for name in ('challenges.py','rivalry.py'):
 path=package/name
 original=path.read_text(encoding='utf-8')
 node=next(n for n in ast.parse(original).body if isinstance(n,ast.FunctionDef) and n.name=='ghost')
 lines=original.splitlines(keepends=True)
 function=''.join(lines[node.lineno-1:node.end_lineno])
 source=function
 if name=='challenges.py':
  source=replace_once(source,'stage: int | None = Query(default=None, ge=0, le=2)):',
      'stage: int | None = Query(default=None, ge=0, le=2), metadata: bool = False, expected_run_id: str = "", encoding: str = "json"):')
 else:
  source=replace_once(source,'def ghost(group_id: str, slot: int, driver_id: str, request: Request, session: BoardDB, player: Auth):',
      'def ghost(group_id: str, slot: int, driver_id: str, request: Request, session: BoardDB, player: Auth,\n          metadata: bool = False, expected_run_id: str = "", encoding: str = "json"):')
 source=replace_once(source,'    run_id, ghost_hash = run.id, run.ghost_hash\n    session.commit()\n    return {"run_id": run_id, "recording": request.app.state.blobs.get_json(ghost_hash)}',
     '    run_id, ghost_hash, owner_id = run.id, run.ghost_hash, run.player_id\n    session.commit()\n    from .ghost_http import recording_response\n    return recording_response(request, run_id, ghost_hash, owner_id, metadata=metadata, expected_run_id=expected_run_id, encoding=encoding)')
 source=''.join(lines[:node.lineno-1])+source+''.join(lines[node.end_lineno:])
 # Every other function/class/import remains exact at the syntax-tree level.
 old=ast.parse(original);new=ast.parse(source)
 assert len(old.body)==len(new.body)
 changed=[]
 for a,b in zip(old.body,new.body):
  if ast.dump(a)!=ast.dump(b):
   assert isinstance(a,ast.FunctionDef) and a.name=='ghost' and b.name=='ghost'
   assert [ast.dump(x) for x in a.body[:-3]]==[ast.dump(x) for x in b.body[:-4]]
   changed.append(a.name)
 assert changed==['ghost']
 path.write_text(source,encoding='utf-8',newline='\n')

path=package/'app.py'
source=path.read_text(encoding='utf-8')
source=replace_once(source,'    app.state.blobs = make_blob_store(settings, app.state.session_factory)\n',
 '    app.state.blobs = make_blob_store(settings, app.state.session_factory)\n    from .immutable_payloads import ImmutablePayloadCache\n    app.state.immutable_payloads = ImmutablePayloadCache()\n')
source=replace_once(source,'            "upload_encodings": ["identity", "gzip"],\n',
 '            "upload_encodings": ["identity", "gzip"],\n            "ghost_identity_version": 1,\n            "ghost_wire_version": 1,\n')
path.write_text(source,encoding='utf-8',newline='\n')

for name in ('ghost_http.py','ghost_wire.py','immutable_payloads.py'):
 assert not (package/name).exists()
 shutil.copyfile(ROOT/'backend/bmt_backend'/name,package/name)

def hashes(directory):
 return {p.relative_to(directory).as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
         for p in sorted(directory.rglob('*')) if p.is_file() and '__pycache__' not in p.parts}
before=hashes(baseline);after=hashes(package)
changed=[name for name in after if before.get(name)!=after[name]]
assert set(changed)=={'app.py','challenges.py','rivalry.py','ghost_http.py','ghost_wire.py','immutable_payloads.py'}
assert set(before).issubset(after)
overlay=release/'overlay/bmt_backend';overlay.mkdir(parents=True)
patch=[]
for name in changed:
 shutil.copyfile(package/name,overlay/name)
 old=(baseline/name).read_text(encoding='utf-8').splitlines(keepends=True) if name in before else []
 new=(package/name).read_text(encoding='utf-8').splitlines(keepends=True)
 patch.extend(difflib.unified_diff(old,new,fromfile='a/bmt_backend/'+name,tofile='b/bmt_backend/'+name))
(OUT/'deployed-overlay.patch').write_text(''.join(patch),encoding='utf-8',newline='\n')
inspection=json.loads((WORK/'inspection.json').read_text())
api=next(x for x in inspection if x['name'].endswith('-api'))
fingerprint=hashlib.sha256(json.dumps({'parent':api['image'],'changed':{k:after[k] for k in changed}},sort_keys=True).encode()).hexdigest()
tag='europe-west1-docker.pkg.dev/beat-my-track/bmt-stg-e7a444ab-images/ghost-cache:cache-'+fingerprint[:20]
(release/'Dockerfile').write_text('FROM '+api['image']+'\nCOPY overlay/bmt_backend/ /app/bmt_backend/\nRUN python -c "from bmt_backend.ghost_http import recording_response; from bmt_backend.ghost_wire import compact; from bmt_backend.immutable_payloads import ImmutablePayloadCache"\n',encoding='utf-8')
receipt={'parent':api['image'],'prior_revision':api['revision'],'url':api['url'],'tag':tag,'source_hash':fingerprint,
 'changed_files':changed,'unchanged_existing_files':len(before)-3,'baseline_hashes':before,'package_hashes':after,
 'schema_migration':False,'worker_update':False,'studio_update':False,'physics_change':False,'retention_change':False}
(WORK/'release.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
(OUT/'release.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
tests=WORK/'test-work/backend/tests';tests.mkdir(parents=True)
prior=ROOT/'build/security-deploy-2026-10-24/frozen/backend/tests'
for path in prior.rglob('*'):
 if path.is_file() and '__pycache__' not in path.parts and path.suffix in ('.py','.json'):
  target=tests/path.relative_to(prior);target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(path,target)
shutil.copyfile(WORK/'test_ghost_cache_release.py',tests/'test_ghost_cache_release.py')
print(json.dumps({k:receipt[k] for k in ('parent','tag','changed_files','unchanged_existing_files','schema_migration','worker_update')},indent=2))
