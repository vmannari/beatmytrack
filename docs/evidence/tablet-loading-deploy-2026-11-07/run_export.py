"""Pinned dev export with private offline test data and existing signing setup."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time

ROOT = Path(__file__).resolve().parent / 'isolated-accepted'
OUT = Path(__file__).resolve().parent
PROFILE = OUT/'profile'
env = os.environ.copy()
env['GIT_OPTIONAL_LOCKS'] = '0'
# Trust only this task-owned private repository for this build process.
config_count=int(env.get('GIT_CONFIG_COUNT','0'))
env['GIT_CONFIG_COUNT']=str(config_count+1)
env['GIT_CONFIG_KEY_'+str(config_count)]='safe.directory'
env['GIT_CONFIG_VALUE_'+str(config_count)]=ROOT.as_posix()
original_appdata = Path(env['APPDATA'])
settings = (original_appdata/'Godot/editor_settings-4.7.tres').read_text(encoding='utf-8-sig')
android_settings = [line for line in settings.splitlines() if line.startswith('export/android/')]
assert any(line.startswith('export/android/debug_keystore = ') for line in android_settings)
godot_settings = PROFILE/'appdata/Godot'
godot_settings.mkdir(parents=True,exist_ok=True)
(godot_settings/'editor_settings-4.7.tres').write_text('[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'+ '\n'.join(android_settings)+'\n',encoding='utf-8')
templates = godot_settings/'export_templates'
if not templates.exists():
    target = original_appdata/'Godot/export_templates'
    command = "New-Item -ItemType Junction -Path '"+str(templates).replace("'","''")+"' -Target '"+str(target).replace("'","''")+"' | Out-Null"
    subprocess.run(['powershell','-NoProfile','-Command',command],check=True)
for key in ['APPDATA','LOCALAPPDATA']:
    destination = PROFILE/key.lower()
    destination.mkdir(parents=True,exist_ok=True)
    env[key] = str(destination)
user = Path(env['APPDATA'])/'Circuit01Lab'
user.mkdir(exist_ok=True)
(user/'backend.cfg').write_text('[backend]\nurl=""\n',encoding='utf-8')
for key in ['BMT_API_URL','BMT_DEV_AUTH_KEY','BMT_NATIVE_TRACE','BMT_NATIVE_EXTENSION']:
    env.pop(key,None)

def sources():
    result={}
    for folder in ['game','native']:
        for path in (ROOT/folder).rglob('*'):
            name=path.relative_to(ROOT).as_posix()
            if '/.godot/' in name or '/android/build/' in name or '/assets/' in name: continue
            if path.is_file() and path.suffix in {'.gd','.gdshader','.gdshaderinc','.tscn','.godot','.cfg','.gdextension','.cpp','.h','.java','.gradle','.so','.dll'}:
                result[name]=hashlib.sha256(path.read_bytes()).hexdigest()
    return result

before=sources()
(OUT/'sources-before.json').write_text(json.dumps(before,indent=2),encoding='utf-8')
for relative in ['game/core/build_identity.gd','game/project.godot']:
    copy=OUT/'before'/relative
    copy.parent.mkdir(parents=True,exist_ok=True)
    copy.write_bytes((ROOT/relative).read_bytes())
command=['powershell','-NoProfile','-ExecutionPolicy','Bypass','-File',str(ROOT/'scripts/dev.ps1'),'-Action','ExportAndroid','-AndroidPreset','Android ARM64','-QuickValidation','-CommandTimeoutSeconds','600']
started=time.monotonic()
with (OUT/'export.log').open('w',encoding='utf-8') as log:
    result=subprocess.run(command,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=2400,creationflags=subprocess.CREATE_NO_WINDOW)
after=sources()
(OUT/'sources-after.json').write_text(json.dumps(after,indent=2),encoding='utf-8')
record=dict(command=command,exit_code=result.returncode,elapsed_seconds=time.monotonic()-started,profile=str(PROFILE),
            source_changes=[name for name in sorted(before.keys()|after.keys()) if before.get(name)!=after.get(name)])
apk=ROOT/'build/android/circuit01-arm64.apk'
if result.returncode==0:
    record['apk']={'path':str(apk),'bytes':apk.stat().st_size,'sha256':hashlib.sha256(apk.read_bytes()).hexdigest()}
    record['build_id']=re.search(r'const ID: String = \"([^\"]+)\"',(ROOT/'game/core/build_identity.gd').read_text()).group(1)
(OUT/'export-result.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
print(json.dumps(record),flush=True)
raise SystemExit(result.returncode)
