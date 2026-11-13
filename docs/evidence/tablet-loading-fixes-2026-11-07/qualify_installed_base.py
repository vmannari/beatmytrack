"""Isolate the exact installed e14bec client and apply only this task's fixes."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT/'build/tablet-loading-fixes-20261107'
EVIDENCE = Path(__file__).resolve().parent
BASE = ROOT/'build/race-verification-speed-20261107/frozen'
TARGET = OUT/'qualified'
resume = '--resume-after-copy' in sys.argv
assert TARGET.exists() if resume else not TARGET.exists()
TARGET.mkdir(exist_ok=resume)
copied = {}

def copy(source,destination):
    if source.is_dir():
        destination.mkdir(parents=True,exist_ok=True)
        for item in source.iterdir():
            if item.name in ('build','.gradle','__pycache__','.git','tmp','.tmp') or item.name.startswith(('~','recordings-track_')): continue
            copy(item,destination/item.name)
    else:
        destination.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(source,destination)
        copied[destination.relative_to(TARGET).as_posix()] = hashlib.sha256(destination.read_bytes()).hexdigest()

def junction(source,destination):
    assert destination.absolute().is_relative_to(TARGET.absolute())
    quote = lambda p: "'"+str(p).replace("'","''")+"'"
    subprocess.run(['powershell','-NoProfile','-Command','New-Item -ItemType Junction -Path '+quote(destination)+' -Target '+quote(source)+' | Out-Null'],check=True)

for name in (() if resume else ('game','scripts','native')):
    if name=='game':
        (TARGET/name).mkdir()
        for child in (BASE/name).iterdir():
            if child.name in ('android','tmp','.tmp') or child.name.startswith(('~','recordings-track_')): continue
            copy(child,TARGET/name/child.name)
    else: copy(BASE/name,TARGET/name)
for name in ('.gitignore','.gitattributes','godot-version.txt'): copy(BASE/name if (BASE/name).exists() else ROOT/name,TARGET/name)
copy(BASE/'backend/tests/fixtures',TARGET/'backend/tests/fixtures')
copy(BASE/'.tools/admob/android_source.zip',TARGET/'.tools/admob/android_source.zip')
junction(ROOT/'docs',TARGET/'docs')
subprocess.run(['git','init','--quiet',str(TARGET)],check=True)
subprocess.run(['git','-C',str(TARGET),'config','core.longpaths','true'],check=True)
subprocess.run(['git','-C',str(TARGET),'apply','--check',str(EVIDENCE/'runtime.patch')],check=True)
subprocess.run(['git','-C',str(TARGET),'apply',str(EVIDENCE/'runtime.patch')],check=True)
copy(ROOT/'game/track/spatial_mesh_preparation.gd',TARGET/'game/track/spatial_mesh_preparation.gd')
for name in ['test_snapshot_writer_lifecycle.gd','test_fitted_simple_cache.gd','test_initial_menu_readiness.gd','test_spatial_worker_object_ranges.gd','profile_loading_world_stages.gd']:
    copy(ROOT/'game/tests'/name,TARGET/'game/tests'/name)
(EVIDENCE/'installed-base.json').write_text(json.dumps({'source':str(BASE),'project':str(TARGET),'resumed_after_complete_copy':resume,'copied':copied},indent=2)+'\n')
print(json.dumps({'project':str(TARGET),'copied_files':len(copied),'handling_preserved':(BASE/'game/vehicle/handling_config.gd').read_bytes()==(TARGET/'game/vehicle/handling_config.gd').read_bytes()}))
