from pathlib import Path
import hashlib,json,os,subprocess,time
root=Path.cwd();lab=root/'build/cold-render-investigation-2026-10-27'
original=root/'game/tests/profile_runtime_correctness.gd'
source=original.read_text(encoding='utf-8').replace('res://../docs/evidence/runtime-correctness-2026-10-26','res://../build/cold-render-investigation-2026-10-27/race')
fields='''
var native_frames: Array[Dictionary]=[]
var native_last: int=0
func native_frame() -> void:
	var now: int=Time.get_ticks_usec()
	if native_last>0 and native_frames.size()<6000: native_frames.append({"utc_us":int(Time.get_unix_time_from_system()*1000000.0),"frame_us":now-native_last})
	native_last=now
'''
source=source.replace('extends SceneTree','extends SceneTree'+fields,1)
source=source.replace('func run() -> void:','''func run() -> void:
	var isolated_config:=ConfigFile.new()
	isolated_config.set_value("backend","url","")
	assert(isolated_config.save("user://backend.cfg")==OK)
	OS.unset_environment("BMT_API_URL")
	process_frame.connect(native_frame)
''',1)
source=source.replace('app.queue_free(); await process_frame','app.queue_free(); app=null\n\tfor teardown_frame: int in range(32): await process_frame')
source=source.replace('\tquit(', '\tFileAccess.open("res://../build/cold-render-investigation-2026-10-27/race/native-frames.json",FileAccess.WRITE).store_string(JSON.stringify(native_frames))\n\tquit(')
probe=lab/'race_probe.gd';probe.write_text(source,encoding='utf-8',newline='\n')
profile=lab/'profiles/race';profile.mkdir(parents=True,exist_ok=True);(lab/'race').mkdir(parents=True,exist_ok=True)
env={k:v for k,v in os.environ.items() if not k.startswith('BMT_')};env.update(APPDATA=str(profile),LOCALAPPDATA=str(profile))
command=['C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64.exe','--audio-driver','Dummy','--rendering-method','gl_compatibility','--path',str(root/'game'),'--script',str(probe)]
began=time.monotonic()
with (lab/'race.log').open('wb') as log,(lab/'race-native.jsonl').open('wb') as native:
 p=subprocess.Popen(command,env=env,stdout=log,stderr=subprocess.STDOUT)
 (lab/'race-pid.json').write_text(json.dumps(dict(pid=p.pid,command=command)),encoding='utf-8')
 sampler=subprocess.Popen([str(lab/'sampler.exe'),str(p.pid),str(os.getpid()),'170'],env=env,stdout=native,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
 try:code=p.wait(timeout=240)
 except subprocess.TimeoutExpired:p.kill();p.wait();code='timeout'
 sampler.wait(timeout=20)
result=dict(command=command,pid=p.pid,exit=code,seconds=round(time.monotonic()-began,3),original_sha256=hashlib.sha256(original.read_bytes()).hexdigest(),probe_sha256=hashlib.sha256(probe.read_bytes()).hexdigest())
(lab/'race-execution.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps(result));print((lab/'race.log').read_text(encoding='utf-8',errors='replace')[-1600:])
