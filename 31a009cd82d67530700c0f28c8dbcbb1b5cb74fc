"""Task-owned, isolated native runs with process-scoped crash dialog suppression."""
import os
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[3]
out = Path(__file__).resolve().parent
script = next((a for a in sys.argv[1:] if not a.startswith("--")), "test_daily_medal_page")
graphical = "--graphical" in sys.argv
renderer = "mobile" if "--mobile" in sys.argv else "gl_compatibility"
profile = root / "build" / ("daily-car-dropdown-" + script + "-" + renderer)
profile.mkdir(parents=True, exist_ok=True)
env = dict(os.environ, APPDATA=str(profile), LOCALAPPDATA=str(profile), BMT_API_URL="",
           BMT_DAILY_MEDAL_OUTPUT=str(out / ("mobile" if renderer == "mobile" else "gl_compatibility")),
           BMT_DAILY_FIXED_EVIDENCE=str(out))
(out / renderer).mkdir(parents=True, exist_ok=True)
command = [sys.executable, str(root / "scripts/run_no_crash_dialog.py"), "--",
           r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe",
           "--path", str(root / "game"), "--rendering-method", renderer,
           "--audio-driver", "Dummy", "--script", "res://tests/" + script + ".gd"]
if not graphical:
    command.append("--headless")
if "--import-catalogues" in sys.argv:
    command = command[:command.index("--script")] + ["--headless", "--editor", "--import", "--quit"]
result = subprocess.run(command, cwd=root, env=env, capture_output=True, text=True,
                        encoding="utf-8", errors="replace", timeout=240)
output = result.stdout + result.stderr
(out / (script + "-" + renderer + ("-native-" if graphical else "-headless-") +
        str(os.getpid()) + ".log")).write_text(output, encoding="utf-8")
print(output)
raise SystemExit(result.returncode)
