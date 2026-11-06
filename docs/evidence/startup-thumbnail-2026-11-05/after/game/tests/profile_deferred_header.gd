extends SceneTree
## Identical offline, fresh-process startup probe for the archived and new App.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1280,720)
	var customized: bool = "--stock" not in OS.get_cmdline_user_args()
	var began: int = Time.get_ticks_usec()
	var script: Script = load("res://core/app.gd")
	var loaded: int = Time.get_ticks_usec()
	var app: Node = script.new()
	var records: RefCounted = load("res://persistence/local_records.gd").new("user://header-startup/records.json")
	if not FileAccess.file_exists(records.path):
		DirAccess.make_dir_recursive_absolute(records.path.get_base_dir())
		records.settings.music_enabled = false
		if customized:
			var paint: Dictionary = load("res://vehicle/vehicle_livery.gd").defaults("compact")
			paint.colors.body = "32b5d7"
			records.settings.vehicle_liveries = {"compact":paint}
		assert(records.save_records() == OK)
	app.records = records
	app.library = load("res://persistence/track_library.gd").new("user://header-startup/tracks")
	app.cloud_root_override = "user://header-startup/cloud"
	var installed: int = Time.get_ticks_usec()
	root.add_child(app)
	while not app.startup_complete:
		app._publishing_slots_foreground = true
		await process_frame
	var ready: int = Time.get_ticks_usec()
	app._garage_preloader.set_process(false)
	await RenderingServer.frame_post_draw
	var presented: int = Time.get_ticks_usec()
	var result: Dictionary = {"customized":customized,"resource_ms":(loaded-began)/1000.0,"initialization_ms":(ready-installed)/1000.0,"engine_to_menu_ms":presented/1000.0,"header_captures":app.header_car_cache.captures,"header_disk_hits":app.header_car_cache.disk_hits,"network_disabled":not app.online.configured,"screen":app.screen,"feature_resources":app._feature_resources.keys()}
	var deadline: int = Time.get_ticks_msec()+10000
	while Time.get_ticks_msec() < deadline:
		app._publishing_slots_foreground = true
		if app.header_car_cache.reads_idle() if app.header_car_cache.has_method("reads_idle") else app.header_car_cache.idle(): break
		await process_frame
	result.io_drained = app.header_car_cache.reads_idle() if app.header_car_cache.has_method("reads_idle") else app.header_car_cache.idle()
	result.settled_disk_hits = app.header_car_cache.disk_hits
	result.settled_captures = app.header_car_cache.captures
	result.peak_worlds = app.header_car_cache.peak_worlds
	FileAccess.open(OS.get_environment("BMT_LOADING_OUTPUT"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("DEFERRED_HEADER_PROFILE ",JSON.stringify(result))
	app.queue_free()
	app = null
	script = null
	for _i: int in range(12): await process_frame
	quit(0 if result.network_disabled and result.screen == "account" and result.io_drained else 1)
