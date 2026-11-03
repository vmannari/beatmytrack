extends "res://tests/profile_track_load_stages.gd"
## Evaluation only: exact shipping loading sequence, timestamp hooks in RAM.
## Private records, cloud folder and disk cache; no network or owner data.
const WORLDS = preload("res://track/prepared_world_cache.gd")
var checks: int = 0
var failures: int = 0
var cache_events: Array = []
var last_cache_state: Array = []
var current_case: String = "startup"

func observe() -> void:
	super.observe()
	if not is_instance_valid(app): return
	var state: Array = [WORLDS.entries.size(),WORLDS.bytes_used(),app.editor_memory.trims]
	if state == last_cache_state: return
	last_cache_state = state
	cache_events.append({"us":Time.get_ticks_usec(),"case":current_case,"state":state,"telemetry":app.editor_memory.telemetry.duplicate(true)})

func instrumented_app() -> GDScript:
	# Daily limits were added after the older profiler; keep that original
	# diagnostic and adapt the anchors only for this evaluation.
	var source := FileAccess.get_file_as_string(APP_PATH).replace("\r\n","\n")
	var start := source.find("func _start_race(track:")
	var end := source.find("\nfunc _race_installation_current(",start)
	if start < 0 or end <= start: push_error("Missing race function"); return null
	var body := source.substr(start,end-start)
	var hooks := [
		["\tif not await _await_selected_preparation(track,","selected_wait_begin"],
		["\tvar daily_rules: RefCounted","selected_wait_end"],
		["\tvar prepared_roads: Dictionary = {}","roads_begin"],
		["\treturning_to_editor = from_editor","roads_end"],
		["\tadd_child(game)\n\tvar prepared_game: Node = game","game_begin"],
		["\tif is_instance_valid(prepared_game.world_render_preparation):","game_end"],
		["\t\tif not await prepared_game.world_render_preparation.prepare(","graphics_begin"],
		["\tif rivalry_racing:\n\t\tgame.ghost_mode","graphics_end"],
		["\tvar preparation_started: int = Time.get_ticks_usec()","effects_begin"],
		["\tvar preparation_ms: float = (Time.get_ticks_usec() - preparation_started)","effects_end"],
		["\t_close_race_loading(loading_id)\n\n","race_end"],
	]
	for hook: Array in hooks:
		var needle: String = hook[0]
		if body.count(needle) != 1: push_error("Review anchor changed: "+str(hook[1])); return null
		var indent := "\t\t" if needle.begins_with("\t\t") else "\t"
		body = body.replace(needle,indent+"_load_probe_mark(\""+str(hook[1])+"\")\n"+needle)
	source = source.substr(0,start)+body+source.substr(end)
	source += "\nvar _load_probe_marks: Array = []\nfunc _load_probe_mark(label: String) -> void:\n\t_load_probe_marks.append({\"name\":label,\"us\":Time.get_ticks_usec()})\n"
	var script := GDScript.new()
	script.source_code = source
	if script.reload() != OK: push_error("Review App failed to compile"); return null
	return script

func verify(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("LOAD_REVIEW_FAIL ", label)

func run() -> void:
	OS.set_environment("BMT_API_URL", "")
	root.size = Vector2i(1280,720)
	var folder := "user://race-loading-review-"+TrackLibrary.unique_id()
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
	process_frame.connect(observe)
	var themes: PackedStringArray = ["pine","desert","winter"]
	var cycles: int = 3
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--themes="): themes = argument.trim_prefix("--themes=").split(",")
		if argument.begins_with("--cycles="): cycles = clampi(argument.trim_prefix("--cycles=").to_int(),1,3)
	for theme: String in themes:
		var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TRACK_PATH))
		document.theme = theme
		var began := Time.get_ticks_usec()
		var track: NativeTrack = TrackCompiler.compile(document)
		var compile_ms := (Time.get_ticks_usec()-began)/1000.0
		verify(track != null,theme+" compilation")
		if track == null: continue
		track.metadata.cloud_version = "owned-loading-review"
		WORLDS.entries.clear()
		for cycle: int in range(cycles):
			current_case = theme+"-"+str(cycle)
			app.records.settings.camera_mode = "overhead"
			app._show_screen("tracks")
			app.selected_track = track
			app._load_probe_marks.clear()
			frames.clear()
			last_frame = Time.get_ticks_usec()
			measuring = true
			began = Time.get_ticks_usec()
			await app._start_race(track,false,true)
			var wall_ms := (Time.get_ticks_usec()-began)/1000.0
			measuring = false
			verify(is_instance_valid(app.game),theme+" game installed")
			if not is_instance_valid(app.game): continue
			var game: Node = app.game
			game.set_physics_process(false)
			game.hitch_diagnostics.persist_enabled = false
			verify(game.preparation_complete,theme+" construction complete")
			verify(game.sim.state.tick == 0,theme+" canonical tick zero")
			verify(game.countdown_ticks == 360,theme+" complete countdown")
			verify(game.track_session.target_laps == 5,theme+" five laps")
			verify(not is_instance_valid(app.race_loading),theme+" loading cover released")
			var row := {"theme":theme,"cycle":cycle,"compile_ms_before_race":compile_ms,"wall_ms":wall_ms,"max_frame_ms":frames.max() if not frames.is_empty() else 0.0,"marks":app._load_probe_marks.duplicate(true),"game_costs":game.preparation_costs.duplicate(true),"world_costs":game.track_ground.build_costs.duplicate(true),"effects_finish_ms":game.bridge_preparation_ms,"effect_counts":game.effect_preparation_counts.duplicate(true),"world_cache_entries":WORLDS.entries.size(),"world_cache_bytes":WORLDS.bytes_used()}
			if is_instance_valid(game.world_render_preparation):
				row.draw_groups = game.world_render_preparation.frame_groups
				row.draw_wait_max_us = game.world_render_preparation.draw_us_max
			var game_id: int = game.get_instance_id()
			began = Time.get_ticks_usec()
			await app._retry_race(true)
			row.retry_ms = (Time.get_ticks_usec()-began)/1000.0
			verify(is_instance_valid(app.game) and app.game.get_instance_id() == game_id,theme+" retry reuses Game")
			verify(game.sim.state.tick == 0 and game.countdown_ticks == 360,theme+" retry retains exact start")
			samples.append(row)
			print("RACE_LOADING_REVIEW ",JSON.stringify(row))
			app._leave_race()
			await process_frame
	var output := OS.get_environment("BMT_LOADING_OUTPUT")
	verify(not output.is_empty(),"explicit evidence destination")
	if not output.is_empty():
		var file := FileAccess.open(output,FileAccess.WRITE)
		verify(file != null,"evidence opens")
		if file != null:
			file.store_string(JSON.stringify({"checks":checks,"failures":failures,"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"headless":DisplayServer.get_name()=="headless","app_sha256":FileAccess.get_sha256(APP_PATH),"game_sha256":FileAccess.get_sha256("res://core/game.gd"),"samples":samples,"cache_events":cache_events},"  "))
			file.close()
	app.queue_free()
	app = null
	for _frame: int in range(8): await process_frame
	print("RACE_LOADING_REVIEW_COMPLETE ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
