"""Task-only Git checkpoint, preserving the shared branch, real index and work.

Reconstruct the overlapping car/garage edits from the captured starting files,
so concurrent compact body-kit changes are absent from this checkpoint's diff.
"""
from pathlib import Path
import subprocess
import os
import json
import difflib
import hashlib

ROOT = Path(__file__).resolve().parents[3]
EVIDENCE = Path(__file__).resolve().parent
BEFORE = EVIDENCE / 'before'
AFTER = EVIDENCE / 'scoped-after'
AFTER.mkdir(exist_ok=True)

def read(path): return path.read_text(encoding='utf-8-sig').replace('\r\n','\n')
def initial(name): return read(BEFORE / name.replace('/','__'))
def replace(text, old, new):
    if text.count(old) != 1: raise ValueError(f'Expected one scoped anchor: {old[:70]}')
    return text.replace(old,new,1)
def section(text, start, end): return text[text.index(start):text.index(end)]

owned = {}
name = 'game/vehicle/car_visual.gd'
car = initial(name)
car = replace(car,'var simple_model: bool = false\n','var simple_model: bool = false\nvar graphics := LiveryGraphics.new()\n')
car = replace(car,'livery = value.duplicate(true) if VehicleLivery.valid(value) else VehicleLivery.defaults(vehicle_id)','livery = VehicleLivery.normalize(value,vehicle_id)')
line = '\t\t(variant.material as StandardMaterial3D).albedo_color = color.darkened(float(variant.get("darken",0.0)))\n'
car = replace(car,line,line+'\tgraphics.apply()\n')
line = '\tif batch_parts: VisualGeometry.batch_car_parts(self)\n'
car = replace(car,line,line+'\tif livery.is_empty(): livery = VehicleLivery.defaults(vehicle_id)\n\tgraphics.configure(self)\n')
owned[name] = car

name = 'game/ui/garage_page.gd'
garage, current = initial(name), read(ROOT / name)
variables = section(current,'var _customise_tab:', '\nfunc _ready()')
# The owner may append unrelated kit fields after these six task-owned fields.
variables = variables[:variables.index('var _sticker_sliders:')]+variables[variables.index('var _sticker_sliders:'):].split('\n',1)[0]+'\n'
garage = replace(garage,'var _presets: OptionButton\n','var _presets: OptionButton\n'+variables)
garage = replace(garage,'\t_presets = null\n','\t_presets = null\n\t_sticker_board = null\n\t_sticker_choice = null\n\t_sticker_sliders.clear()\n')
garage = replace(garage,'\ttools.add_child(MenuStyle.label(section.to_upper(), 20))','\tif section != "customise": tools.add_child(MenuStyle.label(section.to_upper(), 20))')
for start,end in [('func _build_customise()','func _finish_tools()'),('func _save()','func _reset()')]:
    garage = replace(garage,section(garage,start,end),section(current,start,end))
owned[name] = garage

for name in ['game/vehicle/vehicle_livery.gd','game/vehicle/vehicle_weathering.gd','game/vehicle/vehicle_weathering.gdshader','scripts/build_identity.ps1']:
    owned[name] = read(ROOT / name)
name = 'game/ui/menu_page_swipe.gd'
owned[name] = replace(initial(name),'\t\tif control is CarShowroom and control.owns_gesture(location): return true\n','\t\tif control is CarShowroom and control.owns_gesture(location): return true\n\t\tif control is StickerPlacement and control.get_global_rect().has_point(location): return true\n')

agent_note = '''## Livery patterns and hood/roof stickers override (2026-10-13)
The owner requests twenty distinct AAA-target livery patterns and stickers for hood and roof. Use the twenty original three-colour vector wraps and twelve fictional emblems, independent per-panel mouse/touch placement, size/rotation and local per-car persistence with version-one pigment migration. Replace existing opaque paint surfaces beneath dirt/snow; keep geometry/shadow budgets, actual glazing/trim, garage reflections/retained framing, concurrent body kits and canonical driving/scoring. Roof tools exist only on actual roofed cars. See `docs/LIVERY_PATTERNS_STICKERS.md` for files, paired real-car/UI/race captures, actual checks, scoped checkpoint and remaining owner/physical-phone quality acceptance.

'''
status_note = '''2026-10-13 LV01-LV06/V04/V05/G01/R01/Q01: owner twenty livery patterns and panel stickers. Original editable vector20wraps/12emblems, three pigment slots/native mouse-touch place-size-rotate/physical roofs only/version1->2 local migration. Existing opaque surfaces and weathering/clean restoration; no new geometry/draw passes, four-mask cache, canonical/PB unchanged and concurrent body-kit work retained. Compatibility333/MobileVulkan333; garage115/transition23/wash1383/models57/records54/driving72/rewind61 pass; parser644 scripts/0fail. Actual both-renderer20-car sheets/three-size UI/five-car stickers/ordinary race captures reviewed. Launcher byte-array hash and JSON/fixture issues corrected; initial graphical-only headless timeout recorded. Doctor DN2103 attached; no phone livery test/APK/fullValidate/backend/deploy/onlinewrites/performance claim. Files/commands/task-only Git checkpoint/owner-device AAA acceptance: docs/LIVERY_PATTERNS_STICKERS.md.

'''
for name,prefix in [('AGENTS.md',agent_note),('DEVELOPMENT_STATUS.md',status_note),('docs/PHASE_0_PLAN.md',status_note)]:
    original = initial(name)
    owned[name] = original.replace('# Project agent instructions\n\n','# Project agent instructions\n\n'+prefix,1) if name == 'AGENTS.md' else prefix+original
    # Preserve current concurrent notes in the real working file.
    current = read(ROOT / name)
    current = current.replace(status_note.replace('parser644','parser642'),status_note)
    if current != read(ROOT / name): (ROOT / name).write_text(current,encoding='utf-8')
    if prefix not in current:
        updated = current.replace('# Project agent instructions\n\n','# Project agent instructions\n\n'+prefix,1) if name == 'AGENTS.md' else prefix+current
        (ROOT / name).write_text(updated,encoding='utf-8')

