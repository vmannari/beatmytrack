extends SceneTree
## Isolated actual-App callback and presented-frame observations, not phone FPS.
var output: String = "user://garage-navigation-profile.json"
var app: Node
var page: GaragePage
var rows: Array[Dictionary] = []
var failures: int = 0
var changed_only: bool = false

func _initialize() -> void:
	_run.call_deferred()

func settle() -> void:
	await create_timer(0.5).timeout
	for i: int in range(3): await process_frame

func observe(label: String, action: Callable, expected_car: String = "") -> void:
	var start: int = Time.get_ticks_usec()
	action.call()
	var dispatch: float = (Time.get_ticks_usec() - start) / 1000.0
	var previous: int = start
	var first: float = -1.0
	var intervals: Array[float] = []
	var ready: float = -1.0
	for frame: int in range(120):
		await process_frame
		await RenderingServer.frame_post_draw
		var now: int = Time.get_ticks_usec()
		intervals.append((now - previous) / 1000.0)
		previous = now
		if first < 0: first = (now - start) / 1000.0
		if ready < 0 and (expected_car.is_empty() or (is_instance_valid(page.showroom.car) and page.showroom.car.vehicle_id == expected_car and page.showroom.car.model_ready)):
			ready = (now - start) / 1000.0
		if frame >= 9 and ready >= 0: break
		if now - start > 10000000: break
	if ready < 0:
		failures += 1
		print("FAIL: target car did not become ready: ", label)
	var worst: float = 0.0
	for interval: float in intervals: worst = maxf(worst, interval)
	var row: Dictionary = {"action": label, "dispatch_ms": dispatch, "first_draw_ms": first, "ready_ms": ready, "max_draw_interval_ms": worst, "draw_intervals_ms": intervals}
	rows.append(row)
	print("GARAGE_NAV_PROFILE ", JSON.stringify(row))
	await settle()

func _run() -> void:
	OS.set_environment("BMT_API_URL", "")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg == "--changed-selection-only": changed_only = true
	if DisplayServer.get_name() == "headless":
		print("FAIL: graphical renderer required")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	var folder: String = "user://garage-nav-" + TrackLibrary.unique_id()
	app = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete:
		app._publishing_slots_foreground = true
		await process_frame
	GameSoundtrack.instance().music_enabled = false
	GameSoundtrack.instance().menu_player.stop()
	app._show_screen("tracks")
	await settle()
	app._navigate_menu_page("garage")
	await settle()
	page = app._retained_garage
	if not is_instance_valid(page):
		print("FAIL: Garage not ready")
		quit(1)
		return
	if not changed_only:
		for pass_index: int in range(2):
			for index: int in range(VehicleCatalog.IDS.size()):
				await observe("car/%s/%d" % [VehicleCatalog.IDS[index], pass_index], page.preview_car.bind(index), VehicleCatalog.IDS[index])
		for destination: String in ["tracks", "settings", "biome"]:
			for pass_index: int in range(2):
				app._show_screen(destination)
				await settle()
				await observe("return/%s/%d" % [destination, pass_index], app._navigate_menu_page.bind("garage"))
				if app._retained_garage != page or app.screen != "garage":
					failures += 1
					print("FAIL: return did not retain the same Garage from ", destination)
	for id: String in ["kart", "forklift", "compact"]:
		app._show_screen("tracks")
		await settle()
		app._select_header_vehicle(VehicleCatalog.IDS.find(id))
		await settle()
		await observe("return/changed-selection/" + id, app._navigate_menu_page.bind("garage"), id)
		if app._retained_garage != page or app.screen != "garage":
			failures += 1
			print("FAIL: changed-selection return did not retain Garage")
	var path: String = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		print("FAIL: cannot write benchmark output ", path)
		quit(1)
		return
	file.store_string(JSON.stringify({"renderer": RenderingServer.get_current_rendering_method(), "rows": rows, "failures": failures, "scope": "isolated actual App; desktop callback and draw intervals, not device FPS"}, "  "))
	file.close()
	app.queue_free()
	await process_frame
	print("GARAGE_NAV_PROFILE complete failures=", failures)
	quit(1 if failures else 0)
