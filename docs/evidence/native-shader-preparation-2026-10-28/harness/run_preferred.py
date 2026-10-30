from pathlib import Path
import hashlib,json,os,subprocess,time
ROOT=Path.cwd();LAB=ROOT/'build/native-shader-preparation-2026-10-28'
paths=['game/project.godot','game/core/build_identity.gd']
before={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in paths}
for p in paths:
    target=LAB/'generated-before'/p;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes((ROOT/p).read_bytes())
profile=LAB/'profiles/preferred';profile.mkdir(parents=True,exist_ok=True)
env={k:v for k,v in os.environ.items() if not k.startswith('BMT_')};env.update(APPDATA=str(profile),LOCALAPPDATA=str(profile))
command=['powershell','-NoProfile','-ExecutionPolicy','Bypass','-File',str(ROOT/'scripts/dev.ps1'),'-Action','CheckScript','-ScriptPath','res://ui/garage_preloaded_studio.gd','-GodotPath','C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe','-CommandTimeoutSeconds','90']
began=time.monotonic()
with (LAB/'preferred.log').open('wb') as log:
    child=subprocess.Popen(command,env=env,stdout=log,stderr=subprocess.STDOUT)
    try:code=child.wait(timeout=120)
    except subprocess.TimeoutExpired:child.kill();child.wait();code='timeout'
after={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in paths}
result=dict(command=command,exit=code,seconds=round(time.monotonic()-began,3),generated_files_before=before,generated_files_after=after,
    note='Normal dev wrapper regenerates client build metadata; excluded from task source checkpoint, never rolled back over owner work.')
(LAB/'preferred-execution.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps(result));print((LAB/'preferred.log').read_text(encoding='utf-8',errors='replace')[-1700:])
