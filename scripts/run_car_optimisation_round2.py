"""Run read-only car reduction candidates with a private offline profile."""
import ctypes
import gzip
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/car-optimisation-review-round2-2026-11-13"
BUILD = ROOT / "build/car-optimisation-review-round2-2026-11-13"


def pins():
    files = [ROOT / ".git/index"]
    for directory in ["game/vehicle", "game/resources/cars", "game/assets/vehicles"]:
        files.extend(p for p in (ROOT / directory).rglob("*") if p.is_file() and p.suffix in
                     [".gd", ".gdshader", ".gdshaderinc", ".res", ".scn", ".json", ".tres"])
    return {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}


def main():
    label, *options = sys.argv[1:]
    script = "res://tests/review_car_optimisation_round2.gd"
    for option in list(options):
        if option.startswith("--script="):
            script = option.split("=", 1)[1]
            options.remove(option)
    OUT.mkdir(parents=True, exist_ok=True)
    BUILD.mkdir(parents=True, exist_ok=True)
    (BUILD / ".keep").touch()
    for name in ["roaming", "local"]:
        (BUILD / name).mkdir(exist_ok=True)
    before = pins()
    source_bytes = json.dumps(before).encode("utf-8")
    source_sha = hashlib.sha256(source_bytes).hexdigest()
    source_path = OUT / "source-pins" / (source_sha + ".json.gz")
    source_path.parent.mkdir(exist_ok=True)
    if not source_path.exists():
        source_path.write_bytes(gzip.compress(source_bytes, mtime=0))
    env = dict(os.environ, APPDATA=str(BUILD / "roaming"), LOCALAPPDATA=str(BUILD / "local"),
               BMT_API_URL="", BMT_DEV_AUTH_KEY="")
    engine = r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64.exe"
    ctypes.windll.kernel32.SetErrorMode(0x0002)
    command = [engine, "--path", str(ROOT / "game"), "--audio-driver", "Dummy",
               "--position", "10000,10000", "--script", script] + options
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
    receipt["source_before"] = {"file": source_path.relative_to(OUT).as_posix(),
                                "uncompressed_sha256": source_sha, "encoding": "gzip JSON"}
    (OUT / (label + "-receipt.json")).write_text(json.dumps(receipt, indent=2))
    print(json.dumps(receipt))
    print("\n".join(content.splitlines()[-10:]))
    return int(code != 0 or bool(errors))


if __name__ == "__main__":
    raise SystemExit(main())
