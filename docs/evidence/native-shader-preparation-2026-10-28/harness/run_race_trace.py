from pathlib import Path
import hashlib,json,os,subprocess,time
ROOT=Path.cwd();LAB=ROOT/'build/native-shader-preparation-2026-10-28'
label='race-trace';output=LAB/label;output.mkdir(exist_ok=True)
profile=LAB/'profiles'/label;profile.mkdir(parents=True,exist_ok=True)
env={k:v for k,v in os.environ.items() if not k.startswith('BMT_')}
env.update(APPDATA=str(profile),LOCALAPPDATA=str(profile),BMT_PREP_MODE='trace',BMT_PREP_JOBS=str(output/'jobs'),
    BMT_PREP_BINARIES=str(output/'binaries'),BMT_PREP_REPORT=str(output/'native-report.json'))
source=(ROOT/'game/tests/profile_runtime_correctness.gd').read_text(encoding='utf-8')
source=source.replace('res://../docs/evidence/runtime-correctness-2026-10-26','res://../build/native-shader-preparation-2026-10-28/race-trace')
source=source.replace('extends SceneTree','''extends SceneTree
var native_spans: Array[Dictionary]=[]
var utc_epoch: int=0
var monotonic_epoch: int=0
func stamp() -> int: return utc_epoch+Time.get_ticks_usec()-monotonic_epoch
''',1)
source=source.replace('func run() -> void:','''func run() -> void:
	utc_epoch=int(Time.get_unix_time_from_system()*1000000.0);monotonic_epoch=Time.get_ticks_usec()
	var config:=ConfigFile.new();config.set_value("backend","url","");assert(config.save("user://backend.cfg")==OK)
	OS.unset_environment("BMT_API_URL")
	assert(GDExtensionManager.load_extension("res://../build/native-shader-preparation-2026-10-28/program_probe.gdextension")==GDExtensionManager.LOAD_STATUS_OK)
	# More precise presentation-only slice labels, inside this owned process.
	var model: GDScript=load("res://vehicle/car_visual.gd")
	model.source_code=model.source_code.replace("var elapsed: int = Time.get_ticks_usec()-_model_slice_started", "var elapsed: int = Time.get_ticks_usec()-_model_slice_started\\n\\tif elapsed>16000: print(\\\"CAR_SLICE \\\",_model_stage,\\\" us=\\\",elapsed,\\\" utc_end_us=\\\",int(Time.get_unix_time_from_system()*1000000.0))")
	assert(model.reload(true)==OK)
''',1)
source=source.replace('frame_times.append(duration)','''frame_times.append(duration)
		if native_spans.size()<20000:
			native_spans.append({"utc_end_us":stamp(),"us":int(duration*1000.0),"stage":app.game.track_ground.build_stage if is_instance_valid(app.game) and is_instance_valid(app.game.track_ground) else "before world","status":app.race_loading.status_label.text if is_instance_valid(app.race_loading) else "closed"})''',1)
source=source.replace('app.queue_free(); await process_frame','app.queue_free(); app=null\n\tfor index: int in range(32): await process_frame')
source=source.replace('\tquit(', '\tFileAccess.open("res://../build/native-shader-preparation-2026-10-28/race-trace/frames.json",FileAccess.WRITE).store_string(JSON.stringify(native_spans))\n\tquit(',1)
probe=output/'probe.gd';probe.write_text(source,encoding='utf-8',newline='\n')
command=['C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64.exe','--audio-driver','Dummy','--rendering-method','gl_compatibility','--path',str(ROOT/'game'),'--script',str(probe),'--','--only-star']
began=time.monotonic()
with (output/'output.log').open('wb') as log:
    child=subprocess.Popen(command,env=env,stdout=log,stderr=subprocess.STDOUT)
    try:code=child.wait(timeout=180)
    except subprocess.TimeoutExpired:child.kill();child.wait();code='timeout'
result=dict(command=command,pid=child.pid,exit=code,seconds=round(time.monotonic()-began,3),probe_sha256=hashlib.sha256(probe.read_bytes()).hexdigest())
(output/'execution.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps(result));print((output/'output.log').read_text(encoding='utf-8',errors='replace')[-3000:])
