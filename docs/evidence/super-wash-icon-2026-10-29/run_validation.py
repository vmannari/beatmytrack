"""Run the retained wash regression with isolated local storage and new captures."""
import argparse
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).parent

parser = argparse.ArgumentParser()
parser.add_argument("--mode", choices=["headless", "gl_compatibility", "mobile"], default="headless")
parser.add_argument("--test", default="test_super_wash")
parser.add_argument("--inspect", action="store_true")
args = parser.parse_args()
profile = ROOT / "tmp/super-wash-layout-profile"
profile.mkdir(parents=True, exist_ok=True)
environment = os.environ.copy()
environment.update(APPDATA=str(profile), LOCALAPPDATA=str(profile), BMT_API_URL="", BMT_SUPER_WASH_OUTPUT=str(HERE))
script = "res://../docs/evidence/super-wash-icon-2026-10-29/inspect.gd" if args.inspect else "res://tests/"+args.test+".gd"
command = [environment.get("GODOT_BIN", r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe"),
           "--path", str(ROOT / "game"), "--script", script]
command += ["--headless"] if args.mode == "headless" else ["--rendering-method", args.mode]
log = HERE / ("images-check.log" if args.inspect else args.test+"-"+args.mode+".log")
with log.open("w", encoding="utf-8") as stream:
    result = subprocess.run(command, cwd=ROOT, env=environment, stdout=stream, stderr=subprocess.STDOUT,
                            creationflags=subprocess.CREATE_NO_WINDOW, timeout=240)
lines = log.read_text(encoding="utf-8").splitlines()
print(f"{args.test} / {args.mode}: exit {result.returncode}; {sum('ERROR:' in line for line in lines)} error lines")
print("\n".join(lines[-12:]))
raise SystemExit(result.returncode)
