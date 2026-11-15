"""RFL03: scoped catalogue/header refresh and imported image verification."""
import json
import subprocess
import sys
import run_car_step10
from run_car_step10 import ROOT,OUT
import refresh_car_10k_assets as refresh
refresh.checked('garage-pictures','res://../scripts/bake_garage_previews.gd','--rendering-method','gl_compatibility','--','--exclude-vehicle=super_rally')
with (OUT/'catalogue-check.log').open('w') as log:
    subprocess.run([sys.executable,'scripts/check_garage_previews.py','--vehicles=compact,kart,forklift,electric,hovercraft'],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
refresh.checked('header-picture','res://tests/bake_header_car_thumbnails.gd','--rendering-method','gl_compatibility','--','--exclude-vehicle=super_rally','--evidence-root=res://../docs/evidence/car-step10-2026-11-15')
subprocess.run([sys.executable,'scripts/import_car_step10_images.py'],cwd=ROOT,check=True)
final=refresh.identity('identity-final')
previous=json.loads((OUT/'identity-after.json').read_text())
assert all(final['modular_car_sha256'][car]==previous['modular_car_sha256'][car] for car in ('compact','kart','forklift','electric','hovercraft'))
refresh.checked('prepared-final','res://tests/check_prepared_assets.gd','--headless','--','--exclude-vehicle=super_rally')
print('RALLY_FRONT_ARTWORK two catalogue bindings, Rally header, native imports, final keys/preflight pass',flush=True)
