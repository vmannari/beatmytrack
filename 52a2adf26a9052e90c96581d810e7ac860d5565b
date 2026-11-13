"""Existing concurrency/cost tests against only the generated synthetic database."""
import os
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/"backend"))
import pytest
from database_probe import fixture_url


if __name__=="__main__":
    os.environ["BMT_TEST_DATABASE_URL"]=fixture_url()
    raise SystemExit(pytest.main([
        "backend/tests/test_cost_archives.py","backend/tests/test_cost_transport.py",
        "backend/tests/test_race_acceptance_sql.py","backend/tests/test_bounded_retention.py",
        "-q","-k","postgres","-m","not godot",
        "--junitxml=docs/evidence/backend-local-cost-simulation-2026-10-26/postgres-checks.xml",
        "-o","cache_dir=build/backend-local-cost-simulation-2026-10-26/pg-cache",
        "--basetemp=build/backend-local-cost-simulation-2026-10-26/pg-tests"]))
