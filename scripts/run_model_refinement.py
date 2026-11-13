"""Pinned, bounded offline engine runner for the five-car refinement."""
import ctypes
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/car-model-refinement-2026-11-12"


def main():
    name, script, *options = sys.argv[1:]
    OUT.mkdir(parents=True, exist_ok=True)
    profile = ROOT / "build/car-model-refinement-2026-11-12/profile"
    for folder in [profile / "roaming", profile / "local"]:
        folder.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, APPDATA=str(profile / "roaming"), LOCALAPPDATA=str(profile / "local"),
               BMT_API_URL="", BMT_DEV_AUTH_KEY="")
    engine = Path(r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64.exe")
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.SetErrorMode(kernel.GetErrorMode() | 0x0002)
    command = [str(engine), "--path", str(ROOT / "game"), "--audio-driver", "Dummy",
               "--position", "10000,10000", "--script", script] + options
    started = time.monotonic()
    with (OUT / (name + ".log")).open("w", encoding="utf-8") as log:
        process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
        (OUT / (name + "-process.json")).write_text(json.dumps(dict(pid=process.pid, command=command), indent=2))
        reason = None
        while process.poll() is None:
            time.sleep(0.2)
            content = (OUT / (name + ".log")).read_text(encoding="utf-8", errors="replace")
            if "SCRIPT ERROR:" in content or time.monotonic()-started > 900:
                reason = "script error" if "SCRIPT ERROR:" in content else "900s timeout"
                process.kill()
                break
        code = process.wait()
    content = (OUT / (name + ".log")).read_text(encoding="utf-8", errors="replace")
    errors = [line for line in content.splitlines() if line.startswith(("ERROR:", "SCRIPT ERROR:"))
              and line != "ERROR: Failed to read the root certificate store."]
    receipt = dict(command=command, exit_code=code, stop_reason=reason, errors=errors,
                   seconds=time.monotonic()-started)
    (OUT / (name + "-receipt.json")).write_text(json.dumps(receipt, indent=2))
    print(json.dumps(receipt))
    print("\n".join(content.splitlines()[-8:]))
    return int(code != 0 or bool(errors))


if __name__ == "__main__":
    raise SystemExit(main())
