"""Build and round-trip only this task's patch in an owned repository."""
import difflib
import hashlib
import json
from pathlib import Path
import subprocess
import time

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
prefix = OUT.relative_to(ROOT).as_posix()
changed = ['game/core/app.gd','game/ui/header_car_appearance_cache.gd','game/ui/profile_car.gd',
           'AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md']
new = ['game/tests/profile_deferred_header.gd','game/tests/test_deferred_header.gd','game/tests/test_header_capture_fences.gd',
       'docs/STARTUP_THUMBNAIL_2026_11_05.md']
new += [prefix+'/'+name for name in ['freeze_project.py','run_case.py','run_matrix.py','validate.py','update_trackers.py','checkpoint.py','validation.json']]
owned = ROOT/'build/startup-thumbnail-20261105'/('checkpoint-'+str(time.time_ns()))
owned.mkdir(parents=True)
subprocess.run(['git','init','--quiet',str(owned)],check=True)
before = {path:(OUT/'before'/path).read_bytes() for path in changed}
after = {path:(ROOT/path).read_bytes() for path in changed+new}
patch = []
for path in changed+new:
    original = before.get(path,b'')
    if path in before:
        destination = owned/path
        destination.parent.mkdir(parents=True,exist_ok=True)
        destination.write_bytes(original)
    patch.append(''.join(difflib.unified_diff(original.decode('utf-8').splitlines(True),after[path].decode('utf-8').splitlines(True),
                                           fromfile='a/'+path if path in before else '/dev/null',tofile='b/'+path)))
patch_path = OUT/'task.patch'
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
report = dict(files=len(after),path=str(patch_path),sha256=hashlib.sha256(patch_path.read_bytes()).hexdigest(),
              checked=True,forward_byte_exact=True,reverse_byte_exact=True,main_index_written=False,commands=commands)
(OUT/'checkpoint.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps({key:value for key,value in report.items() if key!='commands'}))
