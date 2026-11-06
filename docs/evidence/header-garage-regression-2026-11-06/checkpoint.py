"""Round-trip this task's source patch in an owned repository, never the main index."""
import difflib
import hashlib
import json
from pathlib import Path
import subprocess
import time

out = Path(__file__).resolve().parent
root = out.parents[2]
prefix = out.relative_to(root).as_posix()
changed = ['game/core/app.gd','game/core/features/garage.gd',
           'game/ui/header_car_appearance_cache.gd','game/ui/garage_preloader.gd',
           'game/ui/garage_preloaded_studio.gd','scripts/build_identity.ps1',
           'scripts/garage_preview_identity.ps1','scripts/test_build_identity.ps1',
           'game/tests/test_header_capture_fences.gd','game/tests/test_deferred_header.gd']
new = ['game/tests/profile_header_garage_regression.gd',
       'docs/HEADER_GARAGE_LOADING_REGRESSION_2026_11_06.md']
new += [prefix+'/'+name for name in ['freeze_project.py','run_case.py','run_entry.py',
                                    'validate.py','validation.json','checkpoint.py']]
owned = root/'build/header-garage-regression-20261106'/('checkpoint-'+str(time.time_ns()))
owned.mkdir(parents=True)
subprocess.run(['git','init','--quiet',str(owned)],check=True)
before = {p:(out/'before'/p).read_bytes() for p in changed}
after = {p:(root/p).read_bytes() for p in changed+new}
patch = []
for path in changed+new:
    original = before.get(path,b'')
    if path in before:
        target = owned/path
        target.parent.mkdir(parents=True,exist_ok=True)
        target.write_bytes(original)
    patch.append(''.join(difflib.unified_diff(original.decode('utf-8').splitlines(True),
        after[path].decode('utf-8').splitlines(True),
        fromfile='a/'+path if path in before else '/dev/null',tofile='b/'+path)))
patch_path = out/'task.patch'
patch_path.write_bytes(''.join(patch).encode('utf-8'))
commands = []
def git(*args):
    command = ['git','-C',str(owned),'-c','core.autocrlf=false','-c','core.eol=lf',*args]
    result = subprocess.run(command,check=True,capture_output=True,text=True)
    commands.append(dict(command=command,exit_code=result.returncode,stdout=result.stdout,stderr=result.stderr))
git('apply','--check','--whitespace=error',str(patch_path))
git('apply','--whitespace=error',str(patch_path))
for path,data in after.items(): assert (owned/path).read_bytes()==data,path
git('apply','--reverse','--check',str(patch_path))
git('apply','--reverse',str(patch_path))
for path,data in before.items(): assert (owned/path).read_bytes()==data,path
for path in new: assert not (owned/path).exists(),path
report = dict(files=len(after),sha256=hashlib.sha256(patch_path.read_bytes()).hexdigest(),
    checked=True,forward_byte_exact=True,reverse_byte_exact=True,main_index_written=False,commands=commands)
(out/'checkpoint.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({key:value for key,value in report.items() if key!='commands'}))
