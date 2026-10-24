"""Own hidden desktop renderer test process; never controls the owner's client."""
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
renderer = sys.argv[1] if len(sys.argv) > 1 else "gl_compatibility"
assert renderer in ("gl_compatibility", "mobile")
environment = dict(os.environ)
dimensions = sys.argv[2] if len(sys.argv)>2 else "1280x800"
assert dimensions in ("1280x800","390x844","430x932")
suffix = renderer if dimensions == "1280x800" else renderer+"-"+dimensions
environment["BMT_WORLD_VIEWPORT"] = dimensions
environment["BMT_WORLD_EVIDENCE"] = str(OUT / ("native-"+suffix+".png"))
startup = subprocess.STARTUPINFO()
startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
startup.wShowWindow = 0
command = ["C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe", "--path", str(ROOT / "game"),
    "--log-file", str(OUT / ("native-"+suffix+".log")), "--rendering-method", renderer,
    "--resolution", dimensions, "--script", "res://tests/test_world_ranking.gd"]
result = subprocess.run(command, cwd=ROOT, env=environment, startupinfo=startup,
    text=True, capture_output=True, encoding="utf-8", errors="replace", timeout=90, check=False)
(OUT / ("native-"+suffix+"-process.log")).write_text(result.stdout+result.stderr,encoding="utf-8")
print(result.stdout+result.stderr)
assert result.returncode == 0
assert "failures=0" in result.stdout
assert (OUT / ("native-"+suffix+".png")).exists()
