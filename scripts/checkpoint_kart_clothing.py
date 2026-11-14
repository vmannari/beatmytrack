"""Verify the clothing-only source patch without touching the shared index."""
from pathlib import Path
import hashlib
import json
import shutil
import tempfile
from checkpoint_visual_finish import make_patch, git

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/evidence/kart-clothing-2026-11-14'
WORK = ROOT / 'build/kart-clothing-2026-11-14'
sha = lambda data: hashlib.sha256(data).hexdigest()
name = 'game/vehicle/kart_driver_cloth.gdshader'
before = {name: (OUT / 'before.gdshader').read_bytes()}
added = ['scripts/run_kart_clothing.py', 'scripts/refresh_kart_clothing.py',
         'scripts/refresh_kart_clothing_identity.ps1', 'scripts/import_kart_clothing_images.py',
         'scripts/checkpoint_kart_clothing.py', 'docs/KART_CLOTHING_READABILITY_2026_11_14.md',
         'docs/evidence/kart-clothing-2026-11-14/capture.gd',
         'docs/evidence/kart-clothing-2026-11-14/steering.gd',
         'docs/evidence/kart-clothing-2026-11-14/test_app.gd']
after = {p: (ROOT / p).read_bytes() for p in [name] + added}
index_before = sha((ROOT / '.git/index').read_bytes())
patch = make_patch(before, after)
scratch = Path(tempfile.mkdtemp(prefix='cloth-source-check-', dir=WORK)).resolve()
assert scratch.parent == WORK.resolve() and scratch.is_relative_to(ROOT.resolve())
try:
    git(['init', '--quiet', str(scratch)], scratch)
    patch_path = scratch / 'source.patch'
    patch_path.write_bytes(patch)
    path = scratch / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(before[name])
    for reverse in [False, True]:
        git(['apply', '--whitespace=error', *(['--reverse'] if reverse else []), str(patch_path)], scratch)
        for p, data in after.items():
            target = scratch / p
            if reverse and p not in before:
                assert not target.exists(), p
            else:
                assert target.read_bytes() == (before[p] if reverse else data), p
finally:
    assert scratch.parent == WORK.resolve() and not scratch.is_symlink()
    shutil.rmtree(scratch)
assert index_before == sha((ROOT / '.git/index').read_bytes())
assert all((ROOT / p).read_bytes() == data for p, data in after.items())
controls = json.loads((OUT / 'controls.json').read_text())
assert all(sha((ROOT / p).read_bytes()) == digest for p, digest in controls.items())
(OUT / 'source-only.patch').write_bytes(patch)
receipt = {'production_files': [name], 'added_tooling_and_report_files': len(added),
           'forward_byte_exact': True, 'reverse_byte_exact': True, 'whitespace': 'passed',
           'index_unchanged_during_verification': True, 'index_sha256': index_before,
           'immutable_control_files': len(controls), 'controls_exact': True,
           'files': {p: sha(data) for p, data in after.items()}}
(OUT / 'source-checkpoint.json').write_text(json.dumps(receipt, indent=2))
print('KART_CLOTHING_CHECKPOINT: forward/reverse byte exact; controls/index preserved')
