extends Node
## Task-owned, offline performance entry point. Never installed over the game.
var app: Node
var phase: String = "startup"
var frame_times: Array[float] = []
var phase_started: int = 0
var previous_frame: int = 0
var report: Dictionary = {"schema":1,"kind":"isolated actual-App Android performance probe","target_fps":60,"expected_cases":17,"cases":[],"errors":[]}
var stopped: bool = false
var mode: String = "full"
var overlay: Label
var process_ms: Array[float] = []
var physics_ms: Array[float] = []

class ProbeDriver extends DriverInput:
	var game_ref: WeakRef
	var route := RouteDriver.new()
	var callback_us: int = 0
	var samples: int = 0
	var meters: float = 0
	var previous: Vector2 = Vector2.INF
	func sample() -> DriveFrame:
		var game: Node = game_ref.get_ref()
		if game == null: return DriveFrame.new()
		if previous!=Vector2.INF: meters+=previous.distance_to(game.sim.state.position)
		previous=game.sim.state.position
		var start: int = Time.get_ticks_usec()
		var result: DriveFrame = route.sample(game.sim.state,game.native_track,game.handling)
		callback_us += Time.get_ticks_usec()-start
		samples += 1
		return result

func _ready() -> void:
	if "--perf-garage-only" in OS.get_cmdline_user_args(): mode="garage"
	if OS.get_name()=="Android":
		var directory: String="/storage/emulated/0/Android/data/org.beatmytrack.perf.r20261027a/files"
		DirAccess.make_dir_recursive_absolute(directory)
		var path: String=directory.path_join("probe_mode.txt")
		if FileAccess.file_exists(path):
			var requested: String=FileAccess.get_file_as_string(path).strip_edges()
			if requested in ["full","garage"]: mode=requested
	report.mode=mode
	report.expected_cases=5 if mode=="garage" else 17
	# Preserve the production frame limiter and VSync settings.
	report.engine_max_fps = Engine.max_fps
	report.screen_hz = DisplayServer.screen_get_refresh_rate()
	if DisplayServer.has_method("screen_set_keep_on"): DisplayServer.call("screen_set_keep_on",true)
	var cfg := ConfigFile.new()
	cfg.set_value("backend","url","")
	cfg.save("user://backend.cfg")
	OS.set_environment("BMT_API_URL","")
	get_tree().process_frame.connect(observe)
	get_tree().create_timer(720).timeout.connect(func() -> void:
		report.errors.append("overall deadline"); finish())
	run.call_deferred()

func observe() -> void:
	var now: int = Time.get_ticks_usec()
	if previous_frame>0 and not phase.is_empty(): frame_times.append((now-previous_frame)/1000.0)
	previous_frame = now
	if not phase.is_empty():
		process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
		physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)

func begin(value: String) -> void:
	phase = value
	phase_started = Time.get_ticks_usec()
	previous_frame = phase_started
	frame_times.clear()
	process_ms.clear()
	physics_ms.clear()
	if is_instance_valid(overlay): overlay.text = "Automatic performance test — "+value+"\nAndroid Back stops this isolated probe"
	print("BMT_PERF_BEGIN ",value)

func summary() -> Dictionary:
	var values: Array[float] = frame_times.duplicate()
	values.sort()
	process_ms.sort()
	physics_ms.sort()
	var slow34: int = 0
	var slow100: int = 0
	for value: float in values:
		if value>34: slow34+=1
		if value>100: slow100+=1
	return {"phase":phase,"wall_ms":(Time.get_ticks_usec()-phase_started)/1000.0,"frames":values.size(),"p50_ms":percentile(values,0.5),"p95_ms":percentile(values,0.95),"p99_ms":percentile(values,0.99),"max_ms":values.back() if not values.is_empty() else 0,"over34":slow34,"over100":slow100,"engine_process_monitor_p95_ms":percentile(process_ms,.95),"engine_physics_monitor_p95_ms":percentile(physics_ms,.95)}

func percentile(values: Array[float], fraction: float) -> float:
	return values[clampi(ceili(values.size()*fraction)-1,0,values.size()-1)] if not values.is_empty() else 0

func record(value: Dictionary) -> void:
	report.cases.append(value)
	print("BMT_PERF_CASE ",JSON.stringify(value))
	phase = ""
	DirAccess.make_dir_recursive_absolute("user://performance_probe")
	var file := FileAccess.open("user://performance_probe/report.json",FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report)); file.close()

