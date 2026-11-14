"""Offline pinned-engine checks with private saves, bounded processes and receipts."""
import ctypes
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
GODOT = "C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe"
label, script, *extra = sys.argv[1:]
profile = ROOT / "build/challenger-corner-finalise-2026-11-13/profile"
(profile / "Circuit01Lab").mkdir(parents=True, exist_ok=True)
(profile / "Circuit01Lab/backend.cfg").write_text('[backend]\nurl=""\n', encoding="utf-8")
env = {**os.environ, "APPDATA": str(profile), "BMT_API_URL": ""}
ctypes.windll.kernel32.SetErrorMode(0x0002)
command = [GODOT, "--path", str(ROOT / "game"), "--script", script, *extra]
started = time.monotonic()
with (OUT / (label + ".log")).open("w", encoding="utf-8") as log:
    process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
    (OUT / (label + "-running.json")).write_text(json.dumps({"owned_pid":process.pid,"command":command}),encoding="utf-8")
    while process.poll() is None:
        if "SCRIPT ERROR:" in (OUT / (label + ".log")).read_text(encoding="utf-8",errors="replace"):
            process.kill();process.wait();break
        if time.monotonic()-started>300:
            process.kill();process.wait();break
        time.sleep(0.25)
    code = process.returncode
lines = (OUT / (label + ".log")).read_text(encoding="utf-8", errors="replace").splitlines()
process_code = code
script_errors = sum("SCRIPT ERROR:" in line for line in lines)
if code == 0 and script_errors: code = 1
receipt = {"command": command, "process_exit_code": process_code, "script_errors": script_errors, "exit_code": code, "elapsed_seconds": time.monotonic()-started,
           "owned_pid": process.pid, "private_profile": str(profile)}
(OUT / (label + "-command.json")).write_text(json.dumps(receipt, indent=2), encoding="utf-8")
lines = (OUT / (label + ".log")).read_text(encoding="utf-8", errors="replace").splitlines()
print(label, "exit", code)
print("\n".join(lines[-15:]))
sys.exit(code)
