"""RFL01-RFL04: pinned isolated Rally front refinement tooling."""
import os
import sys
from pathlib import Path
import run_car_coarse_models as runner
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/evidence/rally-lamp-style-2026-11-15'
WORK=ROOT/'build/rally-lamp-style-2026-11-15'
for suffix,value in [('WORK_DIR','build/rally-lamp-style-2026-11-15'),('OUT_DIR','docs/evidence/rally-lamp-style-2026-11-15')]:
    os.environ['BMT_CAR_BUDGET_'+suffix]=value
    os.environ['BMT_CAR_BUDGET_'+suffix.removesuffix('_DIR')]='res://../'+value
def run(label,script,*options):
    runner.OUT,runner.WORK=OUT,WORK
    return runner.run(label,script,*options)
if __name__=='__main__':raise SystemExit(run(*sys.argv[1:]))
