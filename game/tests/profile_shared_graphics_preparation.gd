extends "res://tests/review_race_loading_2026_11_02.gd"
## Same current App/Game/art, interleaved task-start and shared graphics queues.
const Shared = preload("res://rendering/graphics_preparation.gd")
const Before = preload("res://../docs/evidence/graphics-preparation-2026-11-04/before/game/race/world_render_preparation.gd")
var _race_script: GDScript

func instrumented_app() -> GDScript:
	var code: String = FileAccess.get_file_as_string("res://core/features/race.gd").replace("\r\n","\n")
	var begin: int = code.find("static func _start_race(app:")
	var end: int = code.find("\nstatic func _race_installation_current(",begin)
	if begin < 0 or end < begin: push_error("Missing current race module"); return null
	var body: String = code.substr(begin,end-begin)
	var hooks: Array = [
		["\tif not await app._await_selected_preparation(track,","selected_wait_begin"],
		["\tvar daily_rules: RefCounted","selected_wait_end"],
		["\tvar prepared_roads: Dictionary = {}","roads_begin"],
		["\tapp.returning_to_editor = from_editor","roads_end"],
		["\tapp.add_child(app.game)","game_begin"],
		["\tif is_instance_valid(prepared_game.world_render_preparation):","game_end"],
		["\t\tif not await prepared_game.world_render_preparation.prepare(","graphics_begin"],
		["\tapp.game.opponent_ghost =","graphics_end"],
		["\tvar preparation_started: int = Time.get_ticks_usec()","effects_begin"],
		["\tvar preparation_ms: float = (Time.get_ticks_usec() - preparation_started)","effects_end"],
		["\tapp._close_race_loading(loading_id)\n\n","race_end"]]
	for hook: Array in hooks:
		if body.count(hook[0]) != 1: push_error("Current graphics probe anchor: "+hook[1]); return null
		var indent: String = "\t\t" if hook[0].begins_with("\t\t") else "\t"
		body = body.replace(hook[0],indent+"app._load_probe_mark(\""+hook[1]+"\")\n"+hook[0])
	_race_script = GDScript.new()
	_race_script.source_code = code.substr(0,begin)+body+code.substr(end)
	if _race_script.reload() != OK: return null
	var source: String = FileAccess.get_file_as_string(APP_PATH)
	source += "\nvar _load_probe_marks: Array = []\nfunc _load_probe_mark(label: String) -> void:\n\t_load_probe_marks.append({\"name\":label,\"us\":Time.get_ticks_usec()})\n"
	var script := GDScript.new()
	script.source_code = source
	return script if script.reload() == OK else null

func control_scene() -> PackedScene:
	var code: String = FileAccess.get_file_as_string("res://core/game.gd")
	var needle: String = 'preload("res://race/world_render_preparation.gd").new()'
	if code.count(needle) != 1: push_error("Missing exact graphics control constructor"); return null
	code = code.replace(needle,'preload("res://../docs/evidence/graphics-preparation-2026-11-04/before/game/race/world_render_preparation.gd").new()')
	var script := GDScript.new()
	script.source_code = code
	if script.reload() != OK: return null
	var original: Node = load("res://core/game.tscn").instantiate()
	original.set_script(script)
	var scene := PackedScene.new()
	var error: Error = scene.pack(original)
	original.free()
	return scene if error == OK else null

func run() -> void:
	create_timer(300,true,false,true).timeout.connect(func() -> void: printerr("GRAPHICS_PROFILE_TIMEOUT"); quit(1))
	root.size = Vector2i(1280,720)
	var folder: String = "user://shared-graphics-profile"
	preload("res://track/road_mesh_disk_cache.gd").directory = folder.path_join("roads")
	var script: GDScript = instrumented_app()
	if script == null: quit(1); return
	var old_scene: PackedScene = control_scene()
	if old_scene == null: quit(1); return
	var new_scene: PackedScene = load("res://core/game.tscn")
	app = script.new()
	app._feature_resources["res://core/features/race.gd"] = _race_script
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.records.settings.music_enabled = false
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override = folder.path_join("cloud")
	app.race_profile_enabled = true
	root.add_child(app)
	while not app.startup_complete:
		app._publishing_slots_foreground = true
		await process_frame
	# Isolate actual race preparation from unrelated optional Garage work.
	app._garage_preloader.idle_ms = 100000000
	app._garage_preloader.foreground = false
	Engine.time_scale = 0.0
	var theme: String = "pine"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--theme="): theme = argument.trim_prefix("--theme=")
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TRACK_PATH))
	document.theme = theme
	var track: NativeTrack = TrackCompiler.compile(document)
	track.metadata.cloud_version = "owned-shared-graphics-review"
	process_frame.connect(observe)
	var reference: PackedByteArray
	for cycle: int in range(6):
		var control: bool = cycle in [0,1,3,5]
		app._feature_resources["res://core/game.tscn"] = old_scene if control else new_scene
		Before.warmed.clear()
		Shared.invalidate("controlled cold program ledger")
		current_case = theme+"-"+str(cycle)
		app._show_screen("tracks")
		app.selected_track = track
		app._load_probe_marks.clear()
		frames.clear()
		last_frame = Time.get_ticks_usec()
		measuring = true
		var began: int = Time.get_ticks_usec()
		await app._start_race(track,false,true)
		var elapsed: float = (Time.get_ticks_usec()-began)/1000.0
		measuring = false
		verify(is_instance_valid(app.game),"actual race installed "+str(cycle))
		if not is_instance_valid(app.game): break
		var game: Node = app.game
		game.set_physics_process(false)
		game.process_mode = Node.PROCESS_MODE_DISABLED
		game.hitch_diagnostics.persist_enabled = false
		verify(game.preparation_complete and game.sim.state.tick == 0 and game.countdown_ticks == 360 and game.track_session.target_laps == 5,"exact race start "+str(cycle))
		var row: Dictionary = {"cycle":cycle,"control":control,"theme":theme,"wall_ms":elapsed,"max_frame_ms":frames.max() if not frames.is_empty() else 0.0,"marks":app._load_probe_marks.duplicate(true),"groups":game.world_render_preparation.frame_groups,"graphics_max_draw_us":game.world_render_preparation.draw_us_max,"effects_ms":game.bridge_preparation_ms,"world_cache_bytes":WORLDS.bytes_used()}
		for _i: int in range(4): await process_frame
		await RenderingServer.frame_post_draw
		var picture: Image = root.get_texture().get_image()
		if cycle == 1: reference = picture.get_data()
		if cycle >= 2:
			verify(reference == picture.get_data(),"exact warm native control/optimized pixels "+str(cycle))
			row.image_exact = reference == picture.get_data()
		verify(picture.save_png(OS.get_environment("BMT_GRAPHICS_EVIDENCE").path_join(str(cycle)+".png")) == OK,"native capture "+str(cycle))
		samples.append(row)
		print("SHARED_GRAPHICS_PROFILE ",JSON.stringify(row))
		app._leave_race()
		for _i: int in range(4): await process_frame
	FileAccess.open(OS.get_environment("BMT_LOADING_OUTPUT"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":samples,"renderer":RenderingServer.get_current_rendering_method(),"cache_events":cache_events},"  "))
	app.queue_free()
	app = null
	process_frame.disconnect(observe)
	script = null
	old_scene = null
	new_scene = null
	_race_script = null
	track = null
	Engine.time_scale = 1.0
	for _i: int in range(16): await process_frame
	quit(1 if failures else 0)
