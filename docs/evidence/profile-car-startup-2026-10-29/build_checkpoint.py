"""Task-baseline patch, checked in a disposable repository without the main index."""
import difflib
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

OUT = Path(__file__).resolve().parent
ROOT = next(p for p in OUT.parents if (p / 'godot-version.txt').exists())
EXISTING = ['game/core/app.gd', 'game/ui/header_car_appearance_cache.gd',
            'game/ui/header_car_icons.gd', 'AGENTS.md', 'DEVELOPMENT_STATUS.md',
            'docs/PHASE_0_PLAN.md']
NEW = ['game/tests/test_profile_car_startup.gd',
       'game/tests/test_profile_car_race_control.gd',
       'docs/evidence/profile-car-startup-2026-10-29/before/game/ui/header_car_icons.gd',
       'docs/evidence/profile-car-startup-2026-10-29/before/game/ui/header_car_appearance_cache.gd',
       'docs/PROFILE_CAR_STARTUP_2026_10_29.md',
       'docs/evidence/profile-car-startup-2026-10-29/run_checks.py',
       'docs/evidence/profile-car-startup-2026-10-29/build_checkpoint.py']
parts = []
hashes = {}
for name in EXISTING + NEW:
    before = (OUT / 'before' / name).read_bytes() if name in EXISTING else b''
    after = (ROOT / name).read_bytes()
    if name == 'game/core/app.gd':
        # Retain concurrent biome-description edits outside this task's two hunks.
        text = after.decode('utf-8')
        assert text.count('await header_car_cache.prepare_selected()') == 1
        text = text.replace('\tawait header_car_cache.prepare_selected()\n', '', 1)
        current = 'return (startup_complete or header_car_cache.preparing_selected) and not is_instance_valid(game) and _background_work_allowed() and (screen != "restoring" or header_car_cache.preparing_selected)'
        assert text.count(current) == 1
        text = text.replace(current, 'return startup_complete and not is_instance_valid(game) and _background_work_allowed() and screen not in ["account","restoring"]', 1)
        before = text.encode('utf-8')
    if name in ['AGENTS.md', 'DEVELOPMENT_STATUS.md', 'docs/PHASE_0_PLAN.md']:
        text = after.decode('utf-8')
        begin = '<!-- PROFILE-CAR-STARTUP-20261029 -->'
        end = '<!-- /PROFILE-CAR-STARTUP-20261029 -->'
        assert text.count(begin) == 1 and text.count(end) == 1
        start = text.index(begin)
        finish = text.index(end) + len(end)
        if text[finish:finish+2] == '\r\n': finish += 2
        elif text[finish:finish+1] == '\n': finish += 1
        if text[finish:finish+2] == '\r\n': finish += 2
        elif text[finish:finish+1] == '\n': finish += 1
        before = (text[:start] + text[finish:]).encode('utf-8')
    if name in EXISTING:
        checkpoint_before = OUT / 'checkpoint-before' / name
        checkpoint_before.parent.mkdir(parents=True, exist_ok=True)
        checkpoint_before.write_bytes(before)
    parts.extend(difflib.unified_diff(before.decode('utf-8').splitlines(True),
                                     after.decode('utf-8').splitlines(True),
                                     fromfile='a/' + name if name in EXISTING else '/dev/null',
                                     tofile='b/' + name))
    hashes[name] = {'before': hashlib.sha256(before).hexdigest() if before else None,
                    'after': hashlib.sha256(after).hexdigest()}
patch = OUT / 'source.patch'
patch.write_text(''.join(parts), encoding='utf-8', newline='\n')
sandbox = Path(tempfile.mkdtemp(prefix='profile-car-checkpoint-', dir=ROOT / 'tmp'))
commands = []

def git(*args):
    command = ['git', '-C', str(sandbox), *args]
    result = subprocess.run(command, text=True, capture_output=True, check=True)
    commands.append({'command': command, 'stdout': result.stdout, 'stderr': result.stderr})

git('init', '-q')
for name in EXISTING:
    destination = sandbox / name
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(OUT / 'checkpoint-before' / name, destination)
git('apply', '--check', str(patch))
git('apply', str(patch))
forward = all((sandbox / name).read_bytes().replace(b'\r\n', b'\n') ==
              (ROOT / name).read_bytes().replace(b'\r\n', b'\n') for name in EXISTING + NEW)
assert forward
git('apply', '--reverse', '--check', str(patch))
git('apply', '--reverse', str(patch))
reverse = all((sandbox / name).read_bytes().replace(b'\r\n', b'\n') ==
              (OUT / 'checkpoint-before' / name).read_bytes().replace(b'\r\n', b'\n') for name in EXISTING)
assert reverse and all(not (sandbox / name).exists() for name in NEW)
record = {'files': hashes, 'forward_contents': forward, 'reverse_contents': reverse,
          'commands': commands, 'sandbox': str(sandbox),
          'main_index_touched': False, 'patch_sha256': hashlib.sha256(patch.read_bytes()).hexdigest()}
(OUT / 'checkpoint.json').write_text(json.dumps(record, indent=2), encoding='utf-8')
print(json.dumps({'files': len(hashes), 'forward_contents': forward, 'reverse_contents': reverse}))
