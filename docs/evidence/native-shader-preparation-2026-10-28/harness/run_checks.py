from pathlib import Path
import hashlib,json,os,shutil,subprocess,sys,time

ROOT=Path.cwd();LAB=ROOT/'build/native-shader-preparation-2026-10-28'
ENGINE='C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64.exe'
label,script,mode=sys.argv[1:4]
profile=LAB/'profiles'/label;profile.mkdir(parents=True,exist_ok=True)
seed=ROOT/'build/cold-render-investigation-2026-10-27/profiles/original-standalone/Circuit01Lab/shader_cache'
if '--seed-cache' in sys.argv and seed.exists():shutil.copytree(seed,profile/'Circuit01Lab/shader_cache',dirs_exist_ok=True)
env={k:v for k,v in os.environ.items() if not k.startswith('BMT_')};env.update(APPDATA=str(profile),LOCALAPPDATA=str(profile))
source=ROOT/'game'/script;text=source.read_text(encoding='utf-8')
if 'func run() -> void:' in text:
    text=text.replace('func run() -> void:','func run() -> void:\n\tvar task_config:=ConfigFile.new();task_config.set_value("backend","url","");assert(task_config.save("user://backend.cfg")==OK)\n\tOS.unset_environment("BMT_API_URL")\n',1)
if '--task-start' in sys.argv:
    text=text.replace('func run() -> void:','func run() -> void:\n\tvar old_studio: GDScript=load("res://ui/garage_preloaded_studio.gd")\n\told_studio.source_code=FileAccess.get_file_as_string("res://../build/native-shader-preparation-2026-10-28/before/game/ui/garage_preloaded_studio.gd")\n\tassert(old_studio.reload(true)==OK)\n',1)
if '--task-start-models' in sys.argv:
    setup='''
	for name: String in ["compact_rear_design.gd","compact_detail.gd"]:
		var old: GDScript=load("res://vehicle/"+name)
		old.source_code=FileAccess.get_file_as_string("res://../build/native-shader-preparation-2026-10-28/before/game/vehicle/"+name)
		assert(old.reload(true)==OK)
	var old_cache: GDScript=load("res://ui/garage_car_cache.gd")
	old_cache.source_code=old_cache.source_code.replace("res://assets/garage/cars_v1/","res://../build/native-shader-preparation-2026-10-28/baseline-native-templates/")
	old_cache.source_code=old_cache.source_code.replace('const DIRECTORY: String="res://../build/native-shader-preparation-2026-10-28/baseline-native-templates/"','static var DIRECTORY: String=ProjectSettings.globalize_path("res://../build/native-shader-preparation-2026-10-28/baseline-native-templates/")')
	old_cache.source_code=old_cache.source_code.replace('result[file]=FileAccess.get_sha256("res://vehicle/"+file)', 'result[file]=FileAccess.get_sha256("res://vehicle/"+file)\\n\\t\\t\\tif file in ["compact_rear_design.gd","compact_detail.gd"]: result[file]=FileAccess.get_sha256("res://../build/native-shader-preparation-2026-10-28/before/game/vehicle/"+file)')
	assert(old_cache.reload(true)==OK)
	if ResourceLoader.exists("res://../build/native-shader-preparation-2026-10-28/baseline-native-templates/compact.scn"):
		var holder: Node3D=load("res://../build/native-shader-preparation-2026-10-28/baseline-native-templates/compact.scn").instantiate()
		assert(old_cache.geometry_sources()==holder.get_meta("garage_rest").sources,"Baseline control templates retain the exact loaded frozen builders and current unchanged authors")
		holder.free()
'''
    if script=='tests/bake_garage_cars.gd':setup=setup[:setup.index('\n\tif ResourceLoader.exists(')]
    text=text.replace('func run() -> void:','func run() -> void:'+setup,1)