new_files = [
    'game/vehicle/livery_catalog.gd','game/vehicle/livery_graphics.gd',
    'game/vehicle/livery_finish.gdshader','game/vehicle/livery_finish.gdshaderinc',
    'game/ui/sticker_placement.gd','game/ui/sticker_panel.gdshader',
    'game/tests/test_livery_patterns.gd','scripts/build_livery_art.py',
    'docs/LIVERY_PATTERNS_STICKERS.md',
]
new_files += [name+'.uid' for name in list(new_files) if (ROOT / (name+'.uid')).is_file()]
new_files += [p.relative_to(ROOT).as_posix() for p in sorted((ROOT/'game/assets/liveries').iterdir()) if p.is_file()]
patch = ''
for name,content in owned.items():
    destination = AFTER / name
    destination.parent.mkdir(parents=True,exist_ok=True)
    destination.write_text(content,encoding='utf-8')
    patch += ''.join(difflib.unified_diff(initial(name).splitlines(True),content.splitlines(True),fromfile='a/'+name,tofile='b/'+name))
for name in new_files:
    content = read(ROOT / name)
    patch += ''.join(difflib.unified_diff([],content.splitlines(True),fromfile='/dev/null',tofile='b/'+name))
(EVIDENCE/'task-only.patch').write_text(patch,encoding='utf-8')

if '--git' in os.sys.argv:
    env = os.environ.copy()
    env['GIT_INDEX_FILE'] = str(AFTER / 'checkpoint.index')
    def git(*args,input=None):
        return subprocess.check_output(['git','-C',str(ROOT),*args],input=input,env=env).decode().strip()
    head = git('rev-parse','HEAD')
    git('read-tree',head)
    def stage(name,data):
        digest = git('hash-object','-w','--stdin',input=data)
        git('update-index','--add','--cacheinfo','100644',digest,name)
    for name in owned: stage(name,initial(name).encode())
    baseline = git('commit-tree',git('write-tree'),'-p',head,'-m','Captured starting sources for the livery/sticker slice (pre-existing work)')
    for name,content in owned.items(): stage(name,content.encode())
    for name in new_files: stage(name,read(ROOT/name).encode())
    checkpoint = git('commit-tree',git('write-tree'),'-p',baseline,'-m','Add twenty car livery patterns and twelve local hood/roof stickers')
    ref = 'refs/codex/checkpoints/livery-stickers-2026-10-13'
    previous = subprocess.run(['git','-C',str(ROOT),'rev-parse','--verify',ref],capture_output=True,env=env)
    old_ref = previous.stdout.decode().strip() if previous.returncode == 0 else '0'*40
    git('update-ref',ref,checkpoint,old_ref)
    manifest = dict(head_unchanged=head,baseline_commit=baseline,checkpoint_commit=checkpoint,checkpoint_ref=ref,
                    modified_files=list(owned),new_files=new_files,patch='task-only.patch',
                    live_sha256={name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in [*owned,*new_files]},
                    concurrent_car_kit_changes='Preserved in live files; excluded from the task-only car/garage snapshots.',
                    validation={'livery_gl':333,'livery_mobile':333,'garage_livery':115,'garage_transition':23,'car_wash':1383,'racing_models':57,'records':54,'driving':72,'rewind':61,'parse_scripts':644,'failures':0},
                    phone='DN2103 attached; no physical-phone livery test or Android export/install.')
    (EVIDENCE/'delivery.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:manifest[k] for k in ['baseline_commit','checkpoint_commit','checkpoint_ref']}))
else:
    print(f'Prepared {len(owned)} task-owned modifications and {len(new_files)} new files; shared branch/index unchanged.')
