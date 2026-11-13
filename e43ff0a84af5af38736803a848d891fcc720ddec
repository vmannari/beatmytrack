"""Reuse byte-exact validated geometry; refresh a Garage presentation-only change."""
from pathlib import Path
import hashlib,json,os,subprocess,sys,time
ROOT=Path(__file__).resolve().parents[3];OUT=ROOT/'build/challenger-refinement-presentation';OUT.mkdir(parents=True,exist_ok=True)
BASE=ROOT/'build/challenger-refinement-assets'
old=json.loads((BASE/'source-receipt.json').read_text(encoding='utf-8'))['after']
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
sources=lambda:{f:sha(ROOT/f) for f in old}
before=sources();changed=[f for f in old if old[f]!=before[f]]
assert changed==['game/ui/car_showroom.gd'],changed
profile=OUT/'private-profile';(profile/'Circuit01Lab').mkdir(parents=True,exist_ok=True)
(profile/'Circuit01Lab/backend.cfg').write_text('[backend]\nurl=""\n',encoding='utf-8')
env={**os.environ,'APPDATA':str(profile),'BMT_API_URL':''}
godot='C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe'
def run(label,command):
    started=time.monotonic()
    with (OUT/(label+'.log')).open('w',encoding='utf-8') as log:
        result=subprocess.run(command,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=300)
    errors=(OUT/(label+'.log')).read_text(encoding='utf-8').count('SCRIPT ERROR:')
    (OUT/(label+'-command.json')).write_text(json.dumps({'command':command,'exit_code':result.returncode,'script_errors':errors,'elapsed_seconds':time.monotonic()-started},indent=2),encoding='utf-8')
    print(label,'exit',result.returncode,flush=True);assert result.returncode==0 and errors==0
def identity(label):
    run(label,['powershell','-NoProfile','-ExecutionPolicy','Bypass','-Command',". ./scripts/build_identity.ps1; Write-ClientBuildIdentity (Get-Location).Path 'build/challenger-refinement-presentation'"])
def engine(label,script,native=False):
    run(label,[sys.executable,str(ROOT/'scripts/run_no_crash_dialog.py'),'--',godot,*([] if native else ['--headless']),'--path',str(ROOT/'game'),'--audio-driver','Dummy','--rendering-method','gl_compatibility','--script',script])
identity('identity-before')
identity_before=json.loads((OUT/'client-build-identity.json').read_text(encoding='utf-8-sig'))
old_identity=json.loads((BASE/'client-build-identity.json').read_text(encoding='utf-8-sig'))
assert identity_before['modular_car_sha256']==old_identity['modular_car_sha256'],'Presentation change must not alter geometry revisions'
engine('prepared-before','res://tests/check_prepared_assets.gd')
engine('artwork','res://tests/bake_super_rally_art.gd',True)
engine('pictures','res://../scripts/bake_garage_previews.gd',True)
after=sources();assert before==after
identity('identity-after')
identity_after=json.loads((OUT/'client-build-identity.json').read_text(encoding='utf-8-sig'))
assert identity_before['modular_car_sha256']==identity_after['modular_car_sha256']
engine('prepared','res://tests/check_prepared_assets.gd')
run('picture-preflight',[sys.executable,'scripts/check_garage_previews.py'])
(OUT/'source-receipt.json').write_text(json.dumps({'before':before,'after':after,'changed':[],'delta_from_geometry_bake':changed,'geometry_revisions_exact':True,'geometry_bake':'build/challenger-refinement-assets'},indent=2),encoding='utf-8')
print('CHALLENGER_PRESENTATION: exact prepared geometry reused; stable source/pictures and both strict preflights pass',flush=True)
