"""CP303: refresh six active cache consumers, without Challenger authoring."""
from concurrent.futures import ThreadPoolExecutor
import json,sys
import run_car_mechanics
from run_car_mechanics import OUT
import refresh_car_10k_assets as refresh
IDS=('compact','kart','forklift','hovercraft')
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
            jobs=[executor.submit(refresh.checked,'kits-'+car,'res://tests/bake_modular_car_kits.gd',*(['--rendering-method','gl_compatibility'] if car=='forklift' else ['--headless']),'--','--vehicle='+car) for car in IDS if car!='electric']
            # Existing explicit category/shard baker publishes disjoint files.
            # Rebuild every Volt full/simple module from the actual source.
            specs=[(quality,'body',shard,4) for quality in ('full','simple') for shard in range(4)]
            specs += [(quality,category,0,1) for quality in ('full','simple') for category in ('hood','aero','rims')]
            if 'electric' in IDS:
                jobs += [executor.submit(refresh.checked,'kits-electric-'+quality+'-'+category+'-'+str(shard),'res://tests/bake_volt_smooth_kits.gd','--headless','--','--vehicle=electric','--quality='+quality,'--category='+category,'--shard='+str(shard),'--shards='+str(shards)) for quality,category,shard,shards in specs]
            for job in jobs:job.result()
    for car in IDS:refresh.checked('garage-'+car,'res://tests/bake_garage_cars.gd','--headless','--','--vehicle='+car)
    refresh.checked('header','res://tests/bake_header_simple_compact.gd','--headless')
    before={k:v for k,v in before.items() if refresh.prior.consumed(k) or k=='scripts/prepared_asset_identity.ps1'}
    after=refresh.sources();changed=sorted(k for k in before.keys()|after.keys() if before.get(k)!=after.get(k))
    (OUT/'refresh-fence.json').write_text(json.dumps(dict(inputs=len(before),changed=changed),indent=2)+'\n')
    assert not changed,changed
    final=refresh.identity('identity-after')
    assert all(first['modular_car_sha256'][car]==final['modular_car_sha256'][car] for car in IDS)
    refresh.checked('prepared-preflight','res://tests/check_prepared_assets.gd','--headless','--','--exclude-vehicle=super_rally','--exclude-vehicle=electric')
    print('MECHANICS_REFRESH four scoped cars, consumer and source/key fences pass')
if __name__=='__main__':main()
