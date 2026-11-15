"""Isolated pinned-engine runner for the Rally side-marker adjustment."""
import os
import sys
from pathlib import Path
import run_car_coarse_models as runner

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/evidence/rally-marker-adjustment-2026-11-15'
WORK = ROOT / 'build/rally-marker-adjustment-2026-11-15'
os.environ['BMT_CAR_BUDGET_WORK_DIR'] = 'build/rally-marker-adjustment-2026-11-15'
os.environ['BMT_CAR_BUDGET_OUT_DIR'] = 'docs/evidence/rally-marker-adjustment-2026-11-15'
runner.OUT, runner.WORK = OUT, WORK
if __name__ == '__main__':
    raise SystemExit(runner.run(*sys.argv[1:]))
