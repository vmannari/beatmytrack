"""Run a Garage probe with disposable offline storage and retained timing logs."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "build/garage-first-entry-2026-11-14"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("name")
    parser.add_argument("--script", default="res://tests/profile_garage_first_entry.gd")
    parser.add_argument("--renderer", default="gl_compatibility")
    parser.add_argument("--headless", action="store_true")
    parser.add_argument("options", nargs="*")
    args, options = parser.parse_known_args()
    output = OUT / args.name
    output.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env.update(APPDATA=str(output / "profile"), LOCALAPPDATA=str(output / "profile/local"),
               BMT_API_URL="", BMT_DEV_AUTH_KEY="", BMT_GRAPHICS_EVIDENCE=str(output),
               BMT_LOADING_OUTPUT=str(output / "report.json"))
    command = [sys.executable, str(ROOT / "scripts/run_no_crash_dialog.py"), "--",
               r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe",
               "--path", str(ROOT / "game"), "--audio-driver", "Dummy",
               "--position", "10000,10000", "--rendering-method", args.renderer,
               *(["--headless"] if args.headless else []),
               "--script", args.script, "--", "--output=" + str(output), *args.options, *options]
    def inputs():
        paths = [p for folder in ("ui", "vehicle", "rendering", "core")
                 for p in (ROOT / "game" / folder).rglob("*.gd")]
        paths += list((ROOT / "game/assets/vehicles/modular_car_bases_v1").glob("*.scn"))
        paths += list((ROOT / "game/assets/vehicles/modular_kits_v1").rglob("*.scn"))
        paths += list((ROOT / "game/assets/garage").rglob("*.scn"))
        return {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in paths}
    before = inputs()
    began = time.monotonic()
    reason = None
    with (output / "run.log").open("w", encoding="utf-8") as log:
        process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=log,
                                   stderr=subprocess.STDOUT)
        while process.poll() is None:
            content = (output / "run.log").read_text(encoding="utf-8", errors="replace")
            if "SCRIPT ERROR:" in content or "Assertion failed:" in content:
                reason = "script/assertion failure"
            elif time.monotonic() - began > 180:
                reason = "180 second timeout"
            if reason:
                if os.name == "nt":
                    subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                else:
                    process.kill()
                break
            time.sleep(0.1)
        code = process.wait()
    after = inputs()
    changed = sorted(p for p in before.keys() | after.keys() if before.get(p) != after.get(p))
    result = dict(command=command, exit_code=code, seconds=time.monotonic() - began,
                  changed_inputs=changed, stop_reason=reason)
    (output / "inputs.json").write_text(json.dumps(before, indent=2), encoding="utf-8")
    (output / "run.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps(result))
    print((output / "run.log").read_text(encoding="utf-8")[-6000:])
    return 0 if code == 0 and reason is None else 1


if __name__ == "__main__":
    sys.exit(main())
