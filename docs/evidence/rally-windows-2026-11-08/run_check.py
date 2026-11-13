"""Pinned, offline Rally checks with private saves and retained command receipts."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import time

parser = argparse.ArgumentParser()
parser.add_argument("label")
parser.add_argument("script")
parser.add_argument("--native", action="store_true")
parser.add_argument("--renderer", default="gl_compatibility")
args, extra = parser.parse_known_args()
evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
profile = root / "build/rally-windows-20261108" / args.label
(profile / "Circuit01Lab").mkdir(parents=True, exist_ok=True)
(profile / "Circuit01Lab/backend.cfg").write_text('[backend]\nurl=""\n')
env = dict(os.environ, APPDATA=str(profile), LOCALAPPDATA=str(profile), BMT_API_URL="")
engine = "C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe"
wrapper = [sys.executable, str(root / "scripts/run_no_crash_dialog.py"), "--", engine]
assert subprocess.check_output(wrapper + ["--version"], text=True).strip() == (root / "godot-version.txt").read_text().strip()
command = wrapper + ["--path", str(root / "game"), "--audio-driver", "Dummy", "--rendering-method", args.renderer]
if not args.native:
    command += ["--headless"]
command += ["--script", args.script, "--"] + extra
start = time.monotonic()
with (evidence / (args.label + ".log")).open("w", encoding="utf-8") as log:
    process = subprocess.Popen(command, cwd=root, env=env, stdout=log, stderr=subprocess.STDOUT)
    try:
        code = process.wait(timeout=240)
    except subprocess.TimeoutExpired:
        subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"], capture_output=True)
        code = 124
errors = [line for line in (evidence / (args.label + ".log")).read_text(encoding="utf-8", errors="replace").splitlines() if line.startswith(("SCRIPT ERROR:", "SHADER ERROR:"))]
receipt = dict(command=command, exit_code=code, seconds=time.monotonic()-start, script_errors=errors)
(evidence / (args.label + ".json")).write_text(json.dumps(receipt, indent=2))
print(json.dumps(receipt))
sys.exit(code or bool(errors))
