"""VKR02: actual Volt-only cache rebuild, preserving unrelated consumers."""
import json,sys
from concurrent.futures import ThreadPoolExecutor
import run_volt_kit_review
from run_volt_kit_review import ROOT,OUT
import refresh_car_10k_assets as refresh
refresh.IDS=('electric',)
refresh.prior.IDS=('electric',)
def main():
    before=refresh.sources()
    (OUT/'refresh-inputs.json').write_text(json.dumps(before,indent=2)+'\n',encoding='utf-8')
    first=refresh.identity('identity-before')
    refresh.checked('bases','res://tests/bake_modular_car_bases.gd','--headless','--','--vehicle=electric')
    jobspec=[(quality,'body',shard,4) for quality in ('full','simple') for shard in range(4)]
    jobspec += [(quality,category,0,1) for quality in ('full','simple') for category in ('hood','aero','rims')]
    with ThreadPoolExecutor(max_workers=4) as executor:
        jobs=[executor.submit(refresh.checked,'kits-'+quality+'-'+category+'-'+str(shard),'res://tests/bake_volt_smooth_kits.gd','--headless','--','--vehicle=electric','--quality='+quality,'--category='+category,'--shard='+str(shard),'--shards='+str(shards)) for quality,category,shard,shards in jobspec]
        for job in jobs:job.result()
    refresh.checked('garage','res://tests/bake_garage_cars.gd','--headless','--','--vehicle=electric')
    after=refresh.sources();changed=sorted(k for k in before.keys()|after.keys() if before.get(k)!=after.get(k))
    (OUT/'refresh-fence.json').write_text(json.dumps(dict(inputs=len(before),changed=changed),indent=2)+'\n',encoding='utf-8')
    assert not changed,changed
    final=refresh.identity('identity-after')
    assert first['modular_car_sha256']['electric']==final['modular_car_sha256']['electric']
    refresh.checked('prepared-preflight','res://tests/check_volt_hood_outline_prepared.gd','--headless')
    print('VOLT_KIT_REFRESH complete')
if __name__=='__main__':main()
