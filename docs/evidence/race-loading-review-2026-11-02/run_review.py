"""Bounded isolated offline desktop review; run from the repository root."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

root = Path(__file__).resolve().parents[3]
evidence = Path(__file__).resolve().parent
renderer = sys.argv[1] if len(sys.argv) > 1 else "gl_compatibility"
assert renderer in ("gl_compatibility", "mobile")
label = "compat" if renderer == "gl_compatibility" else "mobile"
profile = root / "build" / "race-loading-review-20261102" / (label + "-" + str(time.time_ns()))
profile.mkdir(parents=True)
env = os.environ.copy()
env.update(APPDATA=str(profile), BMT_API_URL="", BMT_LOADING_OUTPUT=str(evidence / (label + ".json")))
command = [sys.executable, str(root / "scripts/run_no_crash_dialog.py"), "--",
           "C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe", "--path", str(root / "game"),
           "--audio-driver", "Dummy", "--rendering-method", renderer,
           "--script", "res://tests/review_race_loading_2026_11_02.gd", *sys.argv[2:]]
paths = ["game/core/app.gd", "game/core/game.gd", "game/track/native_track_visual.gd",
         "game/race/world_render_preparation.gd", "game/vehicle/effect_render_preparation.gd",
         "game/race/selected_track_preparation.gd", "game/race/race_ground_preparation.gd",
         "game/tests/review_race_loading_2026_11_02.gd"]
def hashes():
    return {p: hashlib.sha256((root / p).read_bytes()).hexdigest() for p in paths}
receipt = dict(command=command, profile=str(profile), before=hashes())
began = time.monotonic()
with (evidence / (label + ".log")).open("w", encoding="utf-8") as log:
    process = subprocess.Popen(command, env=env, cwd=root, stdout=log, stderr=subprocess.STDOUT)
    try:
        receipt["exit_code"] = process.wait(timeout=360)
    except subprocess.TimeoutExpired:
        # Only the process tree created above, never another Godot session.
        subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"], capture_output=True, check=False)
        process.wait(timeout=20)
        receipt["exit_code"] = 124
receipt.update(elapsed_seconds=time.monotonic()-began, after=hashes())
(evidence / (label + "-receipt.json")).write_text(json.dumps(receipt, indent=2), encoding="utf-8")
print(json.dumps({k: receipt[k] for k in ("exit_code", "elapsed_seconds", "profile")}))
sys.exit(receipt["exit_code"])
