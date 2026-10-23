"""Run the unchanged no-population-scan assertion with the saved award function.

Only the in-process function is replaced, against disposable SQLite fixtures.
The expected pytest failure reproduces the four original leaderboard scans.
"""
import importlib.util
from pathlib import Path

import pytest
from bmt_backend import economy

source = Path(__file__).with_name("before").joinpath("economy.py")
spec = importlib.util.spec_from_file_location("bmt_backend._saved_reward_economy", source)
original = importlib.util.module_from_spec(spec)
# The archive contains source only; resolve its unchanged catalogue lookup
# against the real package directory while loading the saved Python file.
original.__file__ = economy.__file__
spec.loader.exec_module(original)
economy.accept_verified = original.accept_verified
raise SystemExit(pytest.main([
    "backend/tests/test_reward_ranks.py::test_race_acceptance_does_not_scan_population",
    "-k", "not postgres", "-q", "--tb=short",
    "--junitxml=docs/evidence/reward-rank-index-2026-10-22/original-reproduction.xml",
]))