if '--await-normal-garage' in sys.argv:
    # The shared App already uses asynchronous progressive entry for a
    # rejected/unavailable preload. Retain assertions; await that real contract.
    text=text.replace('var decoded: WeakRef=weakref(loader._resources[asset])', '''var decoded: WeakRef=weakref(loader._resources[asset])
	var retained_asset: Dictionary={"alive":decoded.get_ref()!=null}
	var observe_asset: Callable=func() -> void:
		if is_instance_valid(app._retained_garage) and not app._retained_garage.showroom.showroom_ready: retained_asset.alive=retained_asset.alive and decoded.get_ref()!=null
	process_frame.connect(observe_asset)''')
    text=text.replace('app._retained_garage.showroom.showroom_ready and decoded.get_ref()!=null', 'app._retained_garage.showroom.showroom_ready and retained_asset.alive')
    text=text.replace('# Entering while the first draw batch is outstanding restores every original.', 'process_frame.disconnect(observe_asset)\n\t# Entering while the first draw batch is outstanding restores every original.')
    text=text.replace('app._show_screen("garage")','''app._show_screen("garage")
	var normal_deadline: int=Time.get_ticks_msec()+30000
	while (not is_instance_valid(app._retained_garage) or app._retained_garage.showroom.car==null or not app._retained_garage.showroom.showroom_ready or app._retained_garage.showroom.get("preparing")==true) and Time.get_ticks_msec()<normal_deadline: await process_frame''')
    # Each replacement is in the same scope; use a local block-specific id.
    sections=text.split('var normal_deadline: int=')
    text=sections[0]+''.join('var normal_deadline_'+str(i)+': int='+s.replace('Time.get_ticks_msec()<normal_deadline:', 'Time.get_ticks_msec()<normal_deadline_'+str(i)+':') for i,s in enumerate(sections[1:],1))
if '--settle-shader-defaults' in sys.argv:
    text=text.replace('var original: Array=shape(reference)', 'await process_frame\n\t\tvar original: Array=shape(reference)')
    text=text.replace('var rebuilt: Array=shape(restored)', 'await process_frame\n\t\tvar rebuilt: Array=shape(restored)')
    text=text.replace('check(shape(other)==original,', 'await process_frame\n\t\tcheck(shape(other)==original,')
if '--effective-shader-defaults' in sys.argv:
    text=text.replace('var value: Variant=material.get_shader_parameter(item.name)', 'var value: Variant=material.get_shader_parameter(item.name)\n\t\t\tif value==null: value=RenderingServer.shader_get_parameter_default(material.shader.get_rid(),item.name)')
if '--wrong-glass-control' in sys.argv:
    text=text.replace('var restored: CarVisual=make(id,true)', '''var restored: CarVisual=make(id,true)
		if id=="compact":
			for part: MeshInstance3D in restored.find_children("*","MeshInstance3D",true,false):
				var finish_material: Material=part.get_active_material(0)
				if finish_material is ShaderMaterial and "glass_tint" in finish_material.shader.code:
					finish_material.set_shader_parameter("glass_tint",Color.RED)
					break''')
for old in ['res://../build/garage-preload','res://../docs/evidence/runtime-correctness-2026-10-26']:
    text=text.replace(old,'res://../build/native-shader-preparation-2026-10-28/outputs/'+label)
probe=LAB/'checks'/(label+'.gd');probe.parent.mkdir(parents=True,exist_ok=True);probe.write_text(text,encoding='utf-8',newline='\n')
output=LAB/'outputs'/label;output.mkdir(parents=True,exist_ok=True)
command=[ENGINE,'--audio-driver','Dummy','--path',str(ROOT/'game'),'--script',str(probe)]
if mode=='headless':command.insert(1,'--headless')
else:command.extend(['--rendering-method',mode])
command.extend(['--','--output=res://../build/native-shader-preparation-2026-10-28/outputs/'+label])
start=time.monotonic()
with (LAB/(label+'.log')).open('wb') as log:
    process=subprocess.Popen(command,env=env,stdout=log,stderr=subprocess.STDOUT)
    (LAB/(label+'-pid.json')).write_text(json.dumps(dict(pid=process.pid,command=command)),encoding='utf-8')
    code=None
    while process.poll() is None and time.monotonic()-start<240:
        time.sleep(0.25)
        if 'SCRIPT ERROR:' in (LAB/(label+'.log')).read_text(encoding='utf-8',errors='replace'):
            process.kill();process.wait();code='script_error';break
    if code is None:
        if process.poll() is None:process.kill();process.wait();code='timeout'
        else:code=process.returncode
result=dict(label=label,command=command,pid=process.pid,exit=code,seconds=round(time.monotonic()-start,3),
    cache_seeded='--seed-cache' in sys.argv,task_start_in_memory='--task-start' in sys.argv,task_start_models_in_memory='--task-start-models' in sys.argv,
    await_existing_progressive_entry='--await-normal-garage' in sys.argv,
    settle_shader_defaults='--settle-shader-defaults' in sys.argv,
    effective_shader_defaults='--effective-shader-defaults' in sys.argv,
    wrong_glass_control='--wrong-glass-control' in sys.argv,
    test_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),probe_sha256=hashlib.sha256(probe.read_bytes()).hexdigest())
(LAB/(label+'-execution.json')).write_text(json.dumps(result,indent=2),encoding='utf-8')
sys.stdout.reconfigure(encoding='utf-8');print(json.dumps(result));print((LAB/(label+'.log')).read_text(encoding='utf-8',errors='replace')[-2200:])
