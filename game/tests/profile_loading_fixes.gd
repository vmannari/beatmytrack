extends SceneTree
## Actual offline App entry/re-entry/retry. No game-class preloads before timers.
var checks: int = 0
var failures: int = 0
var rows: Array = []

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("LOADING_FIXES_FAIL ",label)

func counter(path: String, name: String) -> int:
	if not ResourceLoader.has_cached(path): return 0
	var script: Script = load(path)
	return int(script.get(name))

func run() -> void:
	var vehicle: String = "compact"
	var theme: String = "pine"
	var star: bool = false
	var persist_world: bool = true
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--car="): vehicle = argument.trim_prefix("--car=")
		if argument.begins_with("--theme="): theme = argument.trim_prefix("--theme=")
		if argument == "--star": star = true
		if argument == "--disable-world-cache": persist_world = false
	root.size = Vector2i(1280,720)
	var began: int = Time.get_ticks_usec()
	var session_began: int = began
	var scene: PackedScene = load("res://core/app.tscn")
	var scene_ms: float = (Time.get_ticks_usec()-began)/1000.0
	var app: Node = scene.instantiate()
	var folder: String = "user://loading-fixes"
	DirAccess.make_dir_recursive_absolute(folder)
	app.records = load("res://persistence/local_records.gd").new(folder+"/records.json")
	app.records.settings.selected_car = vehicle
	app.records.settings.music_enabled = false
	app.library = load("res://persistence/track_library.gd").new(folder+"/tracks")
	app.cloud_root_override = folder+"/cloud"
	app.race_profile_enabled = true
	root.add_child(app)
	while not app.startup_complete: await process_frame
	var startup_ms: float = (Time.get_ticks_usec()-began)/1000.0
	check(not app.online.configured,"private offline App")
	app._garage_preloader.idle_ms = 100000000
	app._garage_preloader.foreground = false
	app._garage_preloader.set_process(false)
	var disk: Script = load("res://track/prepared_world_disk_cache.gd")
	if not persist_world: disk.directory = ""
	var catalog: Script = load("res://vehicle/vehicle_catalog.gd")
	catalog.selected = vehicle
	var path: String = "res://tests/fixtures/star_spline_lap.json" if star else "res://resources/tracks/ellipse.json"
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var track: Variant
	if star:
		document.theme = theme
		track = load("res://editor/track_compiler.gd").compile(document)
	else:
		track = load("res://track/native_track.gd").read(path)
		track.metadata.theme = theme
	check(track != null,"selected track exists")
	track.metadata.cloud_version = "owned-loading-fixes"
	for cycle: int in range(2):
		app._show_screen("tracks")
		app.selected_track = track
		var base_before: int = counter("res://vehicle/modular_car_base.gd","hits")
		began = Time.get_ticks_usec()
		await app._start_race(track,false,true)
		var elapsed: float = (Time.get_ticks_usec()-began)/1000.0
		check(is_instance_valid(app.game),"actual race installed")
		if not is_instance_valid(app.game): break
		var game: Node = app.game
		game.set_physics_process(false)
		game.hitch_diagnostics.persist_enabled = false
		check(game.preparation_complete,"race preparation completes")
		check(game.car.vehicle_id == vehicle,"selected vehicle preserved")
		check(game.sim.state.tick == 0 and game.countdown_ticks == 360,"tick zero and complete countdown on reveal")
		check(game.track_session.target_laps == 5,"five-lap contract retained")
		var row: Dictionary = {"cycle":cycle,"ready_ms":elapsed,
			"scene_to_ready_ms":(Time.get_ticks_usec()-session_began)/1000.0,
			"base_hits":counter("res://vehicle/modular_car_base.gd","hits")-base_before,
			"feature_load_ms":app.feature_load_ms.duplicate(true),
			"game_costs":game.preparation_costs.duplicate(true),
			"world_costs":game.track_ground.build_costs.duplicate(true),
			"graphics_groups":game.world_render_preparation.frame_groups if is_instance_valid(game.world_render_preparation) else 0,
			"finish_ms":game.bridge_preparation_ms}
		check(row.base_hits > 0,"current prepared vehicle base is accepted")
		# A real race remains alive through the countdown. Keep this frozen
		# observation alive until its optional IO settles, outside ready_ms.
		var publish_deadline: int = Time.get_ticks_msec()+5000
		while not disk.pending_writes.is_empty() and Time.get_ticks_msec() < publish_deadline:
			await process_frame
		row["world_costs"] = game.track_ground.build_costs.duplicate(true)
		row["world_disk_hits"] = disk.hits
		began = Time.get_ticks_usec()
		await app._retry_race(true)
		row["retry_ms"] = (Time.get_ticks_usec()-began)/1000.0
		check(app.game == game and game.sim.state.tick == 0 and game.countdown_ticks == 360,"retry reuses Game and resets full countdown")
		rows.append(row)
		print("LOADING_FIXES_ROW ",JSON.stringify(row))
		app._leave_race()
		for frame: int in range(8): await process_frame
	var result: Dictionary = {"checks":checks,"failures":failures,"car":vehicle,"theme":theme,"star":star,
		"persist_world":persist_world,
		"scene_ms":scene_ms,"startup_ms":startup_ms,"races":rows,
		"renderer":RenderingServer.get_current_rendering_method(),"engine":Engine.get_version_info()}
	FileAccess.open(OS.get_environment("BMT_LOADING_OUTPUT"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	app.queue_free(); app = null
	scene = null; catalog = null; track = null
	load("res://soundtrack/audio_world.gd").instance().queue_free()
	for frame: int in range(20): await process_frame
	print("LOADING_FIXES_COMPLETE ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
