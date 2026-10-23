"""Use the existing local test image and disposable DB; never a deployed API."""
import os
import subprocess
import sys
from pathlib import Path

from sqlalchemy.engine import make_url

root = next(parent for parent in Path(__file__).resolve().parents if (parent / 'backend/bmt_backend').is_dir())
task = root / '.tools/queue-capacity-slots-20261022'
task.mkdir(parents=True, exist_ok=True)
evidence = root / 'docs/evidence/queue-capacity-slots-2026-10-22'
value = next(line.split('=', 1)[1].strip() for line in (root / '.tools/backend-postgres.env').read_text().splitlines()
             if line.startswith('BMT_TEST_DATABASE_URL='))
url = make_url(value)
assert url.host in ('localhost', '127.0.0.1') and url.port == 55439
env_file = task / 'private-test.env'
env_file.write_text('BMT_TEST_DATABASE_URL=' + url.set(host='127.0.0.1', port=5432).render_as_string(hide_password=False) + '\n')

def linux(path):
    path = path.resolve().as_posix()
    assert path[:3] == 'C:/'
    return '/mnt/c/' + path[3:]

mode = sys.argv[1]
selection = sys.argv[2:] or ['backend/tests/test_queue_capacity_slots.py', '-k', 'postgres']
command = ['wsl', '-d', 'Ubuntu', '--', 'docker', 'run', '--rm', '--network', 'container:bmt-backend-test',
           '--entrypoint', 'python', '--workdir', '/workspace',
           '--env-file', linux(env_file), '-e', 'PYTHONPATH=/workspace/backend',
           '-e', 'PYTHONDONTWRITEBYTECODE=1',
           '--mount', 'type=bind,source=' + linux(root) + ',target=/workspace,readonly',
           '--mount', 'type=bind,source=' + linux(evidence) + ',target=/evidence',
           '303c521ef446', '-m', 'pytest', *selection, '-q', '--tb=short',
           '--junitxml=/evidence/' + mode + '.xml', '-p', 'no:cacheprovider']
if mode == 'original-linux':
    command[command.index('PYTHONPATH=/workspace/backend')] = 'PYTHONPATH=/baseline'
    position = command.index('303c521ef446')
    command[position:position] = ['--mount', 'type=bind,source=' + linux(task / 'baseline') + ',target=/baseline,readonly']
try:
    result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding='utf-8', errors='replace')
    (evidence / (mode + '.log')).write_text(result.stdout, encoding='utf-8')
    print(result.stdout)
    raise SystemExit(result.returncode)
finally:
    env_file.unlink(missing_ok=True)
