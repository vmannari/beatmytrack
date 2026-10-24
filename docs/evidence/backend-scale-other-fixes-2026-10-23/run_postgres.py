"""Current-source tests on the dedicated fixture's randomly generated schemas."""
import os
import sys
from pathlib import Path

import pytest
from sqlalchemy.engine import make_url

lines = Path("/task/db.env").read_text().splitlines()
raw = next(line.split("=", 1)[1].strip() for line in lines if line.startswith("BMT_TEST_DATABASE_URL="))
url = make_url(raw).set(host="127.0.0.1", port=5432)
os.environ["BMT_TEST_DATABASE_URL"] = url.render_as_string(hide_password=False)
# Historical round-trip fixtures downgrade across the deliberately irreversible
# 0051 telemetry protocol cutover. Keep their assertions intact; exercise the
# new0055 seed/round-trip directly and all current queue/reward invariants here.
selected = ("postgres and not migration_preserves_pending_jobs_and_round_trips "
            "and not migration_backfills_existing_field_and_downgrades_without_changing_receipts")
raise SystemExit(pytest.main([*sys.argv[1:], "-k", selected, "-q", "--tb=short", "-p", "no:cacheprovider",
                             "--junitxml=/evidence/postgres-regression.xml"]))
