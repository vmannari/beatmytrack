"""Audit the driver revision and make an isolated, task-only Git checkpoint."""
from pathlib import Path
import hashlib
import json
import math
import os
import re
import shutil
import subprocess

EV = Path(__file__).resolve().parent
ROOT = EV.parents[2]
BEFORE = EV/'before'
ASSETS = Path('game/assets/vehicles/kart_refined_v1')
DOC = Path('docs/KART_DRIVER_SHAPE_2026_10_25.md')
TAG = 'KART-DRIVER-SHAPE-20261025'

def read(p): return json.loads(Path(p).read_text(encoding='utf-8-sig'))
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def clean(value):
    if isinstance(value,float) and not math.isfinite(value): return None
    if isinstance(value,dict): return {k:clean(v) for k,v in value.items()}
    if isinstance(value,list): return [clean(v) for v in value]
    return value
def save(p,value): Path(p).write_bytes((json.dumps(clean(value),indent=2,allow_nan=False)+'\n').encode())

results = {name:read(EV/name/'report.json') for name in ['shape','construction','fit','proportions','model','model-mobile','retained','native','native-mobile','art']}
assert all(value['failures']==0 for value in results.values())
baseline = read(EV/'shape-before/report.json')
assert baseline['checks']==38 and baseline['failures']==32
parser = re.search(r'SCRIPT_PARSE: (\d+) scripts, 0 failures',(EV/'parser.log').read_text(encoding='utf-8-sig'))
assert parser
assert 'KART_TESTS: 42 checks, 0 failures' in (EV/'handling.log').read_text(encoding='utf-8-sig')
assert '49 actual model captures' in (EV/'liveries.log').read_text(encoding='utf-8-sig')
assert 'NEWS PHOTO FRAMING: 1 cars, 0 failures' in (EV/'news.log').read_text(encoding='utf-8-sig')
unchanged = {}
concurrent = []
allowed_concurrent = {'game/vehicle/vehicle_simulation.gd','game/vehicle/handling_config.gd','game/resources/cars/electric.tres','game/ui/garage_customisation_camera.gd'}
for rel,value in read(EV/'invariants-before.json').items():
    current = sha(ROOT/rel)
    if current==value: unchanged[rel]=current
    else:
        assert rel in allowed_concurrent,rel
        concurrent.append({'path':rel,'before':value,'after':current,'excluded_from_checkpoint':True})
for file in ['kart_model.gd','kart_helmet.gd','kart_geometry.gd']:
    rel=Path('game/vehicle')/file
    assert sha(ROOT/rel)==sha(BEFORE/rel)
old_driver=(BEFORE/'game/vehicle/kart_driver.gd').read_text()
driver=(ROOT/'game/vehicle/kart_driver.gd').read_text()
assert old_driver.split('static func torso_point(')[0]==driver.split('static func torso_point(')[0]
for token in ['"Collar"','"BalaclavaNeck"','"RaceBoot"','"BootSole"','"RacingGlove"','"GloveGrip"','head.position.y']:
    assert [line for line in old_driver.splitlines() if token in line]==[line for line in driver.splitlines() if token in line]
manifest=read(ROOT/ASSETS/'manifest.json')
old_manifest=read(BEFORE/ASSETS/'manifest.json')
for key,file in [('model_sha256','kart_model.gd'),('driver_sha256','kart_driver.gd'),('helmet_sha256','kart_helmet.gd'),('geometry_sha256','kart_geometry.gd')]:
    assert manifest[key]==sha(ROOT/'game/vehicle'/file)
current={m['file'] for m in manifest['meshes']}
previous={m['file'] for m in old_manifest['meshes']}
assert current=={p.name for p in (ROOT/ASSETS).glob('*.res')}
identical=[name for name in current&previous if sha(ROOT/ASSETS/name)==sha(BEFORE/ASSETS/name)]
assert len(current)==254 and len(identical)==222
before_fit=read(EV/'meshes-before-panel-fit.json')
panel_changes=[name for name in current if sha(ROOT/ASSETS/name)!=before_fit[name]]
assert len(panel_changes)==8 # two detail levels, two chest panels and two cuffs
for i in range(1,5):
    rel=Path(f'game/assets/vehicles/racing_simple_v1/kart_shadow_{i}.res')
    assert sha(ROOT/rel)==sha(BEFORE/rel)
