"""Pinned Godot runner for the offline driver adaptation and native captures.

The standard dev.ps1 entry point kills native tests on the Windows certificate
store diagnostic. This bounded runner retains that diagnostic in the log.
"""
import json
import os
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/kart-tomkart-driver-2026-11-08"


def main():
    name, script, *options = sys.argv[1:]
    OUT.mkdir(parents=True, exist_ok=True)
    profile = ROOT / "build/kart-driver-tomkart-2026-11-08/profile"
    for folder in [profile / "roaming", profile / "local"]:
        folder.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, APPDATA=str(profile / "roaming"),
               LOCALAPPDATA=str(profile / "local"), BMT_API_URL="", BMT_DEV_AUTH_KEY="")
    engine = r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe"
    actual = subprocess.check_output([engine, "--version"], text=True).strip()
    assert actual == (ROOT / "godot-version.txt").read_text().strip(), actual
    command = [sys.executable, str(ROOT / "scripts/run_no_crash_dialog.py"), "--", engine,
               "--path", str(ROOT / "game"), "--audio-driver", "Dummy", "--position", "10000,10000",
               "--script", script, *options]
    started = time.monotonic()
    with (OUT / (name + ".log")).open("w", encoding="utf-8") as log:
        process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=log,
                                   stderr=subprocess.STDOUT)
        try:
            code = process.wait(timeout=900)
        except subprocess.TimeoutExpired:
            # Kill only this runner's owned child tree, including native Godot.
            subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                           stdout=log, stderr=subprocess.STDOUT, check=False)
            code = 124
    lines = (OUT / (name + ".log")).read_text(encoding="utf-8").splitlines()
    errors = [line for line in lines if line.startswith(("ERROR:", "SCRIPT ERROR:"))
              and line != "ERROR: Failed to read the root certificate store."]
    receipt = dict(command=command, exit_code=code, errors=errors,
                   seconds=round(time.monotonic() - started, 3), engine=actual)
    (OUT / (name + ".json")).write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(receipt))
    print("\n".join(lines[-18:]))
    return int(code != 0 or bool(errors))


if __name__ == "__main__":
    sys.exit(main())
