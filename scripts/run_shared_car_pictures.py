"""Run shared picture checks with the pinned engine and isolated player storage."""
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/shared-car-pictures-2026-11-15"
name, script = sys.argv[1:3]
folder = OUT / name
folder.mkdir(parents=True, exist_ok=True)
profile = ROOT / "build/shared-car-pictures-2026-11-15" / name
profile.mkdir(parents=True, exist_ok=True)
env = os.environ.copy()
env.update(APPDATA=str(profile), LOCALAPPDATA=str(profile / "local"),
           BMT_API_URL="", BMT_DEV_AUTH_KEY="", BMT_RIVALRY_CARS_EVIDENCE_DIR=str(folder))
renderer = name.partition("-")[0]
command = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
           str(ROOT / "scripts/dev.ps1"), "-Action", "TestScript", "-ScriptPath", script,
           "-CommandTimeoutSeconds", "240", "-TestArgument", f"--evidence-root={folder}"]
if renderer in ("gl_compatibility", "mobile"):
    command += ["-Graphical", "-RenderingMethod", renderer]
if "--direct" in sys.argv[3:]:
    engine = r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe"
    assert subprocess.check_output([engine, "--version"], text=True).strip() == (ROOT / "godot-version.txt").read_text().strip()
    command = [engine, "--path", str(ROOT / "game"), "--audio-driver", "Dummy", "--script", script]
    command += ["--rendering-method", renderer] if renderer in ("gl_compatibility", "mobile") else ["--headless"]
    command += ["--", f"--evidence-root={folder}"]
    command += [argument for argument in sys.argv[3:] if argument != "--direct"]
start = time.monotonic()
with (folder / "run.log").open("w", encoding="utf-8") as log:
    process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
    try:
        code = process.wait(timeout=270)
    except subprocess.TimeoutExpired:
        subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"], stdout=log, stderr=subprocess.STDOUT, check=False)
        process.wait()
        code = "timeout"
receipt = {"command": command, "exit_code": code, "seconds": round(time.monotonic() - start, 3)}
(folder / "command.json").write_text(json.dumps(receipt, indent=2) + "\n")
print(json.dumps(receipt))
print("\n".join((folder / "run.log").read_text(encoding="utf-8").splitlines()[-25:]))
raise SystemExit(0 if code == 0 else 1)
