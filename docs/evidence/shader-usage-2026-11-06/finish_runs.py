"""Serial native validation; keep GPU experiments isolated from one another."""
import json,subprocess,sys
from pathlib import Path
p=Path(__file__).resolve().parent
commands=[]
def run(*args):
    command=[sys.executable,*map(str,args)];r=subprocess.run(command,capture_output=True,text=True)
    commands.append({'command':command,'exit_code':r.returncode,'output':r.stdout+r.stderr})
    (p/'final-runs.json').write_text(json.dumps(commands,indent=2)+'\n')
    assert r.returncode==0,r.stdout+r.stderr
    print(r.stdout,flush=True)
run(p/'analyze.py','themes-accounted')
run(p/'run_check.py','pine-lap','res://tests/profile_usage_lap.gd','--frozen','--native','--timeout','180','--first-emission','--theme=pine')
run(p/'analyze.py','pine-lap')
