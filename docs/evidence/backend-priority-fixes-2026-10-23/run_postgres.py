"""Run current source in random disposable schemas on the local test fixture."""
import os
import sys
from pathlib import Path

import pytest
from sqlalchemy.engine import make_url

raw = next(line.split("=", 1)[1].strip() for line in Path("/task/db.env").read_text().splitlines()
           if line.startswith("BMT_TEST_DATABASE_URL="))
url = make_url(raw).set(host="127.0.0.1", port=5432)
os.environ["BMT_TEST_DATABASE_URL"] = url.render_as_string(hide_password=False)
os.environ["BMT_PRIORITY_EVIDENCE_DIR"] = "/evidence"
selection = "postgres"
if "--exclude-legacy-rollback-tests" in sys.argv:
    sys.argv.remove("--exclude-legacy-rollback-tests")
    for name in ("test_migration_backfills_snapshots_without_rewriting_results",
                 "test_migration_bounded_backfill_matches_legacy_and_survives_restart",
                 "test_migration_seeds_existing_racers_without_old_news",
                 "test_migration_preserves_pending_jobs_and_round_trips"):
        selection += " and not " + name
raise SystemExit(pytest.main([*sys.argv[1:], "-k", selection, "-q", "--tb=short", "-p", "no:cacheprovider"]))
