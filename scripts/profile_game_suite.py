"""Run GPU measurements sequentially so our own probes never compete."""
from pathlib import Path
import json
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
jobs = [
    ("races-gl", "res://tests/profile_races_half.gd", "gl_compatibility", ["--", "--themes=pine,desert,winter", "--cycles=2"]),
    ("driving-gl", "res://tests/profile_overview_driving.gd", "gl_compatibility", []),
    ("editor-gl", "res://tests/profile_overview_editor.gd", "gl_compatibility", []),
    ("menus-mobile", "res://tests/profile_loading_half.gd", "mobile", []),
    ("races-mobile", "res://tests/profile_races_half.gd", "mobile", ["--", "--themes=pine,desert,winter", "--cycles=2"]),
    ("driving-mobile", "res://tests/profile_overview_driving.gd", "mobile", []),
    ("editor-mobile", "res://tests/profile_overview_editor.gd", "mobile", []),
]
if "--followup" in sys.argv:
    jobs = [
        ("editor-gl-fixed", "res://tests/profile_overview_editor.gd", "gl_compatibility", []),
        ("driving-gl-fixed", "res://tests/profile_overview_driving.gd", "gl_compatibility", []),
        ("navigation-gl", "res://tests/profile_menu_responsiveness.gd", "gl_compatibility", ["--", "--output="+str(ROOT / "docs/evidence/game-profile-2026-11-12/navigation-gl")]),
        ("assets-final", "res://tests/profile_overview_assets.gd", "gl_compatibility", ["--headless"]),
        ("startup-final-cold", "res://tests/profile_startup_shell.gd", "gl_compatibility", ["--profile", "startup-final"]),
        ("startup-final-repeat", "res://tests/profile_startup_shell.gd", "gl_compatibility", ["--profile", "startup-final"]),
    ]
results = []
for name, script, renderer, extra in jobs:
    print("BEGIN " + name, flush=True)
    code = subprocess.run([sys.executable, str(ROOT / "scripts/profile_game_overview.py"), name, script, "--renderer", renderer, *extra], cwd=ROOT).returncode
    if code == 126:
        raise SystemExit("Owned failed probe needs process cleanup before continuing")
    results.append(dict(name=name, runner_exit_code=code))
    (ROOT / "docs/evidence/game-profile-2026-11-12" / ("followup-suite.json" if "--followup" in sys.argv else "suite.json")).write_text(json.dumps(results, indent=2))
    print("END " + name + " " + str(code), flush=True)
