"""Export a stable candidate/profile through the pinned standard entry point."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time

WORKSPACE = Path(__file__).resolve().parents[3]
OUT = WORKSPACE/'build/tablet-loading-fixes-20261107'
parser = argparse.ArgumentParser()
parser.add_argument('project',choices=['candidate','profiled','qualified','profiled-qualified'])
args = parser.parse_args()
ROOT = OUT/args.project
RUN = OUT/'exports'/args.project
RUN.mkdir(parents=True,exist_ok=True)
PROFILE = RUN/'profile'
env = os.environ.copy()
env.update(GIT_OPTIONAL_LOCKS='0',GIT_CONFIG_COUNT='1',GIT_CONFIG_KEY_0='safe.directory',GIT_CONFIG_VALUE_0=ROOT.as_posix())
original_appdata = Path(env['APPDATA'])
settings = (original_appdata/'Godot/editor_settings-4.7.tres').read_text(encoding='utf-8-sig')
android_settings = [line for line in settings.splitlines() if line.startswith('export/android/')]
assert any(line.startswith('export/android/debug_keystore = ') for line in android_settings)
godot_settings = PROFILE/'appdata/Godot'
godot_settings.mkdir(parents=True,exist_ok=True)
(godot_settings/'editor_settings-4.7.tres').write_text('[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'+'\n'.join(android_settings)+'\n')
templates = godot_settings/'export_templates'
if not templates.exists():
    target = original_appdata/'Godot/export_templates'
    quote = lambda p: "'"+str(p).replace("'","''")+"'"
    subprocess.run(['powershell','-NoProfile','-Command','New-Item -ItemType Junction -Path '+quote(templates)+' -Target '+quote(target)+' | Out-Null'],check=True)
for key in ['APPDATA','LOCALAPPDATA']:
    path = PROFILE/key.lower(); path.mkdir(parents=True,exist_ok=True); env[key] = str(path)
user = Path(env['APPDATA'])/'Circuit01Lab'; user.mkdir(exist_ok=True)
(user/'backend.cfg').write_text('[backend]\nurl=""\n')
for key in ['BMT_API_URL','BMT_DEV_AUTH_KEY','BMT_NATIVE_TRACE','BMT_NATIVE_EXTENSION']: env.pop(key,None)

def sources():
    result = {}
    for folder in ['game','native']:
        for directory,dirs,files in os.walk(ROOT/folder):
            dirs[:] = [name for name in dirs if name not in ('.godot','assets','build','.gradle')]
            for filename in files:
                if filename.startswith('~'): continue # engine-owned Windows library shadow copies
                path = Path(directory)/filename
                if path.suffix in {'.gd','.gdshader','.gdshaderinc','.tscn','.godot','.cfg','.gdextension','.cpp','.h','.java','.gradle','.so','.dll'}:
                    result[path.relative_to(ROOT).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
    return result

before = sources()
(RUN/'sources-before.json').write_text(json.dumps(before,indent=2))
command = ['powershell','-NoProfile','-ExecutionPolicy','Bypass','-File',str(ROOT/'scripts/dev.ps1'),'-Action','ExportAndroid','-AndroidPreset','Android ARM64','-QuickValidation','-CommandTimeoutSeconds','600']
started = time.monotonic()
with (RUN/'export.log').open('w',encoding='utf-8') as log:
    result = subprocess.run(command,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=2400,creationflags=subprocess.CREATE_NO_WINDOW)
after = sources()
(RUN/'sources-after.json').write_text(json.dumps(after,indent=2))
receipt = {'command':command,'exit_code':result.returncode,'seconds':time.monotonic()-started,
           'source_changes':[p for p in sorted(before.keys()|after.keys()) if before.get(p)!=after.get(p)]}
if result.returncode==0:
    apk = ROOT/'build/android/circuit01-arm64.apk'
    receipt['apk'] = {'path':str(apk),'bytes':apk.stat().st_size,'sha256':hashlib.sha256(apk.read_bytes()).hexdigest()}
    receipt['build_id'] = re.search(r'const ID: String = "([^"]+)"',(ROOT/'game/core/build_identity.gd').read_text()).group(1)
(OUT/(args.project+'-export.json')).write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps(receipt),flush=True)
raise SystemExit(result.returncode)
