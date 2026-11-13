import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import shutil

ROOT = Path(__file__).resolve().parents[2]
WORK = Path(__file__).resolve().parent
p = argparse.ArgumentParser()
p.add_argument("label")
p.add_argument("script")
p.add_argument("--renderer", default="headless")
p.add_argument("--timeout", type=int, default=600)
p.add_argument("--entry", action="store_true")
p.add_argument("--check", action="store_true")
p.add_argument("--pipeline", action="store_true")
p.add_argument("--cache-profile", default="")
p.add_argument("--project-root", default="")
p.add_argument("arguments", nargs="*")
args, extra = p.parse_known_args()
args.arguments += [argument for argument in extra if argument != "--"]
profile = WORK / "profile" / args.label
for folder in (profile / "roaming/Circuit01Lab", profile / "local"):
    folder.mkdir(parents=True, exist_ok=True)
(profile / "roaming/Circuit01Lab/backend.cfg").write_bytes(b'[backend]\nurl=""\n')
if args.cache_profile:
    assert all(c.isalnum() or c in "-_" for c in args.cache_profile)
    for name in ("shader_cache", "vulkan"):
        cache = WORK / "profile" / args.cache_profile / "roaming/Circuit01Lab" / name
        if cache.exists():
            shutil.copytree(cache, profile / "roaming/Circuit01Lab" / name, dirs_exist_ok=True)
env = dict(os.environ, APPDATA=str(profile / "roaming"), LOCALAPPDATA=str(profile / "local"), BMT_API_URL="")
wrapper = [sys.executable, str(ROOT / "scripts/run_no_crash_dialog.py"), "--"]
godot = "C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe"
if args.pipeline:
    command = wrapper + [sys.executable, str(ROOT / "scripts/prepare_car_assets.py"), "--output", str(WORK / args.label)] + args.arguments
elif args.entry:
    command = wrapper + ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(ROOT / "scripts/dev.ps1"), "-Action", "TestScript", "-ScriptPath", args.script, "-CommandTimeoutSeconds", str(args.timeout)]
    if args.arguments:
        command += ["-TestArgument", ",".join(args.arguments)]
else:
    project_root = Path(args.project_root).resolve() if args.project_root else ROOT
    command = wrapper + [godot, "--path", str(project_root / "game"), "--audio-driver", "Dummy", "--log-file", str(WORK / (args.label + "-godot.log"))]
    if args.renderer == "headless":
        command += ["--headless"]
    else:
        command += ["--rendering-method", args.renderer, "--position", "10000,10000"]
    command += (["--check-only"] if args.check else []) + ["--script", args.script, "--"] + args.arguments
started = time.monotonic()
with (WORK / (args.label + ".log")).open("w", encoding="utf-8") as log:
    process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
    print(json.dumps({"label": args.label, "owned_pid": process.pid, "command": command}), flush=True)
    try:
        code = process.wait(timeout=args.timeout)
    except subprocess.TimeoutExpired:
        subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"], capture_output=True)
        process.wait(timeout=30)
        code = 124
receipt = {"label": args.label, "command": command, "owned_pid": process.pid, "exit_code": code, "seconds": time.monotonic()-started}
(WORK / (args.label + "-receipt.json")).write_bytes((json.dumps(receipt, indent=2)+"\n").encode())
print(json.dumps(receipt), flush=True)
print((WORK / (args.label + ".log")).read_text(encoding="utf-8", errors="replace")[-5000:])
sys.exit(code)
