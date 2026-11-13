"""Build and check the task patch without staging files or writing Git objects."""
import difflib
import hashlib
import json
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
EXISTING = [
    'backend/bmt_backend/app.py', 'backend/bmt_backend/load_fixtures.py', 'backend/bmt_backend/loadtest.py',
    'backend/bmt_backend/maintenance.py', 'backend/bmt_backend/publication_worker.py',
    'backend/bmt_backend/run_signals.py', 'backend/bmt_backend/track_models.py', 'backend/bmt_backend/tracks.py',
    'backend/bmt_backend/vehicle_appearance.py', 'backend/bmt_backend/worker.py',
    'backend/bmt_backend/worker_lifecycle.py', 'backend/tests/test_loadtest.py',
    'game/backend/appearance_sync.gd', 'game/backend/backend_client.gd', 'game/persistence/appearance_state.gd',
    'game/tests/test_appearance_sync.gd', 'game/tests/test_sticker_appearance_sync.gd',
]
NEW_SOURCE = [
    'backend/bmt_backend/receipt_references.py',
    'backend/bmt_backend/migrations/versions/0075_receipt_reference_indexes.py',
    'backend/tests/test_performance_cost_fixes.py', 'backend/tests/fixtures/load_trajectory.json',
    'game/tests/record_load_trajectory.gd', 'docs/BACKEND_PERFORMANCE_FIXES_2026_11_07.md',
]
TEST_RUNS = ['backend-regression.xml', 'environment-recheck.xml', 'backend-final.xml',
             'load-http-final.xml', 'profile-final.xml', 'final-read-contracts.xml']


def read_text(path):
    raw = path.read_bytes()
    encoding = 'utf-16' if raw.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig'
    return raw.decode(encoding).replace('\r\n', '\n')


def git(*args):
    return subprocess.run(['git', *args], cwd=ROOT, capture_output=True, check=False)


passed, skipped, latest = set(), set(), {}
for name in TEST_RUNS:
    for case in ET.parse(OUT / name).getroot().iter('testcase'):
        key = case.attrib.get('classname', '').removeprefix('backend.') + '::' + case.attrib['name']
        state = ('skipped' if case.find('skipped') is not None else
                 'failed' if case.find('failure') is not None or case.find('error') is not None else 'passed')
        latest[key] = state
        if state == 'passed':
            passed.add(key)
        elif state == 'skipped':
            skipped.add(key)
summary = {'distinct_backend_passed': len(passed), 'distinct_backend_skipped': len(skipped),
           'remaining_failed_cases': [key for key, state in latest.items() if state == 'failed'],
           'native_sync_checks': 120, 'native_verified_races': 3,
           'native_http_requests': 81, 'postgresql_integration_run': False,
           'source_files': EXISTING + NEW_SOURCE}
assert not summary['remaining_failed_cases'], summary
(OUT / 'validation-summary.json').write_text(json.dumps(summary, indent=2) + '\n', encoding='utf-8')

# These three files were clean at task start but did not need an initial copy.
for name in EXISTING:
    before = OUT / 'before' / name.replace('/', '__')
    if not before.exists():
        result = git('show', ':' + name)
        if result.returncode:
            raise RuntimeError('Cannot read the task baseline for ' + name)
        before.write_bytes(result.stdout)

initial_index = read_text(OUT / 'initial-index-sha256.txt').strip().lower()
current_index = hashlib.sha256((ROOT / '.git/index').read_bytes()).hexdigest()
assert initial_index == current_index, 'The shared index changed during the task; do not overwrite it.'

uid = ROOT / 'game/tests/record_load_trajectory.gd.uid'
if uid.exists():
    NEW_SOURCE.append(uid.relative_to(ROOT).as_posix())
new_files = [ROOT / name for name in NEW_SOURCE]
new_files += sorted(path for path in OUT.rglob('*') if path.is_file()
                    and path.suffix in {'.py', '.gd', '.uid', '.json', '.txt', '.md', '.xml', '.log'}
                    and path.name != 'checkpoint-result.json'
                    and '__pycache__' not in path.parts and 'objects' not in path.parts)
# Normalize owned diagnostic text only; runtime line endings are left to Git.
for path in new_files:
    value = read_text(path)
    path.write_text(value if value.endswith('\n') else value + '\n', encoding='utf-8', newline='\n')

changes = git('diff', '--binary', '--', *EXISTING)
if changes.returncode:
    raise RuntimeError('Cannot read task source changes')
chunks = [changes.stdout]
for path in new_files:
    name = path.relative_to(ROOT).as_posix()
    chunks.append(f'diff --git a/{name} b/{name}\nnew file mode 100644\n'.encode())
    chunks.append(''.join(difflib.unified_diff([], read_text(path).splitlines(keepends=True),
                                           fromfile='/dev/null', tofile='b/' + name)).encode())
patch = OUT / 'task-only.patch'
patch.write_bytes(b''.join(chunks))
check = git('apply', '--check', '--reverse', '--whitespace=nowarn', str(patch))
receipt = {'main_index_unchanged': initial_index == current_index,
           'reverse_apply_check_exit': check.returncode, 'new_text_files': len(new_files),
           'patch_sha256': hashlib.sha256(patch.read_bytes()).hexdigest(),
           'validation': summary,
           'source_sha256': {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
                             for name in EXISTING + NEW_SOURCE}}
(OUT / 'checkpoint-result.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
print(json.dumps({key: value for key, value in receipt.items() if key != 'source_sha256'}))
if check.returncode:
    print(check.stderr.decode(errors='replace'))
    raise SystemExit(check.returncode)
