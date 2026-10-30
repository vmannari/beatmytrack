from pathlib import Path
import hashlib,json,os,shutil,subprocess,sys

ROOT=Path.cwd();LAB=ROOT/'build/runtime-loading-fixes-2026-10-27'
PRODUCTION=['game/core/app.gd','game/editor/editor_memory.gd','game/vehicle/skid_trails.gd','game/vehicle/skid_trails.gdshader','game/vehicle/effect_render_preparation.gd','game/vehicle/effect_preparation_pool.gd','game/vehicle/compact_detail.gd','game/vehicle/compact_grille.gd']
APP_PAIRS=[
('\tif what == NOTIFICATION_OS_MEMORY_WARNING:\n','\tif what == NOTIFICATION_OS_MEMORY_WARNING:\n\t\tpreload("res://vehicle/effect_render_preparation.gd").trim_cache(self)\n\t\tCompactDetail.trim_front_cache()\n'),
('''	var prepared_effects: Dictionary = effect_preparation.begin(game.get_node("World"),game.get("sand_dust"),game.get("camera"),game.get("impact_cracks"))
	var effect_counts: Dictionary = {"particles":prepared_effects.particles,"batches":prepared_effects.batches,"damage_meshes":prepared_effects.damage_meshes,"canvas":prepared_effects.canvas}
	var preparation_started: int = Time.get_ticks_usec()
	var finish_drawn: bool = await _present_race_loading()
''','''	var preparation_started: int = Time.get_ticks_usec()
	var effect_current: Callable = _race_installation_current.bind(loading_id,original_scope,navigation_generation,starting_screen,selected_vehicle,starting_selection)
	var prepared_effects: Dictionary = await effect_preparation.prepare(game.get_node("World"),game.get("sand_dust"),game.get("camera"),game.get("impact_cracks"),self,_present_race_loading,effect_current)
	var effects_drawn: bool = bool(prepared_effects.get("complete",false))
	var effect_counts: Dictionary = {"particles":prepared_effects.particles,"batches":prepared_effects.batches,"damage_meshes":prepared_effects.damage_meshes,"canvas":prepared_effects.canvas,"reused":int(prepared_effects.get("reused",0))}
	var finish_drawn: bool = false
	if effects_drawn and effect_current.is_valid() and effect_current.call() and is_instance_valid(prepared_game) and game == prepared_game:
		finish_drawn = await _present_race_loading()
'''),
('\tif is_instance_valid(prepared_game) and game == prepared_game:\n\t\tnight_preparation = await _prepare_night_lighting(loading_id, prepared_game)', '\tif effects_drawn and is_instance_valid(prepared_game) and game == prepared_game:\n\t\tnight_preparation = await _prepare_night_lighting(loading_id, prepared_game)'),
('\tprepared_finish.end_render_warmup()\n','''	prepared_finish.end_render_warmup()
	if not effects_drawn:
		if is_queued_for_deletion(): return
		_race_preparation_changed(loading_id,original_scope,navigation_generation,starting_screen,selected_vehicle,starting_selection)
		if is_instance_valid(prepared_game): _discard_preparing_game(prepared_game)
		_close_race_loading(loading_id)
		return
''')]
MEMORY_PAIRS=[
('\tif force:\n\t\tpreload("res://ui/garage_paint_icons.gd").images.clear()', '\tif force:\n\t\tpreload("res://vehicle/effect_render_preparation.gd").trim_cache(app)\n\t\tCompactDetail.trim_front_cache()\n\t\tpreload("res://ui/garage_paint_icons.gd").images.clear()'),
('\tvar other: Dictionary = {"read_bytes":READS.bytes,"encoding_bytes":ENCODING.bytes,"race_world_bytes":WORLDS.bytes_used(),\n','\tvar other: Dictionary = {"read_bytes":READS.bytes,"encoding_bytes":ENCODING.bytes,"race_world_bytes":WORLDS.bytes_used(),\n\t\t"effect_preparation_bytes":preload("res://vehicle/effect_render_preparation.gd").cache_bytes(app),"front_fitting_bytes":CompactDetail.front_cache_bytes,\n')]

def transform(text,pairs,reverse=False):
    for before,after in pairs:
        old,new=(after,before) if reverse else (before,after)
        assert text.count(old)==1,old[:100]
        text=text.replace(old,new,1)
    return text


def write(path,text):
    path.parent.mkdir(parents=True,exist_ok=True);path.write_text(text,encoding='utf-8',newline='\n')


source_map={};baseline_map={}
for name in PRODUCTION:
    current=(ROOT/name).read_text(encoding='utf-8')
    baseline_path=LAB/'before'/(name+'.txt')
    if baseline_path.exists():
        baseline=baseline_path.read_text(encoding='utf-8')
        if name=='game/core/app.gd':
            source_map[name]=transform(baseline,APP_PAIRS)
            baseline_map[name]=transform(current,APP_PAIRS,True)
        elif name=='game/editor/editor_memory.gd':
            source_map[name]=transform(baseline,MEMORY_PAIRS)
            baseline_map[name]=transform(current,MEMORY_PAIRS,True)
        else:source_map[name]=current;baseline_map[name]=baseline
    else:source_map[name]=current
    write(LAB/'task-only-after'/name,source_map[name])

if '--sources-only' in sys.argv:
    print('Refreshed task-only source candidates without modifying frozen projects.')
    sys.exit(0)

# Freeze source code so concurrent editor work cannot alter a running regression.
# Public assets/imported data and runtime native libraries are shared read-only.
skip={'assets','platform','android','.godot','music'}
for variant in ['after','before']:
    parent=LAB/('frozen-'+variant);game=parent/'game';game.mkdir(parents=True,exist_ok=True)
    for folder,dirs,files in os.walk(ROOT/'game'):
        relative=Path(folder).relative_to(ROOT/'game')
        if relative==Path('.'):dirs[:]=[d for d in dirs if d not in skip and not d.startswith('recordings-')]
        for name in files:
            source=Path(folder)/name;target=game/relative/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
    (game/'.godot').mkdir(exist_ok=True)
    for name in ['global_script_class_cache.cfg','uid_cache.bin','extension_list.cfg']:
        source=ROOT/'game/.godot'/name
        if source.exists():shutil.copy2(source,game/'.godot'/name)
    for dest,source in [(game/'assets',ROOT/'game/assets'),(game/'platform',ROOT/'game/platform'),(game/'.godot/imported',ROOT/'game/.godot/imported'),(parent/'docs',ROOT/'docs'),(parent/'build',ROOT/'build')]:
        assert dest.parent.resolve().is_relative_to(LAB.resolve())
        assert source.resolve().is_relative_to(ROOT.resolve())
        if not dest.exists():subprocess.run(['cmd','/c','mklink','/J',str(dest),str(source)],check=True,capture_output=True)
    if variant=='before':
        for name,text in baseline_map.items():write(parent/name,text)
    hashes=[]
    for folder,dirs,files in os.walk(game):
        dirs[:]=[d for d in dirs if d not in skip and not d.startswith('recordings-')]
        for name in files:
            path=Path(folder)/name
            if path.suffix in {'.gd','.gdshader','.gdshaderinc','.godot','.tscn'}:
                hashes.append({'path':path.relative_to(game).as_posix(),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
    (LAB/('frozen-'+variant+'-source-hashes.json')).write_text(json.dumps(hashes,indent=2),encoding='utf-8')
print('Prepared task-only sources and two source-frozen regression projects.')
