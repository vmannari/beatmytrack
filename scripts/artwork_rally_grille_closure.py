"""VHO03: refresh Volt's actual packaged pictures and native imports."""
import json,subprocess,sys
import run_rally_grille_closure
from run_rally_grille_closure import ROOT,OUT
import refresh_car_10k_assets as refresh
refresh.prior.IDS=('compact',)
refresh.checked('garage-picture','res://../scripts/bake_garage_previews.gd','--rendering-method','gl_compatibility','--',*['--exclude-vehicle='+car for car in ('electric','kart','forklift','hovercraft','super_rally')])
with (OUT/'catalogue-check.log').open('w',encoding='utf-8') as log:
    subprocess.run([sys.executable,'scripts/check_garage_previews.py','--vehicles=compact'],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
refresh.checked('header-picture','res://tests/bake_header_car_thumbnails.gd','--rendering-method','gl_compatibility','--','--vehicle=compact','--evidence-root=res://../docs/evidence/rally-grille-closure-2026-11-16')
refresh.checked('selection-portraits','res://tests/bake_garage_selection_portraits.gd','--rendering-method','gl_compatibility')
with (OUT/'selection-portraits-check.log').open('w',encoding='utf-8') as log:
    subprocess.run([sys.executable,'scripts/check_garage_selection_pictures.py'],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
subprocess.run([sys.executable,'scripts/import_rally_grille_closure_images.py'],cwd=ROOT,check=True)
final=refresh.identity('identity-final')
previous=json.loads((OUT/'identity-after.json').read_text())
assert final['modular_car_sha256']['compact']==previous['modular_car_sha256']['compact']
refresh.checked('prepared-final','res://tests/check_rally_grille_closure_prepared.gd','--headless')
print('VOLT_CORNER_ARTWORK packaged pictures/imports and live identity pass')
