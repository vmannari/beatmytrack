"""Prove bounded picture retention and restoration in separate native App processes."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import uuid

ROOT = Path(__file__).resolve().parents[1]
renderer = sys.argv[1]
assert renderer in ("gl_compatibility", "mobile")
run_id = uuid.uuid4().hex[:10]
OUT = ROOT / "docs/evidence/car-picture-restart-cache-2026-11-15" / renderer / run_id
OUT.mkdir(parents=True)
fixture = ROOT / "build/car-picture-restart-cache-2026-11-15" / renderer / run_id
fixture.mkdir(parents=True)


def run(phase, script, *arguments, headless=False):
    name = ("headless" if headless else renderer) + f"-restart-{phase}-{run_id}"
    command = [sys.executable, str(ROOT / "scripts/run_shared_car_pictures.py"), name,
               script, "--direct", f"--records-root={fixture}", *arguments]
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True)
    source = ROOT / "docs/evidence/shared-car-pictures-2026-11-15" / name
    shutil.copytree(source, OUT / phase)
    if result.returncode:
        print(result.stdout)
        print(result.stderr)
        raise RuntimeError(f"{phase} failed; retained at {OUT / phase}")
    report = json.loads((OUT / phase / "report.json").read_text(encoding="utf-8"))
    print(json.dumps({"phase": phase, "checks": report["checks"],
                      "failures": report["failures"], "captures": report.get("captures"),
                      "disk_hits": report.get("disk_hits")}), flush=True)
    return report


script = "res://tests/test_car_picture_restart_cache.gd"
seed = run("seed", script, "--phase=seed")
control = fixture / "old-policy-control"
control.mkdir()
cache = (fixture / "header_appearance_icons").resolve()
for picture in seed["cars"].values():
    path = Path(picture["path"]).resolve()
    assert path.parent == cache and cache.is_relative_to(fixture.resolve())
    destination = control / path.name
    shutil.copy2(path, destination)
    # Guarantee that current cars are older than every history fixture file.
    os.utime(path, (1, 1))
    os.utime(destination, (1, 1))
retention = run("retention", "res://tests/test_car_picture_cache_retention.gd", headless=True)
restored = run("restore", script, "--phase=restore")
assert seed["pid"] != restored["pid"]
assert restored["captures"] == 0 and restored["disk_hits"] == 2
assert restored["peak_picture_worlds"] == 0
for vehicle in ("compact", "kart"):
    assert seed["cars"][vehicle] == restored["cars"][vehicle]
summary = {"renderer": renderer, "run_id": run_id, "private_fixture": str(fixture),
           "seed": seed, "retention": retention, "restore": restored,
           "different_os_processes": True, "saved_pixels_exact": True}
(OUT / "summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"renderer": renderer, "result": "passed", "evidence": str(OUT)}))
