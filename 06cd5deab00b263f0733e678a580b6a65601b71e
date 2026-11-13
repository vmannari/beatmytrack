"""Freeze only compatible read optimizations on the exact live API image."""
import ast
import difflib
import hashlib
import json
from pathlib import Path
import shutil

WORK=Path(__file__).resolve().parent
ROOT=WORK.parents[1]
OUT=ROOT/'docs/evidence/backend-reuse-fixes-2026-10-26'
OUT.mkdir(parents=True,exist_ok=True)
release=WORK/'release';assert not release.exists()
package=release/'bmt_backend'
baseline=WORK/'baseline/bmt_backend'
shutil.copytree(baseline,package,ignore=shutil.ignore_patterns('__pycache__','*.pyc'))

def source_function(source,name):
 node=next(n for n in ast.parse(source).body if isinstance(n,(ast.FunctionDef,ast.AsyncFunctionDef)) and n.name==name)
 # Include decorators: route parameters must be captured together with the endpoint.
 start=min([node.lineno]+[n.lineno for n in node.decorator_list])-1
 return start,node.end_lineno,''.join(source.splitlines(keepends=True)[start:node.end_lineno])

allowed={
 'economy.py':['established_wallet','balance'],
 'runs.py':['recover_submission','run_statuses','get_run','waiting_run_snapshot','wait_run'],
 'rivalry.py':['standings_data','snapshot','current','view','snapshot_response'],
}
for filename,names in allowed.items():
 path=package/filename;original=path.read_text(encoding='utf-8');patched=original
 local=(ROOT/'backend/bmt_backend'/filename).read_text(encoding='utf-8')
 for name in names:
  _,_,replacement=source_function(local,name)
  nodes={n.name:n for n in ast.parse(patched).body if isinstance(n,(ast.FunctionDef,ast.AsyncFunctionDef))}
  if name not in nodes:
   patched+='\n\n'+replacement+'\n'
  else:
   start,end,_=source_function(patched,name)
   lines=patched.splitlines(keepends=True)
   patched=''.join(lines[:start])+replacement+''.join(lines[end:])
 # Every other top-level statement/function remains unchanged.
 def retained(source):
  return [ast.dump(n) for n in ast.parse(source).body
          if not isinstance(n,(ast.FunctionDef,ast.AsyncFunctionDef)) or n.name not in names]
 assert retained(original)==retained(patched),filename
 path.write_text(patched,encoding='utf-8',newline='\n')

path=package/'discovery_v3.py';source=path.read_text(encoding='utf-8')
anchor='    locate_version: str = Field("", max_length=36)\n'
assert source.count(anchor)==1
source=source.replace(anchor,anchor+'    preview_cache: bool = False\n    known_previews: list[Annotated[str, Field(pattern=r"^[0-9a-f]{64}$")]] = Field(default_factory=list, max_length=32)\n',1)
source=source.replace('from contextlib import contextmanager\n','from contextlib import contextmanager\nfrom typing import Annotated\n',1)
anchor='            db.commit()\n            return result'
assert source.count(anchor)==1
source=source.replace(anchor,'            db.commit()\n            if body.preview_cache:\n                from .preview_wire import compact_previews\n                result = compact_previews(result, body.known_previews)\n            return result',1)
path.write_text(source,encoding='utf-8',newline='\n')
path=package/'app.py';source=path.read_text(encoding='utf-8')
anchor='            "ghost_identity_version": 1,\n'
assert source.count(anchor)==1
source=source.replace(anchor,'            "discovery_preview_version": 1,\n            "run_completion_version": 1,\n'+anchor,1)
path.write_text(source,encoding='utf-8',newline='\n')
for name in ('preview_wire.py','completion_reads.py','rivalry_reads.py'):
 assert not (package/name).exists()
 shutil.copyfile(ROOT/'backend/bmt_backend'/name,package/name)
def hashes(folder):
 return {p.relative_to(folder).as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
         for p in sorted(folder.rglob('*')) if p.is_file() and '__pycache__' not in p.parts}
before=hashes(baseline);after=hashes(package)
changed=[name for name in after if before.get(name)!=after[name]]
assert set(changed)=={'app.py','discovery_v3.py','preview_wire.py','economy.py','completion_reads.py','runs.py','rivalry.py','rivalry_reads.py'}
overlay=release/'overlay/bmt_backend';overlay.mkdir(parents=True)
patch=[]
for name in changed:
 shutil.copyfile(package/name,overlay/name)
 old=(baseline/name).read_text(encoding='utf-8').splitlines(keepends=True) if name in before else []
 new=(package/name).read_text(encoding='utf-8').splitlines(keepends=True)
 patch.extend(difflib.unified_diff(old,new,fromfile='a/bmt_backend/'+name,tofile='b/bmt_backend/'+name))
(OUT/'deployed-overlay.patch').write_text(''.join(patch),encoding='utf-8')
api=next(v for v in json.loads((WORK/'inspection.json').read_text()) if v['name'].endswith('-api'))
fingerprint=hashlib.sha256(json.dumps({'parent':api['image'],'changed':{k:after[k] for k in changed}},sort_keys=True).encode()).hexdigest()
tag='europe-west1-docker.pkg.dev/beat-my-track/bmt-stg-e7a444ab-images/backend-reuse:read-'+fingerprint[:20]
(release/'Dockerfile').write_text('FROM '+api['image']+'\nCOPY overlay/bmt_backend/ /app/bmt_backend/\nRUN python -c "from bmt_backend.rivalry_reads import response; from bmt_backend.completion_reads import enrich; from bmt_backend.preview_wire import compact_previews"\n',encoding='utf-8')
receipt={'parent':api['image'],'prior_revision':api['revision'],'url':api['url'],'tag':tag,'source_hash':fingerprint,
 'changed_files':changed,'unchanged_existing_files':len(before)-5,'baseline_hashes':before,'package_hashes':after,
 'new_capabilities':['discovery_preview_version','run_completion_version'],
 'schema_migration':False,'worker_update':False,'studio_update':False,'physics_change':False,'retention_change':False}
for path in (WORK/'release.json',OUT/'release.json'):path.write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
tests=WORK/'test-work/backend/tests'
shutil.copytree(ROOT/'build/backend-ghost-cache-deploy-2026-10-26/test-work/backend/tests',tests,ignore=shutil.ignore_patterns('__pycache__','*.pyc'))
shutil.copyfile(ROOT/'backend/tests/test_backend_reuse.py',tests/'test_backend_reuse.py')
print(json.dumps({k:receipt[k] for k in ('tag','changed_files','unchanged_existing_files','schema_migration','new_capabilities')},indent=2))
