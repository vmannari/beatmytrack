"""CP204: close exact authored, consumed-source and receiving checks."""
import hashlib,json,re
import run_car_pass12
from run_car_pass12 import ROOT,OUT
import refresh_car_10k_assets as refresh
refresh.prior.IDS=('compact','kart','forklift','electric','hovercraft')
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
    old=json.loads((OUT/'refresh-inputs.json').read_text());now=refresh.sources()
    changed=sorted(k for k in old.keys()|now.keys() if old.get(k)!=now.get(k))
    assert not changed,changed
    pub=json.loads((OUT/'publication.json').read_text())
    for name,row in pub['files'].items():assert digest(ROOT/name)==row['after'],name
    assert not any('super_rally' in name or 'challenger' in name for name in pub['files'])
    required=['models-source-final-target','models-prepared-final','doors','recipe-guards','panel-batch','parser','driving','prepared-final']
    required+=['modules-'+car for car in refresh.prior.IDS]
    required+=[kind+'-'+method for kind in ('native','app','steering','icons','wash','reflections') for method in ('gl_compatibility','mobile')]
    required=[label+'-repeat' if label=='wash-mobile' else label for label in required]
    for label in required:
        value=json.loads((OUT/(label+'-receipt.json')).read_text());assert value['exit_code']==0 and not value['errors'],label
    for method in ('gl_compatibility','mobile'):
        for prefix,suffix in [('prepared-','-decorated'),('garage-prepared-','-decorated-sweep')]:
            value=json.loads((OUT/(prefix+method+suffix)/'comparisons.json').read_text());assert value['failures']==0
    first=json.loads((OUT/'identity-before.json').read_text())['modular_car_sha256'];last=json.loads((OUT/'identity-final.json').read_text())['modular_car_sha256']
    assert all(first[car]==last[car] for car in refresh.prior.IDS)
    original=json.loads((OUT/'before-controls.json').read_text())
    vehicle_source_changed=[n for n,h in original.items() if n.startswith('game/vehicle/') and not n.endswith('.uid') and digest(ROOT/n)!=h]
    assert set(vehicle_source_changed)<={'game/vehicle/super_rally_model.gd'},vehicle_source_changed
    # Write-ClientBuildIdentity updates this generated field during actual bakes.
    # Reconstruct the exact task-start bytes; every other setting stays fenced.
    previous_id=json.loads((ROOT/'docs/evidence/rally-grille-closure-2026-11-16/identity-final.json').read_text())['build_id']
    project=(ROOT/'game/project.godot').read_bytes()
    restored,count=re.subn(rb'(?m)^config/version="[^"]+"',b'config/version="'+previous_id.encode()+b'"',project)
    assert count==1 and hashlib.sha256(restored).hexdigest()==original['game/project.godot']
    import_receipt=json.loads((OUT/'image-import-receipt.json').read_text());assert import_receipt['verified_images']==16 and not import_receipt['editor_diagnostics']
    value=dict(consumed_inputs=len(now),changed_inputs=changed,authored_files=len(pub['files']),required_clean_receipts=required,
        retained_initial_mobile_wash=json.loads((OUT/'wash-mobile-receipt.json').read_text()),
        project_settings_exact_except_generated_version=True,project_generated_version_before=previous_id,
        concurrent_vehicle_source_changes=vehicle_source_changed,Challenger='Excluded from authoring and five-car readiness; its global derived selection portrait is refreshed with the six-image set.',
        physical_device_test=False,fps_claim=False,backend_export_deployment=False,main_index_staged=False)
    (OUT/'closure.json').write_text(json.dumps(value,indent=2)+'\n');print('CP2_CLOSURE',len(now),'exact inputs')
if __name__=='__main__':main()
