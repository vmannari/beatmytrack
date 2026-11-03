"""Isolated offline measurements; never touch an owner's profile or old evidence."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

p = argparse.ArgumentParser()
p.add_argument("label")
p.add_argument("script")
p.add_argument("--renderer", default="gl_compatibility", choices=["gl_compatibility", "mobile"])
p.add_argument("--profile", default="")
args, extra = p.parse_known_args()
evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
profile = root / "build/game-loading-review-20261102" / (args.profile or args.label)
profile.mkdir(parents=True, exist_ok=True)
env = os.environ.copy()
env.update(APPDATA=str(profile), BMT_API_URL="", BMT_LOADING_OUTPUT=str(evidence / (args.label + ".json")))
command = [sys.executable, str(root / "scripts/run_no_crash_dialog.py"), "--",
           "C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe", "--path", str(root / "game"),
           "--audio-driver", "Dummy", "--rendering-method", args.renderer,
           "--script", args.script, "--", *extra]
paths = ["game/core/app.gd", "game/core/game.gd", "game/core/build_identity.gd", "game/project.godot", "game/ui/garage_preloader.gd",
         "game/ui/garage_preview_cache.gd", "game/ui/header_car_appearance_cache.gd",
         "game/vehicle/effect_render_preparation.gd", "game/vehicle/effect_preparation_pool.gd",
         "game/track/prepared_world_cache.gd", "game/editor/editor_memory.gd",
         "game/race/selected_track_preparation.gd", "game/race/race_ground_preparation.gd",
         "game/track/native_track_visual.gd", "game/race/world_render_preparation.gd",
         args.script.replace("res://", "game/")]
def hashes():
    return {path: hashlib.sha256((root / path).read_bytes()).hexdigest() for path in paths}
receipt = dict(command=command, profile=str(profile), before=hashes())
began = time.monotonic()
with (evidence / (args.label + ".log")).open("w", encoding="utf-8") as log:
    process = subprocess.Popen(command, env=env, cwd=root, stdout=log, stderr=subprocess.STDOUT)
    try:
        receipt["exit_code"] = process.wait(timeout=300)
    except subprocess.TimeoutExpired:
        subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"], capture_output=True, check=False)
        process.wait(timeout=20)
        receipt["exit_code"] = 124
receipt.update(elapsed_seconds=time.monotonic()-began, after=hashes())
receipt["changed_sources"] = [path for path in paths if receipt["before"][path] != receipt["after"][path]]
(evidence / (args.label + "-receipt.json")).write_text(json.dumps(receipt, indent=2), encoding="utf-8")
print(json.dumps({key: receipt[key] for key in ("exit_code", "elapsed_seconds", "changed_sources")}))
sys.exit(receipt["exit_code"])
