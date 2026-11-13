from pathlib import Path
import sys
root=Path.cwd()
sys.path.insert(0,str(root/'backend'))
from bmt_backend import daily_snapshot_preparation
# Disable every new publication/maintenance hook for the retained migration control.
daily_snapshot_preparation.schedule=lambda *args,**kwargs: None
import pytest
raise SystemExit(pytest.main(['backend/tests/test_histogram_snapshots.py::test_migration_backfills_snapshots_without_rewriting_results','-q','-k','sqlite']))
