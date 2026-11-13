"""Pinned native checks, isolated saves, retained logs and source stability receipts."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
SOURCES = ["game/ui/daily_standings.gd", "game/ui/daily_elimination_results.gd", "game/ui/daily_results_standings.gd", "game/ui/track_of_day_page.gd", "game/tests/test_daily_standings_refinement.gd", "game/tests/test_daily_results_design.gd", "game/tests/test_daily_standings.gd"]
def hashes():
    return {name: hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in SOURCES}
env = dict(os.environ, APPDATA=str(ROOT/"build/daily-refinement-final-profile"), LOCALAPPDATA=str(ROOT/"build/daily-refinement-final-profile"), BMT_API_URL="", BMT_DAILY_RESULTS_OUTPUT=str(OUT/"final-results"), BMT_DAILY_REFINEMENT_OUTPUT=str(OUT/"final-underpass"), BMT_DAILY_STANDINGS_OUTPUT=str(OUT/"final-board"))
Path(env["APPDATA"]).mkdir(parents=True, exist_ok=True)
for key in ("BMT_DAILY_RESULTS_OUTPUT", "BMT_DAILY_REFINEMENT_OUTPUT", "BMT_DAILY_STANDINGS_OUTPUT"):
    Path(env[key]).mkdir(parents=True,exist_ok=True)
cases = [("refinement-headless", "test_daily_standings_refinement", "headless"), ("results-headless", "test_daily_results_design", "headless"), ("retained-board-headless", "test_daily_standings", "headless"), ("refinement-compatibility", "test_daily_standings_refinement", "gl_compatibility"), ("results-compatibility", "test_daily_results_design", "gl_compatibility"), ("refinement-mobile", "test_daily_standings_refinement", "mobile")]
if len(sys.argv)>1:
    cases=[case for case in cases if case[0] in sys.argv[1:]]
receipts=[]
for label, script, renderer in cases:
    before=hashes()
    command=[sys.executable,str(ROOT/"scripts/run_no_crash_dialog.py"),"--",r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe","--path",str(ROOT/"game"),"--audio-driver","Dummy","--script",f"res://tests/{script}.gd"]
    command += ["--headless"] if renderer=="headless" else ["--rendering-method",renderer]
    run=subprocess.run(command,cwd=ROOT,env=env,capture_output=True,text=True,encoding="utf-8",errors="replace",timeout=210,check=False)
    (OUT/(label+".log")).write_text(run.stdout+run.stderr,encoding="utf-8")
    receipt={"case":label,"returncode":run.returncode,"stable_sources":before==hashes(),"source_sha256":before,"command":command}
    receipts.append(receipt)
    (OUT/"checks.json").write_text(json.dumps(receipts,indent=2)+"\n",encoding="utf-8")
    print(label,run.returncode,"stable",receipt["stable_sources"],flush=True)
    print(run.stdout+run.stderr,flush=True)
    if run.returncode or not receipt["stable_sources"]:
        raise SystemExit(1)
