"""Private offline runner for the loading implementation and its measurements."""
from pathlib import Path
import run_car_optimisation_round2 as runner

runner.OUT = runner.ROOT / "docs/evidence/car-loading-improvements-2026-11-13"
runner.BUILD = runner.ROOT / "build/car-loading-improvements-2026-11-13"
vehicle_pins = runner.pins

def pins():
    result = vehicle_pins()
    files = [runner.ROOT / "game/project.godot"]
    for folder in ["game/core", "game/ui", "game/track", "game/rendering"]:
        files.extend(p for p in (runner.ROOT / folder).rglob("*")
                     if p.is_file() and p.suffix in [".gd", ".gdshader", ".gdshaderinc"])
    for path in files:
        result[path.relative_to(runner.ROOT).as_posix()] = runner.hashlib.sha256(path.read_bytes()).hexdigest()
    return result

runner.pins = pins

if __name__ == "__main__":
    raise SystemExit(runner.main())
