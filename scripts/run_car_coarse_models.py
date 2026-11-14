"""Pinned, isolated offline engine runner for CCG01-CCG04."""
from __future__ import annotations
import ctypes
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/car-coarse-models-2026-11-14"
WORK = ROOT / "build/car-coarse-models-2026-11-14"


def run(label: str, script: str, *options: str) -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    for name in ("roaming", "local"):
        (WORK / name).mkdir(parents=True, exist_ok=True)
    environment = dict(os.environ, APPDATA=str(WORK / "roaming"),
                       LOCALAPPDATA=str(WORK / "local"), BMT_API_URL="", BMT_DEV_AUTH_KEY="")
    engine = "C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64.exe"
    assert subprocess.check_output([engine, "--version"], text=True).strip() == (ROOT / "godot-version.txt").read_text().strip()
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.SetErrorMode(kernel.GetErrorMode() | 0x0002)
    command = [engine, "--path", str(ROOT / "game"), "--audio-driver", "Dummy",
               "--position", "10000,10000", "--script", script, *options]
    started = time.monotonic()
    path = OUT / f"{label}.log"
    reason = None
    with path.open("w", encoding="utf-8") as log:
        child = subprocess.Popen(command, cwd=ROOT, env=environment, stdout=log, stderr=subprocess.STDOUT)
        while child.poll() is None:
            time.sleep(0.25)
            content = path.read_text(encoding="utf-8", errors="replace")
            if "SCRIPT ERROR:" in content or "Assertion failed:" in content or time.monotonic()-started > 1200:
                reason = "script/assertion failure or 1200s timeout"
                child.kill()
                break
        code = child.wait()
    content = path.read_text(encoding="utf-8", errors="replace")
    errors = [line for line in content.splitlines() if line.startswith(("ERROR:", "SCRIPT ERROR:"))
              and line != "ERROR: Failed to read the root certificate store."]
    receipt = {"command": command, "exit_code": code, "seconds": round(time.monotonic()-started, 3),
               "errors": errors, "stop_reason": reason}
    (OUT / f"{label}-receipt.json").write_text(json.dumps(receipt, indent=2)+"\n")
    print(json.dumps(receipt), flush=True)
    print("\n".join(content.splitlines()[-12:]), flush=True)
    return int(code != 0 or bool(errors))


if __name__ == "__main__":
    raise SystemExit(run(*sys.argv[1:]))
