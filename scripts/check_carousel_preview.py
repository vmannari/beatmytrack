"""Private offline regression runner; never touches the owner's desktop saves."""
import json
import hashlib
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "build/carousel-preview-20261107"
OUT.mkdir(parents=True, exist_ok=True)
name, script, *options = sys.argv[1:]
profile = OUT / "profiles" / name
profile.mkdir(parents=True, exist_ok=True)
env = os.environ.copy()
env.update(APPDATA=str(profile), LOCALAPPDATA=str(profile / "local"),
           BMT_API_URL="", BMT_DEV_AUTH_KEY="")
command = [r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe",
           "--path", str(ROOT / "game"), "--audio-driver", "Dummy",
           "--position", "10000,10000", "--script", script, *options]
sources = [ROOT / "game" / path for path in [
    "ui/preview_touch_input.gd", "ui/garage_cached_thumbnail.gd",
    "ui/garage_preview_cache.gd", "ui/garage_preloader.gd",
    "tests/test_preview_touch_consumption.gd", "tests/test_carousel_preview_delivery.gd"]]
def hashes():
    return {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in sources}
before = hashes()
started = time.monotonic()
with (OUT / (name + ".log")).open("w", encoding="utf-8") as log:
    try:
        code = subprocess.run(command, env=env, cwd=ROOT, stdout=log,
                              stderr=subprocess.STDOUT, timeout=180).returncode
    except subprocess.TimeoutExpired:
        code = "timeout"
after = hashes()
result = dict(command=command, exit_code=code, seconds=round(time.monotonic()-started, 3),
              source_sha256=after, source_changes=[p for p in before if before[p] != after[p]])
(OUT / (name + ".json")).write_text(json.dumps(result, indent=2)+"\n", encoding="utf-8")
print(json.dumps({k: v for k, v in result.items() if k != "source_sha256"}), flush=True)
print("\n".join((OUT / (name + ".log")).read_text(encoding="utf-8").splitlines()[-28:]))
sys.exit(0 if code == 0 and not result["source_changes"] else 1)
