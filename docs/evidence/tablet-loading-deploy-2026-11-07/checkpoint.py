"""Round-trip this deployment's documentation in an owned scratch repository."""
import difflib
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
MARKER = 'TABLET-LOADING-DEPLOY-20261107'
before = {}
for name in ['AGENTS.md', 'DEVELOPMENT_STATUS.md', 'docs/PHASE_0_PLAN.md']:
    data = (ROOT/name).read_bytes()
    start = data.index(('<!-- '+MARKER+' -->').encode())
    end = data.index(('<!-- /'+MARKER+' -->').encode(), start)+len('<!-- /'+MARKER+' -->')
    while data[end:end+1] in [b'\r', b'\n']:
        end += 1
    before[name] = data[:start]+data[end:]
inventory = {p.name: {'bytes':p.stat().st_size, 'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
             for p in OUT.iterdir() if p.is_file() and p.name not in ['checkpoint.json','task.patch','files.json']}
(OUT/'files.json').write_text(json.dumps(inventory,indent=2)+'\n')
new = ['docs/TABLET_LOADING_DEPLOYMENT_2026_11_07.md']
new += [p.relative_to(ROOT).as_posix() for p in OUT.iterdir()
        if p.is_file() and p.suffix in ['.py','.json'] and p.name != 'checkpoint.json']
new = sorted(set(new))
after = {name:(ROOT/name).read_bytes() for name in list(before)+new}
scratch = ROOT/'build/tablet-loading-deploy-20261107'/('checkpoint-'+str(time.time_ns()))
scratch.mkdir()
env = {**os.environ,'GIT_OPTIONAL_LOCKS':'0'}
subprocess.run(['git','init','--quiet',str(scratch)],check=True,env=env)
patch = []
for name,data in after.items():
    original = before.get(name,b'')
    if name in before:
        destination = scratch/name
        destination.parent.mkdir(parents=True,exist_ok=True)
        destination.write_bytes(original)
    lines = difflib.unified_diff(original.decode().splitlines(True),data.decode().splitlines(True),
                 fromfile='a/'+name if name in before else '/dev/null',tofile='b/'+name)
    patch.append(''.join(line if line.endswith('\n') else line+'\n\\ No newline at end of file\n' for line in lines))
path = OUT/'task.patch'
path.write_bytes(''.join(patch).encode())
commands = []
for args in [('apply','--check','--whitespace=error'),('apply','--whitespace=error'),
             ('apply','--reverse','--check'),('apply','--reverse')]:
    if args == ('apply','--reverse','--check'):
        for name,data in after.items():
            assert (scratch/name).read_bytes()==data,name
    command = ['git','-C',str(scratch),'-c','core.autocrlf=false','-c','core.whitespace=trailing-space,space-before-tab,cr-at-eol',*args,str(path)]
    result = subprocess.run(command,env=env,check=True,capture_output=True,text=True)
    commands.append({'command':command,'exit_code':result.returncode})
for name,data in before.items():
    assert (scratch/name).read_bytes()==data,name
for name in new:
    assert not (scratch/name).exists(),name
report = {'files':len(after),'forward_byte_exact':True,'reverse_byte_exact':True,
          'patch_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'commands':commands,
          'main_repository_staged_or_committed':False}
(OUT/'checkpoint.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k!='commands'}))
