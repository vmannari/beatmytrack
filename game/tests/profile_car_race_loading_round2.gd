extends SceneTree
## Actual App path, no game-class preloads in this profiler. Owned offline saves.
const OUT: String = "res://../docs/evidence/car-optimisation-review-round2-2026-11-13"
var frames: Array[float] = []
var last_frame: int = 0
var measuring: bool = false
var checks: int = 0
var failures: int = 0

class DrawTrace extends Node:
	var rows: Array = []
	func describe(submitted: Array) -> Array:
		var groups: Array=[]
		for group: Dictionary in submitted:
			var paths: Array=[]
			for source: Dictionary in group.sources:
				var node: Node=source.node.get_ref()
				if is_instance_valid(node): paths.append(str(node.get_path()))
			groups.append(paths)
		return groups
	func record(groups: Array, usec: int, drawn: bool) -> void:
		rows.append({"groups":groups,"elapsed_us":usec,"drawn":drawn})

func instrument_draws() -> DrawTrace:
	var trace: DrawTrace=DrawTrace.new()
	trace.name="CarLoadDrawTrace"
	root.add_child(trace)
	var script: GDScript=load("res://race/world_render_preparation.gd")
	var source: String=script.source_code.replace("\r\n","\n")
	var anchor: String="\t\tvar drawn: bool = await draw.call()"
	check(source.count(anchor)==1,"single real-draw instrumentation anchor")
	source=source.replace(anchor,"\t\tvar round2_trace: Node = Engine.get_main_loop().root.get_node(\"CarLoadDrawTrace\")\n\t\tvar round2_groups: Array = round2_trace.describe(submitted)\n"+anchor+"\n\t\tround2_trace.record(round2_groups,Time.get_ticks_usec()-began,drawn)")
	script.source_code=source
	check(script.reload()==OK,"diagnostic draw timers reload in memory only")
	return trace

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; printerr("CAR_LOAD_FAIL ",message)
func observe() -> void:
	var now: int=Time.get_ticks_usec()
	if measuring and last_frame>0: frames.append((now-last_frame)/1000.0)
	last_frame=now
func counter(path: String, field: String) -> int:
	if not ResourceLoader.has_cached(path): return 0
	var script: Script=ResourceLoader.call("get_cached_ref",path)
	return int(script.get(field)) if script!=null else 0
func driver_cached() -> Dictionary:
	var result: Dictionary={}
	for file: String in ["driver.res","helmet_static.res"]:
		result[file]=ResourceLoader.has_cached("res://assets/vehicles/kart_refined_v1/tomkart_driver_v1/"+file)
	return result
func source_differences(a: Dictionary,b: Dictionary) -> Array:
	var result: Array=[]
	for path: String in a:
		if a[path]!=b.get(path,""): result.append(path)
	for path: String in b:
		if not a.has(path): result.append(path)
	return result
func audit_base(id: String) -> Dictionary:
	var base: Script=load("res://vehicle/modular_car_base.gd")
	var validation: Script=load("res://vehicle/prepared_asset_sources.gd")
	var car: Node=load("res://vehicle/car_visual.gd").new()
	car.vehicle_id=id
	var path: String=base.path_for(car)
	var result: Dictionary={"path":path,"eligible":base._eligible(car),"exists":ResourceLoader.exists(path)}
	if result.exists:
		var scene: PackedScene=load(path)
		if scene!=null:
			var holder: Node=scene.instantiate()
			var metadata: Dictionary=holder.get_meta("modular_car_base",{})
			var current: Dictionary=validation.runtime_hashes(id)
			var saved: Dictionary=validation.runtime_projection(metadata.get("sources",{}))
			result["key_matches"]=metadata.get("key",[])==base.key_for(car)
			result["runtime_source_matches"]=saved==current
			result["source_differences"]=source_differences(saved,current)
			result["holder_valid"]=base._valid_holder(holder,metadata)
			holder.free()
	car.free()
	return result
