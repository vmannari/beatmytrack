"""Reversible task-only source/evidence patch; no main-index operation."""
import difflib
import hashlib
import json
import os
import shutil
import subprocess
import time
from pathlib import Path

E = Path(__file__).resolve().parent
ROOT = E.parents[2]
OUT = ROOT/'build/tablet-loading-fixes-20261107'
marker = 'TABLET-LOADING-FIXES-20261107'
runtime = ['game/backend/menu_snapshot_writer.gd','game/vehicle/prepared_car_cache.gd','game/track/spatial_mesh_chunks.gd']
scratch = OUT/('checkpoint-'+str(time.time_ns()))
scratch.mkdir()
env = {**os.environ,'GIT_OPTIONAL_LOCKS':'0'}
subprocess.run(['git','init','--quiet',str(scratch)],check=True,env=env)
# Unified-diff artifacts intentionally contain space-prefixed tab indentation
# and blank context lines. Keep whitespace errors enabled for actual sources.
(scratch/'.gitattributes').write_text('docs/evidence/tablet-loading-fixes-2026-11-07/*.patch -whitespace\ndocs/evidence/tablet-loading-fixes-2026-11-07/**/*.patch -whitespace\n',encoding='utf-8')
for name in runtime:
    target = scratch/name
    target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(ROOT/name,target)
subprocess.run(['git','-C',str(scratch),'apply','--reverse',str(E/'runtime.patch')],check=True,env=env)
before = {name:(scratch/name).read_bytes() for name in runtime}
for name in ['AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md']:
    data = (ROOT/name).read_bytes()
    start = data.index(('<!-- '+marker+' -->').encode())
    end = data.index(('<!-- /'+marker+' -->').encode(),start)+len('<!-- /'+marker+' -->')
    while data[end:end+1] in (b'\r',b'\n'): end += 1
    before[name] = data[:start]+data[end:]
excluded = {'task.patch','checkpoint.json','files.json'}
inventory = {p.relative_to(E).as_posix():{'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
    for p in E.rglob('*') if p.is_file() and p.name not in excluded and '__pycache__' not in p.parts}
(E/'files.json').write_text(json.dumps(inventory,indent=2)+'\n')
new = ['docs/TABLET_LOADING_FIXES_2026_11_07.md','game/track/spatial_mesh_preparation.gd']
new += ['game/tests/'+name+'.gd' for name in ['test_fitted_simple_cache','test_snapshot_writer_lifecycle','test_spatial_worker_object_ranges','profile_loading_world_stages']]
new += [name+'.uid' for name in list(new) if name.endswith('.gd') and (ROOT/(name+'.uid')).exists()]
new += [p.relative_to(ROOT).as_posix() for p in E.rglob('*') if p.is_file() and p.name not in {'task.patch','checkpoint.json'}
    and '__pycache__' not in p.parts and p.suffix in {'.py','.gd','.json','.md','.uid','.log','.patch'}]
new = sorted(set(new))
after = {name:(ROOT/name).read_bytes() for name in list(before)+new}
patch = []
for name,data in after.items():
    original = before.get(name,b'')
    if name in before:
        target = scratch/name
        target.parent.mkdir(parents=True,exist_ok=True)
        target.write_bytes(original)
    lines = difflib.unified_diff(original.decode('utf-8').splitlines(True),data.decode('utf-8').splitlines(True),
        fromfile='a/'+name if name in before else '/dev/null',tofile='b/'+name)
    patch.append(''.join(line if line.endswith('\n') else line+'\n\\ No newline at end of file\n' for line in lines))
path = E/'task.patch'
path.write_bytes(''.join(patch).encode())
commands = []
for args in [('apply','--check','--whitespace=error'),('apply','--whitespace=error'),('apply','--reverse','--check'),('apply','--reverse')]:
    if args==('apply','--reverse','--check'):
        for name,data in after.items(): assert (scratch/name).read_bytes()==data,name
    command = ['git','-C',str(scratch),'-c','core.autocrlf=false',
        '-c','core.whitespace=trailing-space,space-before-tab,cr-at-eol,-blank-at-eof',*args,str(path)]
    result = subprocess.run(command,env=env,capture_output=True,text=True)
    commands.append({'command':command,'exit_code':result.returncode})
    assert result.returncode==0,result.stderr
for name,data in before.items(): assert (scratch/name).read_bytes()==data,name
for name in new: assert not (scratch/name).exists(),name
receipt = {'files':len(after),'forward_byte_exact':True,'reverse_byte_exact':True,
    'patch_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'commands':commands,'main_index_written':False,
    'raw_diff_artifacts':'Whitespace exemption only for literal unified-diff context lines in archived .patch files; runtime/tests/docs retain whitespace=error.',
    'scope':'Authored runtime/tests, journals and text evidence. PNG evidence is hash-inventoried; prepared binaries include concurrent authorship and are reproduced via asset manifests, not included as a task-only binary diff.'}
(E/'checkpoint.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps({k:v for k,v in receipt.items() if k!='commands'}))
