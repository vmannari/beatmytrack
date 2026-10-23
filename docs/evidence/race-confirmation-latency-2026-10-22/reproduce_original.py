"""Run the same prompt idle-wake invariant with the archived worker loop."""
import importlib.util
from pathlib import Path

import pytest
from bmt_backend import worker_lifecycle

here = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('bmt_backend.confirmation_old_lifecycle', here / 'before/worker_lifecycle.py')
original = importlib.util.module_from_spec(spec)
spec.loader.exec_module(original)
worker_lifecycle.run_worker = original.run_worker
raise SystemExit(pytest.main([
    'backend/tests/test_run_confirmation.py::test_idle_worker_wakes_after_check_without_waiting_for_idle_interval',
    '-q', '--tb=short', '--junitxml=' + str(here / 'original-idle-wake.xml'),
]))
