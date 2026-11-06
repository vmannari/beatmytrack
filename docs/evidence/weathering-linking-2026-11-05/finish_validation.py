"""Finish evidence-only visibility and first-lap controls, then restore the owned hook."""
import json,shutil,subprocess,sys
from pathlib import Path
p=Path(__file__).resolve().parent
g=Path(json.loads((p/'frozen-project.json').read_text())['project'])
for name in ('weathering_candidate.gd','review_weathering_candidate.gd'):
    shutil.copyfile(p/'harness'/name,g/'tests'/name)
commands=[]
def run(*args):
    command=[sys.executable,*map(str,args)]
    result=subprocess.run(command,check=False)
    commands.append({'command':command,'exit_code':result.returncode})
    assert result.returncode==0,command
try:
    if '--lap-only' not in sys.argv:
        run(p/'run_check.py','rear-pixels-visible','res://tests/review_weathering_candidate.gd','--frozen','--timeout','240')
    run(p/'app_candidate.py','candidate')
    run(p/'run_check.py','candidate-pine-final','res://tests/test_shared_graphics_first_laps.gd','--frozen','--timeout','240','--first-emission','--theme=pine')
finally:
    run(p/'app_candidate.py','before')
    (p/('final-validation-fixed.json' if '--lap-only' in sys.argv else 'final-validation.json')).write_text(json.dumps(commands,indent=2)+'\n')
run(p/'summarize.py')
