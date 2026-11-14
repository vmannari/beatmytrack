"""Retain concise final provenance and task controls before disposable cleanup."""
from pathlib import Path
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
BUILD = ROOT / 'build/challenger-reference-body-2026-11-13'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()

source = json.loads((BUILD / 'assets/source-receipt.json').read_text())
live = {p: sha(ROOT / p) for p in source['after']}
changes = [p for p, value in live.items() if value != source['after'][p]]
controls = json.loads((OUT / 'controls-before.json').read_text())
protected = {p: sha(ROOT / p) for p in controls
             if not p.replace('\\', '/').startswith('game/assets/vehicles/challenger_hellcat_v1/')}
control_changes = [p for p in protected if protected[p] != controls[p]]
pictures = json.loads((OUT / 'pictures-pre-refresh.json').read_text())
picture_after = {p: sha(ROOT / p) for p in pictures}
picture_changes = [p for p in pictures if pictures[p] != picture_after[p]]
receipt = {
    'qualified_source_count': len(source['after']),
    'bake_source_changes': source['changed'],
    'live_changes_since_bake': changes,
    'protected_control_count': len(protected),
    'protected_control_changes': control_changes,
    'protected_picture_count': len(pictures),
    'protected_picture_changes': picture_changes,
    'current_controls': protected,
    'native_sha256': {p.name: sha(p) for p in sorted((ROOT / 'game/assets/vehicles/challenger_hellcat_v1').glob('*')) if p.is_file()},
    'source_sha256': live,
    'pictures_sha256': picture_after,
}
(OUT / 'final-audit.json').write_text(json.dumps(receipt, indent=2))
destination = OUT / 'assets'
destination.mkdir(exist_ok=True)
for p in (BUILD / 'assets').iterdir():
    if p.is_file(): shutil.copy2(p, destination / p.name)
assert not source['changed'], source['changed']
assert not changes, changes
assert not [p for p in control_changes if p.replace('\\', '/') != '.git/index'], control_changes
print(json.dumps({key: value for key, value in receipt.items() if key.endswith('count') or key.endswith('changes')}))
