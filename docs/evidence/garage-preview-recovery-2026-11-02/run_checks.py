"""Native regression with private user data and process-scoped crash suppression."""
from pathlib import Path
import json
import os
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[3]
EVIDENCE = Path(__file__).resolve().parent
label = sys.argv[1]
renderer = sys.argv[2]
control = "--task-start" in sys.argv[3:]
output = EVIDENCE / label
output.mkdir(parents=True, exist_ok=True)
environment = os.environ.copy()
environment["APPDATA"] = str(ROOT / "tmp/garage-recovery/appdata")
environment["LOCALAPPDATA"] = str(ROOT / "tmp/garage-recovery/localappdata")
command = [
    sys.executable, str(ROOT / "scripts/run_no_crash_dialog.py"), "--",
    r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe",
    "--path", str(ROOT / "game"), "--rendering-method", renderer,
    "--script", "res://tests/test_garage_preview_recovery.gd", "--",
    "--output=" + output.as_posix(),
]
if control:
    command.append("--task-start")
with (output / "native.log").open("w", encoding="utf-8") as log:
    result = subprocess.run(command, cwd=ROOT, env=environment, stdout=log,
                            stderr=subprocess.STDOUT, timeout=180, check=False)
(output / "command.json").write_text(json.dumps(command, indent=2), encoding="utf-8")
lines = (output / "native.log").read_text(encoding="utf-8").splitlines()
script_errors = any("SCRIPT ERROR:" in line or "ERROR: Failed to load script" in line for line in lines)
exit_code = result.returncode or int(script_errors)
for line in lines:
    if line.startswith(("FAIL:", "GARAGE_RECOVERY:", "POPUP_TOUCH:")):
        print(line)
print("Exit:", exit_code, "Script errors:", script_errors, "Log:", output / "native.log")
sys.exit(exit_code)
