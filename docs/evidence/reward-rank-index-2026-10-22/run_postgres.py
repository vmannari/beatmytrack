"""Run only disposable-schema tests next to the existing local test PostgreSQL.

Executed in a disposable cached backend image, networked only through the test
container namespace. The mounted env file is the documented test fixture only.
No connection URL, password or service environment is printed or retained.
"""
import os
import sys
from pathlib import Path

import pytest
from sqlalchemy import create_engine, text
from sqlalchemy.engine import make_url

values = Path("/task/db.env").read_text().splitlines()
raw = next(line.split("=", 1)[1].strip() for line in values if line.startswith("BMT_TEST_DATABASE_URL="))
url = make_url(raw).set(host="127.0.0.1", port=5432)
os.environ["BMT_TEST_DATABASE_URL"] = url.render_as_string(hide_password=False)
if "--fixture-activity" in sys.argv:
    engine = create_engine(url, hide_parameters=True)
    with engine.connect() as db:
        active = db.scalar(text("SELECT count(*) FROM pg_stat_activity WHERE backend_type='client backend' AND pid<>pg_backend_pid()"))
    engine.dispose()
    print("Other fixture clients:", active)
    raise SystemExit(0)
targets = (["tests/test_reward_ranks.py::test_race_acceptance_does_not_scan_population"]
           if "--hot-only" in sys.argv else [
               "tests/test_reward_ranks.py", "tests/test_earned_coins.py", "tests/test_lap_bests.py",
               "tests/test_scalability.py::test_concurrent_restriction_and_pb_improvement_keep_projections_exact"])
receipt = "postgres-hot-final.xml" if "--hot-only" in sys.argv else "postgres-final.xml"
raise SystemExit(pytest.main([
    *targets,
    "-k", "postgres", "-q", "--tb=short", "-p", "no:cacheprovider",
    "--junitxml=/evidence/" + receipt,
]))
