import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parents[2]
WORK=Path(__file__).resolve().parent
OUT=WORK/'asset-repair'
OUT.mkdir(exist_ok=True)
profile=OUT/'profile'
(profile/'roaming/Circuit01Lab').mkdir(parents=True,exist_ok=True)
(profile/'local').mkdir(exist_ok=True)
(profile/'roaming/Circuit01Lab/backend.cfg').write_bytes(b'[backend]\nurl=""\n')
env=dict(os.environ,APPDATA=str(profile/'roaming'),LOCALAPPDATA=str(profile/'local'),BMT_API_URL='')
paths=set(json.loads((WORK/'assets/source-receipt.json').read_text(encoding='utf-8'))['after'])
paths.update('game/ui/'+name+'.gd' for name in ['car_showroom','garage_page','garage_preloader','garage_preview_cache','garage_thumbnail_studio','garage_cleanliness','settings_page'])
def sources():return {rel:hashlib.sha256((ROOT/rel).read_bytes()).hexdigest() for rel in sorted(paths)}
before=sources()
receipts=[]
def run(label,args):
    started=time.monotonic()
    with (OUT/(label+'.log')).open('w',encoding='utf-8') as log:
        result=subprocess.run(args,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=900)
    receipts.append({'label':label,'command':args,'exit_code':result.returncode,'seconds':time.monotonic()-started})
    (OUT/'commands.json').write_bytes((json.dumps(receipts,indent=2)+'\n').encode())
    print(label,result.returncode,flush=True)
    assert result.returncode==0,label
def identity(label):
    command=". ./scripts/build_identity.ps1; Write-ClientBuildIdentity (Get-Location).Path '"+OUT.as_posix().replace("'","''")+"'"
    run(label,[sys.executable,str(ROOT/'scripts/run_no_crash_dialog.py'),'--','powershell','-NoProfile','-ExecutionPolicy','Bypass','-Command',command])
def engine(label,script,*arguments,renderer='headless'):
    args=[sys.executable,str(WORK/'run.py'),label,script,'--renderer',renderer,'--timeout','600']
    if arguments:args+=['--']+list(arguments)
    run(label,args)
identity('identity-before')
engine('repair-bases','res://tests/bake_modular_car_bases.gd','--vehicle=kart')
engine('repair-kits','res://tests/bake_modular_car_kits.gd','--vehicle=kart')
engine('repair-garage','res://tests/bake_garage_cars.gd','--vehicle=kart')
engine('repair-pictures','res://../scripts/bake_garage_previews.gd',renderer='gl_compatibility')
after=sources()
receipt={'before':before,'after':after,'changed':[rel for rel in before if before[rel]!=after[rel]],'scope':'Only pre-existing stale Kart assets rebaked; all native photographs refreshed. Concurrent handling source is read, never edited.'}
(OUT/'source-receipt.json').write_bytes((json.dumps(receipt,indent=2)+'\n').encode())
assert before==after,'Source changed during selected repair'
identity('identity-after')
engine('repair-preflight','res://tests/check_prepared_assets.gd')
run('picture-preflight',[sys.executable,str(ROOT/'scripts/check_garage_previews.py')])
print('GARAGE_SIMPLE_ASSETS verified',flush=True)
