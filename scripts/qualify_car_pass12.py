"""CP203: actual prepared sources, all kits and desktop receiving paths."""
from concurrent.futures import ThreadPoolExecutor
import json,os
from run_car_pass12 import OUT,WORK,run
def checked(label,script,*options):
    path=OUT/(label+'-receipt.json')
    if path.exists():
        row=json.loads(path.read_text())
        if row['exit_code']==0 and not row['errors']:return
    assert run(label,script,*options)==0,label
def main():
    with ThreadPoolExecutor(max_workers=3) as executor:
        jobs=[executor.submit(checked,'modules-'+car,'res://tests/test_modular_car_assets.gd',*(['--rendering-method','gl_compatibility'] if car=='forklift' else ['--headless']),'--','--vehicle='+car,'--all-kits') for car in ('compact','kart','forklift','electric','hovercraft')]
        for job in jobs:job.result()
    checked('panel-batch','res://tests/test_car_step10_protected_batch.gd','--headless')
    for renderer in ('gl_compatibility','mobile'):
        checked('native-'+renderer,'res://tests/capture_car_pass12.gd','--rendering-method',renderer,'--','--decorated')
        checked('steering-'+renderer,'res://tests/test_car_pass12_steering.gd','--rendering-method',renderer,'--','--prepared')
        folder=OUT/('icons-'+renderer);folder.mkdir(parents=True,exist_ok=True)
        os.environ['BMT_RIVALRY_CARS_EVIDENCE_DIR']=str(folder)
        checked('icons-'+renderer,'res://tests/test_car_10k_icons.gd','--rendering-method',renderer)
        checked('wash-'+renderer+('-repeat' if renderer=='mobile' else ''),'res://tests/test_car_10k_wash.gd','--rendering-method',renderer,*(['--verbose'] if renderer=='mobile' else []),'--','--evidence-root=res://../docs/evidence/car-pass12-2026-11-16')
    print('CP2_RECEIVERS_PASS')
if __name__=='__main__':main()
