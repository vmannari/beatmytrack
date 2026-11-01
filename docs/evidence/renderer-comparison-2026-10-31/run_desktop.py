"""One isolated desktop renderer observation; no owner records or network.

Run separately with gl_compatibility or mobile. A timeout stops only the
wrapper process tree launched by this script. GPU/driver caches are not cleared.
"""
from pathlib import Path
import hashlib
import json
import os
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[3]
EVIDENCE = ROOT / "docs/evidence/renderer-comparison-2026-10-31"
BASE = ROOT / "build/renderer-comparison-2026-10-31"
ENGINE = Path("C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe")


def hashes(result_dir, phase):
    selected = []
    for path in (ROOT / "game").rglob("*"):
        if not path.is_file() or ".godot" in path.parts:
            continue
        if path.suffix in {".gd", ".gdshader", ".gdshaderinc", ".tscn", ".tres", ".godot", ".scn", ".res", ".png", ".import"} or path.name == "star_spline_lap.json":
            selected.append(path)
    digest = hashlib.sha256()
    files = {}
    for path in sorted(selected):
        name = path.relative_to(ROOT).as_posix()
        file_hash = hashlib.sha256(path.read_bytes()).digest()
        files[name] = file_hash.hex()
        digest.update(name.encode("utf-8") + b"\0")
        digest.update(file_hash)
    manifest = result_dir / ("source-" + phase + ".json")
    manifest.write_text(json.dumps(files, indent=2), encoding="utf-8")
    return {"files": len(selected), "sha256": digest.hexdigest(), "manifest": str(manifest)}


def main():
    if len(sys.argv) not in (2, 3) or sys.argv[1] not in ("gl_compatibility", "mobile"):
        raise SystemExit("usage: run_desktop.py gl_compatibility|mobile [label]")
    mode = sys.argv[1]
    label = sys.argv[2] if len(sys.argv) == 3 else ""
    if label and not all(c.isascii() and (c.isalnum() or c in "-_") for c in label):
        raise SystemExit("label must contain only letters, digits, '-' or '_'")
    name = mode + ("-" + label if label else "")
    result_dir = BASE / name
    user_dir = BASE / (name + "-user")
    result_dir.mkdir(parents=True, exist_ok=True)
    user_dir.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env.update(APPDATA=str(user_dir), LOCALAPPDATA=str(user_dir), BMT_API_URL="")
    driver = "opengl3" if mode == "gl_compatibility" else "vulkan"
    command = [sys.executable, str(ROOT / "scripts/run_no_crash_dialog.py"), "--", str(ENGINE),
               "--audio-driver", "Dummy", "--rendering-method", mode, "--rendering-driver", driver,
               "--path", str(ROOT / "game"), "--script", str(EVIDENCE / "desktop_probe.gd"), "--",
               "--output=res://../build/renderer-comparison-2026-10-31/" + name]
    started = time.monotonic()
    summary = {"command": command, "timeout_s": 240, "driver_caches_cleared": False, "source_start": hashes(result_dir, "start")}
    with (result_dir / "process.log").open("wb") as log:
        child = subprocess.Popen(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
        try:
            summary["exit"] = child.wait(timeout=240)
        except subprocess.TimeoutExpired:
            subprocess.run(["taskkill", "/PID", str(child.pid), "/T", "/F"], capture_output=True, check=False)
            child.wait(timeout=15)
            summary["exit"] = "timeout"
    summary["seconds"] = round(time.monotonic()-started, 3)
    summary["source_end"] = hashes(result_dir, "end")
    summary["source_stable"] = summary["source_start"]["sha256"] == summary["source_end"]["sha256"]
    (result_dir / "execution.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps(summary, indent=2))
    print((result_dir / "process.log").read_text(encoding="utf-8", errors="replace")[-6000:])
    return 0 if summary["exit"] == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
