"""Refresh affected stock pictures and derived selection artwork, then imports."""
import json
import subprocess
import sys
import run_car_mechanics
from run_car_mechanics import ROOT, OUT
import refresh_car_10k_assets as refresh
IDS=('compact','kart','forklift','hovercraft')
refresh.prior.IDS=IDS
refresh.checked('garage-pictures','res://../scripts/bake_garage_previews.gd','--rendering-method','gl_compatibility','--','--exclude-vehicle=super_rally','--exclude-vehicle=electric')
with (OUT/'catalogue-check.log').open('w',encoding='utf-8') as log:
    subprocess.run([sys.executable,'scripts/check_garage_previews.py','--vehicles='+','.join(IDS)],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
for car in IDS:
    (OUT/('header-'+car)).mkdir(parents=True,exist_ok=True)
    refresh.checked('header-picture-'+car,'res://tests/bake_header_car_thumbnails.gd','--rendering-method','gl_compatibility','--','--vehicle='+car,'--evidence-root=res://../docs/evidence/car-mechanics-2026-11-17/header-'+car)
refresh.checked('selection-portraits','res://tests/bake_garage_selection_portraits.gd','--rendering-method','gl_compatibility')
with (OUT/'selection-portraits-check.log').open('w',encoding='utf-8') as log:
    subprocess.run([sys.executable,'scripts/check_garage_selection_pictures.py'],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
subprocess.run([sys.executable,'scripts/import_car_mechanics_images.py'],cwd=ROOT,check=True)
final=refresh.identity('identity-final')
previous=json.loads((OUT/'identity-after.json').read_text())
assert all(final['modular_car_sha256'][car]==previous['modular_car_sha256'][car] for car in IDS)
refresh.checked('prepared-final','res://tests/check_prepared_assets.gd','--headless','--','--exclude-vehicle=super_rally','--exclude-vehicle=electric')
print('MECHANICS_ARTWORK current four-car pictures, imports and exact keys')