func run() -> void:
	OS.set_environment("BMT_API_URL","")
	var id: String="compact"
	var fitted: bool=false
	var track_path: String="res://resources/tracks/ellipse.json"
	for option: String in OS.get_cmdline_user_args():
		if option.begins_with("--car="): id=option.trim_prefix("--car=")
		if option=="--fitted": fitted=true
		if option=="--star": track_path="res://tests/fixtures/star_spline_lap.json"
	assert(id in ["compact","kart","forklift","electric","hovercraft"])
	root.size=Vector2i(1280,720)
	var folder: String="user://car-load-round2-"+str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(folder)
	var began: int=Time.get_ticks_usec()
	var scene: PackedScene=load("res://core/app.tscn")
	var scene_load_ms: float=(Time.get_ticks_usec()-began)/1000.0
	var app: Node=scene.instantiate()
	app.records=load("res://persistence/local_records.gd").new(folder+"/records.json")
	app.records.settings.selected_car=id
	app.records.settings.music_enabled=false
	app.library=load("res://persistence/track_library.gd").new(folder+"/tracks")
	app.cloud_root_override=folder+"/cloud"
	app.race_profile_enabled=true
	root.add_child(app)
	while not app.startup_complete: await process_frame
	var startup_ms: float=(Time.get_ticks_usec()-began)/1000.0
	var startup_driver: Dictionary=driver_cached()
	var trace: DrawTrace=instrument_draws() if "--trace" in OS.get_cmdline_user_args() else null
	var catalog: Script=load("res://vehicle/vehicle_catalog.gd")
	catalog.selected=id
	app.records.settings.selected_car=id
	if fitted:
		var options: Script=load("res://vehicle/vehicle_customisation.gd")
		var selection: Dictionary=options.defaults()
		for category: String in ["hood","aero","rims","body"]:
			var choices: Array=options.options(category,id)
			if choices.size()>1: selection[category]=choices[1][0]
		app.records.settings.vehicle_customisation={id:selection}
	var native: Script=load("res://track/native_track.gd")
	var compile_began: int=Time.get_ticks_usec()
	var track: Variant=load("res://editor/track_compiler.gd").compile(JSON.parse_string(FileAccess.get_file_as_string(track_path))) if "--star" in OS.get_cmdline_user_args() else native.read(track_path)
	var compile_ms: float=(Time.get_ticks_usec()-compile_began)/1000.0
	check(track!=null,"track loads")
	# Exercise the ordinary offline race path with a local owned version pin,
	# just as the existing loading profiles do; never request a live ticket.
	track.metadata.cloud_version="owned-offline-car-load-review"
	var samples: Array=[]
	process_frame.connect(observe)
	for cycle: int in range(2):
		app._show_screen("tracks")
		app.selected_track=track
		var before_base: int=counter("res://vehicle/modular_car_base.gd","hits")
		var before_rest: int=counter("res://vehicle/prepared_car_cache.gd","hits")
		frames.clear(); last_frame=Time.get_ticks_usec(); measuring=true
		if trace!=null: trace.rows.clear()
		began=Time.get_ticks_usec()
		await app._start_race(track,false,true)
		var wall: float=(Time.get_ticks_usec()-began)/1000.0
		measuring=false
		check(is_instance_valid(app.game),"actual race installed")
		if not is_instance_valid(app.game): break
		var game: Node=app.game
		game.set_physics_process(false)
		if is_instance_valid(game.hitch_diagnostics): game.hitch_diagnostics.persist_enabled=false
		check(game.preparation_complete and game.car.vehicle_id==id,"finished current car preparation")
		var row: Dictionary={"cycle":cycle,"race_wall_ms":wall,"max_frame_ms":frames.max() if not frames.is_empty() else 0.0,
			"game_costs":game.preparation_costs.duplicate(true),"base_hits":counter("res://vehicle/modular_car_base.gd","hits")-before_base,
			"rest_hits":counter("res://vehicle/prepared_car_cache.gd","hits")-before_rest,"frame_count":frames.size(),
			"tick_at_reveal":game.sim.state.tick,"countdown_at_reveal":game.countdown_ticks}
		row["car_path"]=str(game.car.get_path())
		row["driver_cached"]=driver_cached()
		row["kit_hits_total"]=counter("res://vehicle/modular_car_kits.gd","hits")
		if is_instance_valid(game.world_render_preparation):
			row["render_draw_max_us"]=game.world_render_preparation.draw_us_max
			row["render_groups"]=game.world_render_preparation.frame_groups
		row["world_costs"]=game.track_ground.build_costs.duplicate(true)
		row["feature_load_ms"]=app.feature_load_ms.duplicate(true)
		row["effects"]=game.effect_preparation_counts.duplicate(true)
		row["shared_finish_effects_ms"]=game.bridge_preparation_ms
		row["night"]=game.night_preparation.duplicate(true)
		if trace!=null: row["draw_trace"]=trace.rows.duplicate(true)
		began=Time.get_ticks_usec()
		await app._retry_race(true)
		row["retry_ms"]=(Time.get_ticks_usec()-began)/1000.0
		samples.append(row)
		print("CAR_LOADING_SAMPLE ",id," ",JSON.stringify(row))
		app._leave_race()
		for frame: int in range(6): await process_frame
	var audit: Dictionary=audit_base(id)
	process_frame.disconnect(observe)
	var name: String=id+("-fitted" if fitted else "")+("-star" if "star_" in track_path else "")+("-trace" if trace!=null else "")+"-"+RenderingServer.get_current_rendering_method()
	var result: Dictionary={"vehicle":id,"fitted":fitted,"track":track_path,"app_scene_load_ms":scene_load_ms,"startup_ms":startup_ms,
		"driver_cached_at_startup":startup_driver,
		"track_read_compile_ms":compile_ms,"samples":samples,"base_audit_after_timing":audit,"checks":checks,"failures":failures,
		"method":"Fresh process; existing OS/import/shader caches. Unmodified actual App path; ordinary five-lap offline practice. Desktop observations, not device timings."}
	FileAccess.open(OUT+"/loading-"+name+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	app.queue_free(); app=null
	scene=null; catalog=null; native=null; track=null
	load("res://soundtrack/audio_world.gd").instance().queue_free()
	if trace!=null: trace.queue_free()
	for frame: int in range(18): await process_frame
	print("CAR_LOADING_ROUND2 ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
