"""CP203: refresh six active cache consumers, without Challenger authoring."""
from concurrent.futures import ThreadPoolExecutor
import json,sys
import run_car_pass12
from run_car_pass12 import OUT
import refresh_car_10k_assets as refresh
IDS=('compact','kart','forklift','electric','hovercraft')
refresh.IDS=IDS
refresh.prior.IDS=IDS
def main():
    before=json.loads((OUT/'refresh-inputs.json').read_text()) if '--finish' in sys.argv else refresh.sources()
    if '--finish' not in sys.argv:(OUT/'refresh-inputs.json').write_text(json.dumps(before,indent=2)+'\n')
    first=json.loads((OUT/'identity-before.json').read_text()) if '--finish' in sys.argv else refresh.identity('identity-before')
    if '--finish' not in sys.argv:
        for car in IDS:
            options=['--rendering-method','gl_compatibility'] if car=='forklift' else ['--headless']
            refresh.checked('bases-'+car,'res://tests/bake_modular_car_bases.gd',*options,'--','--vehicle='+car)
        with ThreadPoolExecutor(max_workers=3) as executor:
            jobs=[executor.submit(refresh.checked,'kits-'+car,'res://tests/bake_modular_car_kits.gd',*(['--rendering-method','gl_compatibility'] if car=='forklift' else ['--headless']),'--','--vehicle='+car) for car in IDS]
            for job in jobs:job.result()
    for car in IDS:refresh.checked('garage-'+car,'res://tests/bake_garage_cars.gd','--headless','--','--vehicle='+car)
    refresh.checked('header','res://tests/bake_header_simple_compact.gd','--headless')
    after=refresh.sources();changed=sorted(k for k in before.keys()|after.keys() if before.get(k)!=after.get(k))
    (OUT/'refresh-fence.json').write_text(json.dumps(dict(inputs=len(before),changed=changed),indent=2)+'\n')
    assert not changed,changed
    final=refresh.identity('identity-after')
    assert all(first['modular_car_sha256'][car]==final['modular_car_sha256'][car] for car in IDS)
    refresh.checked('prepared-preflight','res://tests/check_prepared_assets.gd','--headless','--','--exclude-vehicle=super_rally')
    print('CP2_REFRESH all six active cache consumers and source/key fences pass')
if __name__=='__main__':main()
