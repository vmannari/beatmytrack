"""Read-only bind of frozen tests into the exact candidate; SQLite only, no cloud calls."""
import copy
import importlib.util
import json
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'docs/evidence/backend-studio-deploy-2026-10-11'
CONTEXT = ROOT / 'build/backend-studio-deploy-2026-10-11/image'
TESTS = CONTEXT.parent / 'frozen-tests'
receipt_path = OUTPUT / 'rollout.json'
receipt = json.loads(receipt_path.read_text())
assert receipt.get('local_tag')
if not TESTS.exists():
    shutil.copytree(ROOT / 'backend/tests', TESTS, ignore=shutil.ignore_patterns('__pycache__', '.pytest_cache'))
config = copy.deepcopy(json.loads((ROOT / '.tools/gcp-staging/config.json').read_text()))
if '--cd' in config['docker']:
    config['docker'][config['docker'].index('--cd') + 1] = '/mnt/' + CONTEXT.drive[0].lower() + CONTEXT.as_posix()[2:]
test_path = '/mnt/' + TESTS.drive[0].lower() + TESTS.as_posix()[2:]
command = [*config['docker'], 'run', '--rm', '--network=none',
           '-v', test_path + ':/studio-tests:ro', '-e', 'PYTHONPATH=/app:/studio-tests',
           '--entrypoint=python', receipt['local_tag'], '-m', 'pytest',
           '/studio-tests/test_admin.py', '/studio-tests/test_admin_support.py',
           '/studio-tests/test_studio.py', '/studio-tests/test_store_admin.py',
           '-q', '-m', 'not postgres', '-k', 'not postgres', '-p', 'no:cacheprovider', '--tb=short']
result = subprocess.run(command, cwd=CONTEXT, capture_output=True, text=True, timeout=180, check=False)
output = result.stdout + result.stderr
(OUTPUT / 'exact-image-tests.log').write_text(output, encoding='utf-8')
print(output[-5000:])
if result.returncode == 0:
    receipt['exact_image_tests'] = True
    receipt_path.write_text(json.dumps(receipt, indent=2) + '\n')
sys.exit(result.returncode)
