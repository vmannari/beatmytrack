"""Record task sources and check a scoped patch without touching the main index."""
import difflib
import hashlib
import json
from pathlib import Path
import re
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = next(p for p in HERE.parents if (p / 'godot-version.txt').exists())
EXISTING = ['game/track/prop_equipment.gd', 'game/track/creator_prop_visual.gd',
            'game/track/native_track_visual.gd', 'game/track/winter_prop_finish.gd',
            'game/editor/placed_object_batches.gd']
NEW = ['game/track/guardrail_visual.gd', 'game/track/guardrail_visual.gd.uid',
       'game/tests/test_guardrail_ends.gd', 'game/tests/test_guardrail_ends.gd.uid']
patch = []
hashes = {}
check_dir = HERE / 'patch-check'
check_dir.mkdir(exist_ok=True)
for name in EXISTING + NEW:
    current = ROOT / name
    raw = current.read_bytes()
    hashes[name] = {'sha256': hashlib.sha256(raw).hexdigest(), 'bytes': len(raw)}
    target = HERE / 'after' / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(raw)
    before = (HERE / 'before' / name).read_text(encoding='utf-8') if name in EXISTING else ''
    if name in EXISTING:
        hashes[name]['before_sha256'] = hashlib.sha256((HERE / 'before' / name).read_bytes()).hexdigest()
        check_file = check_dir / name
        check_file.parent.mkdir(parents=True, exist_ok=True)
        check_file.write_text(before, encoding='utf-8', newline='\n')
    patch += difflib.unified_diff(before.splitlines(keepends=True), raw.decode('utf-8').replace('\r\n', '\n').splitlines(keepends=True),
                                  fromfile='a/' + name if name in EXISTING else '/dev/null', tofile='b/' + name)
(HERE / 'task.patch').write_text(''.join(patch), encoding='utf-8', newline='\n')
subprocess.run(['git', '-C', str(check_dir), 'init', '--quiet'], check=True)
command = ['git', '-C', str(check_dir), 'apply', '--check', '--whitespace=error-all', str(HERE / 'task.patch')]
receipt = subprocess.run(command, capture_output=True, text=True)
(HERE / 'patch-check.json').write_text(json.dumps({'command': command, 'exit_code': receipt.returncode,
                                                'stdout': receipt.stdout, 'stderr': receipt.stderr}, indent=2), encoding='utf-8')
assert receipt.returncode == 0, receipt.stderr
checks = {}
for record in sorted(HERE.glob('*/command.json')):
    data = json.loads(record.read_text(encoding='utf-8'))
    log = record.with_name('run.log').read_text(encoding='utf-8', errors='replace')
    data['summary_lines'] = [line for line in log.splitlines() if re.search(r': \d+ (checks|scripts), \d+ failures', line)]
    checks[record.parent.name] = data
shots = {str(p.relative_to(HERE)).replace('\\', '/'): hashlib.sha256(p.read_bytes()).hexdigest()
         for p in sorted(HERE.glob('*/*.png'))}
report = {'requirements': {'GF01': 'Smooth ground-level exposed Guardrail ends',
                           'GF02': 'Post spacing continues across fitted road-edge sections',
                           'GF03': 'Matching editor/race geometry and fitted winter snow',
                           'R01': 'Canonical objects, physics, undo and local saves preserved',
                           'Q01': 'Native views, actual commands and scoped checkpoint'},
          'sources': hashes, 'checks': checks, 'screenshots_sha256': shots,
          'patch': {'path': 'task.patch', 'sha256': hashlib.sha256((HERE / 'task.patch').read_bytes()).hexdigest(),
                    'git_apply_check': receipt.returncode, 'main_index_used': False},
          'measurements': {'original_terminal_height_m': 1.02999997138977, 'new_terminal_height_m': 0.0,
                           'straight_24m_old_posts': 12, 'straight_24m_new_posts': 8,
                           'curve_sections': 12, 'curve_posts': 13, 'curve_min_post_distance_m': 3.12145090103149},
          'limitations': ['Desktop renderers only; no device attachment query or physical-device test.',
                          'Original spline suite: four stale null/96-object-capacity fixture failures retained. Current-limit valid fixture passes all original 6645 assertions.',
                          'Initial native test-closeup fixture had a SubViewport/Node3D type error; corrected. Failed attempts retained.',
                          'PowerShell execution policy and default-user log access blocked initial wrapper attempts; isolated pinned-engine runs used after wrapper identified exact version.',
                          'Initial check needed an import for concurrent JumpProfiles class registration. Import succeeds.',
                          'A later Compatibility attempt passed 95 assertions but logged a concurrent unimported sign_in_mark.svg dependency failure. A second pinned import and final native rerun are recorded separately.',
                          'Existing sandbox root-certificate-store error is retained separately from offline test assertions.',
                          'Development wrapper regenerated build identity metadata; excluded from this task checkpoint.',
                          'Reload and owner appearance acceptance remain. No APK, backend deployment, live save mutation, owner-process restart or main-index staging/commit.']}
(HERE / 'report.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps({'task_sources': len(hashes), 'recorded_runs': len(checks), 'screenshots': len(shots), 'patch_check': receipt.returncode}))
