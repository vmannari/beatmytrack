"""Bounded execution of the project's pinned development entry point."""

import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
EVIDENCE = Path(__file__).resolve().parent


def run():
    results = []
    for action in ("TestMenus", "TestRecords", "TestMenuLoading", "TestCreator", "TestApp"):
        command = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "scripts/dev.ps1", "-Action", action]
        log_path = EVIDENCE / (action + ".log")
        try:
            with log_path.open("wb") as output:
                process = subprocess.Popen(command, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT)
                try:
                    exit_code = process.wait(timeout=90)
                except subprocess.TimeoutExpired:
                    # Stop only the exact process tree created by this probe.
                    subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"], capture_output=True)
                    process.wait(timeout=10)
                    raise
            row = {"action": action, "exit_code": exit_code}
        except subprocess.TimeoutExpired:
            row = {"action": action, "timeout_seconds": 90}
        results.append(row)
        print(json.dumps(row), flush=True)
    (EVIDENCE / "game-checks.json").write_text(json.dumps(results, indent=2) + "\n")


if __name__ == "__main__":
    run()
