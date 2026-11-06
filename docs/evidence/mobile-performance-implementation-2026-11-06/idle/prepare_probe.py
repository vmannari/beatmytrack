from pathlib import Path
import shutil
import subprocess
import json

ROOT = Path(__file__).resolve().parents[4]
EVIDENCE = Path(__file__).resolve().parent
PRIOR = ROOT/'build/mobile-performance-review-20261106/frozen-1793977531804473800'
OWNED = ROOT/'build/mobile-performance-implementation-20261106/idle'
GAME = OWNED/'game'
GAME.mkdir(parents=True,exist_ok=True)
for source in (PRIOR/'game').iterdir():
    if source.name in ('.godot','assets'): continue
    target = GAME/source.name
    if source.is_dir(): shutil.copytree(source,target,dirs_exist_ok=True)
    else: shutil.copyfile(source,target)
def junction(source,target):
    if target.exists(): return
    assert source.resolve().is_relative_to(ROOT.resolve())
    assert target.absolute().is_relative_to(OWNED.absolute())
    cmd = "New-Item -ItemType Junction -Path '"+str(target).replace("'","''")+"' -Target '"+str(source).replace("'","''")+"' | Out-Null"
    subprocess.run(['powershell','-NoProfile','-Command',cmd],check=True)
junction(PRIOR/'game/assets',GAME/'assets')
(GAME/'.godot').mkdir(exist_ok=True)
for name in ('global_script_class_cache.cfg','uid_cache.bin','extension_list.cfg'):
    source=PRIOR/'game/.godot'/name
    if source.exists(): shutil.copyfile(source,GAME/'.godot'/name)
junction(ROOT/'game/.godot/imported',GAME/'.godot/imported')
for name in ('native','docs','backend'): junction(ROOT/name,OWNED/name)
for source in (EVIDENCE/'before/game').rglob('*.gd'):
    shutil.copyfile(source,GAME/source.relative_to(EVIDENCE/'before/game'))
app = EVIDENCE.parent/'navigation/before/game/core/app.gd'
if app.exists(): shutil.copyfile(app,GAME/'core/app.gd')
probe=(ROOT/'docs/evidence/mobile-performance-review-2026-11-06/review_header_idle.gd').read_text(encoding='utf-8')
probe=probe.replace('var phase_max: Dictionary = {}','var phase_max: Dictionary = {}\nvar stage_max: Dictionary = {}')
probe=probe.replace('var frame_began: int = Time.get_ticks_usec()','var frame_began: int = Time.get_ticks_usec()\n\tvar stage: String = str(app.header_car_cache._stage) if app.header_car_cache != null else "startup"')
probe=probe.replace('phase_max[phase] = maxf', 'stage_max[stage] = maxf(float(stage_max.get(stage,0.0)),(Time.get_ticks_usec()-frame_began)/1000.0)\n\tphase_max[phase] = maxf')
probe=probe.replace('result.max_frame_ms = phase_max','result.max_frame_ms = phase_max\n\tresult.stage_max_ms = stage_max')
(GAME/'tests/idle_attribution.gd').write_text(probe,encoding='utf-8')
(EVIDENCE/'probe-project.json').write_text(json.dumps({'project':str(GAME)},indent=2)+'\n',encoding='utf-8')
print(GAME)
