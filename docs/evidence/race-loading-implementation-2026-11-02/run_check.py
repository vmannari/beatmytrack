"""Run one bounded isolated offline Godot check, preserving logs/exit codes."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

parser = argparse.ArgumentParser()
parser.add_argument("label")
parser.add_argument("script")
parser.add_argument("--renderer", default="gl_compatibility", choices=["gl_compatibility", "mobile"])
parser.add_argument("--headless", action="store_true")
parser.add_argument("--timeout", type=int, default=360)
parser.add_argument("extra", nargs="*")
args, extra = parser.parse_known_args()
evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
profile = root / "build/race-loading-implementation-20261102" / (args.label + "-" + str(time.time_ns()))
profile.mkdir(parents=True)
offline_config = profile / "Circuit01Lab/backend.cfg"
offline_config.parent.mkdir(parents=True)
offline_config.write_text('[backend]\nurl=""\n', encoding="utf-8")
env = os.environ.copy()
env.update(APPDATA=str(profile), BMT_API_URL="", BMT_LOADING_OUTPUT=str(evidence / (args.label + ".json")),
           BMT_RACE_LOADING_EVIDENCE=str(evidence))
command = [sys.executable, str(root / "scripts/run_no_crash_dialog.py"), "--",
           "C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe", "--path", str(root / "game"),
           "--audio-driver", "Dummy", "--rendering-method", args.renderer,
           *( ["--headless"] if args.headless else []), "--script", args.script]
if args.extra or extra:
    command += ["--", *args.extra, *extra]
paths = ["game/vehicle/effect_render_preparation.gd", "game/vehicle/effect_preparation_pool.gd",
         "game/track/prepared_world_cache.gd", "game/editor/editor_memory.gd",
         "game/race/selected_track_preparation.gd", "game/core/app.gd"]
def hashes():
    return {p: hashlib.sha256((root / p).read_bytes()).hexdigest() for p in paths}
receipt = dict(command=command, profile=str(profile), offline_config=str(offline_config), before=hashes())
began = time.monotonic()
with (evidence / (args.label + ".log")).open("w", encoding="utf-8") as log:
    process = subprocess.Popen(command, env=env, cwd=root, stdout=log, stderr=subprocess.STDOUT)
    receipt["owned_process_id"] = process.pid
    (evidence / (args.label + "-running.json")).write_text(json.dumps(receipt, indent=2), encoding="utf-8")
    try:
        receipt["exit_code"] = process.wait(timeout=args.timeout)
    except subprocess.TimeoutExpired:
        subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"], capture_output=True, check=False)
        process.wait(timeout=20)
        receipt["exit_code"] = 124
receipt.update(elapsed_seconds=time.monotonic()-began, after=hashes())
(evidence / (args.label + "-receipt.json")).write_text(json.dumps(receipt, indent=2), encoding="utf-8")
print(json.dumps({k: receipt[k] for k in ("exit_code", "elapsed_seconds", "profile")}))
sys.exit(receipt["exit_code"])
