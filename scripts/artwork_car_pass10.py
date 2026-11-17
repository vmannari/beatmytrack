"""CP303: current native pictures, source hashes, imports and receiving keys."""
import json,subprocess,sys
import run_car_pass10
from run_car_pass10 import ROOT,OUT
import refresh_car_10k_assets as refresh
refresh.prior.IDS=('compact','kart','forklift','electric','hovercraft')
refresh.checked('garage-pictures','res://../scripts/bake_garage_previews.gd','--rendering-method','gl_compatibility','--','--exclude-vehicle=super_rally')
with (OUT/'catalogue-check.log').open('w',encoding='utf-8') as log:
    subprocess.run([sys.executable,'scripts/check_garage_previews.py','--vehicles=compact,kart,forklift,electric,hovercraft'],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
refresh.checked('header-pictures','res://tests/bake_header_car_thumbnails.gd','--rendering-method','gl_compatibility','--','--exclude-vehicle=super_rally','--evidence-root=res://../docs/evidence/car-pass10-2026-11-16')
refresh.checked('selection-portraits','res://tests/bake_garage_selection_portraits.gd','--rendering-method','gl_compatibility')
with (OUT/'selection-portraits-check.log').open('w',encoding='utf-8') as log:
    subprocess.run([sys.executable,'scripts/check_garage_selection_pictures.py'],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
subprocess.run([sys.executable,'scripts/import_car_pass10_images.py'],cwd=ROOT,check=True)
final=refresh.identity('identity-final')
previous=json.loads((OUT/'identity-after.json').read_text())
assert all(final['modular_car_sha256'][car]==previous['modular_car_sha256'][car] for car in refresh.prior.IDS)
refresh.checked('prepared-final','res://tests/check_prepared_assets.gd','--headless','--','--exclude-vehicle=super_rally')
print('CP3_ARTWORK actual pictures, imports and final keys pass')
