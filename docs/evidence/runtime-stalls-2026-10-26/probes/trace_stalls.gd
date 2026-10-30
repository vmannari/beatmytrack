extends SceneTree
const TraceApp = preload("res://../build/runtime-stall-investigation-2026-10-26/trace_app.gd")
const CPUCar = preload("res://../build/runtime-stall-investigation-2026-10-26/cpu_car.gd")
var app: Node
var events: Array = []
var frames: Array = []
var current: Dictionary = {}
var loads: Array = []
var watching: bool = false
var phase: String = "startup"
var options: Dictionary = {"timers":true,"vsync":true,"cover_only":false,"menu_off":false}
var failures: Array[String] = []
var output: String
var began: int
var root_rid: RID
var seen_geometry: Dictionary = {}
var shader_descriptions: Dictionary = {}
var trail_substitutions: int = 0

func _initialize() -> void: run.call_deferred()

func context() -> Dictionary:
	var result: Dictionary = {"phase":phase}
	if not is_instance_valid(app): return result
	result.menu_visible = is_instance_valid(app.root_ui) and app.root_ui.visible
	result.loading = app.race_loading.status_label.text if is_instance_valid(app.race_loading) else "none"
	if is_instance_valid(app.game):
		result.game_ready = app.game.preparation_complete
		result.world = app.game.track_ground.build_stage if is_instance_valid(app.game.track_ground) else "none"
		if app.game.car != null: result.car = app.game.car._model_stage
	return result

func mark(label: String) -> void:
	if watching: events.append({"at_us":Time.get_ticks_usec(),"label":label,"context":context()})

func span(label: String, start: int, facts: Dictionary = {}) -> void:
	if watching: events.append({"at_us":Time.get_ticks_usec(),"start_us":start,"duration_us":Time.get_ticks_usec()-start,"label":label,"context":context(),"facts":facts})

func render_group() -> void:
	if not watching or not is_instance_valid(app.game) or not app.game.preparation_complete: return
	var additions: Array = []
	for node: GeometryInstance3D in app.game.find_children("*","GeometryInstance3D",true,false):
		if not node.is_visible_in_tree() or seen_geometry.has(node.get_instance_id()): continue
		seen_geometry[node.get_instance_id()] = true
		var mesh: Mesh = node.mesh if node is MeshInstance3D else node.multimesh.mesh if node is MultiMeshInstance3D and node.multimesh != null else null
		var materials: Array = []
		if mesh != null:
			for surface: int in range(mesh.get_surface_count()):
				var material: Material = node.get_active_material(surface) if node is MeshInstance3D else node.material_override if node.material_override != null else mesh.surface_get_material(surface)
				if material == null: continue
				var detail: Dictionary = {"kind":material.get_class(),"id":material.get_instance_id(),"path":material.resource_path}
				if material is ShaderMaterial and material.shader != null:
					var key: int = material.shader.get_instance_id()
					if not shader_descriptions.has(key): shader_descriptions[key] = {"shader_hash":material.shader.code.sha256_text(),"shader_path":material.shader.resource_path,"shader_id":key}
					detail.merge(shader_descriptions[key])
				materials.append(detail)
		additions.append({"node":str(node.get_path()),"kind":node.get_class(),"shadow":node.cast_shadow,"materials":materials})
	events.append({"at_us":Time.get_ticks_usec(),"label":"visible_geometry","context":context(),"items":additions})

func begin_frame() -> void:
	if not watching: return
	var at: int = Time.get_ticks_usec()
	if not current.is_empty():
		current.end_us = at
		current.wall_us = at-int(current.begin_us)
		current.end_context = context()
		frames.append(current)
	current = {"begin_us":at,"begin_context":context(),"engine_frame":Engine.get_process_frames(),"process_previous_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,"physics_previous_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0}

func before_draw() -> void:
	if watching and not current.is_empty(): current.draw_begin_us = Time.get_ticks_usec(); current.draw_context = context()

func after_draw() -> void:
	if not watching or current.is_empty(): return
	current.draw_end_us = Time.get_ticks_usec()
	current.render_setup_ms = RenderingServer.get_frame_setup_time_cpu()
	if options.timers:
		current.viewport_cpu_ms = RenderingServer.viewport_get_measured_render_time_cpu(root_rid)
		current.viewport_gpu_ms = RenderingServer.viewport_get_measured_render_time_gpu(root_rid)
	current.pipeline_canvas = Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS)
	current.pipeline_mesh = Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH)
	current.pipeline_draw = Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)

func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label); print("FAIL: ",label)

