"""Verify the scoped shader/asset change in private Git repositories."""
import hashlib
import json
from pathlib import Path
import subprocess
import time

evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
base = evidence.relative_to(root).as_posix()
before, after = {}, {}
for path in (evidence/'before').rglob('*'):
    if not path.is_file(): continue
    name = path.relative_to(evidence/'before').as_posix()
    if path.read_bytes() != (root/name).read_bytes():
        before[name], after[name] = path.read_bytes(), (root/name).read_bytes()
added = ['game/tests/test_volt_night_glass_shape.gd', 'game/tests/probe_volt_canopy_normals.gd',
         'game/tests/probe_volt_glass_shape_pictures.gd',
         'game/tests/probe_volt_glass_shape_pixels.gd', 'game/tests/review_volt_canopy_candidate.gd',
         'docs/VOLT_NIGHT_GLASS_SHAPE_2026_11_06.md',
         *[base+'/'+name for name in ['run_check.py','prepare_assets.py','checkpoint.py','finalize.py',
           'candidate-elevation.gdshader.txt','before/game/vehicle/electric_glass.gdshader']]]
for name in added:
    before[name], after[name] = b'', (root/name).read_bytes()
marker = 'VOLT-NIGHT-GLASS-SHAPE-20261106'
for name in ['AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md']:
    new = (root/name).read_bytes()
    start = new.index(('<!-- '+marker+' -->').encode())
    close = ('<!-- /'+marker+' -->').encode()
    end = new.index(close)+len(close)
    if new[end:end+2] == b'\n\n': end += 2
    before[name], after[name] = new[:start]+new[end:], new
private = root/'build/volt-night-glass-shape-checkpoints'/str(time.time_ns())
commands = []
def git(folder, *args, output=None):
    command = ['git','-C',str(folder),'-c','core.autocrlf=false',*args]
    result = subprocess.run(command,stdout=subprocess.PIPE if output is None else output,stderr=subprocess.PIPE)
    commands.append({'command':command,'exit_code':result.returncode,'stderr':result.stderr.decode(errors='replace')})
    assert result.returncode == 0, commands[-1]
for folder in [private/'source',private/'verify']:
    folder.mkdir(parents=True)
    git(folder,'init','-q')
    for name,data in before.items():
        if name in added: continue
        path = folder/name
        path.parent.mkdir(parents=True,exist_ok=True)
        path.write_bytes(data)
source, verify = private/'source',private/'verify'
git(source,'add','--','.')
for name,data in after.items():
    path = source/name
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_bytes(data)
git(source,'add','--intent-to-add','--',*added)
patch = evidence/'task.patch'
with patch.open('wb') as output: git(source,'diff','--binary','--no-ext-diff',output=output)
git(verify,'apply','--check',str(patch))
git(verify,'apply',str(patch))
assert all((verify/name).read_bytes() == data for name,data in after.items())
git(verify,'apply','--reverse','--check',str(patch))
git(verify,'apply','--reverse',str(patch))
assert all(not (verify/name).exists() if name in added else (verify/name).read_bytes() == data for name,data in before.items())
(evidence/'checkpoint.json').write_text(json.dumps({'files':sorted(after),'forward_exact':True,'reverse_exact':True,'main_index_written':False,'patch_sha256':hashlib.sha256(patch.read_bytes()).hexdigest(),'commands':commands},indent=2))
print(json.dumps({'files':len(after),'forward_exact':True,'reverse_exact':True}))
