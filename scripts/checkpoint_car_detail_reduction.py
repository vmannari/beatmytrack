"""CLV04: source-only checkpoint and byte-exact round trip in disposable output."""
import hashlib
import json
import re
import subprocess
from pathlib import Path

from run_car_detail_reduction import ROOT, OUT, WORK

MARKER = 'CAR-DETAIL-REDUCTION-20261114'
modified = list(json.loads((OUT/'before-controls.json').read_text())['sources'])
trackers = ['AGENTS.md', 'DEVELOPMENT_STATUS.md', 'docs/PHASE_0_PLAN.md']
added = [
    'game/vehicle/car_detail_reduction.gd', 'game/vehicle/compact_plate.gdshader',
    'game/tests/bake_car_detail_reductions.gd', 'game/tests/bake_compact_plate_texture.gd',
    'game/tests/capture_car_detail_baseline.gd', 'game/tests/capture_car_detail_editable_before.gd',
    'game/tests/capture_car_detail_models.gd', 'game/tests/finalize_car_detail_materials.gd',
    'game/tests/measure_car_detail_results.gd', 'game/tests/probe_car_detail_reset_control.gd',
    'game/tests/test_car_detail_app.gd', 'game/tests/test_car_detail_reductions.gd',
    'scripts/bake_car_detail_reductions.py', 'scripts/compare_car_detail_reduction.ps1',
    'scripts/finalize_car_detail_materials.py', 'scripts/refresh_car_detail_assets.py',
    'scripts/refresh_car_detail_identity.ps1', 'scripts/run_car_detail_reduction.py',
    'scripts/checkpoint_car_detail_reduction.py', 'docs/CAR_DETAIL_REDUCTION_2026_11_14.md',
    'game/assets/vehicles/compact_plate_v1/manifest.json',
]
added += [name+'.uid' for name in list(added)
          if name.endswith(('.gd', '.gdshader')) and (ROOT/(name+'.uid')).exists()]
digest = lambda data: hashlib.sha256(data).hexdigest()
index_before = digest((ROOT/'.git/index').read_bytes())
original = json.loads((OUT/'before-controls.json').read_text())['sources']
before = {}
after = {name: (ROOT/name).read_bytes() for name in modified+trackers+added}
for name in modified:
    before[name] = (WORK/'before'/name).read_bytes()
    assert digest(before[name]) == original[name], name
for name in trackers:
    pattern = ('<!-- '+MARKER+r' -->\r?\n.*?<!-- /'+MARKER+r' -->\r?\n(?:\r?\n)?').encode()
    before[name], count = re.subn(pattern, b'', after[name], flags=re.S)
    assert count == 1, name

private = (WORK/'source-checkpoint').resolve()
assert private.is_relative_to(WORK.resolve())
assert not private.exists(), 'Preserve the existing checkpoint; choose a fresh task path'
private.mkdir(parents=True)
def git(*args):
    result = subprocess.run(['git','-c','core.autocrlf=false','-c',
        'core.whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol',*args],
        cwd=private, capture_output=True)
    assert result.returncode == 0, result.stderr.decode(errors='replace')
    return result.stdout
def write(files):
    for name, data in files.items():
        target = private/name
        target.parent.mkdir(parents=True,exist_ok=True)
        target.write_bytes(data)

git('init','--quiet')
git('config','user.name','Local source checkpoint')
git('config','user.email','checkpoint@invalid.local')
write(before)
git('add','--all')
git('commit','--quiet','-m','Task-start sources and surrounding documentation')
write(after)
git('add','--all')
patch = git('diff','--cached','--binary','--full-index','HEAD')
(OUT/'source.patch').write_bytes(patch)
git('apply','--check','--reverse',str(OUT/'source.patch'))
git('apply','--reverse','--whitespace=error',str(OUT/'source.patch'))
for name in after:
    target=private/name
    assert (not target.exists()) if name not in before else target.read_bytes()==before[name], name
git('apply','--whitespace=error',str(OUT/'source.patch'))
for name,data in after.items(): assert (private/name).read_bytes()==data, name
git('diff','--cached','--check')
git('commit','--quiet','-m','CLV01-CLV04 reduce low-visibility car detail')
assert digest((ROOT/'.git/index').read_bytes())==index_before
receipt = {'source_files':len(after),'forward_byte_exact':True,'reverse_byte_exact':True,
    'whitespace_check':'passed','main_index_unchanged_during_checkpoint':True,
    'private_commit':git('rev-parse','HEAD').decode().strip(),'patch_sha256':digest(patch),
    'files':{name:{'before_sha256':digest(before[name]) if name in before else None,
                   'sha256':digest(data)} for name,data in after.items()},
    'scope':'Source only. Generated native recipes, meshes, plate image and prepared scenes have separate final asset hashes.'}
(OUT/'source-checkpoint.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps({key:value for key,value in receipt.items() if key!='files'}))
