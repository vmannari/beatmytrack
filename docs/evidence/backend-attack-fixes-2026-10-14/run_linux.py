import os
import subprocess
import sys
from pathlib import Path

from sqlalchemy.engine import make_url

mode = sys.argv[1]
os.chdir('/workspace')
environment = os.environ.copy()
if mode.startswith('postgres'):
    setting = next(line.split('=', 1)[1].strip() for line in Path('/run/pg.env').read_text().splitlines()
                   if line.startswith('BMT_TEST_DATABASE_URL='))
    url = make_url(setting)
    assert url.host in ('localhost', '127.0.0.1') and url.port == 55439
    environment['BMT_TEST_DATABASE_URL'] = url.set(host='127.0.0.1', port=5432).render_as_string(hide_password=False)
    paths = ['backend/tests/test_attack_resistance.py', 'backend/tests/test_publication_intents.py',
             'backend/tests/test_robustness_fixes.py', 'backend/tests/test_auth_postgres.py',
             'backend/tests/test_replica_failures.py']
    selection = 'postgres'
    if mode == 'postgres-focused':
        paths = ['backend/tests/test_attack_resistance.py', 'backend/tests/test_publication_intents.py']
else:
    paths = ['backend/tests/test_attack_resistance.py', 'backend/tests/test_communication_boundary.py',
             'backend/tests/test_worker_lifecycle.py', 'backend/tests/test_review_followups.py',
             'backend/deploy/test_operations.py', 'backend/deploy/test_backup_wrapper.py']
    selection = 'not postgres'
command = [sys.executable, '-m', 'pytest', *paths, '-q', '-x', '-k', selection,
           '-p', 'no:cacheprovider', '--junitxml=/evidence/regression-'+mode+'-linux.xml']
sys.exit(subprocess.run(command, env=environment).returncode)
