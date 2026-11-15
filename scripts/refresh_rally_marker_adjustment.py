"""Rebuild the affected prepared consumers and retain exact source fences."""
import json
import run_rally_marker_adjustment as task
import refresh_car_10k_assets as refresh

refresh.OUT, refresh.WORK, refresh.run = task.OUT, task.WORK, task.runner.run
refresh.prior.IDS = ('compact', 'super_rally')
before = refresh.sources()
(task.OUT / 'refresh-inputs.json').write_text(json.dumps(before, indent=2)+'\n')
first = refresh.identity('identity-before')
for car in ('compact', 'super_rally'):
    for label, script in [('bases', 'bake_modular_car_bases'), ('kits', 'bake_modular_car_kits'), ('garage', 'bake_garage_cars')]:
        refresh.checked(label+'-'+car, 'res://tests/'+script+'.gd', '--headless', '--', '--vehicle='+car)
refresh.checked('header', 'res://tests/bake_header_simple_compact.gd', '--headless')
after = refresh.sources()
changed = sorted(p for p in before.keys() | after.keys() if before.get(p) != after.get(p))
(task.OUT / 'refresh-fence.json').write_text(json.dumps({'inputs':len(before), 'changed':changed}, indent=2)+'\n')
assert not changed, changed
last = refresh.identity('identity-after')
assert first['modular_car_sha256'] == last['modular_car_sha256']
refresh.checked('prepared-scoped', 'res://tests/check_prepared_assets.gd', '--headless', '--',
                *['--exclude-vehicle='+car for car in ('kart','forklift','electric','hovercraft')])
