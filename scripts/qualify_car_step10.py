"""CST03: retained integration tests and receiving desktop renderers."""
from concurrent.futures import ThreadPoolExecutor
import json,os
import run_car_step10
from run_car_step10 import OUT,WORK
import run_car_coarse_models as runner
import refresh_car_10k_assets as refresh
IDS=('compact','kart','forklift','electric','hovercraft')
def checked(label,script,*options):
    receipt=OUT/(label+'-receipt.json')
    if receipt.exists():
        row=json.loads(receipt.read_text())
        if row['exit_code']==0 and not row['errors']:return
    refresh.checked(label,script,*options)
def main():
    checked('prepared-models-final','res://tests/test_car_step10.gd','--headless','--','--prepared','--exclude-vehicle=super_rally')
    with ThreadPoolExecutor(max_workers=3) as executor:
        jobs=[executor.submit(checked,'modules-'+car,'res://tests/test_modular_car_assets.gd',*(['--rendering-method','gl_compatibility'] if car=='forklift' else ['--headless']),'--','--vehicle='+car,'--all-kits') for car in IDS]
        for job in jobs:job.result()
    for label,script in [('parser','check_model_refinement_parse'),('driving','test_driving'),('old-recipe-guards','test_car15_recipe_guards'),('panel-batch-final','test_car_step10_protected_batch')]:
        checked(label,'res://tests/'+script+'.gd','--headless')
    for renderer in ('gl_compatibility','mobile'):
        checked('native-final-'+renderer,'res://tests/capture_car_step10.gd','--rendering-method',renderer)
        checked('app-final-'+renderer,'res://tests/test_car_step10_app.gd','--rendering-method',renderer)
        checked('steering-final-'+renderer,'res://tests/test_car_step10_steering.gd','--rendering-method',renderer,'--','--prepared')
        icons=OUT/('icons-'+renderer);icons.mkdir(parents=True,exist_ok=True)
        os.environ['BMT_RIVALRY_CARS_EVIDENCE_DIR']=str(icons)
        receipt=OUT/('icons-'+renderer+'-receipt.json')
        row=json.loads(receipt.read_text()) if receipt.exists() else {}
        if not row or row['exit_code'] or row['errors']:
            runner.OUT=OUT;runner.WORK=WORK/('icons-final-qualification-'+renderer)
            assert runner.run('icons-'+renderer,'res://tests/test_car_10k_icons.gd','--rendering-method',renderer)==0
        checked('wash-'+renderer,'res://tests/test_car_10k_wash.gd','--rendering-method',renderer,'--','--evidence-root=res://../docs/evidence/car-step10-2026-11-15')
    print('STEP10_QUALIFICATION complete')
if __name__=='__main__':main()
