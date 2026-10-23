"""Execute isolated-schema tests through the existing local test container."""
import os
import sys
from pathlib import Path

import pytest
from sqlalchemy.engine import make_url

raw = next(line.split('=', 1)[1].strip() for line in Path('/task/db.env').read_text().splitlines()
           if line.startswith('BMT_TEST_DATABASE_URL='))
url = make_url(raw).set(host='127.0.0.1', port=5432)
os.environ['BMT_TEST_DATABASE_URL'] = url.render_as_string(hide_password=False)
args = sys.argv[1:] or ['tests/test_race_acceptance_sql.py', 'tests/test_earned_coins.py',
    'tests/test_achievements.py', 'tests/test_rivalry.py', 'tests/test_challenges.py',
    'tests/test_lap_bests.py', 'tests/test_reward_ranks.py',
    'tests/test_scalability.py::test_concurrent_restriction_and_pb_improvement_keep_projections_exact',
    'tests/test_scalability.py::test_finalization_db_failure_keeps_fenced_job_recoverable',
    '-k', 'postgres and not migration_backfills_existing_field',
    '--junitxml=/evidence/postgres-regression.xml']
raise SystemExit(pytest.main([*args, '-q', '--tb=short', '-p', 'no:cacheprovider']))
