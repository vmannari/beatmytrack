"""Reproduce a retained regression with task-original shared client sources."""
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
project = ROOT / "build/world-ranking-native-original-control"
script = sys.argv[1] if len(sys.argv)>1 else "test_rivalry_track_detail"
assert script in ("test_rivalry_track_detail","test_resume_recovery_budget")
assert project.is_dir() and project.parent == ROOT / "build"
(project / ".godot").mkdir(exist_ok=True)
if not (project / ".godot/imported").exists():
    shutil.copytree(ROOT / "game/.godot/imported",project / ".godot/imported",copy_function=os.link)
for name in ("global_script_class_cache.cfg","uid_cache.bin","extension_list.cfg"):
    if (ROOT / "game/.godot" / name).is_file():
        shutil.copy2(ROOT / "game/.godot" / name,project / ".godot" / name)
environment = dict(os.environ,APPDATA=str(ROOT / "build/world-ranking-native-user"))
startup = subprocess.STARTUPINFO()
startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
startup.wShowWindow = 0
result = subprocess.run(["C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe",
    "--headless","--path",str(project),"--log-file",str(OUT / ("original-"+script+".log")),
    "--script","res://tests/"+script+".gd"],env=environment,startupinfo=startup,
    capture_output=True,text=True,encoding="utf-8",errors="replace",timeout=120)
(OUT / ("original-"+script+"-process.log")).write_text(result.stdout+result.stderr,encoding="utf-8")
print(result.stdout+result.stderr)
print(json.dumps({"exit_code":result.returncode,"control":"task-original shared client files, current unchanged assets"}))
raise SystemExit(result.returncode)
