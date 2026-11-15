"""C10K01-C10K04: pinned isolated car-budget runner."""
import sys
import os
from pathlib import Path
import run_car_coarse_models as runner
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/os.environ.get('BMT_CAR_BUDGET_OUT_DIR','docs/evidence/car-10k-models-2026-11-14')
WORK = ROOT/os.environ.get('BMT_CAR_BUDGET_WORK_DIR','build/car-10k-models-2026-11-14')
def run(label, script, *options):
    runner.OUT,runner.WORK=OUT,WORK
    return runner.run(label,script,*options)
if __name__=='__main__': raise SystemExit(run(*sys.argv[1:]))
