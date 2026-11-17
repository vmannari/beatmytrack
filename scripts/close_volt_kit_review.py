"""VKR03. Close the native review against actual source and receiving receipts."""
import hashlib
import json
import subprocess
import sys
import run_volt_kit_review
from run_volt_kit_review import ROOT, OUT, WORK
import refresh_car_10k_assets as refresh


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


refresh.prior.IDS = ('electric',)
initial = json.loads((OUT / 'refresh-inputs.json').read_text())
current = refresh.sources()
changed = sorted(name for name in initial.keys() | current.keys() if initial.get(name) != current.get(name))
assert not changed, changed

task_start = json.loads((OUT / 'before-sources.json').read_text())
bank_root = 'game/assets/vehicles/electric_hoods_v5/'
bank = json.loads((ROOT / bank_root / 'manifest.json').read_text())
for name, value in bank['sources'].items():
    assert digest(ROOT / 'game/vehicle' / name) == value, name
names = ['game/vehicle/electric_kits.gd', 'game/vehicle/electric_body_kits.gd',
         'game/vehicle/electric_reference_mesh.gd', bank_root + 'manifest.json']
names.extend(bank_root + row['file'] for row in bank['meshes'])
files = {}
for name in names:
    after = digest(ROOT / name)
    if task_start.get(name) == after:
        continue
    before = task_start.get(name)
    if before is not None:
        assert digest(WORK / 'before' / name) == before, name
    files[name] = {'before': before, 'after': after}
for name, value in task_start.items():
    if name not in files:
        assert digest(ROOT / name) == value, name
(OUT / 'publication.json').write_text(json.dumps({'files': files}, indent=2) + '\n')

labels = ['bank-distance-safe', 'hood-distance-safe', 'surfaces-final-rear',
          'rear-coverage-distance-safe', 'distance-policy-final', 'counts-distance-safe',
          'all-modules-distance-safe', 'garage-distance-safe-gl', 'garage-distance-safe-mobile',
          'distance-safe-gl', 'distance-safe-mobile', 'parser-distance-safe', 'prepared-final',
          'garage-picture', 'header-picture', 'selection-portraits-final']
receipts = {}
for label in labels:
    row = json.loads((OUT / (label + '-receipt.json')).read_text())
    assert row['exit_code'] == 0 and not row['errors'], label
    receipts[label] = row
for name in ['surfaces.json', 'rear-coverage.json', 'distance-policy.json']:
    assert json.loads((OUT / name).read_text())['failures'] == 0, name
assert json.loads((OUT / 'distance-lock-array-proof.json').read_text())['geometry_arrays_exact']

old_identity = json.loads((OUT / 'identity-before.json').read_text())
final_identity = json.loads((OUT / 'identity-final.json').read_text())
assert old_identity['modular_car_sha256']['electric'] == final_identity['modular_car_sha256']['electric']
imports = json.loads((OUT / 'image-import-receipt.json').read_text())
assert imports['exit_code'] == 0 and imports['project_settings_exact'] and not imports['editor_diagnostics']
selection = subprocess.run([sys.executable, 'scripts/check_garage_selection_pictures.py'],
                           cwd=ROOT, capture_output=True, text=True, check=True)
(OUT / 'selection-portraits-closure.log').write_text(selection.stdout)

views = {}
for renderer in ['gl_compatibility', 'mobile']:
    views[renderer] = len(list((OUT / ('after-' + renderer)).glob('*.png')))
    assert views[renderer] == 352
stock = []
for before in sorted((OUT / 'before-gl_compatibility').glob('*-stock-*.png')):
    equal = digest(before) == digest(OUT / 'after-gl_compatibility' / before.name)
    stock.append({'file': before.name, 'png_exact': equal})
    assert equal, before.name
assert len(stock) == 16
(OUT / 'stock-picture-comparison.json').write_text(json.dumps(stock, indent=2) + '\n')

controls = json.loads((OUT / 'before-controls.json').read_text())
for name in ['game/vehicle/vehicle_customisation.gd', 'game/resources/cars/electric.tres']:
    assert digest(ROOT / name) == controls[name], name
closure = {
    'requirements': ['VKR01', 'VKR02', 'VKR03'],
    'authored_source_files': len(files),
    'consumed_inputs': len(current),
    'changed_consumed_inputs': changed,
    'final_native_views': views,
    'stock_exact_pngs': 16,
    'kit_counts': json.loads((OUT / 'kit-counts.json').read_text()),
    'receipts': receipts,
    'main_index_matches_task_start': digest(ROOT / '.git/index') == controls['.git/index'],
    'physical_device_test_performed': False,
    'remaining_acceptance': ['Client reload', 'Owner appearance review', 'Physical-device rendering and performance'],
}
(OUT / 'closure.json').write_text(json.dumps(closure, indent=2) + '\n')
print('VKR_CLOSURE', len(current), 'stable inputs,', len(labels), 'clean receipts, 704 final native views')
