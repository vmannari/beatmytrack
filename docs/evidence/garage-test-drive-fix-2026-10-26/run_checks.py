"""Pinned, isolated desktop checks; record exact commands, logs and exit codes."""
import json
import os
from pathlib import Path
import subprocess
import sys
import time

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
name, script, *options = sys.argv[1:]
env = os.environ.copy()
profile = ROOT / "build/garage-test-drive-fix" / name
profile.mkdir(parents=True, exist_ok=True)
env.update(APPDATA=str(profile), LOCALAPPDATA=str(profile / "local"),
           BMT_API_URL="", BMT_DEV_AUTH_KEY="")
args = [r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe",
        "--path", str(ROOT / "game"), "--audio-driver", "Dummy",
        "--position", "10000,10000", "--script", script, *options]
began = time.monotonic()
with (OUT / f"{name}.log").open("w", encoding="utf-8") as log:
    try:
        result = subprocess.run(args, cwd=ROOT, env=env, stdout=log,
                                stderr=subprocess.STDOUT, timeout=150)
        code = result.returncode
    except subprocess.TimeoutExpired:
        code = "timeout"
summary = dict(command=args, exit_code=code,
               seconds=round(time.monotonic() - began, 3))
(OUT / f"{name}.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
print(json.dumps(summary), flush=True)
print("\n".join((OUT / f"{name}.log").read_text(encoding="utf-8").splitlines()[-35:]))
sys.exit(0 if code == 0 else 1)
