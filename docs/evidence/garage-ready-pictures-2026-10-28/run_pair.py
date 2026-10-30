import json
from pathlib import Path
import subprocess
import sys
root=next(p for p in Path(__file__).resolve().parents if (p/'godot-version.txt').exists())
mode,label=sys.argv[1:3]
base=Path(__file__).resolve().parent
profile=root/('build/garage-ready-profile-'+label)
for phase in ['seed','reuse']:
 cmd=[sys.executable,str(base/'run_checks.py'),label+'-'+phase,'test_garage_ready_pictures.gd',mode,'--phase='+phase,'--profile='+str(profile)]
 subprocess.run(cmd,cwd=root,check=True)
print('READY_PAIR_PASS:',label,flush=True)