photos=sorted((ROOT/'game/assets/liveries/previews_v2/kart').glob('*.png'))
assert len(photos)==49 and all(sha(p)!=sha(BEFORE/p.relative_to(ROOT)) for p in photos)
for value in results['construction']['measurements'].values():
    assert value['unmatched_suit_edges']==0 and value['inconsistent_suit_edges']==0 and value['helmet_rays_covered']==9
receipts={name:read(EV/(name+'-command.json')) for name in ['shape','model','model-mobile','native','native-mobile','handling','parser']}
assert all(v['shared_sources_before']==v['shared_sources_after'] for v in receipts.values())

def strip(raw):
    return re.sub(rb'(?ms)^<!-- '+TAG.encode()+rb' -->\r?\n.*?^<!-- /'+TAG.encode()+rb' -->\r?\n(?:\r?\n)?',b'',raw)
def block(path,text,append=False):
    p=ROOT/path
    raw=strip(p.read_bytes())
    nl=b'\r\n' if b'\r\n' in raw else b'\n'
    addition=(f'<!-- {TAG} -->\n{text}\n<!-- /{TAG} -->\n\n').encode().replace(b'\n',nl)
    p.write_bytes(raw+nl+addition if append else addition+raw)

summary=(
    '## Kart driver anatomical form and fabric correction (2026-10-25)\n'
    'KDS01-KDS03/V02-V05/R01/G01/Q01: Owner rejects the rubber-like body. Shape a separate ribcage/waist, shallow paired chest planes and sloped shoulders into a narrow collar; two long-bone arm axes meet through a short elbow return. Elliptical biceps/forearms, tapered wrists, thighs/calves and raised knee cloth replace uniform round tubes. Matte fabric, fitted chest/knee panels, shoulder yokes and cuff bands complete the suit. '
    f'Shape38, construction32, fit32, proportions24, model86Compatibility/86desktopMobile, retained172, actual Garage-race15/15, kart42 and parser{parser[1]} pass. Exact original-source38checks/32fail retained. '
    'Full/simple94928/29374 triangles retain the95000 cap. Prepared254 resources include222 exact originals; body shadow and catalogue/news/all49 photos refreshed. Initial subtle draft and panel-fit review are preserved; chest panels avoid the shoulder openings and cuff sampling matches the sleeve rings. Helmet/short neck, seat mounts, hand/foot locations, kart assembly/config and original regression assertions remain. Commands, native views, hashes and scoped Git checkpoint: docs/KART_DRIVER_SHAPE_2026_10_25.md and docs/evidence/kart-driver-shape-2026-10-25/report.json. Reload and owner/device appearance/motion/cost acceptance remain. No device attachment check/test, APK, purchase, live mutation, deployment or owner-process restart; concurrent work preserved.'
)
shared=[Path(p) for p in ['AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md','licenses/ASSETS.md']]
for p in shared[:3]: block(p,summary)
block(shared[3],'## Original kart driver anatomical suit revision\n2026-10-25: Original authored seated human-form torso, shaped bent limbs and fitted fabric panels/cuffs. Matte StandardMaterial3D fabric uses no external model, bitmap or shader. Existing fictional identity, helmet and kart retained. Native prepared meshes, shadow and catalogue/news/49 photos regenerated. Provenance/evidence: docs/KART_DRIVER_SHAPE_2026_10_25.md.',append=True)
doc=f'''# Kart driver shape correction — 2026-10-25

The owner rejects the driver's rubber-like body and asks for proper shapes. This revision addresses KDS01-KDS03 / V02-V05 / R01 / G01 / Q01.

| Requirement | Result |
| --- | --- |
| KDS01: recognisable seated anatomy | The torso has a narrower waist, broader ribcage, shallow paired chest planes, sloped shoulders and a narrow collar base. Sleeves follow two long-bone axes joined through a short tangent-continuous elbow return. Upper arms, elbows, forearms and wrists have distinct elliptical sections. Thighs, knees, calves and ankles have separate volumes. Existing hand/boot locations and seated leg proportions remain. |
| KDS02: tailored cloth | Roughness 1.0 and metallic specular 0.04 replace the previous rubber helper. Dark chest/knee panels, small shoulder yokes, cuff bands and shallow compression folds belong to the suit. The main watertight torso/limb joins remain. Face-centre rays validate actual panel/cuff backing against the actual suit triangles. |
| KDS03: production assets and regressions | Both native desktop renderers show the prepared production model. Matching body shadow, catalogue/news art and all49 appearance photos are regenerated/imported. Actual Garage/race presentation and retained construction, seat fit, proportions, mechanical and kart checks pass. |

Matched native views: [before front](evidence/kart-construction-fixes-2026-10-25/model/full-driver.png), [after front](evidence/kart-driver-shape-2026-10-25/model/full-driver.png); [before side](evidence/kart-construction-fixes-2026-10-25/model/full-driver-side.png), [after side](evidence/kart-driver-shape-2026-10-25/model/full-driver-side.png); [simple model](evidence/kart-driver-shape-2026-10-25/model-mobile/simple-driver.png); [actual Garage](evidence/kart-driver-shape-2026-10-25/native/garage-1280.png), [actual race](evidence/kart-driver-shape-2026-10-25/native/race.png).

Actual tests: new shape **38**, retained construction **32**, fit **32**, proportions **24**, model **86/86 Compatibility/desktop Mobile**, mechanical **172**, actual Garage/race **15/15**, kart handling **42**, and parser **{parser[1]}** scripts, all with zero failures. Exact task-start driver reloaded only in isolated process memory gives **38 checks/32 expected failures**. New measurements inspect the actual mesh widths/sections, actual opaque material and actual cloth backing; they do not call the authoring profile. Old assertions/tolerances remain unchanged.

The first draft's limb sections and shoulder silhouette remained too soft in native review; the final form narrows the neck base, introduces the short elbow return and more clearly elliptical/tapered sections. A later panel review found chest strips extending over the torso's shoulder openings and mismatched cuff/sleeve sampling. Chest strips now stop before those openings, and cuff columns match the existing sleeve rings. The independent face backing audit is retained. First images and full verification are archived in draft-first and before-panel-fit. All meshes except the eight chest/cuff resources are byte-identical across that last panel adjustment. An initial direct PowerShell script call was refused by local execution policy; all actual native runs then use the standard Bypass wrapper through pinned scripts/dev.ps1.

Visible detailed/simple triangles: **94,928/29,374**, below the unchanged95,000 detailed cap. Prepared meshes: **254**, with **222 byte-identical** originals; ten prior torso/limb resources retire,26 new resources appear and six common zipper/piping resources change. Retired originals are retained under before and retired-meshes. Body shadow: **{manifest['shadows'][0]['triangles']}** triangles. Four wheel shadow binaries remain identical. No new textures, shaders, per-frame work, lights or external assets are introduced.

Runtime source scope is game/vehicle/kart_driver.gd. game/tests/test_kart_driver_shape.gd adds the review regression. Exact helmet, kart assembly, geometry helper, corrected seat attachments, driver neck pose, hand/boot locations, production camera and kart configuration are preserved. Shared source hashes and allowed concurrent changes are recorded and excluded from the task checkpoint. The shared sources remain stable during the recorded final native/handling/parser commands. Native startup hitch logs are retained; no frame-pacing/device-performance claim is made.

Actual commands, each with per-job arguments, exit codes, logs and shared-source hashes:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-shape-2026-10-25/run.ps1 -Job draft
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-shape-2026-10-25/verify.ps1 -Phase draft
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-shape-2026-10-25/run.ps1 -Job bake
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-shape-2026-10-25/verify.ps1 -Phase final
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/kart-driver-shape-2026-10-25/verify.ps1 -Phase all
python docs/evidence/kart-driver-shape-2026-10-25/finalize.py
```

The all phase reruns the exact old-source comparison, all final tests/art/import/handling/parser jobs, then model and actual Garage/race in desktop Vulkan Mobile. Engine4.7.2 is pinned by scripts/dev.ps1. APPDATA/LOCALAPPDATA are isolated under build/kart-driver-shape. The existing missing Android build-tools warning is retained; this task does not build an APK.

The isolated Git checkpoint uses exact task-start source/assets and current shared documents with only this task block removed. Its binary patch passes whitespace and reverse-application checks. The main Git index and concurrent work are untouched.

Client reload and owner appearance acceptance remain. No device attachment check/test, APK build/install, real authentication/purchase, live mutation/deployment or owner-process restart was performed. Desktop Mobile is a desktop Vulkan test; physical-device appearance, motion and cost remain untested.
'''
(ROOT/DOC).write_bytes(doc.encode())
sources=[Path(p) for p in ['game/vehicle/kart_driver.gd','game/tests/test_kart_driver_shape.gd','game/tests/test_kart_driver_shape.gd.uid']]
files=sources+shared+[DOC,ASSETS/'manifest.json']+[ASSETS/name for name in sorted(current)]+[p.relative_to(ROOT) for p in photos]
files += [Path('game/assets/menu/kart_illustration_v1.png'),Path('game/assets/news/vehicles/kart.png')]+[Path(f'game/assets/vehicles/racing_simple_v1/kart_shadow_{i}.res') for i in range(5)]
save(EV/'source-asset-hashes.json',{p.as_posix():sha(ROOT/p) for p in files})
checkpoint=ROOT/'build/kart-driver-shape/checkpoint'
assert not checkpoint.exists()
checkpoint.mkdir(parents=True)
index_hash=sha(ROOT/'.git/index')
env={k:v for k,v in os.environ.items() if k not in ['GIT_DIR','GIT_WORK_TREE','GIT_INDEX_FILE']}
def git(*args): return subprocess.run(['git','-c','core.autocrlf=false','-c','user.name=Codex','-c','user.email=codex@local.invalid','-C',str(checkpoint),*args],env=env,check=True,capture_output=True,text=True).stdout.strip()
def copy(source,relative):
    target=checkpoint/relative
    target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(source,target)
