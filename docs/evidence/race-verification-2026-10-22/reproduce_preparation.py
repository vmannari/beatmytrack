"""The unchanged no-IO warm-cache assertion with original preparation code."""
import importlib.util
from pathlib import Path

import pytest
from bmt_backend import trajectory_verifier

source=Path(__file__).parent/"before/trajectory_verifier.py"
spec=importlib.util.spec_from_file_location("bmt_backend._saved_preparation",source)
original=importlib.util.module_from_spec(spec)
spec.loader.exec_module(original)
trajectory_verifier.prepared_geometry=original.prepared_geometry
raise SystemExit(pytest.main([
    "backend/tests/test_verification_preparation.py::test_warm_descriptor_avoids_track_storage_and_sql_and_is_not_mutable_shared_state",
    "-q","--tb=short","--junitxml=docs/evidence/race-verification-2026-10-22/original-preparation.xml",
]))
