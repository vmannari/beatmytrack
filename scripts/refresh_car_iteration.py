"""CI03: refresh only the Forklift consumers; retain the other five car keys."""
import hashlib
import json
import run_car_iteration
from run_car_iteration import ROOT, WORK, OUT, run
import refresh_car_10k_assets as refresh


def checked(label, script, *options):
    if run(label,script,*options): raise RuntimeError(label+' failed')


def main():
    refresh.prior.IDS=('forklift',)
    before=refresh.sources()
    (OUT/'refresh-inputs.json').write_text(json.dumps(before,indent=2)+'\n')
    first=refresh.identity('identity-before')
    initial=json.loads((OUT/'initial-car-keys.json').read_text())
    assert all(first['modular_car_sha256'][car]==key for car,key in initial.items() if car!='forklift'), 'An unrelated car identity changed'
    checked('bases-forklift','res://tests/bake_modular_car_bases.gd','--headless','--','--vehicle=forklift')
    checked('kits-forklift','res://tests/bake_modular_car_kits.gd','--rendering-method','gl_compatibility','--','--vehicle=forklift')
    checked('garage-forklift','res://tests/bake_garage_cars.gd','--headless','--','--vehicle=forklift')
    after=refresh.sources()
    changed=sorted(p for p in before.keys()|after.keys() if before.get(p)!=after.get(p))
    (OUT/'refresh-fence.json').write_text(json.dumps({'input_count':len(before),'changed_inputs':changed},indent=2)+'\n')
    assert not changed, 'Consumed inputs changed during refresh'
    final=refresh.identity('identity-after')
    assert first['modular_car_sha256']==final['modular_car_sha256']
    checked('prepared-preflight','res://tests/check_prepared_assets.gd','--headless','--','--exclude-vehicle=super_rally')
    print('ITERATION_REFRESH: Forklift bases, every kit and Garage ready; other car keys exact')


if __name__=='__main__': main()
