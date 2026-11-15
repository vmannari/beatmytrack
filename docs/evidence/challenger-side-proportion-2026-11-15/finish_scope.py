"""Close the requested chassis after a dependency-map-only invalidation."""
from pathlib import Path
import subprocess,sys,json,shutil
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent;BUILD=ROOT/'build'/OUT.name
prior=OUT/'rejected-routing-change';prior.mkdir(exist_ok=True)
for name in ['opacity-gl-command.json','opacity-gl.log','current-route-check-command.json','current-route-check.log']:
    p=OUT/name
    if p.exists():shutil.copyfile(p,prior/name)
def call(*args,allow_failure=False):
    result=subprocess.run(args,cwd=ROOT,timeout=900)
    if not allow_failure:assert result.returncode==0,args
    return result.returncode
def check(label,script,*args):
    return call(sys.executable,str(OUT/'run_check.py'),label,script,'--headless','--audio-driver','Dummy',*args)
call(sys.executable,str(OUT/'guarded_current.py'))
call(sys.executable,str(OUT/'run_check.py'),'portraits','res://tests/bake_garage_selection_portraits.gd','--rendering-method','gl_compatibility','--audio-driver','Dummy')
call(sys.executable,str(OUT/'import_images.py'))
check('prepared-scoped','res://tests/check_prepared_assets.gd','--',*['--exclude-vehicle='+id for id in ['compact','kart','forklift','electric','hovercraft']])
call(sys.executable,str(OUT/'gpu_checks.py'))
call(sys.executable,str(OUT/'run_check.py'),'before-final','res://../docs/evidence/'+OUT.name+'/capture.gd','--rendering-method','gl_compatibility','--audio-driver','Dummy','--','--baseline','--stage=before','--owner-only','--white-only')
call(sys.executable,'scripts/check_garage_selection_pictures.py')
call(sys.executable,'scripts/check_garage_workshop.py')
(OUT/'delivery-scope.json').write_text(json.dumps({'challenger_current':True,'complete_preflight_exit_code':1,'actual_rebuild':True,'routing_change_repaired_for_challenger':True},indent=2))
print('CHALLENGER_SCOPE_CLOSED',flush=True)
