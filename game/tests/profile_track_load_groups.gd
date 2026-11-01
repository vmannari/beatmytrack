extends SceneTree
## Isolated offline App fixture. Timestamp-only instrumentation is injected into
## an in-memory copy of App; the shipping script is never edited.

const APP_PATH := "res://core/app.gd"
const TRACK_PATH := "res://tests/fixtures/star_spline_lap.json"
var app: Node
var samples: Array = []
var frames: Array[float] = []
var last_frame: int = 0
var measuring := false
var observing_driving := false
var driving_frames: Array[float] = []

func _initialize() -> void:
	run.call_deferred()

func observe() -> void:
	var now := Time.get_ticks_usec()
	if measuring and last_frame > 0: frames.append((now-last_frame)/1000.0)
	if observing_driving and last_frame > 0 and is_instance_valid(app.game) and app.game.countdown_ticks <= 0: driving_frames.append((now-last_frame)/1000.0)
	last_frame = now

func instrumented_app() -> GDScript:
	var source := FileAccess.get_file_as_string(APP_PATH)
	var start := source.find("func _start_race(track:")
	var end := source.find("\nfunc _race_installation_current(", start)
	if start < 0 or end <= start:
		push_error("Cannot find the App race-loading function")
		return null
	var body := source.substr(start,end-start)
	var hooks := [
		["\tif not await _await_selected_preparation(track,", "selected_wait_begin"],
		["\tcloud_ticket = {}\n\tvar road_overlap:", "selected_wait_end"],
		["\tvar prepared_roads: Dictionary = {}", "roads_begin"],
		["\treturning_to_editor = from_editor", "roads_end"],
		["\tadd_child(game)\n\tvar prepared_game: Node = game", "game_begin"],
		["\tif is_instance_valid(prepared_game.world_render_preparation):", "game_end"],
		["\t\tif not await prepared_game.world_render_preparation.prepare(", "graphics_begin"],
		["\tif rivalry_racing:\n\t\tgame.ghost_mode", "graphics_end"],
		["\tvar preparation_started: int = Time.get_ticks_usec()", "effects_begin"],
		["\tvar preparation_ms: float = (Time.get_ticks_usec() - preparation_started)", "effects_end"],
		["\t_close_race_loading(loading_id)\n\n", "race_end"],
	]
	if "--probe-invalid-anchor" in OS.get_cmdline_user_args(): hooks[0][0] = "deliberately invalid anchor"
	for hook: Array in hooks:
		var needle: String = hook[0]
		if body.count(needle) != 1:
			push_error("Instrumentation anchor changed: "+str(hook[1]))
			return null
		var indent := "\t\t" if needle.begins_with("\t\t") else "\t"
		body = body.replace(needle,indent+"_load_probe_mark(\""+str(hook[1])+"\")\n"+needle)
	var wrap_anchor := "\tif is_instance_valid(prepared_game.world_render_preparation):"
	if body.count(wrap_anchor) != 1:
		push_error("Missing world probe anchor")
		return null
	body = body.replace(wrap_anchor,wrap_anchor+"\n\t\t_probe_wrap_world(prepared_game.world_render_preparation)")
	source = source.substr(0,start)+body+source.substr(end)
	source += "\nvar _load_probe_marks: Array = []\nfunc _load_probe_mark(label: String) -> void:\n\t_load_probe_marks.append({\"name\":label,\"us\":Time.get_ticks_usec()})\n"
	source += "\nfunc _probe_wrap_world(node: Node) -> void:\n\tvar p: Dictionary = node.pending\n\tvar n: int = p.size()\n\tvar k: Array = node._pending_keys\n\tvar c: int = node._key_cursor\n\tvar m: Dictionary = node._material_keys\n\tnode.set_script(load(\"res://tests/track_load_world_probe.gd\"))\n\tnode.pending = p\n\tnode._pending_keys.assign(k)\n\tnode._key_cursor = c\n\tnode._material_keys = m\n\tnode.captured_pending = n\n"
	var script := GDScript.new()
	script.source_code = source
	if script.reload() != OK:
		push_error("Instrumented App failed to compile")
		return null
	return script

