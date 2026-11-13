"""Serial same-project App controls and restart hits with one private profile."""
from pathlib import Path
import json
import shutil
import subprocess
import sys

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[3]
info = json.loads((OUT/'candidate.json').read_text())
project = Path(info['project'])
baseline = Path(info['base'])
changed = ['ui/rivalry_victory_car.gd','ui/weekly_rivalry_page.gd','ui/player_profile.gd']
candidate = {name:(project/name).read_bytes() for name in changed}
try:
    for label, mode in [('control-1','control'),('seed-1','candidate'),('hit-1','candidate'),('control-2','control'),('hit-2','candidate')]:
        for name in changed:
            (project/name).write_bytes((baseline/name).read_bytes() if mode == 'control' else candidate[name])
        command = [sys.executable,str(OUT.parent/'run_case.py'),'graphics-app-'+label,
                   'profile_podium_loading_half.gd','--project',str(project),'--native',
                   '--profile','graphics-app-shared-1','--timeout','180','--args','--pages=rivalry']
        print('START '+label,flush=True)
        subprocess.run(command,cwd=ROOT,check=True)
        receipt = json.loads((OUT.parent/('graphics-app-'+label)/'run.json').read_text())
        if receipt['exit_code'] != 0 or receipt['timeout'] or receipt['script_error']:
            raise RuntimeError('Failed arm '+label)
finally:
    for name in changed: (project/name).write_bytes(candidate[name])
