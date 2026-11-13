from pathlib import Path
import hashlib
import json
import os
import subprocess
import sys
import time

ROOT=Path.cwd()
LAB=ROOT/'build/cold-render-investigation-2026-10-27'
SOURCES=['ui/showroom_studio.gd','ui/garage_environment.gd','ui/garage_reflections.gd','ui/car_showroom.gd',
         'ui/garage_preloaded_studio.gd','ui/garage_preloader.gd','core/app.gd','core/game.gd',
         'vehicle/effect_render_preparation.gd','vehicle/effect_preparation_pool.gd','vehicle/skid_trails.gd','vehicle/compact_detail.gd']
ENGINE='C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64.exe'


def setup():
    frozen=LAB/'frozen-original'
    if not frozen.exists():
        hashes={}
        for name in SOURCES:
            data=(ROOT/'game'/name).read_bytes()
            target=frozen/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
            hashes[name]=hashlib.sha256(data).hexdigest()
        (LAB/'source-start.json').write_text(json.dumps(hashes,indent=2),encoding='utf-8')
    for name in SOURCES:
        target=LAB/'frozen'/name;target.parent.mkdir(parents=True,exist_ok=True)
        target.write_bytes((frozen/name).read_bytes())
    source=(frozen/'ui/garage_preloaded_studio.gd').read_text(encoding='utf-8')
    fields='''var _diag_case: String="original"
var _diag_ready: bool=false
var _diag_kind: String="mesh"
var _diag_key: String=""
var _diag_names: Array[String]=[]
var _diag_rows: Array[Dictionary]=[]
'''
    source=source.replace('var permitted: Callable',fields+'var permitted: Callable',1)
    marker='\t_stop_draws()\n\nfunc invalidate_render()'
    assert source.count(marker)==1
    source=source.replace(marker,'\t_stop_draws()\n\t_diag_ready=true\n\nfunc invalidate_render()',1)
    marker='\t\tawait _draw()\n\t\tfor entry: Dictionary in group:'
    assert source.count(marker)==1
    source=source.replace(marker,'\t\t_diag_kind="mesh"\n\t\t_diag_key=key.sha256_text()\n\t\t_diag_names.clear()\n\t\tfor entry: Dictionary in group:\n\t\t\tvar mesh_node: Object=entry.node.get_ref()\n\t\t\tif is_instance_valid(mesh_node): _diag_names.append(str(mesh_node.name))\n\t\tawait _draw()\n\t\tfor entry: Dictionary in group:',1)
    marker='\twhile _pending.is_empty() and _allowed() and not prepared:'
    assert source.count(marker)==1
    restore='''	if _diag_case.begins_with("representatives"):
		for entry: Dictionary in _held:
			var node: Object=entry.node.get_ref()
			if is_instance_valid(node): node.visible=true;node.extra_cull_margin=entry.margin
'''
    source=source.replace(marker,restore+marker+'\n\t\t_diag_kind="settle"',1)
    begin=source.index('\nfunc _draw() -> void:')
    end=source.index('\nfunc adopt() -> void:',begin)
    replacement='''
func _draw() -> void:
	if not _allowed(): return
	var split: bool=_diag_case in ["split_views","representatives_split"]
	for pass_index: int in ([0,1,2] if split else [-1]):
		await _diag_interval(_diag_kind,pass_index)

func _diag_interval(kind: String,pass_index: int) -> void:
	var began: int=Time.get_ticks_usec()
	var utc: int=int(Time.get_unix_time_from_system()*1000000.0)
	var callers: Array=[]
	for item: Dictionary in get_stack(): callers.append(item.function)
	var before: Array=[Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH),Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE),Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)]
	_submit_render()
	if pass_index>=0:
		showroom_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
		for other: SubViewport in reflections.views: other.render_target_update_mode=SubViewport.UPDATE_DISABLED
		if pass_index==0: showroom_viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
		else: reflections.views[pass_index-1].render_target_update_mode=SubViewport.UPDATE_ONCE
	var submitted: int=Time.get_ticks_usec()
	warm_draws+=1
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
	var ended: int=Time.get_ticks_usec()
	max_draw_ms=maxf(max_draw_ms,(ended-began)/1000.0)
	var after: Array=[Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH),Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE),Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)]
	_diag_rows.append({"utc_us":utc,"callers":callers,"kind":kind,"pass":pass_index,"phase":_phase,"pending":_pending.size(),"key":_diag_key,"names":_diag_names.duplicate(),"submit_us":submitted-began,"wait_us":ended-submitted,"total_us":ended-began,"pipelines_before":before,"pipelines_after":after,"target":showroom_viewport.size})
	if ended-began>50000: print("COLD_DRAW ",JSON.stringify(_diag_rows[-1]))
	if is_inside_tree() and not is_queued_for_deletion(): await get_tree().process_frame
'''
    source=source[:begin]+replacement+source[end:]
    if len(sys.argv)>2 and sys.argv[2]=='rename_callback':
        source=source.replace('func _draw() -> void:','func _warm_frame() -> void:').replace('await _draw()','await _warm_frame()')
    (LAB/'frozen/ui/garage_preloaded_studio.gd').write_text(source,encoding='utf-8',newline='\n')


