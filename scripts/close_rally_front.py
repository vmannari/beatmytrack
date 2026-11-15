"""RFL04: stable consumed-source/identity/authoring fences and clean receipts."""
import hashlib
import json
import run_rally_front
from run_rally_front import ROOT,OUT
import refresh_car_10k_assets as refresh
refresh.prior.IDS=('compact','super_rally')
digest=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
before=json.loads((OUT/'refresh-inputs.json').read_text());after=refresh.sources()
changes=sorted(p for p in before.keys()|after.keys() if before.get(p)!=after.get(p))
assert not changes,changes
published=json.loads((OUT/'publication.json').read_text())
assert all(digest(ROOT/p)==row['after'] for p,row in published['files'].items())
controls=json.loads((OUT/'before-controls.json').read_text())
changed_controls=[p for p,h in controls.items() if digest(ROOT/p)!=h]
allowed={'AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md','.git/index','game/project.godot',
         'game/vehicle/compact_front_lamps.gd','game/vehicle/compact_grille.gd'}
assert set(changed_controls)<=allowed,changed_controls
initial=json.loads((OUT/'initial-car-keys.json').read_text());final=json.loads((OUT/'identity-final.json').read_text())['modular_car_sha256']
assert {id for id in initial if initial[id]!=final[id]}=={'compact','super_rally'}
required=['source-models','prepared-models','grille-smooth','modules-compact','modules-super_rally','parser-final','driving','prepared-final','snapshot-fixture-repair','snapshot-uniforms']
required += [kind+'-'+renderer for kind in ('native','night','app','icons') for renderer in ('gl_compatibility','mobile')]
for label in required:
    receipt=json.loads((OUT/(label+'-receipt.json')).read_text());assert receipt['exit_code']==0 and not receipt['errors'],label
receipt=dict(consumed_inputs=len(before),changed_consumed_inputs=changes,published_source_bindings=len(published['files']),
    unchanged_other_car_keys=[id for id in initial if initial[id]==final[id]],changed_task_start_controls=changed_controls,
    clean_receipts=required,scope='Only Rally front geometry/finish is authored. Challenger dependent cache is rebuilt; all ten other stock/full master GPU controls are exact.',
    no_device_test=True,no_fps_claim=True,no_export_backend_deployment=True)
(OUT/'closure.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt,indent=2))
