"""Non-production audit harness: isolated local tests and source inventory."""
from pathlib import Path
import argparse, hashlib, json, os, subprocess, time

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
GODOT = Path(r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe")
PYTHON = ROOT / ".tools/backend-venv/Scripts/python.exe"

def inventory():
    files = []
    for folder in ("game", "backend", "native", "scripts"):
        for path in (ROOT / folder).rglob("*"):
            if not path.is_file() or any(x in path.parts for x in (".godot", "__pycache__", "build", ".pytest_cache", ".ruff_cache")):
                continue
            if path.suffix not in (".gd", ".py", ".java", ".cpp", ".h", ".hpp", ".gdshader", ".ps1", ".cfg", ".godot", ".gradle", ".xml", ".toml", ".lock", ".yml", ".yaml", ".gdextension"):
                continue
            content = path.read_bytes()
            files.append({"path": path.relative_to(ROOT).as_posix(), "bytes": len(content), "lines": len(content.splitlines()), "sha256": hashlib.sha256(content).hexdigest()})
    (OUT / "source-inventory.json").write_text(json.dumps(files, indent=2), encoding="utf-8")
    baseline = subprocess.run(["git", "status", "--porcelain=v1"], cwd=ROOT, capture_output=True, text=True, check=True).stdout
    (OUT / "git-status-before.txt").write_text(baseline, encoding="utf-8")
    print("Inventory:", len(files), "source/config files")

def run(name, args, cwd, timeout=240):
    env = os.environ.copy()
    # Every engine command gets its own profile; never open the owner's saves.
    profile = OUT / "profiles" / name
    profile.mkdir(parents=True, exist_ok=True)
    env["APPDATA"] = str(profile)
    env["LOCALAPPDATA"] = str(profile / "local")
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    env["PYTHONPATH"] = os.pathsep.join([str(ROOT / "backend"), str(ROOT)])
    env["BMT_API_URL"] = ""
    env["BMT_DEV_AUTH_KEY"] = ""
    env["BMT_STORE_EVIDENCE_DIR"] = str(OUT / "store-captures")
    env["BMT_GODOT_BIN"] = str(GODOT)
    env["BMT_GAME_PROJECT"] = str(ROOT / "game")
    env["TEMP"] = str(OUT / "tmp")
    env["TMP"] = env["TEMP"]
    Path(env["TEMP"]).mkdir(exist_ok=True)
    started = time.monotonic()
    with (OUT / (name + ".log")).open("w", encoding="utf-8") as log:
        try:
            result = subprocess.run([str(x) for x in args], cwd=cwd, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=timeout)
            code = result.returncode
        except subprocess.TimeoutExpired:
            code = "timeout"
    record = {"name": name, "command": [str(x) for x in args], "cwd": str(cwd), "seconds": round(time.monotonic()-started,3), "exit_code": code}
    (OUT / (name + ".json")).write_text(json.dumps(record, indent=2), encoding="utf-8")
    print(json.dumps(record), flush=True)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("mode")
    opts = parser.parse_args()
    if opts.mode == "inventory":
        inventory()
    elif opts.mode == "backend":
        run("backend-full", [PYTHON,"-m","pytest","-q","-m","not postgres and not godot","--basetemp",OUT/"pytest-tmp-full","--junitxml",OUT/"backend-junit.xml","-o","cache_dir="+str(OUT/"pytest-cache")], ROOT/"backend", 1800)
    elif opts.mode == "backend-sqlite":
        run("backend-sqlite", [PYTHON,"-m","pytest","-q","-m","not postgres and not godot","-k","not postgres","--maxfail=20","--basetemp",OUT/"pytest-tmp-sqlite","--junitxml",OUT/"backend-sqlite-junit.xml","-o","cache_dir="+str(OUT/"pytest-cache-sqlite")], ROOT/"backend",1800)
    elif opts.mode == "client":
        tests = ["test_script_parse","test_startup_smoke","test_driving","test_handling","test_checkpoint_rules","test_rewind","test_records","test_review_reliability","test_creator","test_editor_workflow","test_track_lifecycle","test_app","test_store","test_challenges","test_localization","test_translations","test_appearance_sync","test_slot_gifts","test_race_menu_label_fit","test_mobile_controls","test_control_layout","test_track_of_day"]
        for test in tests:
            if not (ROOT / "game/tests" / (test+".gd")).exists():
                print("ABSENT", test, flush=True)
                continue
            run(test,[GODOT,"--headless","--path",ROOT/"game","--script","res://tests/"+test+".gd"],ROOT,180)
    elif opts.mode == "lint":
        run("ruff",[PYTHON,"-m","ruff","check","bmt_backend","tests","--output-format","concise","--no-cache"], ROOT/"backend",120)
