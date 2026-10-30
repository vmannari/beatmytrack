from pathlib import Path
import difflib
import hashlib
import json
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
files = ['game/resources/cars/electric.tres', 'backend/tests/fixtures/verified_oval.json',
         'game/tests/test_electric_brake_reverse.gd', 'game/tests/test_electric_drift_easier.gd', 'game/tests/test_electric_acceleration.gd', 'game/tests/test_electric_turning_tighter.gd',
         'docs/ELECTRIC_TURNING_TIGHTER_2026_10_28.md', 'AGENTS.md']
patch = []
hashes = {}
for rel in files:
    current = (ROOT / rel).read_text(encoding='utf-8')
    before = OUT / 'before' / rel
    previous = before.read_text(encoding='utf-8') if before.exists() else ''
    if rel == 'AGENTS.md':
        start = current.index('<!-- ELECTRIC-TURNING-TIGHTER-20261028 -->')
        end = current.index('<!-- /ELECTRIC-TURNING-TIGHTER-20261028 -->') + len('<!-- /ELECTRIC-TURNING-TIGHTER-20261028 -->\n\n')
        previous = current[:start] + current[end:]
    hashes[rel] = hashlib.sha256(current.encode()).hexdigest()
    for directory, data in [('scope-base',previous),('scope-current',current)]:
        path = OUT / directory / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(data,encoding='utf-8',newline='\n')
    patch.extend(difflib.unified_diff(previous.splitlines(True),current.splitlines(True),fromfile='a/'+rel if previous else '/dev/null',tofile='b/'+rel))
(OUT / 'task.patch').write_text(''.join(patch),encoding='utf-8',newline='\n')
result = subprocess.run(['git','apply','--reverse','--check',str(OUT/'task.patch')],cwd=ROOT,capture_output=True,text=True)
(OUT / 'checkpoint.json').write_text(json.dumps({'source_hashes':hashes,'reverse_apply_check':result.returncode,'diagnostics':result.stderr},indent=2)+'\n')
shutil.copy2(ROOT/'game/core/build_identity.gd', OUT/'generated-build-identity.gd.txt')
print('Scoped reverse apply check:', result.returncode)
assert result.returncode == 0, result.stderr
