"""CI01: first gradual reduction with isolated verification."""
import os
import sys
from pathlib import Path
import run_car_coarse_models as runner

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/evidence/car-pass10-2026-11-16'
WORK=ROOT/'build/car-pass10-2026-11-16'
for suffix,value in [('WORK_DIR','build/car-pass10-2026-11-16'),('OUT_DIR','docs/evidence/car-pass10-2026-11-16')]:
    os.environ['BMT_CAR_BUDGET_'+suffix]=value
    os.environ['BMT_CAR_BUDGET_'+suffix.removesuffix('_DIR')]='res://../'+value

def run(label,script,*options):
    runner.OUT,runner.WORK=OUT,WORK
    return runner.run(label,script,*options)

if __name__=='__main__':raise SystemExit(run(*sys.argv[1:]))
