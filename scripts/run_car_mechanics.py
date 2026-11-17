"""CME01-CME05: isolated runner for mechanical-detail improvements."""
import os
import shutil
import sys
from pathlib import Path
import run_car_coarse_models as runner

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/evidence/car-mechanics-2026-11-17'
WORK = ROOT / 'build/car-mechanics-2026-11-17'
for suffix, value in [('WORK_DIR', 'build/car-mechanics-2026-11-17'),
                      ('OUT_DIR', 'docs/evidence/car-mechanics-2026-11-17')]:
    os.environ['BMT_CAR_BUDGET_' + suffix] = value
    os.environ['BMT_CAR_BUDGET_' + suffix.removesuffix('_DIR')] = 'res://../' + value

def run(label, script, *options):
    # Keep initial rejections when a corrected invocation reuses a label.
    if (OUT/(label+'-receipt.json')).exists():
        history=OUT/'history';history.mkdir(parents=True,exist_ok=True)
        revision=1
        while (history/(label+'-'+str(revision)+'-receipt.json')).exists():revision+=1
        for suffix in ('.log','-receipt.json'):
            source=OUT/(label+suffix)
            if source.exists():shutil.copyfile(source,history/(label+'-'+str(revision)+suffix))
    runner.OUT, runner.WORK = OUT, WORK
    return runner.run(label, script, *options)

if __name__ == '__main__':
    raise SystemExit(run(*sys.argv[1:]))
