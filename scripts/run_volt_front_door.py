"""VFD01-VFD03. Pinned engine with an isolated local test profile."""
import os
import sys
from pathlib import Path
import run_car_coarse_models as runner

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/evidence/volt-front-door-2026-11-17'
WORK = ROOT / 'build/volt-front-door-2026-11-17'
for suffix, value in [('WORK_DIR', WORK), ('OUT_DIR', OUT)]:
    relative = value.relative_to(ROOT).as_posix()
    os.environ['BMT_CAR_BUDGET_' + suffix] = relative
    os.environ['BMT_CAR_BUDGET_' + suffix.removesuffix('_DIR')] = 'res://../' + relative


def run(label, script, *options):
    runner.OUT, runner.WORK = OUT, WORK
    return runner.run(label, script, *options)


if __name__ == '__main__':
    raise SystemExit(run(*sys.argv[1:]))