git('init','--quiet')
copy(ROOT/'.gitattributes',Path('.gitattributes'))
for p in BEFORE.rglob('*'):
    if p.is_file(): copy(p,p.relative_to(BEFORE))
for p in shared:
    target=checkpoint/p
    target.parent.mkdir(parents=True,exist_ok=True)
    target.write_bytes(strip((ROOT/p).read_bytes()))
git('add','--all')
git('commit','--quiet','-m','Exact task-start kart driver and current shared documentation baseline')
base=git('rev-parse','HEAD')
for name in previous-current:
    p=(checkpoint/ASSETS/name).resolve()
    assert p.parent==(checkpoint/ASSETS).resolve()
    p.unlink()
for p in files: copy(ROOT/p,p)
git('add','--all')
git('diff','--cached','--check')
git('commit','--quiet','-m','Shape the seated kart driver and tailor the racing suit')
commit=git('rev-parse','HEAD')
git('diff','--binary','--output='+str(EV/'task.patch'),'HEAD~1','HEAD')
git('apply','--reverse','--check',str(EV/'task.patch'))
assert not git('status','--porcelain') and sha(ROOT/'.git/index')==index_hash
(EV/'checkpoint-stat.txt').write_bytes((git('show','--stat','--oneline','HEAD')+'\n').encode())
save(EV/'report.json',{'date':'2026-10-25','requirements':['KDS01','KDS02','KDS03','V02','V03','V04','V05','R01','G01','Q01'],'results':results,'original_source_regression':baseline,'parser_scripts':int(parser[1]),'kart_handling':{'checks':42,'failures':0},'prepared':{'resources':len(current),'byte_identical':len(identical),'retired':sorted(previous-current),'added':sorted(current-previous),'changed_same_key':len(current&previous)-len(identical),'final_panel_adjustment_changed_only':panel_changes,'body_shadow':manifest['shadows'][0],'wheel_shadows_identical':True},'unchanged_sources':unchanged,'concurrent_sources':concurrent,'shared_source_receipts':receipts,'art':{'appearance_photos':49,'all_photo_hashes_changed':True,'news':read(EV/'news/framing.json'),'import_log':'import.log'},'review_iterations':['draft-first','before-panel-fit'],'desktop_startup_hitch_ms':{name:re.findall(r'RACE_HITCH frame_ms=([0-9.]+)',(EV/(name+'.log')).read_text(encoding='utf-8-sig')) for name in ['native','native-mobile']},'commands':'run.ps1, verify.ps1 and *-command.json','hashes':'source-asset-hashes.json','checkpoint':{'repository':str(checkpoint),'base':base,'commit':commit,'patch':'task.patch','sha256':sha(EV/'task.patch'),'whitespace_check':'passed','reverse_application_check':'passed','normal_index_unchanged':True},'remaining':['Client reload','Owner appearance acceptance','Physical-device appearance/motion/cost acceptance'],'not_performed':['Device attachment check/test','APK','Real authentication/purchase','Live mutation/deployment','Owner-process restart']})
print(json.dumps({'checkpoint':commit,'parser_scripts':int(parser[1]),'prepared':len(current),'unchanged_meshes':len(identical),'checks':{name:value['checks'] for name,value in results.items()}},indent=2))
