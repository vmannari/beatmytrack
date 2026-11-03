"""Isolated automated Godot runs; never reads the owner's saves or contacts a service."""
import os
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[3]
out = Path(__file__).resolve().parent
script = next((arg for arg in sys.argv[1:] if not arg.startswith("--")), "test_daily_elimination")
profile = root / ("build/daily-elimination-profile-"+script)
profile.mkdir(parents=True, exist_ok=True)
env = os.environ.copy()
env.update(APPDATA=str(profile), LOCALAPPDATA=str(profile), BMT_API_URL="",
           BMT_DAILY_PAGE_OUTPUT=str(out / "page"))
graphical = "--graphical" in sys.argv
command = [sys.executable, str(root / "scripts/run_no_crash_dialog.py"), "--",
           r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe",
           "--path", str(root / "game"), "--rendering-method", "gl_compatibility",
           "--audio-driver", "Dummy", "--script", "res://tests/"+script+".gd"]
if not graphical:
    command.append("--headless")
result = subprocess.run(command, cwd=root, env=env, capture_output=True, text=True, encoding="utf-8",
                        errors="replace", timeout=240)
output = result.stdout+result.stderr
(out / (script+("-native" if graphical else "-headless")+"-"+str(os.getpid())+".log")).write_text(output, encoding="utf-8")
print(output)
raise SystemExit(result.returncode)
