import os
import sys
from pathlib import Path

import pytest

root = Path(__file__).resolve().parents[3]
os.chdir(root / "backend")
os.environ["PYTHONPATH"] = str(root / "backend")
os.environ["BMT_PRIORITY_EVIDENCE_DIR"] = str(Path(__file__).resolve().parent)
sys.path.insert(0, str(root / "backend"))
selection = "not postgres"
if "--exclude-legacy-rollback-tests" in sys.argv:
    sys.argv.remove("--exclude-legacy-rollback-tests")
    for name in ("test_migration_backfills_snapshots_without_rewriting_results",
                 "test_migration_bounded_backfill_matches_legacy_and_survives_restart",
                 "test_migration_seeds_existing_racers_without_old_news",
                 "test_migration_preserves_pending_jobs_and_round_trips"):
        selection += " and not " + name
raise SystemExit(pytest.main([*sys.argv[1:], "-k", selection, "-q", "--tb=short", "-p", "no:cacheprovider"]))
