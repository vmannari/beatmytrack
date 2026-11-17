extends SceneTree
## No class references that load the application before the timers.
func _initialize() -> void: run.call_deferred()

func run() -> void:
	root.size = Vector2i(1280,720)
	var detail: bool = "--detail" in OS.get_cmdline_user_args()
	var began: int = Time.get_ticks_usec()
	var scene: PackedScene = load("res://core/app.tscn")
	var loaded: int = Time.get_ticks_usec()
	var compile_ms: float = 0.0
	if detail:
		var script: GDScript = load("res://core/app.gd")
		var source: String = script.source_code.replace("\r\n","\n")
		var start: int = source.find("func _ready() -> void:")
		var end: int = source.find("\nfunc ",start+1)
		var body: String = source.substr(start,end-start)
		var hooks: Array = [
			["\tpreload(\"res://backend/menu_snapshot_writer.gd\").shared().background_allowed", "ready_begin"],
			["\trecords.load_records()", "records"],
			["\tGameSoundtrack.instance().bind_records(records)", "services"],
			["\tvar startup_fallback: NativeTrack", "builtin_track"],
			["\tmenu_layer = CanvasLayer.new()", "overlays"],
			["\t_show_screen(\"restoring\")", "restoring_screen"],
			["\tif capture_path.is_empty(): await online.start_session()", "account_session"],
			["\tif active_profile.is_empty(): _restore_selected_track(startup_fallback)", "restore_selection"],
			["\tGameSoundtrack.instance().show_menu()", "soundtrack"],
			["\t_garage_preloader=", "preloader"],
			["\t_show_screen(capture_screen if", "final_screen"],
			["\tstartup_complete = true", "complete"]]
		for hook: Array in hooks:
			assert(body.count(hook[0]) == 1, "Unique startup anchor: "+hook[1])
			body = body.replace(hook[0],"\t_review_marks.append({\"name\":\""+hook[1]+"\",\"us\":Time.get_ticks_usec()})\n"+hook[0])
		script.source_code = source.substr(0,start)+body+source.substr(end)+"\nvar _review_marks: Array = []\n"
		var compile_began: int = Time.get_ticks_usec()
		assert(script.reload() == OK)
		compile_ms = (Time.get_ticks_usec()-compile_began)/1000.0
	var app: Node = scene.instantiate()
	app.records = load("res://persistence/local_records.gd").new("user://startup-review/records.json")
	app.records.settings.music_enabled = false
	app.library = load("res://persistence/track_library.gd").new("user://startup-review/tracks")
	app.cloud_root_override = "user://startup-review/cloud"
	var added: int = Time.get_ticks_usec()
	root.add_child(app)
	while not app.startup_complete: await process_frame
	var ready: int = Time.get_ticks_usec()
	await RenderingServer.frame_post_draw
	var drawn: int = Time.get_ticks_usec()
	var result: Dictionary = {"detail":detail,"scene_graph_ms":(loaded-began)/1000.0,
		"instantiate_and_fixture_ms":(added-loaded)/1000.0-compile_ms,
		"initialization_ms":(ready-added)/1000.0,"ready_to_draw_ms":(drawn-ready)/1000.0,
		"scene_to_first_draw_ms":(drawn-began)/1000.0-compile_ms,
		"engine_to_first_draw_ms":drawn/1000.0,"instrumentation_compile_ms_excluded":compile_ms,
		"features":app.feature_load_ms.duplicate(true),"network_disabled":not app.online.configured,
		"screen":app.screen,"header_captures":app.header_car_cache.captures,
		"header_disk_hits":app.header_car_cache.disk_hits}
	if detail: result.marks = app._review_marks
	assert(result.network_disabled and app.screen == "account")
	FileAccess.open(OS.get_environment("BMT_LOADING_OUTPUT"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("STARTUP_REVIEW ",JSON.stringify(result))
	app.queue_free(); app = null; scene = null
	load("res://soundtrack/audio_world.gd").instance().queue_free()
	for frame: int in range(18): await process_frame
	quit()
