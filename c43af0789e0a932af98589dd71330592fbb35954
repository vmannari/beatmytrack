"""Offline pinned-engine checks with raw logs and a disposable application data root."""
from pathlib import Path
import json
import hashlib
import os
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
ENGINE = Path(r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe")
environment = os.environ.copy()
environment["BMT_API_URL"] = ""
environment["APPDATA"] = str(ROOT / "tmp" / "jump-validation-appdata")
Path(environment["APPDATA"]).mkdir(parents=True, exist_ok=True)
results = []
sources = [path.relative_to(OUT / "before") for path in (OUT / "before").rglob("*") if path.is_file()]
sources += [Path(name) for name in ("game/editor/jump_profiles.gd", "game/editor/jump_style_picker.gd", "game/track/jump_visual.gd", "game/track/jump_earth.gdshader", "game/tests/test_editor_jump_styles.gd", "game/tests/test_jump_profiles_worker.gd")]
def hashes():
    return {str(path).replace("\\", "/"): hashlib.sha256((ROOT / path).read_bytes()).hexdigest() for path in sources}
mode = sys.argv[1] if len(sys.argv) > 1 else "focused"
cases = {
    "focused": [("focused-headless", "test_editor_jump_styles.gd", "headless")],
    "native": [("focused-compatibility", "test_editor_jump_styles.gd", "gl_compatibility"),
               ("focused-mobile", "test_editor_jump_styles.gd", "mobile")],
    "compatibility": [("diagnostic-compatibility", "test_editor_jump_styles.gd", "gl_compatibility")],
    "baseline": [("baseline-speed-bump-width", "test_speed_bump_width.gd", "headless")],
    "final-parser": [("final-parser", "test_script_parse.gd", "headless")],
    "worker": [("staged-worker", "test_jump_profiles_worker.gd", "headless")],
    "regression": [("parser", "test_script_parse.gd", "headless"),
                   ("hazards", "test_hazards.gd", "headless"),
                   ("speed-bump-width", "test_speed_bump_width.gd", "headless"),
                   ("app", "test_app.gd", "headless")],
}[mode]
for name, script, renderer in cases:
    project = ROOT / "tmp/jump-styles-task-start/game" if mode == "baseline" else ROOT / "game"
    if mode == "worker": project = ROOT / "tmp/jump-profiles-worker/game"
    command = [str(ENGINE), "--path", str(project), "--log-file", str(OUT / f"{name}-engine.log")]
    if renderer == "headless":
        command += ["--headless"]
    else:
        command += ["--rendering-method", renderer, "--rendering-driver", "opengl3" if renderer == "gl_compatibility" else "vulkan"]
    command += ["--script", "res://tests/" + script]
    print("RUN", name, flush=True)
    before_hashes = hashes()
    try:
        process = subprocess.run(command, cwd=ROOT, env=environment, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=240)
        output = process.stdout.decode("utf-8", "replace")
        (OUT / f"{name}.log").write_text(output, encoding="utf-8")
        summary = [line for line in output.splitlines() if any(word in line for word in ("TESTS:", "SCRIPT_PARSE:", "EDITOR_JUMP_STYLES:", "SPEED_BUMP_WIDTH:", "JUMP_WORKER:", "FAIL:", "TEST_USER_DATA="))]
        item = {"name": name, "command": command, "exit": process.returncode, "summary": summary,
                "script_error": "SCRIPT ERROR" in output, "certificate_error": "root certificate store" in output}
    except subprocess.TimeoutExpired as error:
        output = (error.stdout or b"").decode("utf-8", "replace")
        (OUT / f"{name}.log").write_text(output, encoding="utf-8")
        item = {"name": name, "command": command, "timeout": True}
    results.append(item)
    item["source_hashes_before"] = before_hashes
    item["source_hashes_after"] = hashes()
    print(json.dumps({key: value for key, value in item.items() if not key.startswith("source_hashes")}), flush=True)
    (OUT / f"commands-{mode}.json").write_text(json.dumps(results, indent=2), encoding="utf-8")
sys.exit(1 if any(item.get("exit", 1) != 0 or item.get("script_error", False) for item in results) else 0)
