"""Run menu header checks through the pinned dev entry point with private storage."""
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
OUT = Path(os.environ.get("BMT_MENU_HEADER_EVIDENCE", ROOT / "docs/evidence/shared-menu-header-2026-11-15"))
name = sys.argv[1] if len(sys.argv) > 1 else "headless"
script = sys.argv[2] if len(sys.argv) > 2 else "res://tests/test_shared_menu_header.gd"
OUT.mkdir(parents=True, exist_ok=True)
profile = ROOT / "build/shared-menu-header-2026-11-15" / name
profile.mkdir(parents=True, exist_ok=True)
env = os.environ.copy()
env.update(APPDATA=str(profile), LOCALAPPDATA=str(profile / "local"),
           BMT_API_URL="", BMT_DEV_AUTH_KEY="")
command = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
           str(ROOT / "scripts/dev.ps1"), "-Action", "TestScript", "-ScriptPath", script,
           "-CommandTimeoutSeconds", "240", "-TestArgument", f"--evidence-root={OUT / name}"]
renderer = name.partition("-")[0]
if renderer in ("gl_compatibility", "mobile"):
    command += ["-Graphical", "-RenderingMethod", renderer]
if "--direct" in sys.argv[3:]:
    engine = r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe"
    version = subprocess.check_output([engine, "--version"], text=True).strip()
    assert version == (ROOT / "godot-version.txt").read_text().strip(), version
    command = [engine, "--path", str(ROOT / "game"), "--audio-driver", "Dummy", "--script", script]
    command += ["--rendering-method", renderer] if renderer in ("gl_compatibility", "mobile") else ["--headless"]
    command += ["--", f"--evidence-root={OUT / name}"]
start = time.monotonic()
with (OUT / f"{name}.log").open("w", encoding="utf-8") as log:
    process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
    try:
        code = process.wait(timeout=270)
    except subprocess.TimeoutExpired:
        subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                       stdout=log, stderr=subprocess.STDOUT, check=False)
        process.wait()
        code = "timeout"
receipt = {"command": command, "exit_code": code,
           "seconds": round(time.monotonic() - start, 3)}
(OUT / f"{name}.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
print(json.dumps(receipt))
print("\n".join((OUT / f"{name}.log").read_text(encoding="utf-8").splitlines()[-18:]))
raise SystemExit(0 if code == 0 else 1)