func run() -> void:
	OS.set_environment("BMT_API_URL", "")
	root.size = Vector2i(1280,720)
	var folder := "user://track-stage-profile-"+TrackLibrary.unique_id()
	var disk: GDScript = preload("res://track/road_mesh_disk_cache.gd")
	disk.directory = folder.path_join("roads")
	var app_script := instrumented_app()
	if app_script == null:
		quit(1)
		return
	app = app_script.new()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.records.settings.music_enabled = false
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override = folder.path_join("cloud")
	app.race_profile_enabled = true
	root.add_child(app)
	while not app.startup_complete: await process_frame
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TRACK_PATH))
	var compile_started := Time.get_ticks_usec()
	var track: NativeTrack = TrackCompiler.compile(document)
	var compile_ms := (Time.get_ticks_usec()-compile_started)/1000.0
	if track == null:
		push_error("Track compilation failed")
		quit(1)
		return
	track.metadata.cloud_version = "owned-runtime-fixture"
	preload("res://track/prepared_world_cache.gd").entries.clear()
	process_frame.connect(observe)
	for cycle in range(2):
		app.records.settings.camera_mode = "overhead"
		app._show_screen("tracks")
		app.selected_track = track
		app._load_probe_marks.clear()
		frames.clear()
		last_frame = Time.get_ticks_usec()
		measuring = true
		var began := Time.get_ticks_usec()
		await app._start_race(track,false,true)
		var ended := Time.get_ticks_usec()
		measuring = false
		if not is_instance_valid(app.game) or not app.game.preparation_complete:
			push_error("Race failed to become ready")
			quit(1)
			return
		var game: Node = app.game
		var row := {"cycle":cycle,"wall_ms":(ended-began)/1000.0,"max_frame_ms":frames.max() if not frames.is_empty() else 0.0,"marks":app._load_probe_marks.duplicate(true),"game_costs":game.preparation_costs.duplicate(true),"world_costs":game.track_ground.build_costs.duplicate(true),"combined_effect_finish_ms":game.bridge_preparation_ms,"effect_counts":game.effect_preparation_counts}
		if is_instance_valid(game.world_render_preparation):
			row.draw_groups = game.world_render_preparation.frame_groups
			row.draw_wait_max_us = game.world_render_preparation.draw_us_max
			row.groups = game.world_render_preparation.group_samples.duplicate(true)
			row.captured_pending = game.world_render_preparation.captured_pending
			if row.draw_groups != row.groups.size():
				push_error("Group instrumentation did not account for all draws")
				quit(1)
				return
			if row.captured_pending != row.groups.size():
				push_error("Not all captured world groups were submitted")
				quit(1)
				return
		frames.clear()
		driving_frames.clear()
		last_frame = Time.get_ticks_usec()
		measuring = true
		game.ai_enabled = true
		observing_driving = true
		for frame: int in range(420): await process_frame
		observing_driving = false
		measuring = false
		row.after_ready_max_frame_ms = frames.max() if not frames.is_empty() else 0.0
		row.after_ready_frames = frames.size()
		row.driving_max_frame_ms = driving_frames.max() if not driving_frames.is_empty() else 0.0
		row.driving_frames = driving_frames.size()
		var drive_elapsed: float = 0.0
		for duration: float in driving_frames: drive_elapsed += duration
		row.driving_elapsed_ms = drive_elapsed
		row.after_ready_race_tick = game.sim.state.tick
		row.after_ready_countdown_ticks = game.countdown_ticks
		game.set_physics_process(false)
		samples.append(row)
		print("TRACK_LOAD_STAGES ",JSON.stringify(row))
		app._leave_race()
		await process_frame
	var output := ProjectSettings.globalize_path(folder.path_join("timings.json"))
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file == null:
		push_error("Could not write timing results")
		quit(1)
		return
	file.store_string(JSON.stringify({"source":TRACK_PATH,"app_sha256":FileAccess.get_sha256(APP_PATH),"compile_ms_before_race":compile_ms,"profile":folder,"samples":samples},"  "))
	print("TRACK_LOAD_OUTPUT ",output)
	app.queue_free()
	await process_frame
	quit()
