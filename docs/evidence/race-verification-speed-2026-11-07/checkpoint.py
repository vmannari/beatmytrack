"""Task-only source/evidence patch, checked without staging or writing objects."""
import difflib,hashlib,json,shutil,subprocess
from pathlib import Path
WORK=Path(__file__).resolve().parent;ROOT=WORK.parents[1]
OUT=ROOT/'docs/evidence/race-verification-speed-2026-11-07'
existing={'game/backend/backend_client.gd':'backend_client.before.gd',
          'game/backend/cloud_tracks.gd':'cloud_tracks.before.gd',
          'game/persistence/cosmetic_catalog.gd':'cosmetic_catalog.before.gd',
          'backend/bmt_backend/publications.py':'publications.before.py'}
new=[ROOT/name for name in ('game/tests/test_prompt_run_confirmation.gd','game/tests/test_cosmetic_wallet_capacity.gd',
     'backend/tests/test_publication_geometry.py','docs/RACE_VERIFICATION_SPEED_2026_11_07.md')]
for name in ('game/tests/test_prompt_run_confirmation.gd.uid','game/tests/test_cosmetic_wallet_capacity.gd.uid'):
    if (ROOT/name).exists():new.append(ROOT/name)
before=OUT/'before';before.mkdir(exist_ok=True)
for name,filename in existing.items():shutil.copyfile(WORK/filename,before/name.replace('/','__'))
shutil.copyfile(Path(__file__),OUT/'checkpoint.py')
new+=sorted(path for path in OUT.rglob('*') if path.is_file() and path.suffix in {'.json','.py','.gd','.xml','.log'}
            and path.name not in ('checkpoint-result.json',) and '__pycache__' not in path.parts)
for path in new:
    if path.is_relative_to(OUT):
        text=path.read_text(encoding='utf-8-sig')
        path.write_text(text if text.endswith('\n') else text+'\n',encoding='utf-8',newline='\n')
chunks=[]
for name in existing:
    chunks.append(f'diff --git a/{name} b/{name}\n')
    chunks+=list(difflib.unified_diff((before/name.replace('/','__')).read_text().splitlines(True),(ROOT/name).read_text().splitlines(True),fromfile='a/'+name,tofile='b/'+name))
for path in new:
    name=path.relative_to(ROOT).as_posix()
    chunks.append(f'diff --git a/{name} b/{name}\nnew file mode 100644\n')
    chunks+=list(difflib.unified_diff([],path.read_text(encoding='utf-8-sig').splitlines(True),fromfile='/dev/null',tofile='b/'+name))
patch=OUT/'task-only.patch';patch.write_text(''.join(chunks),encoding='utf-8',newline='\n')
check=subprocess.run(['git','apply','--check','--reverse','--whitespace=nowarn',str(patch)],cwd=ROOT,capture_output=True)
index=hashlib.sha256((ROOT/'.git/index').read_bytes()).hexdigest()
assert index=='1766916322d5d5a6072a820e8d2e153fd06373edcc8d5d11d0b1c4dcea8a3c31'
result={'main_index_unchanged':True,'reverse_apply_check_exit':check.returncode,
        'patch_sha256':hashlib.sha256(patch.read_bytes()).hexdigest(),'new_text_files':len(new),
        'source_sha256':{name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in existing}}
(OUT/'checkpoint-result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result),flush=True)
if check.returncode:
    print(check.stderr.decode(errors='replace'));raise SystemExit(check.returncode)
