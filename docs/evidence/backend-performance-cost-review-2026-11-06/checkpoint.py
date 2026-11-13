"""Package this review's text additions without writing the Git index or objects."""
import difflib
import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
REPORT = ROOT / 'docs/BACKEND_PERFORMANCE_COST_REVIEW_2026_11_06.md'

# Keep only the redaction marker, including abbreviated credential values in
# pytest's exception repr. Do not emit the original text.
initial_tests = OUT / 'request/focused-tests.xml'
original = initial_tests.read_text(encoding='utf-8')
initial_tests.write_text(original.replace('f6[REDACTED]', '[REDACTED]'), encoding='utf-8')

source_names = [
    'game/backend/appearance_sync.gd', 'game/backend/backend_client.gd',
    'backend/bmt_backend/appearance_routes.py', 'backend/bmt_backend/vehicle_appearance.py',
    'backend/bmt_backend/tracks.py', 'backend/bmt_backend/profile_statistics.py',
    'backend/bmt_backend/worker.py', 'backend/bmt_backend/worker_lifecycle.py',
    'backend/bmt_backend/publication_worker.py', 'backend/bmt_backend/run_signals.py',
    'backend/bmt_backend/maintenance.py', 'backend/bmt_backend/load_fixtures.py',
    'backend/bmt_backend/loadtest.py', 'backend/bmt_backend/verifier.py',
    'backend/bmt_backend/migrations/versions/0038_garage_news.py',
]
manifest = {
    'review_date': '2026-11-06', 'requirements': ['BPC01', 'BPC02', 'BPC03', 'BPC04', 'BPC05'],
    'reviewed_source_sha256': {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
                             for name in source_names},
    'runtime_changes': [], 'deployment_performed': False, 'device_test_performed': False,
    'primary_findings': ['appearance permanent-rejection retries', 'empty worker SQL polling',
                         'load workload lacks required trajectory', 'Profile query amplification',
                         'retention receipt scan'],
    'withdrawn_finding': 'Missing lap-order index: migration 0038 already provides it',
    'validation': {'sqlite_tests_passed': 9, 'sqlite_repeat_deselected': 9,
                   'initial_postgresql_setup_errors': 4, 'initial_tests_skipped': 5,
                   'cloud_reader_ruff': 'passed after two diagnostic fixes',
                   'migrated_probe_wrapper': 'exit 1 with reflection warnings; complete JSON retained'},
}
(OUT / 'review-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
files = [REPORT] + sorted(path for path in OUT.rglob('*')
                         if path.is_file() and path.suffix in {'.py', '.json', '.md', '.log', '.xml'}
                         and path.name != 'checkpoint-result.json' and '__pycache__' not in path.parts)
chunks = []
converted_logs = []
for path in files:
    name = path.relative_to(ROOT).as_posix()
    raw = path.read_bytes()
    if raw.startswith((b'\xff\xfe', b'\xfe\xff')):
        contents = raw.decode('utf-16').replace('\r\n', '\n')
        converted_logs.append(name)
    else:
        contents = raw.decode('utf-8-sig').replace('\r\n', '\n')
    if not contents.endswith('\n'):
        contents += '\n'
    path.write_text(contents, encoding='utf-8', newline='\n')
    chunks.append(f'diff --git a/{name} b/{name}\nnew file mode 100644\n')
    chunks.extend(difflib.unified_diff([], contents.splitlines(keepends=True),
                                     fromfile='/dev/null', tofile='b/' + name))
patch = OUT / 'task-only.patch'
patch.write_text(''.join(chunks), encoding='utf-8', newline='\n')
check = subprocess.run(['git', 'apply', '--check', '--reverse', '--whitespace=nowarn', str(patch)],
                       cwd=ROOT, capture_output=True, text=True, check=False)
receipt = {'files': len(files), 'patch_sha256': hashlib.sha256(patch.read_bytes()).hexdigest(),
           'reverse_apply_check_exit': check.returncode,
           'utf16_logs_normalized_to_utf8': converted_logs,
           'file_sha256': {path.relative_to(ROOT).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
                           for path in files}}
(OUT / 'checkpoint-result.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
print(json.dumps({key: value for key, value in receipt.items() if key != 'file_sha256'}))
if check.returncode:
    print(check.stderr)
    raise SystemExit(check.returncode)
