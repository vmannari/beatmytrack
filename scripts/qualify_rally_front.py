"""RFL03: serial native appearance, night-lens, App and icon checks."""
import os
import json
import run_rally_front
import run_car_coarse_models as runner
from run_rally_front import OUT,WORK
import refresh_car_10k_assets as refresh

for renderer in ('gl_compatibility','mobile'):
    refresh.checked('native-'+renderer,'res://tests/capture_rally_front.gd','--rendering-method',renderer)
    refresh.checked('night-'+renderer,'res://tests/capture_rally_front.gd','--rendering-method',renderer,'--','--night')
    receipt=OUT/('app-'+renderer+'-receipt.json')
    previous=json.loads(receipt.read_text()) if receipt.exists() else {}
    if not previous or previous['exit_code']!=0 or previous['errors']:
        refresh.checked('app-'+renderer,'res://tests/test_rally_front_app.gd','--rendering-method',renderer)
    icons=OUT/('icons-'+renderer);icons.mkdir(parents=True,exist_ok=True)
    os.environ['BMT_RIVALRY_CARS_EVIDENCE_DIR']=str(icons)
    receipt=OUT/('icons-'+renderer+'-receipt.json')
    previous=json.loads(receipt.read_text()) if receipt.exists() else {}
    if not previous or previous['exit_code']!=0 or previous['errors']:
        runner.OUT=OUT;runner.WORK=WORK/('icons-'+renderer)
        if runner.run('icons-'+renderer,'res://tests/test_car_10k_icons.gd','--rendering-method',renderer):raise RuntimeError('Fresh-profile icon consumer failed')
print('RALLY_FRONT_NATIVE day/night, actual App and icon consumers pass both desktop renderers',flush=True)
