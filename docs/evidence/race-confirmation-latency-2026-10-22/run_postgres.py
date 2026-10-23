"""Use only the existing local fixture and generated disposable test schemas."""
import os
import sys
from pathlib import Path

import pytest
from sqlalchemy import create_engine, text
from sqlalchemy.engine import make_url

raw = next(line.split('=', 1)[1].strip() for line in Path('/task/db.env').read_text().splitlines()
           if line.startswith('BMT_TEST_DATABASE_URL='))
url = make_url(raw).set(host='127.0.0.1', port=5432)
os.environ['BMT_TEST_DATABASE_URL'] = url.render_as_string(hide_password=False)
if '--fixture-activity' in sys.argv:
    engine = create_engine(url, hide_parameters=True)
    with engine.connect() as db:
        active = db.scalar(text("SELECT count(*) FROM pg_stat_activity WHERE backend_type='client backend' AND pid<>pg_backend_pid()"))
    engine.dispose()
    print('Other fixture clients:', active)
    raise SystemExit(0 if active == 0 else 2)
args = sys.argv[1:] or ['tests/test_run_confirmation.py', '-k', 'postgres and not sqlite',
    '--junitxml=/evidence/postgres-focused-first.xml']
raise SystemExit(pytest.main([*args, '-q', '--tb=short', '-p', 'no:cacheprovider']))