func node_added_for_probe(node: Node) -> void:
	if options.get("cpu-details",false) and node is CarVisual and node.cooperative_build:
		check(not node.is_node_ready(),"CPU probe precedes car construction")
		if node.is_node_ready(): return
		var fields: Dictionary = {}
		for field: String in ["vehicle_id","livery","customisation","simple_model","editable_kits","cooperative_build","cache_rest_pose","build_budget_us","garage_template","batch_parts"]: fields[field] = node.get(field)
		node.set_script(CPUCar)
		for field: String in fields: node.set(field,fields[field])
	if not node is SkidTrails or not is_instance_valid(app) or not options.get("solution-sequence",false): return
	if not "--share-trails" in app.trace_ablation_flags: return
	check(not node.is_node_ready(),"trail substitution occurs before its normal ready")
	if node.is_node_ready(): return
	var wheelbase: float = node.wheelbase
	var track_width: float = node.track_width
	var clipping: bool = node.bridge_clipping_enabled
	node.set_script(load("res://../build/runtime-stall-investigation-2026-10-26/shared_trails.gd"))
	node.wheelbase = wheelbase; node.track_width = track_width; node.bridge_clipping_enabled = clipping
	trail_substitutions += 1

func verify_ready_game(game: Node) -> Dictionary:
	var facts: Dictionary = {"tick":game.sim.state.tick,"elapsed_ticks":game.track_session.elapsed_ticks,"countdown":game.countdown_ticks,"trail_capacity":game.trails.instances.instance_count,"trail_cursor":game.trails.cursor,"trail_visible":game.trails.instances.visible_instance_count,"effects":game.effect_preparation_counts.duplicate(),"weather_warming":game.car_weathering._render_warming,"live_emitters":[]}
	for node: Node in game.sand_dust.get_children():
		if node is GPUParticles3D: facts.live_emitters.append({"name":str(node.name),"amount":node.amount,"fixed_fps":node.fixed_fps,"lifetime":node.lifetime,"emitting":node.emitting,"preprocess":node.preprocess})
	check(facts.tick==0 and facts.elapsed_ticks==0 and facts.countdown==360,"preparation keeps canonical state and countdown frozen")
	check(facts.trail_capacity==16384 and facts.trail_cursor==0 and facts.trail_visible==0,"preparation preserves live trail ring")
	check(not facts.weather_warming,"weather material warmup restores")
	for node: Dictionary in facts.live_emitters: check(not node.emitting,"live "+str(node.name)+" emitter stays inactive")
	return facts

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument=="--no-timers": options.timers = false
		if argument=="--no-vsync": options.vsync = false
		if argument=="--cover-only": options.cover_only = true
		if argument=="--menu-off": options.menu_off = true
		if argument in ["--detailed","--skip-effects","--skip-finish","--keep-effects","--sequence","--particle-sequence","--solution-sequence","--cpu-details","--memo-grid","--verify-state"]: options[argument.trim_prefix("--")] = true
	OS.set_environment("BMT_API_URL","")
	root.size = Vector2i(1280,720)
	root_rid = root.get_viewport_rid()
	if DisplayServer.get_name()!="headless" and not options.vsync: DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(root_rid,options.timers)
	var tag: String = ("cover" if options.cover_only else "race")+("-menu-off" if options.menu_off else "")+("-timers" if options.timers else "-no-timers")+("-vsync" if options.vsync else "-uncapped")+"-"+RenderingServer.get_current_rendering_method()+"-"+DisplayServer.get_name()
	for flag: String in ["detailed","skip-effects","skip-finish","keep-effects","sequence","particle-sequence","solution-sequence","cpu-details","memo-grid","verify-state"]:
		if options.get(flag,false): tag += "-"+flag
	output = ProjectSettings.globalize_path("res://../docs/evidence/runtime-stalls-2026-10-26/"+tag)
	DirAccess.make_dir_recursive_absolute(output)
	var folder: String = "user://stall-trace-"+TrackLibrary.unique_id()
	app = load("res://core/app.tscn").instantiate()
	app.set_script(load("res://../build/runtime-stall-investigation-2026-10-26/detailed_app.gd") if options.get("detailed",false) else TraceApp)
	app.trace_sink = self
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.records.settings.music_enabled = false
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override = folder.path_join("cloud")
	app.race_profile_enabled = true
	root.add_child(app)
	while not app.startup_complete: await process_frame
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/star_spline_lap.json"))
	var track: NativeTrack = TrackCompiler.compile(document)
	track.metadata.cloud_version = "owned-stall-fixture"
	process_frame.connect(begin_frame)
	RenderingServer.frame_pre_draw.connect(before_draw)
	RenderingServer.frame_post_draw.connect(after_draw)
	node_added.connect(node_added_for_probe)
	var cases: Array = [{"phase":"cold"},{"phase":"warm"}]
	if options.get("sequence",false):
		cases = [{"phase":"cold-control"},{"phase":"warm-control-a"},{"phase":"warm-skip-effects","flag":"--skip-effects"},{"phase":"warm-control-b"},{"phase":"warm-keep-effects","flag":"--keep-effects"},{"phase":"warm-control-c"},{"phase":"warm-skip-finish","flag":"--skip-finish"},{"phase":"warm-control-d"},{"phase":"warm-skip-both","flag":"--skip-effects","second":"--skip-finish"},{"phase":"warm-control-e"}]
	if options.get("particle-sequence",false):
		cases = [{"phase":"cold-control"},{"phase":"warm-control-a"},{"phase":"warm-no-particle-proxies","flag":"--skip-effect-particles"},{"phase":"warm-control-b"},{"phase":"warm-zero-preprocess","flag":"--zero-preprocess"},{"phase":"warm-control-c"},{"phase":"warm-no-canvas-proxy","flag":"--skip-effect-canvas"},{"phase":"warm-control-d"},{"phase":"warm-no-trail-proxy","flag":"--skip-trails"},{"phase":"warm-no-effect-or-trail","flag":"--skip-effects","second":"--skip-trails"},{"phase":"warm-control-e"}]
	if options.get("solution-sequence",false):
		cases = [{"phase":"cold-control"},{"phase":"warm-control-a"},{"phase":"warm-share-trails-first","flag":"--share-trails"},{"phase":"warm-share-trails-repeat","flag":"--share-trails"},{"phase":"warm-control-b"},{"phase":"warm-stage-effects","flag":"--stage-effects"},{"phase":"warm-control-c"},{"phase":"warm-combined-first","flag":"--stage-effects","second":"--share-trails"},{"phase":"warm-combined-repeat","flag":"--stage-effects","second":"--share-trails"},{"phase":"warm-control-d"}]
	for cycle: int in range(cases.size()):
		app._show_screen("tracks"); app.selected_track = track
		app.records.settings.camera_mode = "overhead"
		phase = cases[cycle].phase
		if options.get("sequence",false) or options.get("particle-sequence",false) or options.get("solution-sequence",false):
			app.trace_ablation_flags = PackedStringArray()
			for key: String in ["flag","second"]:
				if cases[cycle].has(key): app.trace_ablation_flags.append(cases[cycle][key])
		watching = true; current = {}; began = Time.get_ticks_usec(); begin_frame()
		mark("attempt_begin")
		if options.cover_only:
			var overlay: CanvasLayer = app._open_race_loading(track)
			if options.menu_off: app._race_menu_visible(false)
			for _frame: int in range(4): await app._present_race_loading()
			app._close_race_loading(overlay.get_instance_id())
			app._race_menu_visible(true)
		else:
			await app._start_race(track,false,true)
			check(is_instance_valid(app.game) and app.game.preparation_complete,"ordinary App race is ready")
			if is_instance_valid(app.game):
				app.game.set_physics_process(false)
				loads.append({"phase":phase,"wall_us":Time.get_ticks_usec()-began,"game":app.game.preparation_costs.duplicate(true),"world":app.game.track_ground.build_costs.duplicate(true)})
		mark("attempt_ready")
		for _frame: int in range(3): await process_frame
		watching = false
		if options.get("verify-state",false) and is_instance_valid(app.game): loads[-1].verification = verify_ready_game(app.game)
		if is_instance_valid(app.game):
			phase = "leave-"+phase; watching = true; current = {}; begin_frame()
			var leave_at: int = Time.get_ticks_usec()
			app._leave_race(); span("leave_race",leave_at)
			for _frame: int in range(4): await process_frame
			watching = false
	process_frame.disconnect(begin_frame)
	node_added.disconnect(node_added_for_probe)
	RenderingServer.frame_pre_draw.disconnect(before_draw)
	RenderingServer.frame_post_draw.disconnect(after_draw)
	var source_hashes: Array = []
	for resource: Script in [app.get_script(),app.get_script().get_base_script(),load("res://core/game.gd"),load("res://race/world_render_preparation.gd")]:
		source_hashes.append({"path":resource.resource_path,"sha256":resource.source_code.sha256_text()})
	var data: Dictionary = {"trail_substitutions":trail_substitutions,"source_hashes":source_hashes,"options":options,"engine":Engine.get_version_info(),"renderer":RenderingServer.get_current_rendering_method(),"display":DisplayServer.get_name(),"frame_count":frames.size(),"frames":frames,"events":events,"loads":loads,"failures":failures}
	var file := FileAccess.open(output.path_join("trace.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(data,"  ")); file.close()
	var ranked: Array = frames.duplicate(); ranked.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.wall_us>b.wall_us)
	for row: Dictionary in ranked.slice(0,8): print("STALL_FRAME ",JSON.stringify(row))
	print("STALL_TRACE ",tag," frames=",frames.size()," failures=",failures.size()," output=",output)
	app.queue_free()
	for _frame: int in range(8): await process_frame
	await create_timer(0.4).timeout # Allow pending engine teardown to settle before exit.
	quit(1 if not failures.is_empty() else 0)
