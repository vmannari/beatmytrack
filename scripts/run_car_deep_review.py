"""Read-only deep car study; private profiles, pinned engine and input fences."""
import hashlib
import json
from pathlib import Path
import sys

import run_car_coarse_models as runner

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/car-deep-review-2026-11-14"
WORK = ROOT / "build/car-deep-review-2026-11-14"


def inputs():
    paths = [ROOT / ".git/index", ROOT / "game/core/build_identity.gd", ROOT / "game/project.godot"]
    for directory in ("game/vehicle", "game/resources/cars", "game/assets/vehicles"):
        paths += [p for p in (ROOT / directory).rglob("*") if p.is_file()]
    return {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    before = inputs()
    label, *options = sys.argv[1:]
    runner.OUT, runner.WORK = OUT, WORK
    code = runner.run(label, "res://tests/review_car_deep_2026_11_14.gd", *options)
    after = inputs()
    changes = sorted(p for p in before.keys() | after.keys() if before.get(p) != after.get(p))
    (OUT / (label+"-fence.json")).write_text(json.dumps({"input_count":len(before),"changed_inputs":changes,
        "scope":"read-only; changes by concurrent work recorded, never restored",
        "model_digest_before":hashlib.sha256(json.dumps({k:v for k,v in before.items() if k!='.git/index'},sort_keys=True).encode()).hexdigest(),
        "model_digest_after":hashlib.sha256(json.dumps({k:v for k,v in after.items() if k!='.git/index'},sort_keys=True).encode()).hexdigest(),
        "before_digest":hashlib.sha256(json.dumps(before,sort_keys=True).encode()).hexdigest()},indent=2)+"\n")
    print("Input changes:", changes)
    return code


if __name__ == "__main__":
    raise SystemExit(main())
