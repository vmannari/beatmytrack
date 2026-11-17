"""VHO03: refresh Volt's actual packaged pictures and native imports."""
import json,subprocess,sys
import run_volt_hood_outline
from run_volt_hood_outline import ROOT,OUT
import refresh_car_10k_assets as refresh
refresh.prior.IDS=('electric',)
refresh.checked('garage-picture','res://../scripts/bake_garage_previews.gd','--rendering-method','gl_compatibility','--',*['--exclude-vehicle='+car for car in ('compact','kart','forklift','hovercraft','super_rally')])
with (OUT/'catalogue-check.log').open('w',encoding='utf-8') as log:
    subprocess.run([sys.executable,'scripts/check_garage_previews.py','--vehicles=electric'],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
refresh.checked('header-picture','res://tests/bake_header_car_thumbnails.gd','--rendering-method','gl_compatibility','--','--vehicle=electric','--evidence-root=res://../docs/evidence/volt-hood-outline-2026-11-16')
refresh.checked('selection-portraits','res://tests/bake_garage_selection_portraits.gd','--rendering-method','gl_compatibility')
with (OUT/'selection-portraits-check.log').open('w',encoding='utf-8') as log:
    subprocess.run([sys.executable,'scripts/check_garage_selection_pictures.py'],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
subprocess.run([sys.executable,'scripts/import_volt_hood_outline_images.py'],cwd=ROOT,check=True)
final=refresh.identity('identity-final')
previous=json.loads((OUT/'identity-after.json').read_text())
assert final['modular_car_sha256']['electric']==previous['modular_car_sha256']['electric']
refresh.checked('prepared-final','res://tests/check_volt_hood_outline_prepared.gd','--headless')
print('VOLT_CORNER_ARTWORK packaged pictures/imports and live identity pass')
