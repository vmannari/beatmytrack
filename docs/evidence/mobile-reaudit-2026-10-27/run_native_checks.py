from pathlib import Path
import os, subprocess, json, time, sys, hashlib
sys.stdout.reconfigure(encoding='utf-8')
root=Path.cwd();lab=root/'build/re-audit-2026-10-27';results=[]
tests=['test_pause_menu','test_garage_live_entry','test_mobile_audit_fixes','test_runtime_render_lifecycle']
for name in tests:
    original=root/'game/tests'/(name+'.gd')
    source=original.read_text(encoding='utf-8')
    output='res://../build/re-audit-2026-10-27/native-outputs/'+name
    for old in ['res://../docs/evidence/pause-menu','res://../build/garage-live-entry','res://../build/mobile-audit-fixes-2026-10-26']:
        source=source.replace(old,output)
    source=source.replace('func run() -> void:','''func run() -> void:
	print("AUDIT_PID ",OS.get_process_id())
	var audit_config := ConfigFile.new(); audit_config.set_value("backend","url",""); assert(audit_config.save("user://backend.cfg")==OK)
	OS.unset_environment("BMT_API_URL")''',1)
    script=lab/'native-checks'/(name+'.gd');script.parent.mkdir(exist_ok=True);script.write_text(source,encoding='utf-8',newline='\n')
    (lab/'native-outputs'/name).mkdir(parents=True,exist_ok=True)
    profile=lab/'profiles'/('native-'+name);profile.mkdir(parents=True,exist_ok=True)
    env={k:v for k,v in os.environ.items() if not k.startswith('BMT_')};env.update(APPDATA=str(profile),LOCALAPPDATA=str(profile))
    command=['C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64.exe','--audio-driver','Dummy','--rendering-method','gl_compatibility','--path',str(root/'game'),'--script',str(script)]
    began=time.monotonic();log=lab/('native-'+name+'.log')
    with log.open('wb') as stream:
        process=subprocess.Popen(command,env=env,stdout=stream,stderr=subprocess.STDOUT)
        try:code=process.wait(timeout=240);timeout=False
        except subprocess.TimeoutExpired:process.kill();process.wait();code=process.returncode;timeout=True
    text=log.read_text(encoding='utf-8',errors='replace');lines=text.splitlines()
    summaries=[line for line in lines if any(x in line for x in ['checks','TESTS:','FAILED','FAIL:','SCRIPT ERROR','WARNING:'])]
    row={'test':name,'command':command,'pid':process.pid,'exit':code,'timed_out':timeout,'seconds':round(time.monotonic()-began,3),
        'original_sha256':hashlib.sha256(original.read_bytes()).hexdigest(),'probe_sha256':hashlib.sha256(script.read_bytes()).hexdigest(),'summary':summaries}
    results.append(row);(lab/'native-results.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
    print(json.dumps(row,ensure_ascii=False),flush=True)
