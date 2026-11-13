"""Import the final native pictures with a private profile and exact exit receipt."""
import json
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
command = ["C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe", "--headless", "--editor",
           "--path", str(ROOT / "game"), "--import"]
started = time.monotonic()
with (OUT / "final-import.log").open("w", encoding="utf-8") as log:
    process = subprocess.Popen(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT,
        env={**os.environ, "APPDATA": str(ROOT / "build/challenger-hellcat-tests/profile"), "BMT_API_URL": ""})
    code = process.wait(timeout=180)
errors = (OUT / "final-import.log").read_text(encoding="utf-8").count("SCRIPT ERROR:")
(OUT / "final-import-command.json").write_text(json.dumps({"command": command,
    "process_exit_code": code, "exit_code": code if code else int(errors > 0), "script_errors": errors,
    "owned_pid": process.pid, "elapsed_seconds": time.monotonic()-started}, indent=2), encoding="utf-8")
print("FINAL_IMPORT:", code, "script errors:", errors)
assert code == 0 and errors == 0
