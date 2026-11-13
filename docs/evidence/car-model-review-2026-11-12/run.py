"""Run the read-only review with pinned Godot and a private offline profile."""
import hashlib
import ctypes
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
ENGINE = Path(r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe")


def pins():
    paths = set()
    for directory in ["game/vehicle", "game/rendering", "game/ui", "game/core", "game/resources/cars",
                      "game/assets/vehicles", "game/assets/garage/cars_v1"]:
        paths.update(p for p in (ROOT / directory).rglob("*") if p.is_file())
    paths.update(ROOT / p for p in ["game/project.godot", "game/core/build_identity.gd",
                                  "game/vehicle/vehicle_simulation.gd", ".git/index"])
    return {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(paths) if p.is_file()}


def main():
    mode = sys.argv[1]
    assert mode in ["headless", "gl_compatibility", "mobile"]
    script = "components.gd" if "--components" in sys.argv else "showroom.gd" if "--showroom" in sys.argv else "review.gd"
    name = mode + ("-components" if script == "components.gd" else "-showroom" if script == "showroom.gd" else "")
    profile = ROOT / "build/car-model-review-2026-11-12" / mode
    for folder in [profile / "roaming", profile / "local"]:
        folder.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, APPDATA=str(profile / "roaming"),
               LOCALAPPDATA=str(profile / "local"), BMT_API_URL="", BMT_DEV_AUTH_KEY="")
    wrapper = [sys.executable, str(ROOT / "scripts/run_no_crash_dialog.py"), "--", str(ENGINE)]
    version = subprocess.check_output(wrapper + ["--version"], text=True).strip()
    assert version == (ROOT / "godot-version.txt").read_text().strip(), version
    # Launch the GUI binary directly so this Popen handle owns the engine.
    # The console launcher forks it; sandbox taskkill cannot stop that tree.
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.SetErrorMode(kernel.GetErrorMode() | 0x0002)
    command = [str(ENGINE).replace("_console.exe", ".exe")] + ["--path", str(ROOT / "game"), "--audio-driver", "Dummy",
                         "--position", "10000,10000", "--script",
                         "res://../docs/evidence/car-model-review-2026-11-12/" + script]
    command += ["--headless"] if mode == "headless" else ["--rendering-method", mode]
    before = pins()
    (OUT / (name + "-pins-before.json")).write_text(json.dumps(before, indent=2))
    started = time.monotonic()
    with (OUT / (name + ".log")).open("w", encoding="utf-8") as log:
        process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
        reason = None
        while process.poll() is None:
            time.sleep(0.2)
            output = (OUT / (name + ".log")).read_text(encoding="utf-8", errors="replace")
            if "SCRIPT ERROR:" in output or time.monotonic() - started > 600:
                reason = "script error" if "SCRIPT ERROR:" in output else "600s timeout"
                process.kill()
                break
        code = process.wait()
    after = pins()
    (OUT / (name + "-pins-after.json")).write_text(json.dumps(after, indent=2))
    changed = [key for key in before.keys() | after.keys() if before.get(key) != after.get(key)]
    receipt = dict(command=command, engine=version, exit_code=code, stop_reason=reason,
                   elapsed_seconds=time.monotonic()-started, pinned_files=len(before),
                   changed_inputs=changed, script_sha256=hashlib.sha256((OUT / script).read_bytes()).hexdigest())
    (OUT / (name + "-receipt.json")).write_text(json.dumps(receipt, indent=2))
    print(json.dumps(receipt))
    print("\n".join((OUT / (name + ".log")).read_text(encoding="utf-8", errors="replace").splitlines()[-12:]))
    return code


if __name__ == "__main__":
    raise SystemExit(main())
