"""CME05: qualify current four-car sources and actual prepared consumers."""
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import sys
import run_car_mechanics
from run_car_mechanics import ROOT, OUT, run
import refresh_car_10k_assets as refresh

IDS=('compact','kart','forklift','hovercraft')
refresh.prior.IDS=IDS
def sources():
    result=refresh.sources()
    name='game/tests/support/car_refinement_lods.gd'
    result[name]=hashlib.sha256((ROOT/name).read_bytes()).hexdigest()
    return result
def checked(label,script,*args):
    assert run(label,script,*args)==0,label
def main():
    before=sources()
    (OUT/'qualification-inputs.json').write_text(json.dumps(before,indent=2)+'\n')
    with ThreadPoolExecutor(max_workers=3) as executor:
        jobs=[executor.submit(checked,'modules-current-'+car,'res://tests/test_modular_car_assets.gd',*(['--rendering-method','gl_compatibility'] if car=='forklift' else ['--headless']),'--','--vehicle='+car,'--all-kits') for car in IDS]
        for job in jobs:job.result()
    checked('prepared-current','res://tests/check_prepared_assets.gd','--headless','--','--exclude-vehicle=super_rally','--exclude-vehicle=electric')
    for renderer in ('gl_compatibility','mobile'):
        checked('native-final-'+renderer,'res://tests/capture_car_mechanics.gd','--rendering-method',renderer,'--','--decorated')
        checked('steering-final-'+renderer,'res://tests/test_car_mechanics_steering.gd','--rendering-method',renderer,'--','--prepared')
    after=sources();changed=[k for k in before.keys()|after.keys() if before.get(k)!=after.get(k)]
    (OUT/'qualification-fence.json').write_text(json.dumps(dict(inputs=len(before),changed=changed),indent=2)+'\n')
    assert not changed,changed
    print('MECHANICS_QUALIFICATION',len(before),'stable current inputs')
if __name__=='__main__':main()
