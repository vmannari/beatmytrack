"""Fence the actual sources, prepared scenes and packaged images during closeout."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[4]
OUT = ROOT / 'docs/evidence/visual-fixes-2026-11-13'
sys.path.insert(0, str(ROOT))
from scripts.refresh_visual_finish import sources, identity


def snapshot():
    result = sources()
    files = [ROOT / 'game/core/build_identity.gd', ROOT / 'game/project.godot']
    for folder in ['game/assets/vehicles/modular_car_bases_v1',
                   'game/assets/vehicles/modular_kits_v1', 'game/assets/garage']:
        files += [p for p in (ROOT / folder).rglob('*') if p.suffix in ['.scn', '.json', '.png']]
    imports = json.loads((OUT / 'image-import-receipt.json').read_text())
    files += [ROOT / row['path'] for row in imports['images'] + imports['rivalry_textures']]
    for path in files:
        result[path.relative_to(ROOT).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
    return result


if sys.argv[1] == 'start':
    baked = json.loads((OUT / 'identity-after-bakes.json').read_text())
    current = identity('closeout-identity')
    assert baked['modular_car_sha256'] == current['modular_car_sha256'], 'Final import changed vehicle revisions'
    before = snapshot()
    (OUT / 'closeout-inputs.json').write_text(json.dumps(before, indent=2))
    print('CLOSEOUT_START', len(before), 'watched inputs')
else:
    before = json.loads((OUT / 'closeout-inputs.json').read_text())
    for script, filename in [('scripts/check_garage_previews.py', 'closeout-picture-preflight.log'),
                             ('scripts/check_garage_workshop.py', 'closeout-workshop-preflight.log')]:
        with (OUT / filename).open('w', encoding='utf-8') as log:
            subprocess.run([sys.executable, script], cwd=ROOT, check=True, stdout=log, stderr=subprocess.STDOUT)
    for label in ['closeout-app-gl-final', 'closeout-app-mobile-final', 'closeout-prepared-final']:
        receipt = json.loads((OUT / (label + '-receipt.json')).read_text())
        assert receipt['exit_code'] == 0 and not receipt['errors'] and not receipt['stop_reason'], label
    after = snapshot()
    changed = sorted(p for p in before.keys() | after.keys() if before.get(p) != after.get(p))
    receipt = {'watched_inputs': len(before), 'changed': changed,
               'prepared_and_native_receipts_clean': True, 'picture_and_workshop_gates': 'passed'}
    (OUT / 'closeout-audit.json').write_text(json.dumps(receipt, indent=2))
    assert not changed, changed
    print('CLOSEOUT_AUDIT', len(before), 'inputs stable; native and provenance gates passed')
