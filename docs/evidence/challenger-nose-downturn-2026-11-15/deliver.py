"""Publish qualified native meshes and rebuild their actual game consumers."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import subprocess
import sys
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
TAG=OUT.name;BASE='res://../docs/evidence/'+TAG+'/'
def call(*args):
    subprocess.run(args,cwd=ROOT,check=True,timeout=900)
def check(label,script,*args,native=False):
    call(sys.executable,str(OUT/'run_check.py'),label,script,*(['--rendering-method','gl_compatibility'] if native else ['--headless']),'--audio-driver','Dummy',*args)
call(sys.executable,str(OUT/'publish.py'))
check('coarse',BASE+'bake_coarse.gd','--','--vehicle=super_rally')
check('livery','res://tests/bake_livery_previews.gd','--','--vehicle=super_rally',native=True)
call(sys.executable,str(OUT/'guarded_assets.py'))
check('portraits','res://tests/bake_garage_selection_portraits.gd',native=True)
call(sys.executable,str(OUT/'import_images.py'))
tests=[('fitted-hood','res://tests/test_super_rally_c3_kits.gd',[]),
       ('modules','res://tests/test_modular_car_assets.gd',['--','--vehicle=super_rally','--all-kits']),
       ('physics','res://tests/test_super_rally.gd',['--','--prepared']),
       ('wash','res://tests/test_car_wash.gd',[]),
       ('driving','res://tests/test_driving.gd',[]),
       ('live-contours','res://tests/test_panel_contours.gd',[]),
       ('production-parse','res://../docs/evidence/super-rally-design-2026-11-08/production_parse.gd',[])]
with ThreadPoolExecutor(max_workers=3) as pool:
    jobs=[pool.submit(check,label,script,*args) for label,script,args in tests]
    for job in jobs:job.result()
check('prepared-complete','res://tests/check_prepared_assets.gd')
call(sys.executable,str(OUT/'gpu_checks.py'))
call(sys.executable,'scripts/check_garage_selection_pictures.py')
print('SURFACE_DELIVERY_COMPLETE',flush=True)
