extends "res://tests/test_runtime_effect_loading.gd"
## Keep the existing real-App car/theme/emission/interruption checks, then
## observe a complete AI-driven opening lap in each biome at native pacing.
var lap_rows: Array = []

func track_for(theme: String) -> NativeTrack:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../backend/tests/fixtures/verified_oval.json"))
	fixture.document.theme = theme
	return TrackCompiler.compile(fixture.document)

func first_emission(game: Node) -> void:
	await super.first_emission(game)
	if mode != "complete" or game.vehicle_id != "compact": return
	game.ai_enabled = true
	game.hitch_diagnostics.persist_enabled = false
	var draw_before: float = Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)
	var began: int = Time.get_ticks_usec()
	var last: int = began
	var maximum: float = 0.0
	var driving_frames: int = 0
	var deadline: int = Time.get_ticks_msec()+90000
	game.process_mode = Node.PROCESS_MODE_INHERIT
	game.set_physics_process(true)
	while game.track_session.completed_laps < 1 and Time.get_ticks_msec() < deadline:
		await process_frame
		var now: int = Time.get_ticks_usec()
		if game.countdown_ticks == 0:
			maximum = maxf(maximum,(now-last)/1000.0)
			driving_frames += 1
		last = now
	game.set_physics_process(false)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	check(game.track_session.completed_laps >= 1,"prepared "+str(game.native_track.metadata.theme)+" completes actual first driving lap")
	check(game.countdown_ticks == 0 and game.sim.state.tick > 0,"full countdown precedes the first real lap")
	var row := {"theme":game.native_track.metadata.theme,"completed_laps":game.track_session.completed_laps,"elapsed_ms":(Time.get_ticks_usec()-began)/1000.0,"driving_frames":driving_frames,"max_driving_frame_ms":maximum,"new_draw_pipelines":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)-draw_before,"contacts":game.sim.state.collision_count}
	lap_rows.append(row)
	cases[-1].first_lap = row
	print("PREPARED_FIRST_LAP ",JSON.stringify(row))

func run() -> void:
	if DisplayServer.get_name() == "headless": quit(1); return
	root.size = Vector2i(960,540)
	var folder := "user://loading-first-lap-"+TrackLibrary.unique_id()
	preload("res://track/road_mesh_disk_cache.gd").directory = folder.path_join("roads")
	if "--loading-control" in OS.get_cmdline_user_args():
		var code: String = FileAccess.get_file_as_string("res://core/app.gd")
		var effect: String = 'var effect_preparation = preload("res://vehicle/effect_render_preparation.gd")'
		var memory: String = 'var editor_memory = preload("res://editor/editor_memory.gd").new()'
		if code.count(effect) != 1 or code.count(memory) != 1:
			push_error("Missing exact task-start loader control anchors"); quit(1); return
		code = code.replace(effect,'var effect_preparation = preload("res://../docs/evidence/race-loading-implementation-2026-11-02/before/game/vehicle/effect_render_preparation.gd")')
		code = code.replace(memory,'var editor_memory = preload("res://../docs/evidence/race-loading-implementation-2026-11-02/before/game/editor/editor_memory.gd").new()')
		var script := GDScript.new(); script.source_code = code
		assert(script.reload() == OK)
		app = script.new()
	else:
		app = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.records.settings.music_enabled = false
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	process_frame.connect(observe)
	var only_theme: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--theme="): only_theme = argument.trim_prefix("--theme=")
	if not only_theme.is_empty():
		await race("compact",only_theme)
	elif not "--only-interruptions" in OS.get_cmdline_user_args():
		for vehicle: String in VehicleCatalog.IDS: await race(vehicle,"pine")
		for theme: String in TrackTheme.IDS:
			if theme != "pine": await race("compact",theme)
	if only_theme.is_empty():
		for interruption: String in ["navigation","car","selection","scope","pressure","teardown"]:
			await race("compact","pine",interruption)
	process_frame.disconnect(observe)
	for _frame: int in range(24): await process_frame
	FileAccess.open(OS.get_environment("BMT_LOADING_OUTPUT"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"cases":cases,"first_laps":lap_rows},"  "))
	print("LOADING_FIRST_LAP_COMPLETE ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
