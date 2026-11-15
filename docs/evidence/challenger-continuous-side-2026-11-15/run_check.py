"""Offline pinned-engine checks with private saves, bounded processes and receipts."""
import ctypes
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
GODOT = "C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe"
def snapshot():
    files=[]
    for name in ["game/vehicle", "game/ui", "game/core", "game/resources/cars", "game/assets/vehicles/challenger_hellcat_v1"]:
        files += [p for p in (ROOT/name).rglob("*") if p.suffix in [".gd", ".gdshader", ".gdshaderinc", ".json", ".res", ".tres"]]
    files += [ROOT/"game/project.godot",ROOT/"game/tests/bake_challenger_hellcat.gd",ROOT/"scripts/prepare_challenger.py",ROOT/"scripts/challenger_clean_panels.py",ROOT/"scripts/challenger_exterior_geometry.py",ROOT/"scripts/challenger_reference_geometry.py",ROOT/"scripts/challenger_shell_geometry.py"]
    files += [ROOT/"scripts/challenger_side_surface.py"]
    return {p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in files}

label, script, *extra = sys.argv[1:]
source_before=snapshot()
encoded=json.dumps(source_before,sort_keys=True).encode()
source_digest=hashlib.sha256(encoded).hexdigest()
pins=OUT/"input-pins";pins.mkdir(exist_ok=True)
pin=pins/(source_digest+".json")
if not pin.exists():pin.write_bytes(encoded)
index_before=hashlib.sha256((ROOT/".git/index").read_bytes()).hexdigest()
profile = ROOT / "build/challenger-continuous-side-2026-11-15/checks" / label
(profile / "Circuit01Lab").mkdir(parents=True, exist_ok=True)
(profile / "Circuit01Lab/backend.cfg").write_text('[backend]\nurl=""\n', encoding="utf-8")
env = {**os.environ, "APPDATA": str(profile), "LOCALAPPDATA": str(profile / "local"), "BMT_API_URL": "", "BMT_DEV_AUTH_KEY": ""}
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
if label.startswith("native") and any(line.startswith("ERROR:") for line in lines): code = 1
source_after=snapshot()
changed=[p for p in source_before.keys()|source_after.keys() if source_before.get(p)!=source_after.get(p)]
if code==0 and changed:code=1
receipt = {"source_pin_sha256":source_digest,"changed_inputs":changed,"index_sha256_before":index_before,"index_sha256_after":hashlib.sha256((ROOT/".git/index").read_bytes()).hexdigest(),"command": command, "process_exit_code": process_code, "script_errors": script_errors, "exit_code": code, "elapsed_seconds": time.monotonic()-started,
           "owned_pid": process.pid, "private_profile": str(profile)}
(OUT / (label + "-command.json")).write_text(json.dumps(receipt, indent=2), encoding="utf-8")
lines = (OUT / (label + ".log")).read_text(encoding="utf-8", errors="replace").splitlines()
print(label, "exit", code)
print("\n".join(lines[-15:]))
sys.exit(code)
