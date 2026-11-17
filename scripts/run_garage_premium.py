"""Isolated Garage integration checks; does not use the owner's profile."""
from pathlib import Path
import json
import os
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/evidence/garage-premium-2026-11-16'
ENGINE=Path('C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe')
mode=sys.argv[1] if len(sys.argv)>1 else 'headless'
assert mode in ['headless','gl_compatibility','mobile','parse','standard']
script='res://tests/check_model_refinement_parse.gd' if mode=='parse' else 'res://tests/test_garage_paint_list.gd' if mode=='standard' else 'res://tests/test_garage_premium_liveries.gd'
command=[str(ENGINE),'--path',str(ROOT/'game'),'--audio-driver','Dummy','--script',script]
command+=['--headless'] if mode in ['headless','parse','standard'] else ['--rendering-method',mode]
extra=sys.argv[2:]
if extra: command+=['--']+extra
env=dict(os.environ,APPDATA=str(ROOT/'build'/('garage-premium-'+mode+'-profile')),BMT_API_URL='')
OUT.mkdir(parents=True,exist_ok=True)
with (OUT/(mode+'.log')).open('w',encoding='utf-8') as log:
    result=subprocess.run(command,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=600)
content=(OUT/(mode+'.log')).read_text(encoding='utf-8',errors='replace')
failed=result.returncode!=0 or 'SCRIPT ERROR:' in content or '\nERROR:' in content
(OUT/(mode+'-command.json')).write_text(json.dumps({'command':command,'exit_code':result.returncode,'log_errors':failed,'owner_profile_used':False},indent=2)+'\n',encoding='utf-8')
print(content[-4000:])
sys.exit(1 if failed else 0)
