extends SceneTree
## Native real-App races, uncapped diagnostic driving and timestamp observations.
var app: Node
var rows: Array = []
var failures: int = 0
const COUNTERS = ["sim","rules","ai","particles","trails","weather","car","props","camera","hud","audio","contact","music","water","history","condition","weathering","physics_total","process_total"]

func _initialize() -> void: run.call_deferred()

func quantiles(values: Array) -> Dictionary:
	if values.is_empty(): return {}
	var ordered: Array = values.duplicate(); ordered.sort()
	var total: float = 0.0
	for value: float in ordered: total += value
	return {"count":ordered.size(),"mean":total/ordered.size(),"p50":ordered[ordered.size()/2],"p95":ordered[mini(ordered.size()-1,ceili(ordered.size()*0.95)-1)],"p99":ordered[mini(ordered.size()-1,ceili(ordered.size()*0.99)-1)],"max":ordered[-1],"over_16_667":ordered.filter(func(v: float) -> bool: return v>16.667).size(),"over_33_333":ordered.filter(func(v: float) -> bool: return v>33.333).size()}

func foreground() -> void:
	if not is_instance_valid(app): return
	app._publishing_slots_foreground = true
	if is_instance_valid(app.game) and app.game.paused: app.game.toggle_pause()
	if is_instance_valid(app._garage_preloader):
		app._garage_preloader.idle_ms = 100000000
		app._garage_preloader.foreground = false

func sample(seconds: float) -> Dictionary:
	var game: Node = app.game
	var frames: Array = []; var gpu: Array = []; var render_cpu: Array = []; var physics: Array = []; var process: Array = []; var draws: Array = []; var primitives: Array = []
	var start: int = Time.get_ticks_usec(); var last: int = start
	var initial_tick: int = game.sim.state.tick
	var counters: Dictionary = {}
	for key: String in COUNTERS: counters[key] = game.get("profile_"+key+"_us")
	while Time.get_ticks_usec()-start < seconds*1000000.0:
		await process_frame
		var now: int = Time.get_ticks_usec()
		frames.append((now-last)/1000.0); last = now
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		render_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
		physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
		process.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var costs: Dictionary = {}
	for key: String in counters: costs[key+"_ms_per_frame"] = (int(game.get("profile_"+key+"_us"))-int(counters[key]))/1000.0/maxi(1,frames.size())
	var elapsed_ms: float = (Time.get_ticks_usec()-start)/1000.0
	var ticks: int = game.sim.state.tick-initial_tick
	if ticks < elapsed_ms*0.12*0.90: failures += 1
	return {"elapsed_ms":elapsed_ms,"fps":frames.size()*1000.0/elapsed_ms,"frame_ms":quantiles(frames),"gpu_ms":quantiles(gpu),"render_cpu_ms":quantiles(render_cpu),"physics_cpu_ms":quantiles(physics),"process_cpu_ms":quantiles(process),"draws":quantiles(draws),"primitives":quantiles(primitives),"callback_costs":costs,"ticks":ticks,"laps":game.track_session.completed_laps,"contacts":game.sim.state.collision_count,"speed_kmh":game.sim.state.velocity.length()*3.6,"static_bytes":OS.get_static_memory_usage(),"video_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}

func run() -> void:
	root.size = Vector2i(1280,720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	app = load("res://core/app.tscn").instantiate()
	app.records = load("res://persistence/local_records.gd").new("user://overview/records.json")
	app.records.settings.music_enabled = false
	app.library = load("res://persistence/track_library.gd").new("user://overview/tracks")
	app.cloud_root_override = "user://overview/cloud"
	app.race_profile_enabled = true
	root.add_child(app)
	process_frame.connect(foreground)
	while not app.startup_complete: await process_frame
	if app.online.configured: push_error("Offline profiling required"); quit(1); return
	var cases: Array = [["compact","pine"],["compact","desert"],["compact","winter"],["compact","storm"],["compact","night_city"],["kart","pine"],["super_rally","pine"],["electric","pine"],["forklift","pine"],["hovercraft","pine"]]
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--cases="):
			cases.clear()
			for value: String in argument.trim_prefix("--cases=").split(","):
				var fields: PackedStringArray = value.split(":")
				if fields.size() == 2: cases.append([fields[0],fields[1]])
	for entry: Array in cases:
		var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../backend/tests/fixtures/verified_oval.json"))
		fixture.document.theme = entry[1]
		var track: NativeTrack = TrackCompiler.compile(fixture.document)
		track.metadata.cloud_version = "owned-offline-profile"
		app.records.settings.selected_car = entry[0]
		VehicleCatalog.selected = entry[0]
		app.records.settings.camera_mode = "overhead"
		await app._show_screen("tracks")
		app.selected_track = track
		var base_cache: GDScript = load("res://vehicle/modular_car_base.gd")
		var base_hits_before: int = base_cache.hits
		var began: int = Time.get_ticks_usec()
		await app._start_race(track,false,true)
		var load_ms: float = (Time.get_ticks_usec()-began)/1000.0
		if not is_instance_valid(app.game):
			failures += 1
			printerr("PROFILE_RACE_NOT_INSTALLED ",entry)
			continue
		var game: Node = app.game
		if game.vehicle_id != entry[0]: push_error("Selected vehicle mismatch"); quit(1); return
		game.ai_enabled = true
		game.hitch_diagnostics.persist_enabled = false
		game.track_session.target_laps = 10000
		while game.countdown_ticks > 0: await process_frame
		await sample(2.0)
		var row: Dictionary = await sample(10.0)
		row.vehicle = entry[0]; row.theme = entry[1]; row.load_ms = load_ms
		row.preparation_costs = game.preparation_costs.duplicate(true)
		row.render_scale = root.scaling_3d_scale; row.msaa = root.msaa_3d
		row.car_simple = game.car.simple_model
		row.modular_base_hits_during_load = base_cache.hits-base_hits_before
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("BMT_GRAPHICS_OUTPUT").path_join(str(entry[0])+"-"+str(entry[1])+".png"))
		rows.append(row)
		print("OVERVIEW_DRIVING ",JSON.stringify(row))
		FileAccess.open(OS.get_environment("BMT_LOADING_OUTPUT"),FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"engine":Engine.get_version_info().string,"viewport":[root.size.x,root.size.y],"vsync":"disabled","fps_cap":0,"music":false,"network_disabled":not app.online.configured},"  "))
		app._leave_race()
		for _i: int in range(5): await process_frame
	app.queue_free(); app = null
	for _i: int in range(18): await process_frame
	quit(1 if failures else 0)
