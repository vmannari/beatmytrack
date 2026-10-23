"""Disposable-schema validation; credentials never leave the ignored fixture file."""
import os
import sys
from pathlib import Path

import pytest
from sqlalchemy.engine import make_url

lines = Path("/task/db.env").read_text().splitlines()
raw = next(line.split("=", 1)[1].strip() for line in lines if line.startswith("BMT_TEST_DATABASE_URL="))
url = make_url(raw).set(host="127.0.0.1", port=5432)
os.environ["BMT_TEST_DATABASE_URL"] = url.render_as_string(hide_password=False)
targets = sys.argv[1:] or ["tests/test_telemetry_parallel.py", "tests/test_product_analytics.py"]
raise SystemExit(pytest.main([*targets, "-k", "postgres", "-q", "--tb=short", "-p", "no:cacheprovider",
                             "--junitxml=/evidence/postgres.xml"]))
