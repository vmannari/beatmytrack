from pathlib import Path
import hashlib
import json
import os
import subprocess
import sys
import time

ROOT=Path.cwd()
LAB=ROOT/'build/race-optional-work-fixes-2026-10-27'
ENGINE='C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64.exe'
label,script,mode=sys.argv[1:4]
profile=LAB/'profiles'/label
profile.mkdir(parents=True,exist_ok=True)
env={key:value for key,value in os.environ.items() if not key.startswith('BMT_')}
env.update(APPDATA=str(profile),LOCALAPPDATA=str(profile))
source=ROOT/'game'/script
text=source.read_text(encoding='utf-8')
# Existing assertions and baseline reads are unchanged. Ensure explicit offline
# configuration even when Windows treats an empty environment value as unset.
if 'func run() -> void:' in text:
    setup='\n\tvar optional_work_test_config:=ConfigFile.new()\n\toptional_work_test_config.set_value("backend","url","")\n\tassert(optional_work_test_config.save("user://backend.cfg")==OK)\n\tOS.unset_environment("BMT_API_URL")\n'
    text=text.replace('func run() -> void:','func run() -> void:'+setup,1)
for old in ['res://../build/garage-preload','res://../docs/evidence/header-car-appearance-cache-2026-10-26/',
            'res://../docs/evidence/runtime-correctness-2026-10-26','res://../docs/evidence/pause-menu',
            'res://../docs/evidence/race-demand-work-2026-10-26']:
    text=text.replace(old,'res://../build/race-optional-work-fixes-2026-10-27/outputs/'+label+'/')
probe=LAB/'checks'/(label+'.gd')
probe.parent.mkdir(parents=True,exist_ok=True)
probe.write_text(text,encoding='utf-8',newline='\n')
output=LAB/'outputs'/label
output.mkdir(parents=True,exist_ok=True)
command=[ENGINE,'--audio-driver','Dummy','--path',str(ROOT/'game'),'--script',str(probe)]
if mode=='headless':command.insert(1,'--headless')
else:command.extend(['--rendering-method',mode])
command.extend(['--','--report=res://../build/race-optional-work-fixes-2026-10-27/outputs/'+label+'/report.json',
                '--output=res://../build/race-optional-work-fixes-2026-10-27/outputs/'+label,'--drive'])
started=time.monotonic()
with (LAB/(label+'.log')).open('wb') as log:
    process=subprocess.Popen(command,env=env,stdout=log,stderr=subprocess.STDOUT)
    (LAB/(label+'-pid.json')).write_text(json.dumps(dict(pid=process.pid,command=command)),encoding='utf-8')
    try:code=process.wait(timeout=360)
    except subprocess.TimeoutExpired:
        process.kill();process.wait();code='timeout'
result=dict(command=command,pid=process.pid,exit=code,seconds=round(time.monotonic()-started,3),
            original_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),probe_sha256=hashlib.sha256(probe.read_bytes()).hexdigest())
(LAB/(label+'-execution.json')).write_text(json.dumps(result,indent=2),encoding='utf-8')
sys.stdout.reconfigure(encoding='utf-8')
print(json.dumps(result))
print((LAB/(label+'.log')).read_text(encoding='utf-8',errors='replace')[-2600:])
