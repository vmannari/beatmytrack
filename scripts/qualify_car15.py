"""C1503: serial native consumer checks and five-car artwork refresh."""
import json
import os
import subprocess
import sys
import run_car15
import run_car_coarse_models as runner
from run_car15 import ROOT,OUT
import refresh_car_10k_assets as refresh

for renderer in ('gl_compatibility','mobile'):
    icon_directory=OUT/('icons-'+renderer)
    icon_directory.mkdir(parents=True,exist_ok=True)
    os.environ['BMT_RIVALRY_CARS_EVIDENCE_DIR']=str(icon_directory)
    for label,script,options in (
        ('app','res://tests/test_car15_app.gd',[]),
        ('steering','res://tests/test_car15_steering.gd',['--','--prepared']),
        ('icons','res://tests/test_car_10k_icons.gd',[])):
        receipt=OUT/(label+'-'+renderer+'-receipt.json')
        if receipt.exists():
            previous=json.loads(receipt.read_text())
            if previous['exit_code']==0 and not previous['errors']:continue
        if label=='icons':
            runner.OUT=OUT;runner.WORK=run_car15.WORK/('icons-qualification-'+renderer)
            if runner.run(label+'-'+renderer,script,'--rendering-method',renderer,*options):raise RuntimeError('Fresh-profile icon check failed')
        else:
            refresh.checked(label+'-'+renderer,script,'--rendering-method',renderer,*options)
refresh.checked('garage-pictures','res://../scripts/bake_garage_previews.gd','--rendering-method','gl_compatibility','--','--exclude-vehicle=super_rally')
with (OUT/'catalogue-check.log').open('w') as log:
    subprocess.run([sys.executable,'scripts/check_garage_previews.py','--vehicles='+','.join(refresh.IDS)],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
refresh.checked('header-pictures','res://tests/bake_header_car_thumbnails.gd','--rendering-method','gl_compatibility','--','--exclude-vehicle=super_rally','--evidence-root=res://../docs/evidence/car15-2026-11-15')
subprocess.run([sys.executable,'scripts/import_car15_images.py'],cwd=ROOT,check=True)
final=refresh.identity('identity-final')
previous=json.loads((OUT/'identity-after.json').read_text())
assert previous['modular_car_sha256']==final['modular_car_sha256'],'Consumer refresh changed model identities'
initial=json.loads((OUT/'initial-car-keys.json').read_text())
assert all(final['modular_car_sha256'][car]==key for car,key in initial.items() if car not in refresh.IDS),'Unrelated car key changed'
refresh.checked('prepared-final','res://tests/check_prepared_assets.gd','--headless','--','--exclude-vehicle=super_rally')
print('CAR15_QUALIFICATION desktop consumers, five pictures/imports, final keys/preflight pass',flush=True)
