extends "res://tests/profile_track_load_stages.gd"
## Interleaved actual-App measurements: only numeric support-cache reuse differs.
const ROADS = preload("res://editor/road_preparation.gd")
const SUPPORT = preload("res://track/road_support_cache.gd")
var failures: int = 0

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	root.size = Vector2i(1280,720)
	var folder := "user://loading-support-"+TrackLibrary.unique_id()
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
	var track: NativeTrack = TrackCompiler.compile(JSON.parse_string(FileAccess.get_file_as_string(TRACK_PATH)))
	track.metadata.cloud_version = "owned-loading-support"
	process_frame.connect(observe)
	for cycle: int in range(5):
		var control: bool = cycle in [1,3]
		if control:
			SUPPORT.trim()
		app._show_screen("tracks")
		app.selected_track = track
		app._load_probe_marks.clear()
		frames.clear()
		last_frame = Time.get_ticks_usec()
		measuring = true
		var retained_before: int = SUPPORT.entries.size()
		var began := Time.get_ticks_usec()
		await app._start_race(track,false,true)
		var elapsed := (Time.get_ticks_usec()-began)/1000.0
		measuring = false
		if not is_instance_valid(app.game) or not app.game.preparation_complete:
			push_error("Race did not become ready"); quit(1); return
		app.game.set_physics_process(false)
		if app.game.countdown_ticks != 360 or app.game.sim.state.tick != 0 or app.game.track_session.target_laps != 5:
			failures += 1; push_error("Loading changed canonical time/countdown/laps")
		var row := {"cycle":cycle,"support_evicted_control":control,"retained_before":retained_before,"retained_after":SUPPORT.entries.size(),"wall_ms":elapsed,"max_frame_ms":frames.max(),"marks":app._load_probe_marks.duplicate(true),"road_bytes":ROADS.residency(),"support_bytes":SUPPORT.bytes_used()}
		samples.append(row)
		print("LOADING_SUPPORT_APP ",JSON.stringify(row))
		app._leave_race()
		await process_frame
	# Exercise the actual App pressure path and its public accounting.
	var retained: Dictionary = app.editor_memory.retained(app)
	if retained.other.road_support_bytes != SUPPORT.bytes_used():
		failures += 1; push_error("Support missing from retained-memory accounting")
	app.notification(NOTIFICATION_OS_MEMORY_WARNING)
	for _frame: int in range(30): await process_frame
	if not SUPPORT.entries.is_empty():
		failures += 1; push_error("App memory pressure did not release support cache")
	var output := OS.get_environment("BMT_LOADING_OUTPUT")
	if not output.is_empty():
		FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"samples":samples,"failures":failures},"  "))
	app.queue_free()
	app = null
	for _frame: int in range(8): await process_frame
	quit(1 if failures else 0)
