"""Run read-only car reduction candidates with a private offline profile."""
import ctypes
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/car-reduction-review-2026-11-13"
BUILD = ROOT / "build/car-reduction-review-2026-11-13"


def pins():
    files = [ROOT / ".git/index"]
    for directory in ["game/vehicle", "game/resources/cars", "game/assets/vehicles"]:
        files.extend(p for p in (ROOT / directory).rglob("*") if p.is_file() and p.suffix in
                     [".gd", ".gdshader", ".gdshaderinc", ".res", ".scn", ".json", ".tres"])
    return {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}


def main():
    label, *options = sys.argv[1:]
    OUT.mkdir(parents=True, exist_ok=True)
    BUILD.mkdir(parents=True, exist_ok=True)
    (BUILD / ".keep").touch()
    for name in ["roaming", "local"]:
        (BUILD / name).mkdir(exist_ok=True)
    before = pins()
    (OUT / (label + "-source-before.json")).write_text(json.dumps(before))
    env = dict(os.environ, APPDATA=str(BUILD / "roaming"), LOCALAPPDATA=str(BUILD / "local"),
               BMT_API_URL="", BMT_DEV_AUTH_KEY="")
    engine = r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64.exe"
    ctypes.windll.kernel32.SetErrorMode(0x0002)
    command = [engine, "--path", str(ROOT / "game"), "--audio-driver", "Dummy",
               "--position", "10000,10000", "--script", "res://tests/review_car_reductions_2026_11_13.gd"] + options
    started = time.monotonic()
    log_path = OUT / (label + ".log")
    with log_path.open("w", encoding="utf-8") as log:
        process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
        (OUT / (label + "-process.json")).write_text(json.dumps({"pid": process.pid, "command": command}))
        reason = None
        while process.poll() is None:
            time.sleep(0.3)
            content = log_path.read_text(encoding="utf-8", errors="replace")
            if "SCRIPT ERROR:" in content or time.monotonic() - started > 900:
                reason = "script error" if "SCRIPT ERROR:" in content else "900s timeout"
                process.kill()
                break
        code = process.wait()
    content = log_path.read_text(encoding="utf-8", errors="replace")
    errors = [line for line in content.splitlines() if line.startswith(("ERROR:", "SCRIPT ERROR:"))
              and line != "ERROR: Failed to read the root certificate store."]
    after = pins()
    changed = sorted(p for p in before.keys() | after.keys() if before.get(p) != after.get(p))
    receipt = {"exit_code": code, "errors": errors, "stop_reason": reason,
               "seconds": time.monotonic() - started, "changed_inputs": changed,
               "input_count": len(before), "command": command}
    (OUT / (label + "-receipt.json")).write_text(json.dumps(receipt, indent=2))
    print(json.dumps(receipt))
    print("\n".join(content.splitlines()[-10:]))
    return int(code != 0 or bool(errors))


if __name__ == "__main__":
    raise SystemExit(main())
