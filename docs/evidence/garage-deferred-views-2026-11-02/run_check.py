"""Run one isolated offline check with scoped crash suppression and timeout."""
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
args, extra = parser.parse_known_args()
evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
profile = root / "build/garage-deferred-views-20261102" / (args.label + "-" + str(time.time_ns()))
profile.mkdir(parents=True)
output = evidence / args.label
output.mkdir(exist_ok=True)
env = os.environ.copy()
env.update(APPDATA=str(profile), BMT_API_URL="", BMT_GARAGE_DEFERRED_EVIDENCE=str(output))
command = [sys.executable, str(root / "scripts/run_no_crash_dialog.py"), "--",
           "C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe", "--path", str(root / "game"),
           "--audio-driver", "Dummy", "--rendering-method", args.renderer,
           *(["--headless"] if args.headless else []), "--script", args.script,
           "--", "--output=" + str(output), *extra]
paths = ["game/core/app.gd", "game/core/build_identity.gd", "game/ui/garage_page.gd",
         "game/ui/garage_preloader.gd", "game/ui/garage_preview_cache.gd",
         "game/ui/garage_cached_thumbnail.gd", "game/ui/garage_opening_showroom.gd",
         "game/ui/garage_loading_car.gd", "game/ui/garage_loading_car.gdshader", args.script.replace("res://", "game/")]
def hashes():
    return {path: hashlib.sha256((root / path).read_bytes()).hexdigest() for path in paths}
receipt = dict(command=command, profile=str(profile), before=hashes())
began = time.monotonic()
with (evidence / (args.label + ".log")).open("w", encoding="utf-8") as log:
    process = subprocess.Popen(command, cwd=root, env=env, stdout=log, stderr=subprocess.STDOUT)
    (evidence / (args.label + "-running.json")).write_text(json.dumps(dict(pid=process.pid, **receipt), indent=2))
    try:
        receipt["exit_code"] = process.wait(timeout=300)
    except subprocess.TimeoutExpired:
        subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"], capture_output=True, check=False)
        receipt["exit_code"] = 124
        try:
            process.wait(timeout=20)
        except subprocess.TimeoutExpired:
            receipt["cleanup_failed"] = True
receipt.update(elapsed_seconds=time.monotonic()-began, after=hashes())
receipt["changed_sources"] = [path for path in paths if receipt["before"][path] != receipt["after"][path]]
(evidence / (args.label + "-receipt.json")).write_text(json.dumps(receipt, indent=2)+"\n")
print(json.dumps({key: receipt[key] for key in ("exit_code", "elapsed_seconds", "changed_sources")}))
sys.exit(receipt["exit_code"])
