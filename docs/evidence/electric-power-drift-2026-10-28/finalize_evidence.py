"""Check task scope and build a review patch without touching the main index."""
from pathlib import Path
import difflib
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
baseline = json.loads((OUT / 'baseline.json').read_text())
trackers = ['AGENTS.md', 'DEVELOPMENT_STATUS.md', 'docs/PHASE_0_PLAN.md']


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


protected = {name: sha(ROOT / name) for name in baseline['protected'] if name != 'game/resources/cars/electric.tres'}
assert all(value == baseline['protected'][name] for name, value in protected.items())
fixture_path = 'backend/tests/fixtures/verified_oval.json'
old_fixture = json.loads((OUT / 'before' / fixture_path.replace('/', '__')).read_text())
new_fixture = json.loads((ROOT / fixture_path).read_text())
old_electric = old_fixture['expected_manifest']['vehicles']['electric']
new_electric = new_fixture['expected_manifest']['vehicles']['electric']
assert old_electric != new_electric
old_fixture['expected_manifest']['vehicles']['electric'] = new_electric
assert old_fixture == new_fixture

initial = json.loads((OUT / 'checks-final.json').read_text())
selected = {result['name']: result for result in initial}
selected.update({r['name']: r for r in json.loads((OUT / 'checks-retained.json').read_text())})
for name, receipt in selected.items():
    assert receipt['exit_code'] == 0, (name, receipt)
    log_path = Path(receipt['command'][receipt['command'].index('--log-file') + 1]).parent / 'console.log'
    log = log_path.read_text()
    assert not re.search(r'SCRIPT ERROR:|Parse Error:|FAIL:', log), (name, log)
    assert re.search(r'0 failures', log), name

backend_log = (OUT / 'backend.log').read_text(encoding='utf-16')
backend_summary = re.findall(r'\d+ passed[^\r\n]*', backend_log)
assert backend_summary and 'FAILED ' not in backend_log and 'ERROR ' not in backend_log, backend_log[-3000:]
canonical = json.loads((OUT / 'canonical-verification.json').read_text())
assert canonical['input_count'] == 35035 and canonical['six_other_car_boards_exact']

new_names = ['game/tests/test_electric_power_increment.gd',
             'game/tests/probe_electric_power_increment.gd',
             'game/tests/probe_electric_power_increment.gd.uid',
             'docs/ELECTRIC_POWER_DRIFT_2026_10_28.md']
new_names += [p.relative_to(ROOT).as_posix() for p in OUT.glob('*.py')]
names = sorted(set(baseline['files'] + trackers + new_names))
patch = []
changed = []
for name in names:
    current = ROOT / name
    previous = (OUT / 'checkpoint-before' / name) if name in trackers else (OUT / 'before' / name.replace('/', '__'))
    before_bytes = previous.read_bytes() if previous.exists() else b''
    after_bytes = current.read_bytes()
    if before_bytes == after_bytes:
        continue
    changed.append(name)
    patch.append(f'diff --git a/{name} b/{name}\n')
    if not previous.exists():
        patch.append('new file mode 100644\n')
    patch.extend(difflib.unified_diff(before_bytes.decode('utf-8').splitlines(keepends=True),
                 after_bytes.decode('utf-8').splitlines(keepends=True),
                 fromfile=f'a/{name}' if previous.exists() else '/dev/null', tofile=f'b/{name}'))
patch_path = OUT / 'task.patch'
patch_path.write_bytes(''.join(patch).encode('utf-8'))
check = subprocess.run(['git', 'apply', '--reverse', '--check', str(patch_path)], cwd=ROOT,
                       capture_output=True, text=True)
assert check.returncode == 0, check.stderr

report = {
    'date': '2026-10-28', 'requirements': ['EPD01 slightly more powered drift',
       'EPD02 retain regen/control/acceleration', 'EPD03 Electric-only identity and replay compatibility'],
    'runtime_scope': ['game/resources/cars/electric.tres'], 'changed_files': changed,
    'sources': {name: sha(ROOT / name) for name in changed}, 'protected_sources_exact': protected,
    'focused': json.loads((OUT / 'final/electric_power_increment/power-increment.json').read_text()),
    'selected_checks': list(selected.values()), 'backend_summary': backend_summary[-1],
    'canonical_verification': canonical, 'checkpoint': {'path': str(patch_path.relative_to(ROOT)),
       'sha256': sha(patch_path), 'git_reverse_check': True, 'main_index_used': False},
    'retained_findings': [
       'Task-start focused run: 416 checks / 4 expected failures; final 416/0.',
       'Initial sandbox probe/baseline/first-tune root-certificate diagnostic retained.',
       '0.25 and 0.26 response candidates cross the retained historical acceleration floor; intermediate0.265 passes unchanged floor.',
       'Final regressions and unchanged strict server adapter use normal Windows certificate access and isolated test profile.',
       'Previous regen power comparison matches the owner-requested later power response; its braking assertions remain unchanged.'],
    'limits': ['No physical-device attachment query or device test.',
       'No APK, live mutation/submission, deployment, real auth/purchase or owner-process restart.',
       'Client reload/rebuild, matching backend/current Electric track contracts and owner feel acceptance remain.']}
(OUT / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps({'changed_files': len(changed), 'selected_client_suites': len(selected),
                  'backend': backend_summary[-1], 'patch_reverse_check': True}))
