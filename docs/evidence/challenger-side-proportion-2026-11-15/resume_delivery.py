"""Recover the Challenger scope after concurrent shared-source edits."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import json,subprocess,sys,shutil
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
BUILD=ROOT/'build'/OUT.name;BASE='res://../docs/evidence/'+OUT.name+'/'
rejected=OUT/('rejected-current-shared-helper' if (OUT/'rejected-concurrent').exists() else 'rejected-concurrent');rejected.mkdir(exist_ok=True)
for name in ['source-before.json','source-receipt.json','identity-before.json']:
    source=BUILD/'assets'/name
    if source.exists():shutil.copyfile(source,rejected/name)
if (BUILD/'assets/shared-source-receipt.json').exists():shutil.copyfile(BUILD/'assets/shared-source-receipt.json',rejected/'shared-source-receipt.json')
# Keep the already completed all-car attempts in the receipts, then qualify
# only the requested chassis against the current shared helper.
guard=(OUT/'guarded_assets.py').read_text()
guard=guard.replace('engine("bases", "res://tests/bake_modular_car_bases.gd", ["--reuse-validated-lods"])','engine("bases-current", "res://tests/bake_modular_car_bases.gd", ["--vehicle=super_rally","--reuse-validated-lods"])')
guard=guard.replace('for car in ("compact","kart","forklift","electric","hovercraft","super_rally")','for car in ("super_rally",)')
guard=guard.replace('engine("garage", "res://tests/bake_garage_cars.gd", ["--reuse-validated-lods"])','engine("garage-current", "res://tests/bake_garage_cars.gd", ["--vehicle=super_rally","--reuse-validated-lods"])')
(OUT/'guarded_current.py').write_text(guard)
def call(*args,allow_failure=False):
    result=subprocess.run(args,cwd=ROOT,timeout=900)
    if not allow_failure:assert result.returncode==0,args
    return result.returncode
def check(label,script,*args,native=False,allow_failure=False):
    return call(sys.executable,str(OUT/'run_check.py'),label,script,*(['--rendering-method','gl_compatibility'] if native else ['--headless']),'--audio-driver','Dummy',*args,allow_failure=allow_failure)
call(sys.executable,str(OUT/'guarded_current.py'))
check('portraits','res://tests/bake_garage_selection_portraits.gd',native=True)
call(sys.executable,str(OUT/'import_images.py'))
tests=[('fitted-hood','res://tests/test_super_rally_c3_kits.gd',[]),
       ('modules','res://tests/test_modular_car_assets.gd',['--','--vehicle=super_rally','--all-kits']),
       ('physics','res://tests/test_super_rally.gd',['--','--prepared']),
       ('wash','res://tests/test_car_wash.gd',[]),('driving','res://tests/test_driving.gd',[]),
       ('live-contours','res://tests/test_panel_contours.gd',[]),
       ('production-parse','res://../docs/evidence/super-rally-design-2026-11-08/production_parse.gd',[])]
with ThreadPoolExecutor(max_workers=3) as pool:
    jobs=[pool.submit(check,label,script,*args) for label,script,args in tests]
    for job in jobs:job.result()
code=check('prepared-complete','res://tests/check_prepared_assets.gd',allow_failure=True)
if code:
    text=(OUT/'prepared-complete.log').read_text()
    assert not any('super_rally' in line for line in text.splitlines() if line.startswith('PREPARED_ASSET_FAIL')), 'Requested chassis must be current'
check('prepared-scoped','res://tests/check_prepared_assets.gd','--',*['--exclude-vehicle='+id for id in ('compact','kart','forklift','electric','hovercraft')])
call(sys.executable,str(OUT/'gpu_checks.py'))
call(sys.executable,'scripts/check_garage_selection_pictures.py')
call(sys.executable,'scripts/check_garage_workshop.py')
(OUT/'delivery-scope.json').write_text(json.dumps({'challenger_current':True,'complete_preflight_exit_code':code,'actual_rebuild':True},indent=2))
print('CHALLENGER_CURRENT_DELIVERY_COMPLETE',flush=True)
