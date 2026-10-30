"""Run the unchanged migration failure with exact task-start modules in memory."""
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[3]
sys.path[:0] = [str(root / "backend"), str(root / "backend/tests")]
import bmt_backend.runs as runs
import bmt_backend.histogram_snapshots as snapshots
import pytest

for module, filename in ((snapshots, "histogram_snapshots.py"), (runs, "runs.py")):
    source = Path(__file__).parent / "task-start/backend/bmt_backend" / filename
    exec(compile(source.read_text(encoding="utf-8-sig"), str(source), "exec"), module.__dict__)

raise SystemExit(pytest.main([
    "backend/tests/test_histogram_snapshots.py::test_migration_backfills_snapshots_without_rewriting_results[sqlite]",
    "-q", "--tb=short", "--junitxml=docs/evidence/statistics-request-reuse-2026-10-26/backend-baseline-control.xml",
]))
