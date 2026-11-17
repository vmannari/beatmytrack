"""VFD03. Verify actual receiving results and the final consumed-source fence."""
import hashlib
import json
import subprocess
import sys
import run_volt_front_door
from run_volt_front_door import ROOT, OUT, WORK
import refresh_car_10k_assets as refresh

refresh.prior.IDS = ('electric',)
before = json.loads((OUT / 'refresh-inputs.json').read_text())
after = refresh.sources()
changed = sorted(name for name in before.keys() | after.keys() if before.get(name) != after.get(name))
assert not changed, changed

publication = json.loads((OUT / 'publication.json').read_text())
for name, row in publication['files'].items():
    assert hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == row['after'], name
    if row['before'] is not None:
        assert hashlib.sha256((WORK / 'before' / name).read_bytes()).hexdigest() == row['before'], name

task_start = json.loads((OUT / 'before-sources.json').read_text())
untouched = {name: value for name, value in task_start.items() if name not in publication['files']}
for name, value in untouched.items():
    assert hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == value, name

labels = ['geometry-topology', 'hood-bank-final', 'fit', 'driving', 'parser',
          'prepared-consumers-enabled', 'prepared-final', 'app-gl', 'app-mobile',
          'native-final-gl', 'native-mobile', 'garage-picture', 'header-picture', 'selection-portraits-final']
receipts = {}
for label in labels:
    row = json.loads((OUT / (label + '-receipt.json')).read_text())
    assert row['exit_code'] == 0 and not row['errors'], label
    receipts[label] = row
assert json.loads((OUT / 'geometry.json').read_text())['failures'] == 0

initial_identity = json.loads((OUT / 'identity-before.json').read_text())
final_identity = json.loads((OUT / 'identity-final.json').read_text())
assert initial_identity['modular_car_sha256']['electric'] == final_identity['modular_car_sha256']['electric']
imports = json.loads((OUT / 'image-import-receipt.json').read_text())
assert imports['exit_code'] == 0 and imports['project_settings_exact'] and not imports['editor_diagnostics']
selection = subprocess.run([sys.executable, 'scripts/check_garage_selection_pictures.py'],
                           cwd=ROOT, capture_output=True, text=True, check=True)
(OUT / 'selection-portraits-closure.log').write_text(selection.stdout)

result = {
    'requirements': ['VFD01', 'VFD02', 'VFD03'],
    'source_files': len(publication['files']),
    'unchanged_task_start_sources': len(untouched),
    'consumed_inputs': len(after),
    'changed_consumed_inputs': changed,
    'receipts': receipts,
    'geometry': json.loads((OUT / 'geometry.json').read_text()),
    'native_views': 24,
    'physical_device_test_performed': False,
    'remaining_acceptance': ['Client reload', 'Owner appearance review', 'Physical-device acceptance'],
}
(OUT / 'closure.json').write_text(json.dumps(result, indent=2) + '\n')
print('VFD_CLOSURE', len(after), 'stable inputs,', len(labels), 'clean receipts')