setup()
if len(sys.argv)==2 and sys.argv[1]=='setup':
    print('Frozen source and diagnostic instrumentation prepared.');sys.exit(0)
label,variant,scope,renderer=sys.argv[1:5]
sample='--sample' in sys.argv
if variant in ['parallel_hint','trace_link']:
    assert hashlib.sha256(Path(ENGINE).read_bytes()).hexdigest()=='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424','Native pointer mapping requires the pinned engine'
profile_label=next((arg.split('=',1)[1] for arg in sys.argv if arg.startswith('--reuse-profile=')),label)
profile=LAB/'profiles'/profile_label;profile.mkdir(parents=True,exist_ok=True)
env={key:value for key,value in os.environ.items() if not key.startswith('BMT_')}
env.update(APPDATA=str(profile),LOCALAPPDATA=str(profile))
if variant=='trace_link':
    shader_dir=LAB/'shader-source';shader_dir.mkdir(parents=True,exist_ok=True)
    env.update(BMT_DIAG_NATIVE_MODE='trace_link',BMT_DIAG_SHADER_DIR=str(shader_dir))
command=[ENGINE,'--audio-driver','Dummy','--rendering-method',renderer,'--path',str(ROOT/'game'),'--script',str(LAB/'probe.gd'),
         '--','--variant='+variant,'--scope='+scope,'--output=res://../build/cold-render-investigation-2026-10-27/results/'+label]
if variant=='thread_separate':command[1:1]=['--render-thread','separate']
began=time.monotonic();sampler=None
with (LAB/(label+'.log')).open('wb') as log:
    process=subprocess.Popen(command,env=env,stdout=log,stderr=subprocess.STDOUT)
    (LAB/(label+'-pid.json')).write_text(json.dumps(dict(pid=process.pid,command=command)),encoding='utf-8')
    if sample:
        native_log=(LAB/(label+'-native.jsonl')).open('wb')
        sampler=subprocess.Popen([str(LAB/'sampler.exe'),str(process.pid),str(os.getpid()),'150'],env=env,stdout=native_log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
    try:code=process.wait(timeout=240)
    except subprocess.TimeoutExpired:process.kill();process.wait();code='timeout'
    if sampler is not None:sampler.wait(timeout=20);native_log.close()
result=dict(command=command,pid=process.pid,exit=code,seconds=round(time.monotonic()-began,3),variant=variant,scope=scope,renderer=renderer,sampled=sample,profile_label=profile_label,
            source_hashes={name:hashlib.sha256((ROOT/'game'/name).read_bytes()).hexdigest() for name in SOURCES})
(LAB/(label+'-execution.json')).write_text(json.dumps(result,indent=2),encoding='utf-8')
sys.stdout.reconfigure(encoding='utf-8');print(json.dumps(result));print((LAB/(label+'.log')).read_text(encoding='utf-8',errors='replace')[-3500:])
