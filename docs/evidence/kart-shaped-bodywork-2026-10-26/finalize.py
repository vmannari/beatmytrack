"""Audit the bodywork pass and prepare a scoped binary Git review patch."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import subprocess

EV = Path(__file__).resolve().parent
ROOT = EV.parents[2]
BASE = EV/'before'
TAG = 'KART-SHAPED-BODYWORK-20261026'
def read(path): return json.loads(path.read_text(encoding='utf-8-sig'))
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()

results = {}
jobs = ['before-gl_compatibility','draft-gl_compatibility','bodywork-draft-gl_compatibility','bodywork-gl_compatibility',
        'model-gl_compatibility','bodywork-view-gl_compatibility','native-gl_compatibility',
        'model-mobile','bodywork-view-mobile','native-mobile','retained-gl_compatibility','shape-gl_compatibility',
        'construction-gl_compatibility','fit-gl_compatibility','proportions-gl_compatibility']
for job in jobs:
    result = read(EV/job/'report.json')
    assert result['failures']==0, job
    results[job] = result
original = read(EV/'bodywork-before-gl_compatibility/report.json')
assert original['checks']==16 and original['failures']==10
assert 'KART_TESTS: 42 checks, 0 failures' in (EV/'handling-gl_compatibility.log').read_text(encoding='utf-8-sig')
parse = re.search(r'SCRIPT_PARSE: (\d+) scripts, 0 failures',(EV/'parser-gl_compatibility.log').read_text(encoding='utf-8-sig'))
assert parse
assert 'ERROR:' not in (EV/'import-gl_compatibility.log').read_text(encoding='utf-8-sig')
assert 'LIVERY_PREVIEWS: 49 captures complete' in (EV/'liveries-gl_compatibility.log').read_text(encoding='utf-8-sig')
assert 'GARAGE_CAR_BAKE kart 0' in (EV/'garage-template-gl_compatibility.log').read_text(encoding='utf-8-sig')

assets = Path('game/assets/vehicles/kart_refined_v1')
manifest = read(ROOT/assets/'manifest.json')
old_manifest = read(BASE/assets/'manifest.json')
new_files = {m['file'] for m in manifest['meshes']}
old_files = {m['file'] for m in old_manifest['meshes']}
assert {p.name for p in (ROOT/assets).glob('*.res')}==new_files
identical = [name for name in new_files&old_files if sha(ROOT/assets/name)==sha(BASE/assets/name)]
assert len(new_files)==292 and len(identical)==250
for field, name in [('model_sha256','kart_model.gd'),('detail_sha256','kart_detail.gd'),('bodywork_sha256','kart_bodywork.gd'),
                    ('geometry_sha256','kart_geometry.gd'),('driver_sha256','kart_driver.gd'),('helmet_sha256','kart_helmet.gd')]:
    assert manifest[field]==sha(ROOT/'game/vehicle'/name)
invariants = {}
concurrent = {}
for name in ['kart_geometry.gd','kart_driver.gd','kart_helmet.gd','handling_config.gd','vehicle_simulation.gd']:
    path = Path('game/vehicle')/name
    assert sha(ROOT/path)==sha(BASE/path), str(path)
    invariants[str(path)] = sha(ROOT/path)
for path in [Path('game/resources/cars/kart.tres'),Path('game/ui/garage_customisation_camera.gd')]:
    assert sha(ROOT/path)==sha(BASE/path), str(path)
    invariants[str(path)] = sha(ROOT/path)
for name in ['game/vehicle/car_visual.gd','game/ui/profile_car.gd']:
    if sha(ROOT/name)!=sha(BASE/name): concurrent[name] = {'before':sha(BASE/name),'after':sha(ROOT/name),'excluded':True}
for i in range(1,5):
    path = Path(f'game/assets/vehicles/racing_simple_v1/kart_shadow_{i}.res')
    assert sha(ROOT/path)==sha(BASE/path)

def add_block(path, text):
    target = ROOT/path
    raw = re.sub(rb'(?ms)^<!-- '+TAG.encode()+rb' -->\r?\n.*?^<!-- /'+TAG.encode()+rb' -->\r?\n(?:\r?\n)?',b'',target.read_bytes())
    baseline = BASE/path
    baseline.parent.mkdir(parents=True,exist_ok=True)
    baseline.write_bytes(raw)
    newline = b'\r\n' if b'\r\n' in raw else b'\n'
    target.write_bytes((f'<!-- {TAG} -->\n{text}\n<!-- /{TAG} -->\n\n').encode().replace(b'\n',newline)+raw)

summary = ('## Kart bumper, tank and bodywork shape correction (2026-10-26)\n'
    'KSB01-KSB03/V02-V05/R01/G01/Q01: Owner rejects overly smooth forms. Formed planes, narrow edge rolls, clipped bumper corners/lower lip and defined pod/Nassau shoulders replace inflated cross-sections. '
    'Actual fuel tank narrows through shaped shoulders into a bevelled filler cap; airbox has defined walls/lid. Inlays, pod strips, sockets and airbox seal fit the actual new triangles. '
    'Independent16 checks pass; exact previous sources fail10/16. Full94870to87136/simple31506to30292 retain95000 cap;292 meshes include250 exact originals, four wheel shadows exact. '
    'Model88/88, tank-cutaway18/18, actual Garage-race16/16, retained160/shape38/construction32/fit32/proportions24/handling42/parser'+parse[1]+' and import pass. '
    'Catalogue/news/Garage/header/all49 photos and only the kart Garage template refreshed. First native check exposes old template references; filtered bake and direct-versus-Garage geometry guard correct it. '
    'Runtime scope is kart model/detail/new bodywork helper; driver/helmet/config/simulation/camera stay exact. '
    'Sources, commands, native views, hashes and scoped patch: docs/KART_SHAPED_BODYWORK_2026_10_26.md and docs/evidence/kart-shaped-bodywork-2026-10-26/report.json. '
    'This supersedes the earlier smooth shell shapes only. Reload and owner/device shape/motion/cost acceptance remain. No device attachment check/test, APK, auth/purchase, live mutation, deployment, main-index staging/commit/merge or owner-process restart; concurrent work preserved.')
for path in [Path('AGENTS.md'),Path('DEVELOPMENT_STATUS.md'),Path('docs/PHASE_0_PLAN.md')]: add_block(path,summary)
add_block(Path('licenses/ASSETS.md'),'## Original formed kart bodywork\n2026-10-26: Original authored bumper/lip, sidepod/Nassau, fuel-tank and airbox meshes with broad design planes and small edge rolls. Existing fictional identity and CompactFinish materials; no external model, generated media, new texture or shader. Prepared native geometry, kart Garage template and existing picture locations refreshed. Provenance: docs/KART_SHAPED_BODYWORK_2026_10_26.md.')

paths = {assets/name for name in old_files|new_files|{'manifest.json'}}
paths.update(p.relative_to(ROOT) for p in (ROOT/'game/assets/liveries/previews_v2/kart').glob('*.png'))
paths.update(Path(p) for p in ['game/vehicle/kart_model.gd','game/vehicle/kart_detail.gd','game/vehicle/kart_bodywork.gd','game/vehicle/kart_bodywork.gd.uid',
    'game/tests/test_kart_bodywork.gd','game/tests/test_kart_bodywork.gd.uid','game/tests/bake_kart_model.gd','game/tests/test_kart_model.gd',
    'game/tests/bake_kart_finishing_art.gd','game/tests/bake_garage_cars.gd','game/tests/test_kart_refinement_ui.gd',
    'game/assets/garage/cars_v1/kart.scn','game/assets/vehicles/racing_simple_v1/kart_shadow_0.res',
    'game/assets/menu/kart_illustration_v1.png','game/assets/news/vehicles/kart.png','game/assets/menu/header_cars_v1/kart.png',
    'game/assets/garage/previews_v1/kart.png','game/assets/garage/previews_v1/provenance.json',
    'AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md','licenses/ASSETS.md','docs/KART_SHAPED_BODYWORK_2026_10_26.md'])
changed = sorted(p for p in paths if (ROOT/p).exists()!=(BASE/p).exists() or ((ROOT/p).exists() and sha(ROOT/p)!=sha(BASE/p)))
review = ROOT/'build/kart-shaped-bodywork/review'
assert not review.exists()
index_hash = sha(ROOT/'.git/index')
for tree,source in [('before',BASE),('after',ROOT)]:
    for path in changed:
        if not (source/path).exists(): continue
        dest = review/tree/path
        dest.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(source/path,dest)
diff = subprocess.run(['git','diff','--no-index','--binary','--no-renames','--','before','after'],cwd=review,capture_output=True)
assert diff.returncode==1
patch = diff.stdout.replace(b'a/before/',b'a/').replace(b'b/after/',b'b/').replace(b'a/after/',b'a/').replace(b'b/before/',b'b/')
patch_path = EV/'task-only.patch'
patch_path.write_bytes(patch)
subprocess.run(['git','init','-q'],cwd=review/'after',check=True)
checked = subprocess.run(['git','apply','--reverse','--check','--whitespace=error',str(patch_path)],cwd=review/'after',capture_output=True)
assert checked.returncode==0, checked.stderr.decode()
assert sha(ROOT/'.git/index')==index_hash
report = {'requirements':['KSB01','KSB02','KSB03','V02-V05','R01','G01','Q01'],
    'engine':'4.7.2.stable.official.ed1daf0bf','results':results,'previous_shapes':original,'handling_checks':42,
    'parser_scripts':int(parse[1]),'final_import':'pass','active_meshes':292,'exact_original_meshes':250,
    'source_invariants':invariants,'concurrent_sources':concurrent,
    'changed_files':[str(p).replace('\\','/') for p in changed],
    'hashes':{str(p).replace('\\','/'):sha(ROOT/p) for p in changed if (ROOT/p).exists()},
    'commands':{p.name:read(p) for p in EV.glob('*-command.json')},
    'checkpoint':{'path':'task-only.patch','sha256':sha(patch_path),'reverse_and_whitespace_check':'pass','main_index_unchanged':True},
    'retained_findings':['exact previous shapes fail10/16','old Garage template referenced retired rounded pod meshes; rebuilt only kart',
        'initial native comparison counted concurrent progressive-opening copies; exact equality retained after preparation',
        'transient concurrent facade property error corrected independently','native ObjectDB shutdown warnings and startup hitches retained; allocation source unestablished'],
    'concurrent_presentation_sources':read(EV/'concurrent-presentation-sources.json'),
    'remaining_acceptance':['reload/rebuild','owner shape review','physical-device appearance, motion and performance'],
    'device_attachment_checked':False,'device_tested':False,'apk_built':False,'deployed':False}
(EV/'report.json').write_text(json.dumps(report,indent=2,allow_nan=False)+'\n')
print('KART_SHAPED_BODYWORK:',len(changed),'task files; report and binary patch checked')
