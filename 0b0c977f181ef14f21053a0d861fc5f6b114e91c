"""Reviewable task-only packaging fix/evidence patch; shared index stays untouched."""
import difflib
import hashlib
import json
import shutil
import subprocess
from pathlib import Path

work=Path(__file__).resolve().parent
root=work.parents[1]
out=root/'docs/evidence/backend-compat-deploy-2026-11-07'
before=out/'before/stage_verifier.py'
before.parent.mkdir(exist_ok=True)
shutil.copyfile(work/'before/stage_verifier.py',before)
existing='backend/deploy/stage_verifier.py'
new=[root/'backend/tests/test_verifier_stage.py',root/'docs/BACKEND_COMPAT_DEPLOY_2026_11_07.md']
new+=sorted(path for path in out.rglob('*') if path.is_file() and path.suffix in {'.py','.json','.xml','.log'}
            and path.name not in ('checkpoint-result.json',) and '__pycache__' not in path.parts)
for path in new:
    if path.is_relative_to(out):
        text=path.read_text(encoding='utf-8-sig')
        path.write_text(text if text.endswith('\n') else text+'\n',encoding='utf-8',newline='\n')
chunks=[f'diff --git a/{existing} b/{existing}\n']
chunks+=list(difflib.unified_diff(before.read_text().splitlines(True),(root/existing).read_text().splitlines(True),fromfile='a/'+existing,tofile='b/'+existing))
for path in new:
    name=path.relative_to(root).as_posix()
    chunks.append(f'diff --git a/{name} b/{name}\nnew file mode 100644\n')
    chunks+=list(difflib.unified_diff([],path.read_text(encoding='utf-8-sig').splitlines(True),fromfile='/dev/null',tofile='b/'+name))
patch=out/'task-only.patch'
patch.write_text(''.join(chunks),encoding='utf-8',newline='\n')
value=subprocess.run(['git','apply','--check','--reverse','--whitespace=nowarn',str(patch)],cwd=root,capture_output=True)
index=hashlib.sha256((root/'.git/index').read_bytes()).hexdigest()
assert index=='1766916322d5d5a6072a820e8d2e153fd06373edcc8d5d11d0b1c4dcea8a3c31'
result={'main_index_unchanged':True,'reverse_apply_check_exit':value.returncode,'patch_sha256':hashlib.sha256(patch.read_bytes()).hexdigest(),
        'source_sha256':{name:hashlib.sha256((root/name).read_bytes()).hexdigest() for name in (existing,'backend/tests/test_verifier_stage.py')},
        'new_text_files':len(new),'runtime_fix_checkpoint':'../backend-performance-fixes-2026-11-07/checkpoint-result.json'}
(out/'checkpoint-result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result),flush=True)
if value.returncode:
    print(value.stderr.decode(errors='replace'))
    raise SystemExit(value.returncode)
