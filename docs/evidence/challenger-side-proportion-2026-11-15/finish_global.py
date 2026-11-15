"""Close shared-helper invalidations after the concurrent source edit settles."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import json,subprocess,sys,shutil
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent;BUILD=ROOT/'build'/OUT.name
source=OUT/'guarded_assets.py'
exec(compile(source.read_text().split('\nbefore = sources()')[0],str(source),'exec'))
EVIDENCE=ROOT/'docs/evidence/challenger-side-proportion-2026-11-15'
prior=EVIDENCE/'rejected-shared-preflight';prior.mkdir(exist_ok=True)
for name in ['prepared-complete.log','prepared-complete-command.json']:
    shutil.copyfile(EVIDENCE/name,prior/name)
before=sources()
identity('identity-shared-before')
engine('bases-shared-current','res://tests/bake_modular_car_bases.gd',['--reuse-validated-lods'])
with ThreadPoolExecutor(max_workers=3) as pool:
    jobs=[pool.submit(engine,'kits-'+car+'-shared-current','res://tests/bake_modular_car_kits.gd',['--vehicle='+car,'--reuse-validated-lods']) for car in ['compact','kart','forklift','electric','hovercraft']]
    for job in jobs:job.result()
engine('garage-shared-current','res://tests/bake_garage_cars.gd',['--reuse-validated-lods'])
engine('header-shared-current','res://tests/bake_header_simple_compact.gd')
engine('pictures-shared-current','res://../scripts/bake_garage_previews.gd',native=True)
after=sources()
(OUT/'shared-source-receipt.json').write_text(json.dumps({'before':before,'after':after,'changed':[p for p in before.keys()|after.keys() if before.get(p)!=after.get(p)]},indent=2))
assert before==after,'Sources changed during final shared-cache repair'
identity('identity-shared-after')
def check(label,script,*args,native=False):
    result=subprocess.run([sys.executable,str(EVIDENCE/'run_check.py'),label,script,*(['--rendering-method','gl_compatibility'] if native else ['--headless']),'--audio-driver','Dummy',*args],cwd=ROOT,timeout=330)
    assert result.returncode==0,label
check('portraits','res://tests/bake_garage_selection_portraits.gd',native=True)
subprocess.run([sys.executable,str(EVIDENCE/'import_images.py')],cwd=ROOT,check=True,timeout=360)
check('prepared-complete','res://tests/check_prepared_assets.gd')
check('prepared-scoped','res://tests/check_prepared_assets.gd','--',*['--exclude-vehicle='+id for id in ['compact','kart','forklift','electric','hovercraft']])
for renderer in ['gl_compatibility','mobile']:
    result=subprocess.run([sys.executable,str(EVIDENCE/'run_check.py'),'app-'+('gl' if renderer=='gl_compatibility' else 'mobile'),'res://tests/test_super_rally_ui.gd','--rendering-method',renderer,'--audio-driver','Dummy','--','--evidence-root=res://../build/'+EVIDENCE.name+'/app'],cwd=ROOT,timeout=330)
    assert result.returncode==0
subprocess.run([sys.executable,'scripts/check_garage_previews.py'],cwd=ROOT,check=True)
subprocess.run([sys.executable,'scripts/check_garage_selection_pictures.py'],cwd=ROOT,check=True)
(EVIDENCE/'delivery-scope.json').write_text(json.dumps({'challenger_current':True,'complete_preflight_exit_code':0,'actual_rebuild':True,'shared_helper_cache_repair':True},indent=2))
print('SHARED_CACHE_REPAIR_COMPLETE',flush=True)
