"""Write scoped review evidence and verify a binary Git checkpoint privately."""
from pathlib import Path
import json
import shutil
import subprocess

e = Path(__file__).resolve().parent
root = e.parents[2]
labels = ['slow-final', 'handling', 'final', 'driving', 'rewind', 'actual-game', 'laps', 'normal-tracks']
for label in labels:
    receipt = json.loads((e / (label + '-receipt.json')).read_text())
    assert receipt['exit_code'] == 0 and not receipt['script_errors'], label
assert (e / 'assets-after.json').exists()
report = '''# Volt slow-speed steering — 2026-11-06

VSS01: The owner finds Volt too sensitive at very low speed. Electric-29 applies
the existing low-speed steering-angle scale at 0.75, down from 1.0. Full reduction
applies through 2 m/s (7.2 km/h), fading smoothly to the previous steering at
8 m/s (28.8 km/h). Input buildup/unwind rates, normal-speed lock, propulsion,
braking and power-slide parameters are unchanged. Shared simulation is unchanged.
The new car version and hash distinguish competitive contracts; the local backend
fixture has the new electric identity only. Deployment was not performed.

VSS02: Actual 0.2-second left/right, partial/full steering cases at +/-1,2,3 m/s
show heading ratios 0.692–0.764 versus the archived electric-28 configuration.
The 75 normal-speed step cases match exactly. Straight power/coast comparisons
and deterministic replay pass. The dedicated check passes 8512/0; retained final
Volt reference 10/0, handling 88/0, driving 72/0 and rewind 61/0 pass. Actual Game
loads electric-29 without an experimental selector. Over-and-under passes 7/0:
five ordered laps, 35891 inputs, zero contacts and exact replay. Five Storm tracks
pass 20/0: one ordered lap each, zero contacts and exact replay.
The final-reference test explicitly applies this approved correction to its Turn 5
reference; all remaining physical fields retain exact comparisons.

VSS03: Volt prepared bases, modules and Garage template are refreshed; the picture
pipeline and complete prepared-asset preflight run after identity generation.
See assets-before.json, assets-after.json, bake logs and preflight/commands.json.
This is a handling change, not a UI change; no new UI screenshot is required.

Commands: `python docs/evidence/volt-slow-steering-2026-11-06/run_check.py LABEL
res://tests/SCRIPT.gd` with the precise arguments in each receipt; preparation uses
`python docs/evidence/volt-slow-steering-2026-11-06/prepare_assets.py`.
Pinned Godot 4.7.2, crash-dialog wrapper, private profiles, empty backend URL.
The standard dev.ps1 attempt exited 1 with Access denied; the direct pinned runs
above passed. Certificate-store errors and ObjectDB/resource shutdown warnings are
retained. An initial PowerShell/Python quoting error made no source changes.

Limitations: automated checks cannot establish the owner's steering feel. Tablet
testing, installation and matching service rollout remain; no device query/test,
APK, backend request, owner-save/process change or main-index write occurred.
No merge or full historical physics-suite acceptance is claimed. Concurrent work
is preserved. task.patch is a private-Git binary checkpoint, checked in reverse
against the exact final files.
'''
doc = root / 'docs/VOLT_SLOW_STEERING_2026_11_06.md'
doc.write_text(report, encoding='utf-8')
mapping = {
    'game/resources/cars/electric.tres': e / 'before/electric.tres',
    'game/tests/test_volt_final_handling.gd': e / 'before/test_volt_final_handling.gd.txt',
    'game/tests/capture_volt_final_handling.gd': e / 'before/capture_volt_final_handling.gd.txt',
    'backend/tests/fixtures/verified_oval.json': e / 'before/verified_oval.json',
}
for name in ['AGENTS.md', 'DEVELOPMENT_STATUS.md', 'docs/PHASE_0_PLAN.md']:
    path = root / name
    before = e / 'before' / name
    before.parent.mkdir(parents=True, exist_ok=True)
    if not before.exists(): shutil.copyfile(path, before)
    link = 'VOLT_SLOW_STEERING_2026_11_06.md' if name.startswith('docs/') else 'docs/VOLT_SLOW_STEERING_2026_11_06.md'
    entry = ('<!-- VOLT-SLOW-STEERING-20261106 -->\n## Volt low-speed steering softened (2026-11-06)\n'
             'VSS01–VSS03: Electric-29 uses 0.75 parking-speed lock, smoothly restoring the accepted tune at 28.8 km/h. '
             'Initial low-speed rotation falls 24–31%; normal-speed steps and straight power/coast remain exact. '
             'Dedicated8512/0, final10/0, handling88/0, driving72/0, rewind61/0 and actual-Game load pass. '
             f'Prepared assets refreshed; [commands, track checks, limitations and task-only checkpoint]({link}). '
             'Owner feel, tablet testing/install and matching service rollout remain. No device test, APK, live request or main-index write.\n'
             '<!-- /VOLT-SLOW-STEERING-20261106 -->\n\n')
    if '<!-- VOLT-SLOW-STEERING-20261106 -->' not in path.read_text(encoding='utf-8'):
        path.write_bytes(entry.encode() + path.read_bytes())
    mapping[name] = before
before_assets = json.loads((e / 'assets-before.json').read_text())
after_assets = json.loads((e / 'assets-after.json').read_text())
for name in before_assets:
    if before_assets[name] != after_assets[name]: mapping[name] = e / 'before' / name
new = ['game/tests/test_volt_slow_steering.gd', 'docs/VOLT_SLOW_STEERING_2026_11_06.md']
for name in ['run_check.py', 'prepare_assets.py', 'finalize.py']:
    new.append((e / name).relative_to(root).as_posix())
work = root / 'build/volt-slow-steering-checkpoint'
assert not work.exists(), 'checkpoint already exists'
work.mkdir(parents=True)
def git(*args):
    return subprocess.run(['git', '-C', str(work), *args], check=True, capture_output=True)
git('init')
for name, before in mapping.items():
    target = work / name
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(before, target)
git('add', '.')
git('-c', 'user.name=Local checkpoint', '-c', 'user.email=checkpoint@local', 'commit', '-m', 'Task-start snapshot')
for name in [*mapping, *new]:
    target = work / name
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(root / name, target)
git('add', '.')
patch = git('diff', '--cached', '--binary', 'HEAD').stdout
(e / 'task.patch').write_bytes(patch)
git('apply', '--reverse', '--check', str(e / 'task.patch'))
(e / 'checkpoint.json').write_text(json.dumps({'files': [*mapping, *new], 'reverse_check': True, 'main_index_touched': False}, indent=2))
print('Checkpoint validated:', len(mapping) + len(new), 'files')
