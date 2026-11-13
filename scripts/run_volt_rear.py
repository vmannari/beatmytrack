"""Offline runner for the pinned engine; dev.ps1 kills on certificate errors."""
from pathlib import Path
import os
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "docs/evidence/volt-rear-smoothing-2026-11-08"


def main():
    name, script, *arguments = sys.argv[1:]
    profile = ROOT / "build/volt-rear-smoothing" / name
    env = os.environ.copy()
    for key in ("APPDATA", "LOCALAPPDATA"):
        folder = profile / key.lower()
        folder.mkdir(parents=True, exist_ok=True)
        env[key] = str(folder)
    env["BMT_API_URL"] = ""
    command = [sys.executable, "scripts/run_no_crash_dialog.py", "--",
               r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe",
               "--path", "game", "--audio-driver", "Dummy", "--script", script,
               *arguments]
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    log_path = EVIDENCE / (name + ".log")
    with log_path.open("w", encoding="utf-8") as log:
        log.write(subprocess.list2cmdline(command) + "\n")
        log.flush()
        process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=log,
                                   stderr=subprocess.STDOUT)
        (profile / "process-id.txt").write_text(str(process.pid), encoding="ascii")
        try:
            status = process.wait(timeout=660)
        except subprocess.TimeoutExpired:
            subprocess.run(["taskkill.exe", "/PID", str(process.pid), "/T", "/F"],
                           stdout=log, stderr=subprocess.STDOUT, check=False)
            status = 124
            log.write("\nTIMEOUT: not a pass\n")
        log.write(f"\nEXIT_STATUS {status}\n")
    content = log_path.read_text(encoding="utf-8")
    print(content[-4500:])
    errors = [line for line in content.splitlines() if
              ("SCRIPT ERROR:" in line or "ERROR:" in line) and
              "Failed to read the root certificate store" not in line]
    return status or bool(errors)


if __name__ == "__main__":
    sys.exit(main())
