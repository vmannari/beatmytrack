"""RFL03: rebuild Rally and any conservative shared-source consumers exactly."""
import hashlib
import json
import run_rally_lamp_style
from run_rally_lamp_style import ROOT,OUT
import refresh_car_10k_assets as refresh

refresh.prior.IDS=('compact','super_rally')
before=refresh.sources()
(OUT/'refresh-inputs.json').write_text(json.dumps(before,indent=2)+'\n')
initial=json.loads((OUT/'initial-car-keys.json').read_text())
first=refresh.identity('identity-before')
changed=[car for car,key in initial.items() if first['modular_car_sha256'][car]!=key]
assert set(changed)=={'compact','super_rally'},changed
(OUT/'consumer-scope.json').write_text(json.dumps(dict(authored_model='compact',rebuilt=changed,
    reason='The existing conservative compact_*.gd dependency rule also covers Challenger. Its model sources are not authored; dependent caches are rebuilt and their master GPU geometry is checked exact.'),indent=2)+'\n')
for car in changed:
    refresh.checked('bases-'+car,'res://tests/bake_modular_car_bases.gd','--headless','--','--vehicle='+car)
    refresh.checked('kits-'+car,'res://tests/bake_modular_car_kits.gd','--headless','--','--vehicle='+car)
    refresh.checked('garage-'+car,'res://tests/bake_garage_cars.gd','--headless','--','--vehicle='+car)
refresh.checked('header','res://tests/bake_header_simple_compact.gd','--headless')
after=refresh.sources();changes=sorted(p for p in before.keys()|after.keys() if before.get(p)!=after.get(p))
(OUT/'refresh-fence.json').write_text(json.dumps(dict(consumed_inputs=len(before),changed=changes),indent=2)+'\n')
assert not changes,changes
last=refresh.identity('identity-after')
assert first['modular_car_sha256']==last['modular_car_sha256']
refresh.checked('prepared-preflight','res://tests/check_prepared_assets.gd','--headless')
print('RALLY_FRONT_REFRESH Rally authored; shared consumer rebuilt with unchanged model source; complete preflight ready',flush=True)
