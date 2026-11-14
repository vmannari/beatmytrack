"""CTR01-CTR03: run a native, read-only triangle study with an offline profile."""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/car-triangle-review-2026-11-14"
BUILD = ROOT / "build/car-triangle-review-2026-11-14"


def snapshot() -> dict[str, str]:
    files = [ROOT / ".git/index", ROOT / "game/project.godot", ROOT / "game/core/build_identity.gd"]
    for directory in ("game/vehicle", "game/resources/cars", "game/assets/vehicles", "game/assets/garage/cars_v1"):
        files.extend(p for p in (ROOT / directory).rglob("*") if p.is_file())
    return {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(set(files))}


def main() -> int:
    renderer = sys.argv[1] if len(sys.argv) > 1 else "gl_compatibility"
    if renderer not in ("gl_compatibility", "mobile", "inventory"):
        raise SystemExit("mode must be gl_compatibility, mobile or inventory")
    OUT.mkdir(parents=True, exist_ok=True)
    BUILD.mkdir(parents=True, exist_ok=True)
    before = snapshot()
    environment = dict(os.environ, APPDATA=str(BUILD / "roaming"),
                       LOCALAPPDATA=str(BUILD / "local"), BMT_API_URL="", BMT_DEV_AUTH_KEY="")
    for name in ("roaming", "local"):
        (BUILD / name).mkdir(exist_ok=True)
    command = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
               str(ROOT / "scripts/dev.ps1"), "-Action", "TestScript", "-ScriptPath"]
    if renderer == "inventory":
        command += ["res://tests/profile_car_simplification.gd", "-TestArgument",
                    "--output=res://../docs/evidence/car-triangle-review-2026-11-14/inventory-final.json"]
    else:
        command += ["res://tests/review_car_triangle_tradeoffs_2026_11_14.gd", "-Graphical",
                    "-RenderingMethod", renderer]
    command += ["-CommandTimeoutSeconds", "600"]
    start = time.monotonic()
    log_path = OUT / f"{renderer}.log"
    with log_path.open("w", encoding="utf-8") as log:
        process = subprocess.run(command, cwd=ROOT, env=environment, stdout=log,
                                 stderr=subprocess.STDOUT, timeout=800)
    after = snapshot()
    changed = [name for name in before.keys() | after.keys() if before.get(name) != after.get(name)]
    receipt = {"command": command, "exit_code": process.returncode,
               "seconds": round(time.monotonic()-start, 3), "input_count": len(before),
               "changed_inputs": sorted(changed), "input_digest": hashlib.sha256(
                   json.dumps(before, sort_keys=True).encode()).hexdigest()}
    (OUT / f"{renderer}-receipt.json").write_text(json.dumps(receipt, indent=2)+"\n")
    print(json.dumps(receipt))
    print("\n".join(log_path.read_text(encoding="utf-8", errors="replace").splitlines()[-12:]))
    return process.returncode


if __name__ == "__main__":
    raise SystemExit(main())
