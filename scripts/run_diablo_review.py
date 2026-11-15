"""Run one isolated native art review with the pinned engine and a timeout."""
from pathlib import Path
import json
import os
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'docs/evidence/diablo-liveries-2026-11-15'
ENGINE = Path('C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe')
mode = sys.argv[1] if len(sys.argv)>1 else 'headless'
assert mode in ['headless','gl_compatibility','mobile','parse']
env = dict(os.environ, APPDATA=str(ROOT/'build'/('diablo-livery-'+mode+'-profile')),BMT_API_URL='')
script = 'res://tests/check_model_refinement_parse.gd' if mode=='parse' else 'res://tests/review_diablo_liveries.gd'
command = [str(ENGINE),'--path',str(ROOT/'game'),'--audio-driver','Dummy','--script',script]
if mode in ['headless','parse']: command += ['--headless']
else: command += ['--rendering-method',mode]
extra = sys.argv[2:]
if extra: command += ['--']+extra
tag=mode+('-pilot-'+next((a.split('=',1)[1] for a in extra if a.startswith('--vehicle=')), 'art') if extra else '')
with (OUT/(tag+'.log')).open('w',encoding='utf-8') as log:
    result = subprocess.run(command,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=600)
content=(OUT/(tag+'.log')).read_text(encoding='utf-8',errors='replace')
failed=result.returncode!=0 or 'SCRIPT ERROR:' in content or '\nERROR:' in content
(OUT/(tag+'-command.json')).write_text(json.dumps({'command':command,'exit_code':result.returncode,'log_errors':failed,'owner_profile_used':False},indent=2)+'\n')
print(content[-2400:])
sys.exit(1 if failed else 0)
