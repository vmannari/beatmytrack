"""C1504: close the five-car source/key fence without rewriting metadata."""
import hashlib
import json
import run_car15
from run_car15 import ROOT,OUT
import refresh_car_10k_assets as refresh

digest=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
original=json.loads((OUT/'refresh-inputs.json').read_text())
current=refresh.sources()
changed=sorted(p for p in original.keys()|current.keys() if original.get(p)!=current.get(p))
publication=json.loads((OUT/'publication.json').read_text())
published_changes=[p for p,row in publication['files'].items() if digest(ROOT/p)!=row['after']]
controls=json.loads((OUT/'before-controls.json').read_text())
control_changes=[p for p,h in controls.items() if digest(ROOT/p)!=h]
assert not changed,changed
assert not published_changes,published_changes
allowed={'AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md','.git/index','game/vehicle/super_rally_model.gd'}
assert set(control_changes)<=allowed,control_changes
initial=json.loads((OUT/'initial-car-keys.json').read_text())
final=json.loads((OUT/'identity-final.json').read_text())['modular_car_sha256']
unrelated=[car for car in initial if car not in refresh.IDS]
assert all(initial[car]==final[car] for car in unrelated)
required=['prepared-models','prepared-native-gl','prepared-native-mobile','recipe-guards','driving','parser','prepared-final']
required += [kind+'-'+renderer for kind in ('app','steering','icons') for renderer in ('gl_compatibility','mobile')]
required += ['modules-'+car for car in refresh.IDS]
for label in required:
    receipt=json.loads((OUT/(label+'-receipt.json')).read_text())
    assert receipt['exit_code']==0 and not receipt['errors'],label
receipt=dict(consumed_inputs=len(original),changed_consumed_inputs=changed,published_source_files=len(publication['files']),
    changed_publication_hashes=published_changes,required_clean_receipts=required,
    unchanged_unrelated_car_keys=unrelated,changed_task_start_controls=control_changes,
    concurrent_exceptions='Tracker/index edits and earlier concurrent Challenger source work are preserved. No Challenger path is authored or rebuilt by this task.',
    no_device_test=True,no_fps_claim=True,no_backend_export_deployment=True)
(OUT/'closure.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps(receipt,indent=2))
