"""Qualify the finished five after a concurrent excluded Challenger edit."""
import json
import run_car_step10
from run_car_step10 import OUT
import refresh_car_10k_assets as refresh
IDS=('compact','kart','forklift','electric','hovercraft')
refresh.prior.IDS=IDS
before=json.loads((OUT/'refresh-inputs.json').read_text());after=refresh.sources()
assert before==after
first=json.loads((OUT/'identity-before.json').read_text())['modular_car_sha256']
last=json.loads((OUT/'identity-after.json').read_text())['modular_car_sha256']
assert all(first[car]==last[car] for car in IDS)
changed=[car for car in first if first[car]!=last[car]]
assert set(changed)<={'super_rally'}
for car in IDS:
    for label in ('bases-','kits-','garage-'):
        row=json.loads((OUT/(label+car+'-receipt.json')).read_text())
        assert row['exit_code']==0 and not row['errors']
refresh.checked('prepared-preflight-final','res://tests/check_prepared_assets.gd','--headless','--','--exclude-vehicle=super_rally')
(OUT/'refresh-scoped-key-fence.json').write_text(json.dumps(dict(vehicles=IDS,inputs=len(after),changed_consumed_inputs=[],unchanged_scoped_keys=True,
    excluded_changed_keys=changed,reason='Owner explicitly excludes unfinished Challenger. Its builder is now routed only to its own model; owned minimal-project controls reject the old all-shared rule.'),indent=2)+'\n')
print('STEP10_SCOPED_REFRESH all five sources, produced caches and keys qualified')