func run() -> void:
	report.engine = Engine.get_version_info().string
	report.debug_build = OS.is_debug_build()
	report.os = OS.get_name()
	report.model = OS.get_model_name()
	report.renderer = RenderingServer.get_current_rendering_method()
	report.adapter = RenderingServer.get_video_adapter_name()
	report.window_size = var_to_str(get_tree().root.size)
	report.viewport_size = var_to_str(get_viewport().get_visible_rect().size)
	report.physics = VehicleSimulation.PHYSICS_VERSION
	report.rules = RaceRules.KEY
	begin("app_startup")
	app = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new("user://performance_probe/records.json")
	app.records.settings.music_enabled = false
	app.records.settings.optional_analytics = false
	app.library = TrackLibrary.new("user://performance_probe/tracks")
	app.cloud_root_override = "user://performance_probe/cloud"
	get_tree().root.add_child(app)
	while not app.startup_complete: await get_tree().process_frame
	record(summary())
	var layer := CanvasLayer.new()
	layer.layer = 200
	add_child(layer)
	overlay = Label.new()
	overlay.position = Vector2(20,80)
	overlay.add_theme_font_size_override("font_size",18)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(overlay)
	# Keep production renderer, original materials/lighting and screen size.
	# Route control is diagnostic input; its CPU time is reported separately.
	if mode=="garage":
		VehicleCatalog.selected="kart"
		await garage("garage_first_visit")
		if not stopped:
			app._show_screen("tracks")
			await get_tree().process_frame
			await garage("garage_repeat")
		finish()
		return
	await race("compact","res://resources/perf/star.json",true,"star_first",35)
	await race("compact","res://resources/perf/star.json",true,"star_repeat",15)
	await race("compact","res://resources/storm_tracks/storm_freight.json",true,"storm_first",15)
	await race("compact","res://resources/storm_tracks/storm_freight.json",true,"storm_repeat",15)
	await race("electric","res://resources/storm_tracks/storm_freight.json",true,"electric_first",15)
	await race("kart","res://resources/storm_tracks/storm_freight.json",true,"kart_night",15,"night_city")
	await garage("garage_first_visit")
	if not stopped:
		app._show_screen("tracks")
		await get_tree().process_frame
		await garage("garage_repeat")
	finish()

func race(vehicle: String, source: String, compile: bool, label: String, seconds: float, theme: String = "") -> void:
	if stopped: return
	VehicleCatalog.selected = vehicle
	app._show_screen("tracks")
	var fixture_started: int=Time.get_ticks_usec()
	var track: NativeTrack = TrackCompiler.compile(JSON.parse_string(FileAccess.get_file_as_string(source))) if compile else NativeTrack.read(source)
	if not theme.is_empty(): track.metadata.theme = theme
	track.metadata.cloud_version = "isolated-performance-probe"
	app.selected_track = track
	var fixture_compile_ms: float=(Time.get_ticks_usec()-fixture_started)/1000.0
	begin("load_"+label)
	app.race_profile_enabled = true
	await app._start_race(track,false,true)
	app.race_profile_enabled = false
	if stopped or not is_instance_valid(app.game):
		report.errors.append("race unavailable: "+label)
		return
	var game: Node = app.game
	var loading: Dictionary = summary()
	loading.vehicle = vehicle
	loading.fixture_compile_ms = fixture_compile_ms
	loading.fixture_to_ready_wall_ms = (Time.get_ticks_usec()-fixture_started)/1000.0
	loading.frozen_tick = game.sim.state.tick
	loading.countdown = game.countdown_ticks
	loading.preparation = game.preparation_costs
	loading.effects = game.effect_preparation_counts
	loading.render_scale = game._render_viewport.scaling_3d_scale
	loading.viewport = var_to_str(game._render_viewport.size)
	record(loading)
	game.profile_enabled = false
	if is_instance_valid(game.hitch_diagnostics): game.hitch_diagnostics.detailed = false
	var input := ProbeDriver.new()
	input.game_ref = weakref(game)
	input.route.speed_scale = 1.0
	game.driver = input
	while game.countdown_ticks>0 and not stopped: await get_tree().process_frame
	if stopped: return
	var initial_tick: int = game.sim.state.tick
	var initial_collisions: int = game.sim.state.collision_count
	begin("drive_"+label)
	var end: int = Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<end and not stopped and not game.track_session.finished: await get_tree().process_frame
	var driving: Dictionary = summary()
	driving.vehicle = vehicle
	driving.meters = input.meters
	driving.ticks = game.sim.state.tick-initial_tick
	driving.completed_laps = game.track_session.completed_laps
	driving.contacts = game.sim.state.collision_count-initial_collisions
	if driving.contacts>0 or input.meters<30: report.errors.append("invalid driving workload: "+label)
	driving.speed_kmh = game.sim.state.velocity.length()*3.6
	driving.driver_samples = input.samples
	driving.driver_cpu_us = input.callback_us
	driving.static_memory = Performance.get_monitor(Performance.MEMORY_STATIC)
	driving.render_scale = game._render_viewport.scaling_3d_scale
	driving.condition_save_attempts = game.condition_save_count
	record(driving)
	if is_instance_valid(app.game): app._leave_race()
	for _frame: int in range(8): await get_tree().process_frame

