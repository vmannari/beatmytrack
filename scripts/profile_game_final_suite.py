"""Queue final cache-matched observations after the preliminary probes finish."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/game-profile-2026-11-12"
deadline = time.monotonic() + 1200
while True:
    try:
        ready = len(json.loads((OUT / "followup-suite.json").read_text())) == 6
    except (FileNotFoundError, json.JSONDecodeError):
        ready = False
    if ready:
        break
    if time.monotonic() > deadline:
        raise SystemExit("Earlier sequential suite did not finish")
    time.sleep(2)
print("BEGIN final asset copy", flush=True)
subprocess.run([sys.executable, str(ROOT / "scripts/freeze_game_profile_assets.py")], check=True)
for name in ("profile_overview_driving.gd", "profile_overview_assets.gd"):
    shutil.copy2(ROOT / "game/tests" / name, ROOT / "build/game-profile-2026-11-12/snapshot/game/tests" / name)
jobs = [
    ("assets-qualified", "res://tests/profile_overview_assets.gd", "gl_compatibility", ["--headless"]),
    ("menus-gl-final", "res://tests/profile_loading_half.gd", "gl_compatibility", []),
    ("menus-mobile-final", "res://tests/profile_loading_half.gd", "mobile", []),
    ("races-gl-final", "res://tests/profile_races_half.gd", "gl_compatibility", ["--", "--themes=pine,desert,winter", "--cycles=2"]),
    ("races-mobile-final", "res://tests/profile_races_half.gd", "mobile", ["--", "--themes=pine,desert,winter", "--cycles=2"]),
    ("editor-mobile-final", "res://tests/profile_overview_editor.gd", "mobile", []),
    ("driving-mobile-qualified", "res://tests/profile_overview_driving.gd", "mobile", ["--", "--cases=compact:pine,compact:winter,kart:pine"]),
]
results = []
for name, script, renderer, extra in jobs:
    print("BEGIN " + name, flush=True)
    code = subprocess.run([sys.executable, str(ROOT / "scripts/profile_game_overview.py"), name, script, "--renderer", renderer, *extra], cwd=ROOT).returncode
    if code == 126:
        raise SystemExit("Owned failed probe needs process cleanup before continuing")
    results.append(dict(name=name, runner_exit_code=code))
    (OUT / "final-suite.json").write_text(json.dumps(results, indent=2))
    print("END " + name + " " + str(code), flush=True)
subprocess.run([sys.executable, str(ROOT / "scripts/summarize_game_profile.py")], check=True)
