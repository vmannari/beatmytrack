"""C10K01-C10K04: pinned isolated car-budget runner."""
import sys
import os
from pathlib import Path
import run_car_coarse_models as runner
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'docs/evidence/car-model-artifacts-2026-11-14'
WORK = ROOT/'build/car-model-artifacts-2026-11-14'
for suffix,value in [('WORK_DIR','build/car-model-artifacts-2026-11-14'),('OUT_DIR','docs/evidence/car-model-artifacts-2026-11-14')]:
    os.environ['BMT_CAR_BUDGET_'+suffix]=value
    os.environ['BMT_CAR_BUDGET_'+suffix.removesuffix('_DIR')]='res://../'+value
def run(label, script, *options):
    runner.OUT,runner.WORK=OUT,WORK
    return runner.run(label,script,*options)
if __name__=='__main__': raise SystemExit(run(*sys.argv[1:]))
