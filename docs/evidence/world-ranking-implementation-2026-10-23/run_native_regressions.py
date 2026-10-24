"""Pinned, owned headless processes only; no owner window or device control."""
import json
import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
tests = ["test_world_ranking", "test_weekly_rivalry", "test_rivalry_entry",
         "test_rivalry_track_detail", "test_rivalry_results_continue", "test_rivalry_start_failure",
         "test_app", "test_resume_recovery_budget", "test_shared_resume_recovery", "test_achievements"]
results = []
startup = subprocess.STARTUPINFO()
startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
startup.wShowWindow = 0
environment = dict(os.environ)
environment["APPDATA"] = str(ROOT / "build/world-ranking-native-user")
Path(environment["APPDATA"]).mkdir(parents=True,exist_ok=True)
for name in tests:
    script = ROOT / "game/tests" / (name+".gd")
    assert script.is_file(), script
    command = ["C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe", "--headless", "--path", str(ROOT / "game"),
               "--log-file",str(OUT / (name+".log")),"--script","res://tests/"+name+".gd"]
    result = subprocess.run(command,cwd=ROOT,startupinfo=startup,env=environment,capture_output=True,text=True,
                            encoding="utf-8",errors="replace",timeout=180,check=False)
    output = result.stdout+result.stderr
    (OUT / (name+"-process.log")).write_text(output,encoding="utf-8")
    passed = result.returncode == 0 and not any(mark in output for mark in ("SCRIPT ERROR:","Parse Error:","FAIL:","Assertion failed"))
    summary = [line for line in output.splitlines() if any(mark in line.lower() for mark in ("checks", "passed", "failures", "assertions"))][-4:]
    results.append({"test":name,"exit_code":result.returncode,"passed":passed,"summary":summary})
    print(name,result.returncode,passed,summary,flush=True)
(OUT / "native-regressions.json").write_text(json.dumps(results,indent=2))
raise SystemExit(0 if all(r["passed"] for r in results) else 1)
