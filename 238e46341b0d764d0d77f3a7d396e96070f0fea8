"""Isolate profiles, retain raw logs and the actual native return code."""
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
profile = ROOT / "build/daily-standings-latency-2026-11-04-repeat"
profile.mkdir(parents=True, exist_ok=True)
env = dict(os.environ, APPDATA=str(profile), LOCALAPPDATA=str(profile), BMT_API_URL="",
           BMT_DAILY_LATENCY_OUTPUT=str(OUT / "native-card-timings-repeat.json"))
result = subprocess.run([
    sys.executable, str(ROOT / "scripts/run_no_crash_dialog.py"), "--",
    r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe", "--path", str(ROOT / "game"),
    "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy",
    "--script", "res://tests/profile_daily_standings_latency.gd",
], env=env, cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace",
    timeout=90, check=False)
(OUT / "native-card-repeat.log").write_text(result.stdout + result.stderr, encoding="utf-8")
(OUT / "native-exit.json").write_text(json.dumps({"returncode": result.returncode}) + "\n", encoding="utf-8")
print(result.stdout + result.stderr)
print("NATIVE_EXIT:", result.returncode)
raise SystemExit(result.returncode)
