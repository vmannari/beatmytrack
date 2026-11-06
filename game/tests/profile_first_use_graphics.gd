extends SceneTree
## Offline actual-App fixture; optional hooks exist only in the frozen project.
var checks: int = 0
var failures: int = 0
var app: Node
var frames: Array[float] = []
var last_frame: int = 0
var measuring: bool = false
var rows: Array = []

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func observe() -> void:
	var now: int = Time.get_ticks_usec()
	if measuring and last_frame: frames.append((now-last_frame)/1000.0)
	last_frame = now
func run() -> void:
	var output: String = OS.get_environment("BMT_GRAPHICS_OUTPUT")
	if output.is_empty():
		push_error("An explicit owned graphics output folder is required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var probe: GDScript = load("res://tests/graphics_probe.gd") if FileAccess.file_exists("res://tests/graphics_probe.gd") else null
	if OS.get_environment("BMT_NATIVE_TRACE") == "1":
		check(GDExtensionManager.load_extension(OS.get_environment("BMT_NATIVE_EXTENSION")) == GDExtensionManager.LOAD_STATUS_OK,"owned native diagnostic loads")
	root.size = Vector2i(1280,720)
	var folder := "user://first-use-graphics"
	NativeTrackVisual.ROAD_DISK_CACHE.directory = folder.path_join("roads")
	app = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(folder.path_join("records.json")); app.records.settings.music_enabled = false
	app.library = TrackLibrary.new(folder.path_join("tracks")); app.cloud_root_override = folder.path_join("cloud")
	app.race_profile_enabled = true
	root.add_child(app)
	while not app.startup_complete: await process_frame
	process_frame.connect(observe)
	var themes: PackedStringArray = OS.get_environment("BMT_GRAPHICS_THEMES").split(",")
	if themes.is_empty() or themes[0].is_empty(): themes = ["pine"]
	for theme: String in themes:
		var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/star_spline_lap.json")); document.theme = theme
		var track: NativeTrack = TrackCompiler.compile(document)
		track.metadata.cloud_version = "owned-first-use-graphics"
		preload("res://track/prepared_world_cache.gd").trim_cache()
		for cycle: int in range(2):
			if probe != null: probe.case_name = theme+"-"+str(cycle)
			app.records.settings.camera_mode = "overhead"
			app._show_screen("tracks"); app.selected_track = track
			frames.clear(); last_frame = Time.get_ticks_usec(); measuring = true
			var began: int = Time.get_ticks_usec()
			print("RACE_BEGIN ",theme," ",cycle," ",int(Time.get_unix_time_from_system()*1000000.0))
			await app._start_race(track,false,true)
			var elapsed: int = Time.get_ticks_usec()-began
			measuring = false
			check(is_instance_valid(app.game) and app.game.preparation_complete,"full actual-App race readiness")
			if not is_instance_valid(app.game): continue
			var game: Node = app.game
			game.set_physics_process(false); game.hitch_diagnostics.persist_enabled = false
			check(game.sim.state.tick == 0 and game.countdown_ticks == 360,"unchanged tick-zero and countdown")
			check(not is_instance_valid(app.race_loading),"loading cover releases after readiness")
			var row := {"theme":theme,"cycle":cycle,"wall_us":elapsed,"max_frame_ms":frames.max(),"game":game.preparation_costs.duplicate(true),"world":game.track_ground.build_costs.duplicate(true),"effects":game.effect_preparation_counts.duplicate(true),"effects_ms":game.bridge_preparation_ms,"draw_groups":game.world_render_preparation.frame_groups,"draw_max_us":game.world_render_preparation.draw_us_max}
			game.paused = true; game._process(0.0)
			for index: int in range(24): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join(theme+"-"+str(cycle)+".png"))
			var identity: int = game.get_instance_id()
			await app._retry_race(true)
			check(is_instance_valid(app.game) and app.game.get_instance_id() == identity,"retry retains Game")
			rows.append(row); print("FIRST_USE_ROW ",JSON.stringify(row))
			app._leave_race(); await process_frame
	app.queue_free(); app = null
	for index: int in range(32): await process_frame
	FileAccess.open(output.path_join("profile.json"),FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"draws":probe.rows if probe != null else [],"checks":checks,"failures":failures},"  "))
	print("FIRST_USE_GRAPHICS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
