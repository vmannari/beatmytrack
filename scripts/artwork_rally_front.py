"""RFL03: scoped catalogue/header refresh and imported image verification."""
import json
import subprocess
import sys
import run_rally_front
from run_rally_front import ROOT,OUT
import refresh_car_10k_assets as refresh
refresh.checked('garage-pictures','res://../scripts/bake_garage_previews.gd','--rendering-method','gl_compatibility','--',
    *['--exclude-vehicle='+car for car in ('kart','forklift','electric','hovercraft')])
with (OUT/'catalogue-check.log').open('w') as log:
    subprocess.run([sys.executable,'scripts/check_garage_previews.py'],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
refresh.checked('header-picture','res://tests/bake_rally_front_header.gd','--rendering-method','gl_compatibility','--','--evidence-root=res://../docs/evidence/rally-front-2026-11-15')
subprocess.run([sys.executable,'scripts/import_rally_front_images.py'],cwd=ROOT,check=True)
final=refresh.identity('identity-final')
previous=json.loads((OUT/'identity-after.json').read_text())
assert final['modular_car_sha256']==previous['modular_car_sha256']
refresh.checked('prepared-final','res://tests/check_prepared_assets.gd','--headless')
print('RALLY_FRONT_ARTWORK two catalogue bindings, Rally header, native imports, final keys/preflight pass',flush=True)
