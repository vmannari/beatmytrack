"""Run Desert regression checks with a private offline profile and pinned Godot."""
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/desert-appearance-fix-2026-11-07"
name, script, *options = sys.argv[1:]
OUT.mkdir(parents=True, exist_ok=True)
profile = ROOT / "tmp/desert-appearance-fix" / name
profile.mkdir(parents=True, exist_ok=True)
env = os.environ.copy()
env.update(APPDATA=str(profile), LOCALAPPDATA=str(profile / "local"),
           BMT_API_URL="", BMT_DEV_AUTH_KEY="")
command = [sys.executable, str(ROOT / "scripts/run_no_crash_dialog.py"), "--",
           r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe",
           "--path", str(ROOT / "game"), "--audio-driver", "Dummy",
           "--position", "10000,10000", "--script", script, *options]
start = time.monotonic()
with (OUT / f"{name}.log").open("w", encoding="utf-8") as log:
    try:
        code = subprocess.run(command, env=env, cwd=ROOT, stdout=log,
                              stderr=subprocess.STDOUT, timeout=300).returncode
    except subprocess.TimeoutExpired:
        code = "timeout"
lines = (OUT / f"{name}.log").read_text(encoding="utf-8").splitlines()
errors = [line for line in lines
          if (line.startswith("SCRIPT ERROR:") or line.startswith("ERROR:"))
          and line != "ERROR: Failed to read the root certificate store."]
receipt = dict(command=command, exit_code=code, engine_errors=errors,
               seconds=round(time.monotonic() - start, 3))
(OUT / f"{name}.json").write_text(json.dumps(receipt, indent=2), encoding="utf-8")
print(json.dumps(receipt))
print("\n".join(lines[-25:]))
sys.exit(0 if code == 0 and not errors else 1)
