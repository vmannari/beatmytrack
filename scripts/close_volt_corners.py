"""VRC03: reject stale source/asset fences and retain the exact repair scope."""
import hashlib,json
import run_volt_corners
from run_volt_corners import ROOT,OUT
import refresh_car_10k_assets as refresh
refresh.prior.IDS=('electric',)
def main():
    before=json.loads((OUT/'refresh-inputs.json').read_text());after=refresh.sources()
    assert before==after,[k for k in before.keys()|after.keys() if before.get(k)!=after.get(k)]
    publication=json.loads((OUT/'publication.json').read_text())
    for name,row in publication['files'].items():assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==row['after'],name
    a=json.loads((OUT/'identity-before.json').read_text())['modular_car_sha256'];b=json.loads((OUT/'identity-final.json').read_text())['modular_car_sha256']
    assert a['electric']==b['electric']
    controls=json.loads((OUT/'before-controls.json').read_text());changed=[n for n,h in controls.items() if hashlib.sha256((ROOT/n).read_bytes()).hexdigest()!=h]
    assert set(changed)<={'AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md','.git/index','game/project.godot','game/vehicle/super_rally_model.gd'},changed
    labels=['source-models','prepared-models','door-clearance','all-kits','parser','driving','prepared-final']+[kind+'-'+method for kind in ('native','app','icons','wash') for method in ('gl_compatibility','mobile')]
    for label in labels:
        data=json.loads((OUT/(label+'-receipt.json')).read_text());assert data['exit_code']==0 and not data['errors'],label
    assert json.loads((OUT/'geometry-proof.json').read_text())['failures']==0
    result=dict(requirements=['VRC01','VRC02','VRC03'],source_files=len(publication['files']),consumed_inputs=len(after),changed_consumed_inputs=[],qualified_receipts=labels,
                changed_task_start_controls=changed,no_phone_test=True,no_export_backend_deployment=True,no_owner_process_save_action=True,source_authoring='Twenty Electric-only native meshes/metadata and exact frame recipes; no production GDScript or other car authoring.')
    (OUT/'closure.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8');print('VOLT_CORNER_CLOSURE',len(after),'stable inputs')
if __name__=='__main__':main()
