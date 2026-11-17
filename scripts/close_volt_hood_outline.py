"""VHO03: preserve exact source/bake fences and current receiving evidence."""
import hashlib,json
import run_volt_hood_outline
from run_volt_hood_outline import ROOT,OUT
import refresh_car_10k_assets as refresh
refresh.prior.IDS=('electric',)
before=json.loads((OUT/'refresh-inputs.json').read_text(encoding='utf-8'))
after=refresh.sources()
changed=sorted(k for k in before.keys()|after.keys() if before.get(k)!=after.get(k))
assert not changed,changed
publication=json.loads((OUT/'publication.json').read_text(encoding='utf-8'))
for name,row in publication['files'].items():assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==row['after'],name
controls=json.loads((OUT/'before-controls.json').read_text(encoding='utf-8'))
changed_controls=[name for name,value in controls.items() if hashlib.sha256((ROOT/name).read_bytes()).hexdigest()!=value]
assert set(changed_controls)<={'AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md','.git/index','game/project.godot','game/vehicle/electric_reference_body.gd','game/vehicle/super_rally_model.gd','game/assets/vehicles/electric_hoods_v5/manifest.json'},changed_controls
labels=['geometry','hood-bank','prepared-consumers','prepared-final','app-gl','app-mobile','native-preview-fixed','native-mobile','parser']
for label in labels:
    row=json.loads((OUT/(label+'-receipt.json')).read_text(encoding='utf-8'));assert row['exit_code']==0 and not row['errors'],label
a=json.loads((OUT/'identity-before.json').read_text(encoding='utf-8'))['modular_car_sha256']['electric']
b=json.loads((OUT/'identity-final.json').read_text(encoding='utf-8'))['modular_car_sha256']['electric']
assert a==b
result={'requirements':['VHO01','VHO02','VHO03'],'source_files':len(publication['files']),'consumed_inputs':len(after),'changed_consumed_inputs':changed,'qualified_receipts':labels,'changed_task_start_controls':changed_controls,'no_phone_test':True,'no_export_backend_deployment':True,'no_owner_process_save_action':True}
(OUT/'closure.json').write_bytes((json.dumps(result,indent=2)+'\n').encode('utf-8'))
print('VHO_CLOSURE',len(after),'stable inputs;',len(labels),'clean receiving receipts')
