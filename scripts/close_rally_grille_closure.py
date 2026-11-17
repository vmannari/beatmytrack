"""RGC03: record exact authored bindings and current Rally source readiness."""
import hashlib
import json
import run_rally_grille_closure
from run_rally_grille_closure import ROOT, OUT
import refresh_car_10k_assets as refresh

refresh.prior.IDS = ('compact',)
before = json.loads((OUT / 'refresh-inputs.json').read_text())
after = refresh.sources()
changed = sorted(p for p in before.keys() | after.keys() if before.get(p) != after.get(p))
publication = json.loads((OUT / 'publication.json').read_text())
for name, row in publication['files'].items():
    assert hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == row['after'], name
labels = ['geometry-costs', 'grille-regression', 'prepared-final-consumers', 'prepared-final',
          'native-winding-gl', 'native-winding-mobile', 'app-mobile', 'parser']
for label in labels:
    row = json.loads((OUT / (label + '-receipt.json')).read_text())
    assert row['exit_code'] == 0 and not row['errors'], label
imports = json.loads((OUT / 'image-import-receipt.json').read_text())
assert imports['verified_images'] == 8 and not imports['editor_diagnostics']
first = json.loads((OUT / 'identity-after.json').read_text())['modular_car_sha256']['compact']
last = json.loads((OUT / 'identity-final.json').read_text())['modular_car_sha256']['compact']
assert first == last, 'Current Rally identity must match the actual completed bakes'
controls = json.loads((OUT / 'before-controls.json').read_text())
result = dict(requirements=['RGC01', 'RGC02', 'RGC03'], authored_sources=len(publication['files']),
              consumed_inputs=len(after), changed_consumed_inputs=changed,
              current_rally_cache_ready=not changed, qualified_receipts=labels,
              compatibility_app='8 checks, 0 failures; retained 2-object/1-resource shutdown diagnostic',
              changed_task_start_controls=[p for p, h in controls.items()
                  if hashlib.sha256((ROOT / p).read_bytes()).hexdigest() != h],
              shared_challenger_readiness='Unqualified: concurrent WIP source changed during shared consumer bake',
              physical_device_test=False, export_backend_deployment=False, owner_save_process_action=False)
(OUT / 'closure.json').write_text(json.dumps(result, indent=2) + '\n')
print('RGC_CLOSURE', len(after), 'inputs; changed=', changed)
