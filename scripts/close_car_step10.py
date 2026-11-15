"""Close accepted source/output/key fences without restamping provenance."""
import hashlib,json
import run_car_step10
from run_car_step10 import ROOT,OUT
import refresh_car_10k_assets as refresh
refresh.prior.IDS=('compact','kart','forklift','electric','hovercraft')
def main():
    old=json.loads((OUT/'refresh-inputs.json').read_text());now=refresh.sources()
    changed=sorted(k for k in old.keys()|now.keys() if old.get(k)!=now.get(k))
    assert not changed,changed
    boundaries=json.loads((OUT/'glazing-boundary-review.json').read_text());assert boundaries['all_original_boundaries_exact'] and boundaries['selected_glazing_meshes']==13
    pub=json.loads((OUT/'authored-publication.json').read_text())
    for name,row in pub['files'].items():assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==row['after'],name
    first=json.loads((OUT/'identity-before.json').read_text())['modular_car_sha256'];last=json.loads((OUT/'identity-final.json').read_text())['modular_car_sha256']
    assert all(first[car]==last[car] for car in refresh.prior.IDS)
    required=['prepared-models-final','source-models-final','current-source-batch-controls','volt-regression-clearance','surface-recipe-guards','protected-landmarks','panel-batch-final','rally-retained','old-recipe-guards','driving','parser','prepared-final']
    required+=['modules-'+car for car in refresh.prior.IDS]
    required+=[kind+'-'+method for kind in ('native-final','app-final','steering-final','icons','wash') for method in ('gl_compatibility','mobile')]
    for label in required:
        value=json.loads((OUT/(label+'-receipt.json')).read_text());assert value['exit_code']==0 and not value['errors'],label
    controls=json.loads((OUT/'before-controls.json').read_text())
    changed_controls=[n for n,h in controls.items() if hashlib.sha256((ROOT/n).read_bytes()).hexdigest()!=h]
    authored=set(pub['files']);allowed=authored|{'AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md','.git/index','game/project.godot','game/vehicle/super_rally_model.gd'}
    assert set(changed_controls)<=allowed,changed_controls
    value=dict(consumed_inputs=len(now),changed_inputs=changed,authored_files=len(pub['files']),required_clean_receipts=required,changed_task_start_controls=changed_controls,
        challenger='No authored model path. Concurrent source change is preserved; frozen original batching/current-source GPU controls pass. Shared cache consumers regenerated.',
        physical_device_test=False,fps_claim=False,backend_export_deployment=False,main_index_staged=False)
    (OUT/'closure.json').write_text(json.dumps(value,indent=2)+'\n');print('STEP10_CLOSURE',len(now),'inputs')
if __name__=='__main__':main()
