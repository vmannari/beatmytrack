"""Run the new scheduling regressions against archived pre-task functions."""
import importlib.util
import sys
from pathlib import Path

import pytest

ROOT = next(parent for parent in Path(__file__).resolve().parents if (parent / "backend/bmt_backend").is_dir())
sys.path.insert(0, str(ROOT / "backend"))
before = ROOT / "docs/evidence/publication-speed-2026-10-18/before"


def archived(name, filename):
    spec = importlib.util.spec_from_file_location(name, before / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


import bmt_backend.publications
import bmt_backend.service_worker

original_publications = archived("bmt_backend._original_publications", "backend__bmt_backend__publications.py")
original_service = archived("bmt_backend._original_service", "backend__bmt_backend__service_worker.py")
bmt_backend.publications.payload = original_publications.payload
bmt_backend.service_worker.supervise = original_service.supervise
# The supervisor function resolves its original globals. Redirect its hooks to
# the current module so the test's injected signal/child controls stay effective.
original_service.__dict__.update({key: value for key, value in bmt_backend.service_worker.__dict__.items()
    if key in ("time", "signal")})
raise SystemExit(pytest.main([str(ROOT / "backend/tests/test_publication_latency.py"),
    "-k", "not postgres and (prompt_polling or supervisor)", "-q", "--tb=short",
    "--junitxml=" + str(ROOT / "docs/evidence/publication-speed-2026-10-18/baseline.xml")]))
