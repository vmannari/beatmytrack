"""Isolated offline Volt body-kit checks and native review captures."""
from pathlib import Path
import os
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "docs/evidence/volt-body-refinement-2026-11-03"


def main():
    name, script, *arguments = sys.argv[1:]
    profile = ROOT / "build/volt-body-refinement" / name
    env = os.environ.copy()
    for variable in ("APPDATA", "LOCALAPPDATA"):
        directory = profile / variable.lower()
        directory.mkdir(parents=True, exist_ok=True)
        env[variable] = str(directory)
    env["BMT_API_URL"] = ""
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    command = [sys.executable, "scripts/run_no_crash_dialog.py", "--",
               r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe",
               "--path", "game", "--audio-driver", "Dummy", "--script", script,
               *arguments]
    with (EVIDENCE / (name + ".log")).open("w", encoding="utf-8") as log:
        log.write(subprocess.list2cmdline(command) + "\n")
        log.flush()
        try:
            process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=log,
                                       stderr=subprocess.STDOUT)
            (profile / "process-id.txt").write_text(str(process.pid), encoding="ascii")
            status = process.wait(timeout=900)
        except subprocess.TimeoutExpired:
            subprocess.run(["taskkill.exe", "/PID", str(process.pid), "/T", "/F"],
                           stdout=log, stderr=subprocess.STDOUT, check=False)
            status = 124
            log.write("\nTIMEOUT: not a pass\n")
        log.write(f"\nEXIT_STATUS {status}\n")
    contents = (EVIDENCE / (name + ".log")).read_text(encoding="utf-8")
    errors = [line for line in contents.splitlines() if
              ("ERROR:" in line and "Failed to read the root certificate store" not in line)]
    if status == 0 and errors:
        status = 1
        with (EVIDENCE / (name + ".log")).open("a", encoding="utf-8") as log:
            log.write("RUNNER_REJECTED_ENGINE_ERRORS\n")
    print(contents[-6000:])
    return status


if __name__ == "__main__":
    sys.exit(main())
