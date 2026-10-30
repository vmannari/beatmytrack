"""Record the finishing pass and create a task-only binary review patch."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import subprocess

EV = Path(__file__).resolve().parent
ROOT = EV.parents[2]
BASE = EV / 'before'
TAG = 'KART-FINISHING-20261026'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))

def block(path, text):
    target = ROOT / path
    raw = target.read_bytes()
    raw = re.sub(rb'(?ms)^<!-- '+TAG.encode()+rb' -->\r?\n.*?^<!-- /'+TAG.encode()+rb' -->\r?\n(?:\r?\n)?', b'', raw)
    # Use the latest shared document as the checkpoint base, preserving concurrent edits.
    dest = BASE / path
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(raw)
    newline = b'\r\n' if b'\r\n' in raw else b'\n'
    addition = (f'<!-- {TAG} -->\n{text}\n<!-- /{TAG} -->\n\n').encode().replace(b'\n', newline)
    target.write_bytes(addition + raw)

results = {}
for job in ['before-gl_compatibility', 'draft-gl_compatibility', 'model-gl_compatibility', 'model-mobile',
            'native-gl_compatibility', 'native-mobile', 'retained-gl_compatibility',
            'shape-gl_compatibility', 'construction-gl_compatibility', 'fit-gl_compatibility', 'proportions-gl_compatibility']:
    result = read(EV / job / 'report.json')
    assert result['failures'] == 0, job
    results[job] = result
assert 'KART_TESTS: 42 checks, 0 failures' in (EV/'handling-gl_compatibility.log').read_text(encoding='utf-8-sig')
parser = re.search(r'SCRIPT_PARSE: (\d+) scripts, 0 failures', (EV/'parser-gl_compatibility.log').read_text(encoding='utf-8-sig'))
assert parser
assert '[ DONE ]' in (EV/'import-gl_compatibility.log').read_text(encoding='utf-8-sig')
assert 'ERROR:' not in (EV/'import-gl_compatibility.log').read_text(encoding='utf-8-sig')

asset_root = Path('game/assets/vehicles/kart_refined_v1')
manifest = read(ROOT / asset_root / 'manifest.json')
old_manifest = read(BASE / asset_root / 'manifest.json')
old_files = {entry['file'] for entry in old_manifest['meshes']}
new_files = {entry['file'] for entry in manifest['meshes']}
assert new_files == {p.name for p in (ROOT / asset_root).glob('*.res')}
identical = [name for name in old_files & new_files if sha(ROOT/asset_root/name) == sha(BASE/asset_root/name)]
assert len(identical) == 250
for key, name in [('model_sha256','kart_model.gd'), ('geometry_sha256','kart_geometry.gd'),
                  ('driver_sha256','kart_driver.gd'), ('helmet_sha256','kart_helmet.gd'), ('detail_sha256','kart_detail.gd')]:
    assert manifest[key] == sha(ROOT/'game/vehicle'/name)

invariants = {}
concurrent = {}
for path, digest in read(EV/'before-hashes.json').items():
    if path.startswith(('game/vehicle/', 'game/resources/', 'game/ui/')) and path != 'game/vehicle/kart_model.gd':
        actual = sha(ROOT/path)
        if actual == digest:
            invariants[path] = actual
        else:
            assert path in ['game/vehicle/car_visual.gd', 'game/ui/profile_car.gd'], path
            concurrent[path] = {'before':digest, 'after':actual, 'excluded_from_patch':True}
for index in range(1,5):
    path = Path(f'game/assets/vehicles/racing_simple_v1/kart_shadow_{index}.res')
    assert sha(ROOT/path) == sha(BASE/path)

summary = (
    '## Kart finishing details to match Compact quality (2026-10-26)\n'
    'KFP01-KFP03/V02-V05/R01/G01/Q01: Fitted fairing/pod socket fasteners, narrow inlay keylines, pod rub strips and chassis brackets; '
    'steering links/bellcrank, rear axle bearing mounts, brake hat and triangle-fitted airbox seal/clips finish the exposed assembly. '
    'Original immutable geometry and shared CompactFinish, with bevelled thin engine fins/socket tray hardware. '
    'Full94928to94870/simple29374to31506 retain the95000 cap;288 prepared resources include250 exact originals, four wheel shadows exact. '
    'Model87Compatibility/87desktopMobile, actual Garage-race15/15, retained160/shape38/construction32/fit32/proportions24/handling42/parser'+parser[1]+' and final import pass. '
    'Catalogue/news/Garage/header/all49 livery photos refreshed. Initial95574-triangle failure, sandbox certificate failure and concurrent import/native parse interruptions are retained; '
    'all-car preview check retains the same task-start Electric source-hash failure. '
    'Exact commands, native views, hashes and task-only patch: docs/KART_FINISHING_2026_10_26.md and docs/evidence/kart-finishing-2026-10-26/report.json. '
    'Driver/helmet/config/simulation/camera remain; concurrent car_visual/profile work is excluded. Reload and owner/device appearance/motion/cost acceptance remain. '
    'No device attachment check/test, APK, auth/purchase, live mutation, deployment, main-index staging/commit/merge or owner-process restart.'
)
for path in ['AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md']:
    block(Path(path), summary)
block(Path('licenses/ASSETS.md'), '## Original kart finishing geometry and pictures\n2026-10-26: Original code-authored fairing hardware/trim, steering and axle fittings, airbox seal/clips and machined engine plates. Shared existing CompactFinish materials; no external model, image, font or generated media. Prepared native meshes/shadow and catalogue/news/Garage/header/49 livery photographs refreshed. Provenance and commands: docs/KART_FINISHING_2026_10_26.md.')

paths = [Path(p) for p in ['game/vehicle/kart_model.gd','game/vehicle/kart_detail.gd','game/vehicle/kart_detail.gd.uid',
    'game/tests/bake_kart_model.gd','game/tests/test_kart_model.gd','game/tests/bake_kart_finishing_art.gd','game/tests/bake_kart_finishing_art.gd.uid',
    'game/assets/vehicles/racing_simple_v1/kart_shadow_0.res','game/assets/menu/kart_illustration_v1.png',
    'game/assets/news/vehicles/kart.png','game/assets/menu/header_cars_v1/kart.png','game/assets/garage/previews_v1/kart.png',
    'game/assets/garage/previews_v1/provenance.json','AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md','licenses/ASSETS.md',
    'docs/KART_FINISHING_2026_10_26.md']]
paths += [asset_root / name for name in old_files | new_files | {'manifest.json'}]
paths += [p.relative_to(ROOT) for p in (ROOT/'game/assets/liveries/previews_v2/kart').glob('*.png')]
paths = sorted(set(paths))
changed = [p for p in paths if (ROOT/p).exists() != (BASE/p).exists() or ((ROOT/p).exists() and sha(ROOT/p) != sha(BASE/p))]
index_path = ROOT/'.git/index'
index_hash = sha(index_path)
review = ROOT/'build/kart-finishing/review'
assert not review.exists(), 'Use a new review directory; do not overwrite an existing checkpoint.'
for tree, origin in [('before',BASE), ('after',ROOT)]:
    for path in changed:
        if not (origin/path).exists(): continue
        dest = review/tree/path
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(origin/path, dest)
diff = subprocess.run(['git','diff','--no-index','--binary','--no-renames','--','before','after'],cwd=review,capture_output=True)
assert diff.returncode == 1, diff.stderr.decode()
patch = diff.stdout.replace(b'a/before/',b'a/').replace(b'b/after/',b'b/').replace(b'a/after/',b'a/').replace(b'b/before/',b'b/')
patch_path = EV/'task-only.patch'
patch_path.write_bytes(patch)
subprocess.run(['git','init','-q'],cwd=review/'after',check=True)
validation = subprocess.run(['git','apply','--reverse','--check',str(patch_path)],cwd=review/'after',capture_output=True)
assert validation.returncode == 0, validation.stderr.decode()
assert sha(index_path) == index_hash

report = {
    'requirements':['KFP01','KFP02','KFP03','V02-V05','R01','G01','Q01'],
    'engine':'4.7.2.stable.official.ed1daf0bf',
    'results':results,
    'handling_checks':42,'parser_scripts':int(parser[1]),'final_import':'pass',
    'prepared_meshes':len(new_files),'byte_identical_originals':len(identical),
    'invariants':invariants,'concurrent_sources_excluded':concurrent,
    'changed_files':[str(p).replace('\\','/') for p in changed],
    'hashes':{str(p).replace('\\','/'):sha(ROOT/p) for p in changed if (ROOT/p).exists()},
    'commands':{p.name:read(p) for p in EV.glob('*-command.json')},
    'checkpoint':{'path':'task-only.patch','reverse_check':'pass','main_git_index_unchanged':True,'sha256':sha(patch_path)},
    'retained_findings':['initial budget 95574/95000','sandbox Windows certificate-store denial',
        'concurrent removed _review_extra_colours.gd import interruption','concurrent challenges_client result_poll_allowed parser interruption',
        'Garage all-car preview checker rejects Electric hash with current and task-start provenance'],
    'acceptance_remaining':['reload/rebuild','owner appearance review','physical-device appearance, motion and performance'],
    'device_attachment_checked':False,'device_tested':False,'apk_built':False,'deployed':False,
}
(EV/'report.json').write_text(json.dumps(report,indent=2,allow_nan=False)+'\n')
print('KART_FINISHING: report and binary patch; reverse check passed;',len(changed),'task files')
