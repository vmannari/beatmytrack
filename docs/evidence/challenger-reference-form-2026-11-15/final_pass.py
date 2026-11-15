"""Ordered final publication, dependent rebuild and receiving-app verification."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import json,subprocess,sys
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
TAG=OUT.name;BASE='res://../docs/evidence/'+TAG+'/'
def call(label,command,allow_failure=False):
    print('FINAL_PASS',label,flush=True)
    result=subprocess.run(command,cwd=ROOT,timeout=900)
    if not allow_failure:assert result.returncode==0,label
    return result.returncode
def check(label,script,*args,allow_failure=False):
    return call(label,[sys.executable,str(OUT/'run_check.py'),label,script,'--headless','--audio-driver','Dummy',*args],allow_failure)
blender=str(ROOT/'build/tools/blender-4.5.15-windows-x64/blender.exe')
def geometry(label,script,*args,allow_failure=False):
    return call(label,[blender,'--background','--factory-startup','--disable-autoexec','--python-exit-code','1','--python',str(OUT/script),'--',*args],allow_failure)
check('native-final','res://tests/bake_challenger_hellcat.gd','--','--source=res://../build/'+TAG+'/converted/','--dest=res://../build/'+TAG+'/native/')
check('native-export',BASE+'export_meshes.gd','--','--root=res://../build/'+TAG+'/native/','--output=res://../build/'+TAG+'/candidate.json')
geometry('native-quality','check_form.py','native-quality-final','candidate.json')
geometry('legacy-side-diagnostic','trace_side_checks.py','native-side-diagnostic','candidate.json',allow_failure=True)
legacy=json.loads((OUT/'native-side-diagnostic.json').read_text())
assert len(legacy['failed'])==8 and not any('normal' in failure or 'support' in failure or 'outward' in failure for failure in legacy['failed'])
check('allocation-final',BASE+'allocation.gd')
check('contours-candidate-final',BASE+'contours_candidate.gd')
call('publish',[sys.executable,str(OUT/'publish.py')])
check('coarse-final-bake',BASE+'bake_coarse.gd','--','--vehicle=super_rally')
call('livery',[sys.executable,str(OUT/'run_check.py'),'livery-final','res://tests/bake_livery_previews.gd','--rendering-method','gl_compatibility','--audio-driver','Dummy','--','--vehicle=super_rally'])
call('prepared-assets',[sys.executable,str(OUT/'guarded_assets.py')])
call('imports',[sys.executable,str(OUT/'import_images.py')])
jobs=[('fitted-hood','res://tests/test_super_rally_c3_kits.gd',[]),
      ('modules','res://tests/test_modular_car_assets.gd',['--','--vehicle=super_rally','--all-kits']),
      ('physics','res://tests/test_super_rally.gd',['--','--prepared']),
      ('wash','res://tests/test_car_wash.gd',[]),
      ('driving','res://tests/test_driving.gd',[]),
      ('live-contours','res://tests/test_panel_contours.gd',[]),
      ('production-parse','res://../docs/evidence/super-rally-design-2026-11-08/production_parse.gd',[])]
with ThreadPoolExecutor(max_workers=3) as pool:
    futures=[pool.submit(check,label,script,*args) for label,script,args in jobs]
    for future in futures:future.result()
check('prepared-complete-current','res://tests/check_prepared_assets.gd',allow_failure=True)
full=(OUT/'prepared-complete-current.log').read_text()
assert not any('super_rally' in line for line in full.splitlines() if line.startswith('PREPARED_ASSET_FAIL'))
call('scope',[sys.executable,str(OUT/'finalise_assets.py')])
call('desktop-views-and-app',[sys.executable,str(OUT/'gpu_checks.py')])
print('REFERENCE_FORM_FINAL_PASS_COMPLETE',flush=True)
