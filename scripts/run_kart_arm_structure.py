"""Pinned Godot runner for the offline driver adaptation and native captures.

The standard dev.ps1 entry point kills native tests on the Windows certificate
store diagnostic. This bounded runner retains that diagnostic in the log.
"""
import json
import os
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/kart-driver-arm-structure-2026-11-12"


def main():
    name, script, *options = sys.argv[1:]
    project_root = Path(os.environ.get("BMT_DRIVER_PROJECT_ROOT", str(ROOT))).resolve()
    if not project_root.is_relative_to(ROOT):
        raise ValueError("Driver review project must stay within this workspace")
    OUT.mkdir(parents=True, exist_ok=True)
    profile = ROOT / ("build/kart-driver-arm-structure-2026-11-12/profile" if project_root == ROOT else "build/kart-driver-arm-structure-2026-11-12/profile-frozen")
    for folder in [profile / "roaming", profile / "local"]:
        folder.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, APPDATA=str(profile / "roaming"),
               LOCALAPPDATA=str(profile / "local"), BMT_API_URL="", BMT_DEV_AUTH_KEY="")
    engine = r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe"
    actual = subprocess.check_output([sys.executable, str(ROOT / "scripts/run_no_crash_dialog.py"), "--", engine, "--version"], text=True).strip()
    assert actual == (project_root / "godot-version.txt").read_text().strip(), actual
    command = [sys.executable, str(ROOT / "scripts/run_no_crash_dialog.py"), "--", engine,
               "--path", str(project_root / "game"), "--audio-driver", "Dummy", "--position", "10000,10000"]
    command += (["--editor", "--headless", "--import", "--quit"] if script == "@import"
                else ["--script", script])
    command += options
    started = time.monotonic()
    with (OUT / (name + ".log")).open("w", encoding="utf-8") as log:
        process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=log,
                                   stderr=subprocess.STDOUT)
        (OUT / (name + "-process.json")).write_text(json.dumps({"pid": process.pid, "command": command}), encoding="utf-8")
        try:
            while process.poll() is None:
                time.sleep(0.1)
                output = (OUT / (name + ".log")).read_text(encoding="utf-8", errors="replace")
                if "SCRIPT ERROR:" in output:
                    stopped = subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                                             stdout=log, stderr=subprocess.STDOUT, check=False)
                    if stopped.returncode:
                        # A parse failure may have exited between poll and kill.
                        try:
                            process.wait(timeout=5)
                        except subprocess.TimeoutExpired as error:
                            raise RuntimeError(f"Cannot stop owned failed test PID {process.pid}; explicit process cleanup required") from error
                    break
                if time.monotonic() - started > 900:
                    raise subprocess.TimeoutExpired(command, 900)
            code = process.wait()
        except subprocess.TimeoutExpired:
            # Kill only this runner's owned child tree, including native Godot.
            subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                           stdout=log, stderr=subprocess.STDOUT, check=False)
            code = 124
    lines = (OUT / (name + ".log")).read_text(encoding="utf-8").splitlines()
    errors = [line for line in lines if line.startswith(("ERROR:", "SCRIPT ERROR:"))
              and line != "ERROR: Failed to read the root certificate store."]
    receipt = dict(command=command, exit_code=code, errors=errors,
                   seconds=round(time.monotonic() - started, 3), engine=actual)
    (OUT / (name + ".json")).write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(receipt))
    print("\n".join(lines[-18:]))
    return int(code != 0 or bool(errors))


if __name__ == "__main__":
    sys.exit(main())