func garage(label: String) -> void:
	if stopped: return
	if label=="garage_first_visit" and is_instance_valid(app._garage_preloader): app._garage_preloader.evict()
	begin(label)
	app._show_screen("garage")
	var navigation_dispatch_ms: float=(Time.get_ticks_usec()-phase_started)/1000.0
	var picture_presented_ms: float=0
	var deadline: int = Time.get_ticks_msec()+90000
	var next_status: int = 0
	var statuses: Array[Dictionary] = []
	while not stopped and Time.get_ticks_msec()<deadline:
		var page: Node = app._retained_garage
		if Time.get_ticks_msec()>=next_status:
			var status: Dictionary={"elapsed_ms":(Time.get_ticks_usec()-phase_started)/1000.0,"screen":app.screen,"page":is_instance_valid(page)}
			if is_instance_valid(page) and is_instance_valid(page.showroom):
				var view: Node=page.showroom
				status.constructed=view.showroom_ready
				status.stage=view.get_meta("performance_stage","")
				var pending_value: Variant=view.get("preparing")
				status.preparing=pending_value if pending_value is bool else false
				status.script=view.get_script().resource_path
				status.visible=view.is_visible_in_tree()
				status.entry_presented=view.call("_entry_presented") if view.has_method("_entry_presented") else true
				var first: Variant=view.get("_first")
				status.pending_materials=first.pending.size() if is_instance_valid(first) else -1
				var pending: Variant=view.get("_pending")
				status.pending_car=not pending.is_empty() if pending is Dictionary else false
			statuses.append(status)
			print("BMT_PERF_GARAGE_STATUS ",JSON.stringify(status))
			next_status=Time.get_ticks_msec()+1000
		if picture_presented_ms==0 and is_instance_valid(page) and is_instance_valid(page.showroom):
			var picture: Node=page.showroom.find_child("GarageOpeningPicture",true,false)
			if is_instance_valid(picture) and picture.visible and (app.menu_page_motion==null or not app.menu_page_motion.is_running()):
				if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
				picture_presented_ms=(Time.get_ticks_usec()-phase_started)/1000.0
		if is_instance_valid(page) and is_instance_valid(page.showroom) and page.showroom.showroom_ready:
			if garage_ready(page.showroom): break
		await get_tree().process_frame
	for _frame: int in range(12): await get_tree().process_frame
	var value: Dictionary = summary()
	value.navigation_dispatch_ms = navigation_dispatch_ms
	value.picture_presented_ms = picture_presented_ms
	value.statuses = statuses
	value.ready = is_instance_valid(app._retained_garage) and is_instance_valid(app._retained_garage.showroom) and app._retained_garage.showroom.showroom_ready and garage_ready(app._retained_garage.showroom)
	value.static_memory = Performance.get_monitor(Performance.MEMORY_STATIC)
	if not value.ready: report.errors.append("Garage missed readiness deadline: "+label)
	record(value)
	if value.ready and not stopped:
		var showroom: Node = app._retained_garage.showroom
		begin(label+"_orbit")
		var orbit_end: int = Time.get_ticks_msec()+5000
		while Time.get_ticks_msec()<orbit_end and not stopped:
			showroom.rotate_view(Vector2(1.5,0))
			await get_tree().process_frame
		var orbit_result: Dictionary = summary()
		orbit_result.ready = garage_ready(showroom)
		orbit_result.static_memory = Performance.get_monitor(Performance.MEMORY_STATIC)
		record(orbit_result)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if report.get("finished",false): get_tree().quit()
		else: stopped = true; report.errors.append("stopped by Android Back"); finish()

func finish() -> void:
	if stopped and report.get("finished",false): return
	stopped = true
	if report.cases.size()!=int(report.expected_cases): report.errors.append("incomplete case set: "+str(report.cases.size())+"/"+str(report.expected_cases))
	report.finished = true
	phase = ""
	var encoded: String = Marshalls.utf8_to_base64(JSON.stringify(report))
	var count: int = ceili(encoded.length()/700.0)
	for index: int in range(count): print("BMT_PERF_CHUNK ",index,"/",count," ",encoded.substr(index*700,700))
	print("BMT_PERF_FINISHED ",report.errors.size())
	# Keep only this probe's finished screen awake until host cleanup/retest.
	# No account/game work continues, and Back still closes the activity.
	if is_instance_valid(app): app.queue_free()
	if get_tree().process_frame.is_connected(observe): get_tree().process_frame.disconnect(observe)
	if is_instance_valid(overlay): overlay.text="Performance capture finished. Android Back closes this test."
	OS.low_processor_usage_mode = true
	OS.low_processor_usage_mode_sleep_usec = 100000
	process_mode = Node.PROCESS_MODE_DISABLED

func garage_ready(view: Node) -> bool:
	if not is_instance_valid(view) or not view.showroom_ready: return false
	var pending_value: Variant=view.get("preparing")
	if pending_value is bool: return not pending_value
	return true
