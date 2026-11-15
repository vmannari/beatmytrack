"""VSR03: reject stale source/asset fences and retain the exact repair scope."""
import hashlib,json
import run_volt_smooth
from run_volt_smooth import ROOT,OUT
import refresh_car_10k_assets as refresh
refresh.prior.IDS=('electric',)
def main():
    before=json.loads((OUT/'refresh-inputs.json').read_text());after=refresh.sources()
    changed_inputs=sorted(k for k in before.keys()|after.keys() if before.get(k)!=after.get(k))
    publication=json.loads((OUT/'publication.json').read_text())
    for name,row in publication['files'].items():assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==row['after'],name
    a=json.loads((OUT/'identity-before.json').read_text())['modular_car_sha256'];b=json.loads((OUT/'identity-final.json').read_text())['modular_car_sha256']
    assert a['electric']==b['electric']
    controls=json.loads((OUT/'before-controls.json').read_text());changed=[n for n,h in controls.items() if hashlib.sha256((ROOT/n).read_bytes()).hexdigest()!=h]
    assert set(changed)<={'AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md','.git/index','game/project.godot','game/vehicle/super_rally_model.gd'},changed
    labels=['source-models','prepared-models','door-clearance','all-kits','parser','driving','prepared-final']+[kind+'-'+method for kind in ('native','app','icons','wash') for method in ('gl_compatibility','mobile')]
    labels += ['source-reflection-sweep','current-authorship','current-source-models','current-door-clearance']
    unqualified=[]
    for label in labels:
        data=json.loads((OUT/(label+'-receipt.json')).read_text())
        if data['exit_code']!=0 or data['errors']:unqualified.append(label)
    assert json.loads((OUT/'geometry-proof.json').read_text())['failures']==0
    result=dict(requirements=['VSR01','VSR02','VSR03'],source_files=len(publication['files']),consumed_inputs=len(after),changed_consumed_inputs=changed_inputs,qualified_receipts=[label for label in labels if label not in unqualified],verification_receipts=labels,unqualified_receipts=unqualified,verification_complete=not unqualified and not changed_inputs,source_fence_valid=not changed_inputs,current_source_receipts=['current-authorship','current-source-models','current-door-clearance'],prepared_cache_current=not changed_inputs,
                changed_task_start_controls=changed,no_phone_test=True,no_export_backend_deployment=True,no_owner_process_save_action=True,source_authoring='Thirty-six Electric-only paint/contour meshes and exact frame recipes; no production GDScript or other car model authoring.')
    (OUT/'closure.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8');print('VSR_SOURCE_CLOSURE',len(after),'stable inputs; unqualified receipts:',unqualified)
    assert not changed_inputs,'Original consumed-input fence remains rejected: '+str(changed_inputs)
    assert not unqualified,'Original validation gate remains unqualified: '+str(unqualified)
if __name__=='__main__':main()
