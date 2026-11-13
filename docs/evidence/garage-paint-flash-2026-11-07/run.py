"""Isolated offline checks with the pinned engine and retained receipts."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "build/garage-paint-flash-20261107"
parser = argparse.ArgumentParser()
parser.add_argument("name")
parser.add_argument("script")
parser.add_argument("--renderer", choices=["headless", "gl_compatibility", "mobile"], default="headless")
args, extra = parser.parse_known_args()
run = OUT / args.name
run.mkdir(parents=True, exist_ok=False)
profile = run / "profile"
profile.mkdir()
env = os.environ.copy()
env.update(APPDATA=str(profile), LOCALAPPDATA=str(profile / "local"),
           BMT_API_URL="", BMT_DEV_AUTH_KEY="",
           BMT_LOADING_OUTPUT=str(run / "result.json"),
           BMT_GRAPHICS_EVIDENCE=str(run))
engine = r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe"
command = [sys.executable, str(ROOT / "scripts/run_no_crash_dialog.py"), "--", engine,
           "--path", str(ROOT / "game"), "--audio-driver", "Dummy",
           "--position", "10000,10000", "--script", args.script]
if args.renderer == "headless":
    command += ["--headless"]
else:
    command += ["--rendering-method", args.renderer, "--rendering-driver",
                "opengl3" if args.renderer == "gl_compatibility" else "vulkan"]
command += ["--", "--evidence-root=" + str(run), *extra]
sources = [ROOT / path for path in ["game/core/app.gd", "game/ui/header_car_appearance_cache.gd",
           "game/ui/car_showroom.gd", "game/ui/garage_page.gd", "game/ui/garage_preloader.gd",
           args.script.replace("res://", "game/")]]
def hashes():
    return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sources}
before = hashes()
started = time.monotonic()
with (run / "console.log").open("w", encoding="utf-8") as log:
    try:
        code = subprocess.run(command, env=env, cwd=ROOT, stdout=log,
                              stderr=subprocess.STDOUT, timeout=190).returncode
    except subprocess.TimeoutExpired:
        code = "timeout"
after = hashes()
receipt = dict(command=command, exit_code=code, seconds=round(time.monotonic()-started, 3),
               sources_before=before, sources_after=after,
               source_changes=[p for p in before if before[p] != after[p]])
(run / "command.json").write_text(json.dumps(receipt, indent=2)+"\n", encoding="utf-8")
print(json.dumps({k: v for k, v in receipt.items() if not k.startswith("sources_")}))
print("\n".join((run / "console.log").read_text(encoding="utf-8").splitlines()[-30:]))
sys.exit(0 if code == 0 and not receipt["source_changes"] else 1)
