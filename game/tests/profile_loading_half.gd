extends SceneTree
## Whole native menu transitions using the shipping App in private offline storage.
## Avoid typed game references here: parsing this probe must not warm the App graph.
var app: Node
var checks: int = 0
var failures: int = 0
var rows: Array = []
var output: String
var last_frame: int = 0
var max_frame_ms: float = 0.0
var measuring: bool = false

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("LOADING_HALF_FAIL ",label)

func observe() -> void:
	var now: int = Time.get_ticks_usec()
	if measuring and last_frame > 0: max_frame_ms = maxf(max_frame_ms,(now-last_frame)/1000.0)
	last_frame = now
	if is_instance_valid(app):
		# Keep native offscreen automation equivalent to a foreground application.
		app._publishing_slots_foreground = true
		if is_instance_valid(app._garage_preloader): app._garage_preloader.foreground = true

func frames(count: int) -> void:
	for _i: int in range(count): await process_frame

func drawn() -> void:
	await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func content_ready(page: String) -> bool:
	if is_instance_valid(app._feature_loading): return false
	if page == "garage":
		return is_instance_valid(app._retained_garage) and app._retained_garage.showroom.showroom_ready and not app._retained_garage.showroom.preparing
	if page == "create":
		return is_instance_valid(app.canvas) and is_instance_valid(app.editor_world) and app.editor_preview_thread == null and app.canvas.native_preview != null and not app.editor_world._building and app.editor_world._initial_preparation_done and not app.editor_commits.unsettled()
	if page == "rivalry":
		var view: Node = app.content.find_child("WeeklyRivalryPage",true,false)
		if view == null or not view.standings_ready or view.track_rows.size() != 5: return false
		for car: Node in view.find_children("RivalryPodiumCar_*","",true,false):
			if not car.presentation_ready: return false
	return app.screen == page

func entry(page: String, cycle: int) -> void:
	var began: int = Time.get_ticks_usec()
	last_frame = began
	max_frame_ms = 0.0
	measuring = true
	await app._show_screen(page)
	var returned: int = Time.get_ticks_usec()
	await drawn()
	var first_draw: int = Time.get_ticks_usec()
	var deadline: int = Time.get_ticks_msec()+90000
	while not content_ready(page) and Time.get_ticks_msec()<deadline: await process_frame
	check(content_ready(page),page+" visible content ready")
	while app.menu_page_motion != null and app.menu_page_motion.is_running(): await process_frame
	await drawn()
	# The native Rivalry renderer refreshes radiance after layout readiness.
	# Include its three refreshes and the final requested draw in this milestone.
	if page == "rivalry":
		for _i: int in range(4): await drawn()
	var ready: int = Time.get_ticks_usec()
	measuring = false
	var row: Dictionary = {"page":page,"cycle":cycle,"dispatch_ms":(returned-began)/1000.0,"first_draw_ms":(first_draw-began)/1000.0,"ready_ms":(ready-began)/1000.0,"max_frame_ms":max_frame_ms}
	rows.append(row)
	print("LOADING_HALF_ROW ",JSON.stringify(row))
	if page == "garage":
		check(not is_instance_valid(app._feature_loading),"Garage retains direct entry without a loading window")
		check(app._retained_garage.showroom.reflections.views.size() == 2,"Garage retains both reflections")
	if cycle == 0 and DisplayServer.get_name() != "headless":
		# Freeze only the separate visual receipt after the timing boundary.
		Engine.time_scale = 0.0
		await frames(4)
		await drawn()
		check(root.get_texture().get_image().save_png(output.path_join(page+".png")) == OK,"capture "+page)
		Engine.time_scale = 1.0

func run() -> void:
	root.size = Vector2i(1280,720)
	create_timer(420,true,false,true).timeout.connect(func() -> void: printerr("LOADING_HALF_TIMEOUT"); quit(1))
	output = OS.get_environment("BMT_GRAPHICS_OUTPUT")
	process_frame.connect(observe)
	var started: int = Time.get_ticks_usec()
	var script: Script = load("res://core/app.gd")
	var loaded: int = Time.get_ticks_usec()
	app = script.new()
	app.name = "CircuitApp"
	app.records = load("res://persistence/local_records.gd").new("user://loading-half/records.json")
	DirAccess.make_dir_recursive_absolute(app.records.path.get_base_dir())
	app.records.settings.music_enabled = false
	check(app.records.save_records() == OK,"private fixture saved")
	app.library = load("res://persistence/track_library.gd").new("user://loading-half/tracks")
	app.cloud_root_override = "user://loading-half/cloud"
	root.add_child(app)
	while not app.startup_complete: await process_frame
	await drawn()
	var startup: Dictionary = {"engine_to_menu_ms":Time.get_ticks_usec()/1000.0,"app_graph_ms":(loaded-started)/1000.0}
	check(not app.online.configured and app.screen == "account","offline original startup")
	app._garage_preloader.set_process(false)
	app.rivalry.model = load("res://race/weekly_rivalry.gd").new(true)
	app.document = load("res://editor/track_document.gd").create_default()
	app.document.name = "Loading measurement"
	var pages: Array[String] = ["rivalry","daily","tracks","challenges","biome","drafts","profile","settings","store","garage","create"]
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--pages="):
			pages.clear()
			for page: String in argument.trim_prefix("--pages=").split(","): pages.append(page)
	for cycle: int in range(2):
		for page: String in pages: await entry(page,cycle)
	var result: Dictionary = {"checks":checks,"failures":failures,"startup":startup,"menus":rows,"feature_load_ms":app.feature_load_ms.duplicate(true),"engine":Engine.get_version_info(),"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"network_disabled":not app.online.configured,"workload":"Sequential offline foreground taps with normal navigation wakeups and sample Rivalry data"}
	FileAccess.open(OS.get_environment("BMT_LOADING_OUTPUT"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	app.queue_free()
	app = null
	await frames(18)
	print("LOADING_HALF_COMPLETE ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
