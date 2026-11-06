"""Verify task-only text/binary patch using private Git repositories."""
import hashlib
import json
from pathlib import Path
import subprocess
import time

evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
before = {}
after = {}
for path in (evidence / 'before').rglob('*'):
    if not path.is_file(): continue
    name = path.relative_to(evidence / 'before').as_posix()
    old = path.read_bytes()
    new = (root / name).read_bytes()
    if name == 'game/core/game.gd':
        old = new
        for line in [
            'var electric_glass_lighting := preload("res://race/electric_glass_lighting.gd").new()',
            '\telectric_glass_lighting.configure(car, str(native_track.metadata.get("theme", "pine")) if native_track != null else "pine")',
            '\tif car != null: electric_glass_lighting.configure(car, weather_theme)',
        ]:
            token = (line + ('\r\n' if (line+'\r\n').encode() in old else '\n')).encode()
            assert old.count(token) == 1
            old = old.replace(token, b'')
    if old != new:
        before[name], after[name] = old, new
added = ['game/race/electric_glass_lighting.gd', 'game/tests/test_volt_night_glass.gd', 'game/tests/probe_volt_glass_pixels.gd',
         'docs/VOLT_NIGHT_ROOF_FIX_2026_11_06.md',
         'docs/evidence/volt-night-roof-fix-2026-11-06/before/game/vehicle/electric_glass.gdshader',
         *['docs/evidence/volt-night-roof-fix-2026-11-06/'+name for name in
           ['run_check.py','prepare_assets.py','checkpoint.py','update_trackers.py']]]
for name in added:
    before[name], after[name] = b'', (root / name).read_bytes()
for name in ['AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md']:
    new = (root / name).read_bytes()
    start = new.index(b'<!-- VOLT-NIGHT-ROOF-FIX-20261106 -->')
    end = new.index(b'<!-- /VOLT-NIGHT-ROOF-FIX-20261106 -->') + len(b'<!-- /VOLT-NIGHT-ROOF-FIX-20261106 -->')
    if new[end:end+2] == b'\n\n': end += 2
    before[name], after[name] = new[:start]+new[end:], new
owned = root / 'build/volt-night-roof-fix-checkpoints' / str(time.time_ns())
source, verify = owned / 'source', owned / 'verify'
commands = []
def git(folder, *arguments, output=None):
    command = ['git','-C',str(folder),'-c','core.autocrlf=false',*arguments]
    result = subprocess.run(command, stdout=subprocess.PIPE if output is None else output, stderr=subprocess.PIPE)
    commands.append({'command': command, 'exit_code': result.returncode, 'stderr': result.stderr.decode(errors='replace')})
    assert result.returncode == 0, commands[-1]
for folder in [source,verify]:
    folder.mkdir(parents=True)
    git(folder,'init','-q')
    for name, data in before.items():
        if name in added: continue
        target = folder / name
        target.parent.mkdir(parents=True,exist_ok=True)
        target.write_bytes(data)
git(source,'add','--','.')
for name, data in after.items():
    target = source / name
    target.parent.mkdir(parents=True,exist_ok=True)
    target.write_bytes(data)
git(source,'add','--intent-to-add','--',*added)
patch = evidence / 'task.patch'
with patch.open('wb') as output: git(source,'diff','--binary','--no-ext-diff',output=output)
git(verify,'apply','--check',str(patch))
git(verify,'apply',str(patch))
assert all((verify/name).read_bytes() == data for name,data in after.items())
git(verify,'apply','--reverse','--check',str(patch))
git(verify,'apply','--reverse',str(patch))
assert all(not (verify/name).exists() if name in added else (verify/name).read_bytes() == data for name,data in before.items())
report = {'files':sorted(after),'forward_exact':True,'reverse_exact':True,'main_index_written':False,
          'patch_sha256':hashlib.sha256(patch.read_bytes()).hexdigest(),'commands':commands}
(evidence/'checkpoint.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps({'files':len(after),'forward_exact':True,'reverse_exact':True}))
