extends "res://tests/review_race_loading_2026_11_02.gd"
## Interleaved actual-App control: task-start effect loop and memory policy.
## Geometry/shaders, preparation coverage and final full draw are unchanged.
const OLD_MEMORY = preload("res://../docs/evidence/race-loading-implementation-2026-11-02/before/game/editor/editor_memory.gd")
const NEW_MEMORY = preload("res://editor/editor_memory.gd")
var control: bool = false
var case_draws: int = 0

func instrumented_app() -> GDScript:
	var script := super.instrumented_app()
	if script == null: return null
	var needle := 'var effect_preparation = preload("res://vehicle/effect_render_preparation.gd")'
	var code: String = script.source_code
	if code.count(needle) != 1: push_error("Missing effect control anchor"); return null
	code = code.replace(needle,'var effect_preparation = preload("res://../docs/evidence/race-loading-implementation-2026-11-02/before/game/vehicle/effect_render_preparation.gd") if loading_effect_control else preload("res://vehicle/effect_render_preparation.gd")')
	code += "\nvar loading_effect_control: bool = false\n"
	script.source_code = code
	if script.reload() != OK: return null
	return script

func count_draws() -> void:
	if not is_instance_valid(app) or not is_instance_valid(app.game): return
	var world: Node = app.game.get_node_or_null("World")
	if world != null and not world.find_children("Covered*","GPUParticles3D",true,false).is_empty(): case_draws += 1

func run() -> void:
	OS.set_environment("BMT_API_URL", "")
	root.size = Vector2i(1280,720)
	var folder := "user://loading-optimisation-profile-"+TrackLibrary.unique_id()
	preload("res://track/road_mesh_disk_cache.gd").directory = folder.path_join("roads")
	var script := instrumented_app()
	if script == null: quit(1); return
	app = script.new()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.records.settings.music_enabled = false
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override = folder.path_join("cloud")
	app.race_profile_enabled = true
	root.add_child(app)
	while not app.startup_complete: await process_frame
	Engine.time_scale = 0.0
	var theme := "pine"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--theme="): theme = argument.trim_prefix("--theme=")
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TRACK_PATH))
	document.theme = theme
	var track: NativeTrack = TrackCompiler.compile(document)
	verify(track != null,"profile compiles")
	if track == null: quit(1); return
	track.metadata.cloud_version = "owned-interleaved-loading"
	WORLDS.entries.clear()
	process_frame.connect(observe)
	process_frame.connect(count_draws)
	var reference: PackedByteArray
	var pictures: Array = []
	# Each optimized pair first populates its retained world, then consumes it.
	# Both control repeats remain warm in shader/car/road caches but use the
	# original memory policy. Raw pre-entry cache state accompanies every row.
	for cycle: int in range(8):
		control = cycle in [0,1,4,5]
		current_case = theme+"-"+str(cycle)
		app.loading_effect_control = control
		app.editor_memory = OLD_MEMORY.new() if control else NEW_MEMORY.new()
		app.editor_memory.next_sample = 0
		app.editor_memory.tick(app)
		var worlds_before: int = WORLDS.entries.size()
		app._show_screen("tracks"); app.selected_track = track
		app._load_probe_marks.clear(); frames.clear(); case_draws = 0
		last_frame = Time.get_ticks_usec(); measuring = true
		var began: int = Time.get_ticks_usec()
		await app._start_race(track,false,true)
		var elapsed: float = (Time.get_ticks_usec()-began)/1000.0
		measuring = false
		verify(is_instance_valid(app.game),"interleaved race installs")
		if not is_instance_valid(app.game): break
		var game: Node = app.game
		game.set_physics_process(false)
		game.hitch_diagnostics.persist_enabled = false
		verify(game.preparation_complete and game.sim.state.tick == 0 and game.countdown_ticks == 360 and game.track_session.target_laps == 5,"exact race start after either preparation path")
		var row := {"cycle":cycle,"control":control,"theme":theme,"wall_ms":elapsed,"max_frame_ms":frames.max() if not frames.is_empty() else 0.0,"marks":app._load_probe_marks.duplicate(true),"game_costs":game.preparation_costs.duplicate(true),"world_costs":game.track_ground.build_costs.duplicate(true),"effects_ms":game.bridge_preparation_ms,"effect_counts":game.effect_preparation_counts.duplicate(true),"worlds_before":worlds_before,"covered_process_frames":case_draws}
		game.process_mode = Node.PROCESS_MODE_DISABLED
		for _frame: int in range(4): await process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var picture: Image = root.get_texture().get_image()
			var data: PackedByteArray = picture.get_data()
			if reference.is_empty(): reference = data
			var changed: int = 0
			var maximum: int = 0
			for index: int in range(data.size()):
				var difference: int = absi(int(data[index])-int(reference[index]))
				if difference > 0: changed += 1; maximum = maxi(maximum,difference)
			row.image_changed_bytes = changed
			row.image_max_channel_difference = maximum
			var path: String = OS.get_environment("BMT_LOADING_OUTPUT").trim_suffix(".json")+"-"+str(cycle)+".png"
			picture.save_png(path); pictures.append(path)
			samples.append(row)
		print("INTERLEAVED_LOADING ",JSON.stringify(row))
		app._leave_race()
		for _frame: int in range(4): await process_frame
		app.editor_memory.next_sample = 0
		app.editor_memory.tick(app)
		if not control:
			verify(NEW_MEMORY.retained(app).retained_bytes <= NEW_MEMORY.RETAINED_BUDGET,"optimized retention respects unchanged total allowance")
	process_frame.disconnect(count_draws)
	var result := {"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"theme":theme,"samples":samples,"cache_events":cache_events,"pictures":pictures}
	FileAccess.open(OS.get_environment("BMT_LOADING_OUTPUT"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	app.queue_free(); app = null; script = null; track = null
	Engine.time_scale = 1.0
	for _frame: int in range(12): await process_frame
	print("INTERLEAVED_LOADING_COMPLETE ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
