"""Capture the UI refinement without staging unrelated work or moving HEAD."""
from pathlib import Path
import os
import json
import subprocess
import hashlib
import shutil

EVIDENCE = Path(__file__).resolve().parent
ROOT = EVIDENCE.parents[2]
BEFORE = EVIDENCE/'before'
MODIFIED = [
    'game/ui/garage_page.gd','game/ui/sticker_placement.gd',
    'game/tests/test_livery_patterns.gd','game/tests/test_garage_livery.gd',
    'game/tests/test_garage_carousel.gd','game/tests/test_garage_studio.gd',
    'AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md',
]
NEW = ['game/ui/garage_livery_menu.gd','game/ui/livery_tile.gd','game/ui/livery_colour_chip.gd',
       'game/tests/bake_livery_previews.gd','docs/LIVERY_MENU_REFINEMENT.md']
NEW += [name+'.uid' for name in list(NEW) if (ROOT/(name+'.uid')).exists()]
NEW += [p.relative_to(ROOT).as_posix() for p in sorted((ROOT/'game/assets/liveries/previews_v2').rglob('*')) if p.is_file()]

def read(path): return path.read_text(encoding='utf-8-sig').replace('\r\n','\n')
def original(name): return read(BEFORE/name.replace('/','__'))
def payload(name): return (ROOT/name).read_bytes() if name.endswith('.png') else read(ROOT/name).encode()

# Only add this task's note to the checkpoint's documentation baselines;
# leave concurrent notes in the real working files alone.
owned = {name:read(ROOT/name) for name in MODIFIED}
for name in ['AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md']:
    current = read(ROOT/name)
    if name == 'AGENTS.md':
        start = current.index('## Livery menu refinement override')
        end = current.index('\n## ',start+4)
        prefix = current[start:end].strip()+'\n\n'
        owned[name] = original(name).replace('# Project agent instructions\n\n','# Project agent instructions\n\n'+prefix,1)
    else:
        prefix = next(p for p in current.split('\n\n') if p.startswith('2026-10-13 LM01-LM05'))+'\n\n'
        owned[name] = prefix+original(name)

env = os.environ.copy()
env['GIT_INDEX_FILE'] = str(EVIDENCE/'checkpoint.index')
def git(*args,input=None):
    return subprocess.check_output(['git','-C',str(ROOT),*args],env=env,input=input).decode().strip()
def stage(name,data):
    digest = git('hash-object','-w','--stdin',input=data)
    git('update-index','--add','--cacheinfo','100644',digest,name)

head = git('rev-parse','HEAD')
git('read-tree',head)
for name in MODIFIED: stage(name,original(name).encode())
baseline = git('commit-tree',git('write-tree'),'-p',head,'-m','Captured starting sources for the livery-menu refinement')
for name,content in owned.items(): stage(name,content.encode())
for name in NEW: stage(name,payload(name))
checkpoint = git('commit-tree',git('write-tree'),'-p',baseline,'-m','Refine livery browsing, colour tools and sticker placement')
ref = 'refs/codex/checkpoints/livery-menu-refinement-2026-10-13'
prior = subprocess.run(['git','-C',str(ROOT),'rev-parse','--verify',ref],env=env,capture_output=True)
git('update-ref',ref,checkpoint,prior.stdout.decode().strip() if prior.returncode == 0 else '0'*40)
patch = subprocess.check_output(['git','-C',str(ROOT),'diff','--binary',baseline,checkpoint])
(EVIDENCE/'task-only.patch').write_bytes(patch)

log_root = EVIDENCE/'logs'
log_root.mkdir(exist_ok=True)
markers = {
    'native-previews':'LIVERY_PREVIEWS: 120 captures complete',
    'livery-menu-compatibility':'Livery patterns: 355 checks, 0 failures (gl_compatibility)',
    'livery-menu-mobile':'Livery patterns: 355 checks, 0 failures (mobile)',
    'garage-livery':'Garage livery: 115 checks, 0 failures',
    'car-transition':'GARAGE_CAR_TRANSITION: 23 checks, 0 failures',
    'garage-carousel':'GARAGE_CAROUSEL: 178 checks, 0 failures',
    'script-parse':'SCRIPT_PARSE: 664 scripts, 0 failures',
}
logs = sorted((ROOT/'build/logs').glob('TestScript-*/test-script.log'),key=lambda p:p.stat().st_mtime,reverse=True)
results = {}
for name,marker in markers.items():
    source = next(p for p in logs if marker in read(p))
    shutil.copy2(source,log_root/(name+'.log'))
    results[name] = {'result':marker,'command_log':source.relative_to(ROOT).as_posix()}
receipt = {'checkpoint_commit':checkpoint,'baseline_commit':baseline,'checkpoint_ref':ref,'head_preserved':head,
           'modified_files':MODIFIED,'new_files':NEW,'results':results,
           'live_source_sha256':{name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in MODIFIED+NEW},
           'scope':'Review diff against captured starting UI sources. Shared branch/index and earlier/concurrent livery/vehicle work are retained.',
           'phone':'No physical-phone commands, interaction tests or Android export/install performed.'}
(EVIDENCE/'delivery.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'checkpoint':checkpoint,'baseline':baseline,'files':len(MODIFIED)+len(NEW),'logs':len(results)}))
