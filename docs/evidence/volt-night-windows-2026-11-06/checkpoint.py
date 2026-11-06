"""Make and verify a task-only patch without writing the workspace Git index."""
import hashlib
import json
from pathlib import Path
import subprocess
import time

evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
base = evidence.relative_to(root).as_posix()
before = {
    'game/race/electric_glass_lighting.gd': (evidence/'before/game/race/electric_glass_lighting.gd').read_bytes(),
    'game/tests/test_volt_night_glass.gd': (evidence/'before/test_volt_night_glass.gd').read_bytes(),
}
added = ['game/tests/test_volt_night_windows.gd', 'game/tests/probe_volt_window_controls.gd', 'docs/VOLT_NIGHT_WINDOWS_2026_11_06.md',
         *[base+'/'+name for name in ['run_check.py', 'checkpoint.py', 'finalize.py', 'before/game/race/electric_glass_lighting.gd']]]
for name in added:
    before[name] = b''
after = {name: (root/name).read_bytes() for name in before}
for name in ['AGENTS.md', 'DEVELOPMENT_STATUS.md', 'docs/PHASE_0_PLAN.md']:
    new = (root/name).read_bytes()
    start = new.index(b'<!-- VOLT-NIGHT-WINDOWS-20261106 -->')
    end = new.index(b'<!-- /VOLT-NIGHT-WINDOWS-20261106 -->')+len(b'<!-- /VOLT-NIGHT-WINDOWS-20261106 -->')
    if new[end:end+2] == b'\n\n': end += 2
    before[name], after[name] = new[:start]+new[end:], new

private = root/'build/volt-night-windows-checkpoints'/str(time.time_ns())
commands = []
def git(folder, *args, output=None):
    command = ['git', '-C', str(folder), '-c', 'core.autocrlf=false', *args]
    result = subprocess.run(command, stdout=subprocess.PIPE if output is None else output, stderr=subprocess.PIPE)
    commands.append({'command':command, 'exit_code':result.returncode, 'stderr':result.stderr.decode(errors='replace')})
    assert result.returncode == 0, commands[-1]

for subdir in ['source', 'verify']:
    folder = private/subdir
    folder.mkdir(parents=True)
    git(folder, 'init', '-q')
    for name, data in before.items():
        if name in added: continue
        path = folder/name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
source, verify = private/'source', private/'verify'
git(source, 'add', '--', '.')
for name, data in after.items():
    path = source/name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
git(source, 'add', '--intent-to-add', '--', *added)
patch = evidence/'task.patch'
with patch.open('wb') as output: git(source, 'diff', '--binary', '--no-ext-diff', output=output)
git(verify, 'apply', '--check', str(patch))
git(verify, 'apply', str(patch))
assert all((verify/name).read_bytes() == data for name, data in after.items())
git(verify, 'apply', '--reverse', '--check', str(patch))
git(verify, 'apply', '--reverse', str(patch))
assert all(not (verify/name).exists() if name in added else (verify/name).read_bytes() == data for name, data in before.items())
receipt = {'files': sorted(after), 'forward_exact':True, 'reverse_exact':True, 'main_index_written':False,
           'patch_sha256':hashlib.sha256(patch.read_bytes()).hexdigest(), 'commands':commands}
(evidence/'checkpoint.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
print(json.dumps({key:receipt[key] for key in ['files','forward_exact','reverse_exact','main_index_written']}))
