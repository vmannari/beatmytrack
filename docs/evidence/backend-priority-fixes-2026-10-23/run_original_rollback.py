"""Reproduce historical rollback failures on the exact pre-review Git source."""
import io
import os
import subprocess
import sys
import zipfile
from pathlib import Path

import pytest

root = Path(__file__).resolve().parents[3]
revision = "dc3e2af6c9e1875db9ffe7e2a8efa321076f19b1"
shadow = root / "build/backend-priority-fixes-2026-10-23/original-rollback"
shadow.mkdir(parents=True, exist_ok=False)
archive = subprocess.run(["git", "archive", "--format=zip", revision, "backend"], cwd=root,
                         capture_output=True, check=True).stdout
with zipfile.ZipFile(io.BytesIO(archive)) as bundle:
    bundle.extractall(shadow)
os.chdir(shadow / "backend")
sys.path.insert(0, str(shadow / "backend"))
os.environ["PYTHONPATH"] = str(shadow / "backend")
targets = ["tests/test_histogram_snapshots.py::test_migration_backfills_snapshots_without_rewriting_results",
           "tests/test_lap_bests.py::test_migration_bounded_backfill_matches_legacy_and_survives_restart",
           "tests/test_news.py::test_migration_seeds_existing_racers_without_old_news",
           "tests/test_queue_capacity_slots.py::test_migration_preserves_pending_jobs_and_round_trips"]
raise SystemExit(pytest.main([*targets, "-k", "not postgres", "-q", "--tb=short", "-p", "no:cacheprovider",
    "--junitxml=" + str(Path(__file__).with_name("original-rollback.xml"))]))
