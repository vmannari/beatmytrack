"""Pinned dev entry point, private profile, crash-dialog suppression and logs."""
import argparse
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).parent
parser = argparse.ArgumentParser()
parser.add_argument("--mode", choices=["headless", "gl_compatibility", "mobile"], default="headless")
parser.add_argument("--test", default="test_super_wash_animation")
parser.add_argument("--direct", action="store_true", help="Pinned engine fallback when the dev entry point cannot open its user log")
parser.add_argument("--motion", action="store_true")
args = parser.parse_args()
profile = ROOT / "tmp/super-wash-animation-profile"
profile.mkdir(parents=True, exist_ok=True)
env = os.environ.copy()
env.update(APPDATA=str(profile), LOCALAPPDATA=str(profile), BMT_API_URL="", BMT_SUPER_WASH_OUTPUT=str(HERE))
if args.motion:
    env["BMT_SUPER_WASH_MOTION"] = "1"
command = [sys.executable, str(ROOT / "scripts/run_no_crash_dialog.py"), "--", "powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(ROOT / "scripts/dev.ps1"), "-Action", "TestScript", "-ScriptPath", f"res://tests/{args.test}.gd", "-CommandTimeoutSeconds", "240"]
if args.mode != "headless":
    command += ["-Graphical", "-RenderingMethod", args.mode]
if args.direct:
    command = [sys.executable, str(ROOT / "scripts/run_no_crash_dialog.py"), "--", env.get("GODOT_BIN", r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe"), "--path", str(ROOT / "game"), "--log-file", str(HERE / f"engine-{args.test}-{args.mode}.log"), "--script", f"res://tests/{args.test}.gd"]
    command += ["--headless"] if args.mode == "headless" else ["--rendering-method", args.mode]
log = HERE / f"{args.test}-{args.mode}{'-direct' if args.direct else ''}{'-motion' if args.motion else ''}.log"
with log.open("w", encoding="utf-8") as stream:
    result = subprocess.run(command, cwd=ROOT, env=env, stdout=stream, stderr=subprocess.STDOUT, timeout=280, creationflags=subprocess.CREATE_NO_WINDOW)
lines = log.read_text(encoding="utf-8").splitlines()
print(f"{args.test} / {args.mode}: exit {result.returncode}")
print("\n".join(lines[-24:]))
raise SystemExit(result.returncode)
