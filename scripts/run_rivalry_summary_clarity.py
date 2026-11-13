"""Pinned, offline UI checks with workspace profiles and retained receipts.

Use after dev.ps1, whose strict stderr gate rejects this machine's existing
Windows certificate-store diagnostic. Only that exact diagnostic is exempted.
"""
from pathlib import Path
import json
import os
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
ENGINE = Path(r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe")


def main():
    name, script, *arguments = sys.argv[1:]
    version = subprocess.check_output([str(ENGINE), "--version"], text=True).strip()
    assert version == (ROOT / "godot-version.txt").read_text().strip(), version
    evidence = ROOT / "docs/evidence/rivalry-summary-clarity-2026-11-09"
    evidence.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    for key in ("APPDATA", "LOCALAPPDATA"):
        folder = ROOT / "build/rivalry-summary-clarity" / name / key.lower()
        folder.mkdir(parents=True, exist_ok=True)
        env[key] = str(folder)
    env["BMT_API_URL"] = ""
    command = [sys.executable, "scripts/run_no_crash_dialog.py", "--", str(ENGINE),
               "--path", "game", "--audio-driver", "Dummy", "--position", "20000,20000",
               "--script", script, *arguments]
    started = time.monotonic()
    with (evidence / f"{name}.log").open("w", encoding="utf-8") as log:
        log.write(subprocess.list2cmdline(command) + "\n")
        log.flush()
        process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=log,
                                   stderr=subprocess.STDOUT)
        try:
            status = process.wait(timeout=300)
        except subprocess.TimeoutExpired:
            subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                           stdout=log, stderr=subprocess.STDOUT)
            status = 124
        log.write(f"\nEXIT_STATUS {status}\n")
    content = (evidence / f"{name}.log").read_text(encoding="utf-8")
    errors = [line for line in content.splitlines() if
              ("SCRIPT ERROR:" in line or "ERROR:" in line) and
              "Failed to read the root certificate store" not in line]
    (evidence / f"{name}.json").write_text(json.dumps({
        "command": command, "engine": version, "owned_pid": process.pid,
        "exit_status": status, "seconds": round(time.monotonic()-started, 2),
        "errors": errors}, indent=2)+"\n", encoding="utf-8")
    print(content[-10000:])
    return status or bool(errors)


if __name__ == "__main__":
    sys.exit(main())
