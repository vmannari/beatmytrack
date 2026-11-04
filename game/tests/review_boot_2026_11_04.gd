extends SceneTree
## No game-class references or in-memory source reload before the real App load.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1280,720)
	var begin: int = Time.get_ticks_usec()
	var scene: PackedScene = load("res://core/app.tscn")
	var loaded: int = Time.get_ticks_usec()
	var app: Node = scene.instantiate()
	# The whole user directory is private; optional custom profile was seeded
	# by the paired diagnostic at this exact private records path.
	app.records = load("res://persistence/local_records.gd").new("user://loading-review/records.json")
	app.library = load("res://persistence/track_library.gd").new("user://loading-review/tracks")
	app.cloud_root_override = "user://loading-review/cloud"
	var installed: int = Time.get_ticks_usec()
	root.add_child(app)
	while not app.startup_complete:
		app._publishing_slots_foreground = true
		await process_frame
	var ready: int = Time.get_ticks_usec()
	# Exclude optional Garage preparation from this boot-only observation.
	app._publishing_slots_foreground = false
	app._garage_preloader.set_process(false)
	await RenderingServer.frame_post_draw
	var presented: int = Time.get_ticks_usec()
	var result: Dictionary = {"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"probe_start_engine_ms":begin/1000.0,"app_load_ms":(loaded-begin)/1000.0,"instantiate_and_fixture_ms":(installed-loaded)/1000.0,"initialization_ms":(ready-installed)/1000.0,"engine_to_ready_ms":ready/1000.0,"engine_to_menu_draw_ms":presented/1000.0,"header_captures":app.header_car_cache.captures,"header_disk_hits":app.header_car_cache.disk_hits,"screen":app.screen,"network_disabled":not app.online.configured}
	FileAccess.open(OS.get_environment("BMT_LOADING_OUTPUT"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("BOOT_REVIEW ",JSON.stringify(result))
	app.queue_free()
	for _i: int in range(12): await process_frame
	quit(0 if result.network_disabled and result.screen == "account" else 1)
