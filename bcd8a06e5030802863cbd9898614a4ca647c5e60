"""Run selected new regressions against retained task-start functions in memory."""
import importlib.util
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
sys.path[:0] = [str(ROOT), str(ROOT / "backend"), str(ROOT / "backend/tests")]

import pytest
from bmt_backend import reward_rank_cache, rivalry, test_population_tool
from bmt_backend.reward_ranks import percentile_amount


def original(name):
    spec = importlib.util.spec_from_file_location("bmt_backend._bwr_before_"+name,
        HERE / "before/backend/bmt_backend" / (name+".py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


old_rivalry = original("rivalry")


def before_accept(*args, **kwargs):
    old_rivalry.standings_data = rivalry.standings_data
    return old_rivalry.accept_verified(*args, **kwargs)


rivalry.accept_verified = before_accept
test_population_tool.recording = original("test_population_tool").recording
reward_rank_cache.percentile_amount = lambda session, player, board, metric, ticks, revisions, earned: percentile_amount(
    session, board, metric, ticks)

raise SystemExit(pytest.main([
    str(ROOT / "backend/tests/test_backend_work_reduction.py"), "-k",
    "not postgres and (rivalry_uses_one_snapshot or driver_adds_hint or reduces_real_repeat_race)",
    "--basetemp="+str(ROOT / "build/backend-work-reduction-before-probe"), "-q",
]))
