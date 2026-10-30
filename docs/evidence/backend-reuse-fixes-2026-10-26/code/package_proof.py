"""Compare code, dependencies and canonical verifier bytes in both images."""
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import subprocess

WORK=Path(__file__).resolve().parent
OUT=WORK.parents[1]/'docs/evidence/backend-reuse-fixes-2026-10-26'
release=json.loads((WORK/'release.json').read_text())
program='''import hashlib,json
from pathlib import Path
def hashes(root):
 return {p.relative_to(root).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(root.rglob('*')) if p.is_file() and '__pycache__' not in p.parts}
print(json.dumps({'package':hashes(Path('/app/bmt_backend')),'canonical':hashes(Path('/opt/bmt/game')),'engine':hashlib.sha256(Path('/usr/local/bin/godot').read_bytes()).hexdigest(),'requirements':hashlib.sha256(Path('/app/requirements.lock').read_bytes()).hexdigest()}))
'''
def inspect(image):
 result=subprocess.run(['wsl.exe','-d','Ubuntu','--','docker','run','--rm','--network=none',
    '--entrypoint=python',image,'-c',program],capture_output=True,text=True,timeout=90)
 assert result.returncode==0,result.stderr
 return json.loads(result.stdout)
with ThreadPoolExecutor(max_workers=2) as pool:
 parent,candidate=list(pool.map(inspect,(release['parent'],release['tag'])))
assert parent['package']==release['baseline_hashes']
assert candidate['package']==release['package_hashes']
for key in ('canonical','engine','requirements'):assert parent[key]==candidate[key]
proof={'parent':release['parent'],'candidate_tag':release['tag'],
       'all_package_hashes_match_frozen_release':True,'changed_files':release['changed_files'],
       'unchanged_existing_package_files':release['unchanged_existing_files'],
       'canonical_files_identical':len(parent['canonical']),'canonical_hashes':parent['canonical'],
       'engine_sha256':parent['engine'],'requirements_sha256':parent['requirements']}
(OUT/'package-proof.json').write_text(json.dumps(proof,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in proof.items() if k!='canonical_hashes'},indent=2))
