"""Pinned, isolated runner for CLV01-CLV04 car detail reductions."""
import sys
from pathlib import Path
import run_car_coarse_models as runner

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/car-detail-reduction-2026-11-14"
WORK = ROOT / "build/car-detail-reduction-2026-11-14"

def run(label, script, *options):
    runner.OUT, runner.WORK = OUT, WORK
    return runner.run(label, script, *options)

if __name__ == "__main__":
    raise SystemExit(run(*sys.argv[1:]))
