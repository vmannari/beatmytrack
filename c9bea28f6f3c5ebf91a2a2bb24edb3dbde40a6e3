from pathlib import Path
import difflib
import hashlib
import json
import subprocess

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
NEW = 'Instant rear-wheel power with responsive steering. Feed in the accelerator for a controlled slide; release for regeneration. Use the brake pedal to slow down, then hold it while stopped to reverse. No handbrake.'
OLD = 'Instant rear-wheel power with responsive steering. Feed in the accelerator for a controlled slide; release to brake and stop. Select D or R while stopped. One pedal, no handbrake.'
files = [str(p.relative_to(OUT / 'before')).replace('\\','/') for p in (OUT / 'before').rglob('*') if p.is_file()]
files.append('game/tests/test_electric_brake_reverse.gd')
files.append('docs/ELECTRIC_BRAKE_REVERSE_2026_10_28.md')
patch = []
hashes = {}
for rel in sorted(files):
    current = (ROOT / rel).read_text(encoding='utf-8')
    previous_path = OUT / 'before' / rel
    previous = previous_path.read_text(encoding='utf-8') if previous_path.exists() else ''
    # Shared files receive only the task's explicit substitutions. Their concurrent
    # catalogue/air-cushion/localization changes remain in both patch endpoints.
    if rel == 'game/vehicle/vehicle_catalog.gd':
        previous = current.replace(NEW, OLD)
    elif rel == 'game/vehicle/handling_config.gd':
        previous = current.replace('@export var handbrake_enabled: bool = true\n', '').replace('@export var blended_regeneration: bool = false # Automatic four-wheel lift-off braking independent of pedal layout.\n', '')
        previous = previous.replace('\tif blended_regeneration: return maxf(regeneration, braking_force/mass)\n', '')
        previous = previous.replace('\tif handbrake_enabled: result.erase("handbrake_enabled")\n', '').replace('\tif not blended_regeneration: result.erase("blended_regeneration")\n', '')
    elif rel == 'game/vehicle/vehicle_simulation.gd':
        previous = current.replace('if config.single_pedal or not config.handbrake_enabled:', 'if config.single_pedal:')
        previous = previous.replace('(config.single_pedal or config.blended_regeneration) and regenerating', 'config.single_pedal and regenerating')
    elif rel.startswith('game/localization/') and rel.endswith(('en.po','messages.pot')):
        previous = current.replace(NEW, OLD)
    elif rel == 'backend/tests/fixtures/verified_oval.json':
        previous = current.replace('electric-21','electric-20').replace('75f0052f7eb3340bbe98b0c719d98b75402f66d2ecc6726accb83d9fb0ccfa0b','b51534ece02975f60d5fb0ced5d9225ad6946d5af13ea054d656de2530024f58')
    if previous == current:
        continue
    hashes[rel] = hashlib.sha256(current.encode()).hexdigest()
    for folder, data in [('scope-base', previous), ('scope-current', current)]:
        target = OUT / folder / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(data, encoding='utf-8', newline='\n')
    patch.extend(difflib.unified_diff(previous.splitlines(True), current.splitlines(True), fromfile='a/'+rel if previous else '/dev/null', tofile='b/'+rel))
(OUT / 'task.patch').write_text(''.join(patch), encoding='utf-8', newline='\n')
check = subprocess.run(['git','apply','--reverse','--check',str(OUT/'task.patch')], cwd=ROOT, capture_output=True, text=True)
(OUT / 'checkpoint.json').write_text(json.dumps({'source_hashes':hashes,'reverse_apply_check':check.returncode,'diagnostics':check.stderr},indent=2)+'\n')
print(f'{len(hashes)} scoped source/test/catalogue files; reverse apply check {check.returncode}')
assert check.returncode == 0, check.stderr
