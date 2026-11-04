extends SceneTree
## Actual App; timestamp-only instrumentation in memory, isolated offline records.
var checks: int = 0
var failures: int = 0
var app: Node
var last_frame: int = 0
var max_frame_ms: float = 0.0

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("LOADING_REVIEW_FAIL ",label)
func observe() -> void:
	var now: int = Time.get_ticks_usec()
	if last_frame > 0: max_frame_ms = maxf(max_frame_ms,(now-last_frame)/1000.0)
	last_frame = now
	if is_instance_valid(app):
		app._publishing_slots_foreground = true
		if is_instance_valid(app._garage_preloader): app._garage_preloader.foreground = true
func reset_frames() -> void:
	last_frame = Time.get_ticks_usec()
	max_frame_ms = 0.0
func frames(count: int) -> void:
	for _i: int in range(count): await process_frame
func run() -> void:
	root.size = Vector2i(1280,720)
	create_timer(300).timeout.connect(func() -> void: printerr("LOADING_REVIEW_TIMEOUT"); quit(1))
	var customized: bool = "--custom" in OS.get_cmdline_user_args()
	var idle: bool = "--idle" in OS.get_cmdline_user_args()
	var records := LocalRecords.new("user://loading-review/records.json")
	if not FileAccess.file_exists(records.path):
		DirAccess.make_dir_recursive_absolute(records.path.get_base_dir())
		records.settings = {"music_enabled":false,"selected_car":"compact"}
		if customized:
			var paint: Dictionary = VehicleLivery.defaults("compact")
			paint.colors.body = "32b5d7"
			records.settings.vehicle_liveries = {"compact":paint}
		check(records.save_records() == OK,"private fixture saved")
	var began: int = Time.get_ticks_usec()
	var scene: PackedScene = load("res://core/app.tscn")
	var load_ms: float = (Time.get_ticks_usec()-began)/1000.0
	check(scene != null,"shipping scene loads")
	var source: String = FileAccess.get_file_as_string("res://core/app.gd").replace("\r\n","\n")
	var begin: int = source.find("func _ready() -> void:")
	var end: int = source.find("\nfunc ",begin+1)
	var body: String = source.substr(begin,end-begin)
	var hooks: Array = [
		["\trecords.load_records()","records"],
		["\tselected_track = NativeTrack.read(\"res://resources/tracks/\" + BUILTIN_IDS[0]","track"],
		["\tmenu_layer = CanvasLayer.new()","overlays"],
		["\t_show_screen(\"restoring\")","restoring"],
		["\tif capture_path.is_empty(): await online.start_session()","session"],
		["\tawait header_car_cache.prepare_selected()","header"],
		["\t_show_screen(capture_screen if","final_screen"],
		["\tstartup_complete = true","ready"]]
	for hook: Array in hooks:
		check(body.count(hook[0]) == 1,"unique timestamp "+hook[1])
		body = body.replace(hook[0],"\t_review_marks.append({\"name\":\""+hook[1]+"\",\"us\":Time.get_ticks_usec()})\n"+hook[0])
	if failures: quit(1); return
	source = source.substr(0,begin)+body+source.substr(end)+"\nvar _review_marks: Array = []\n"
	var script := GDScript.new()
	script.source_code = source
	began = Time.get_ticks_usec()
	check(script.reload() == OK,"instrumented App compiles")
	var reload_ms: float = (Time.get_ticks_usec()-began)/1000.0
	if failures: quit(1); return
	app = script.new()
	app.records = records
	app.library = TrackLibrary.new("user://loading-review/tracks")
	app.cloud_root_override = "user://loading-review/cloud"
	process_frame.connect(observe)
	began = Time.get_ticks_usec()
	reset_frames()
	root.add_child(app)
	while not app.startup_complete: await process_frame
	var result: Dictionary = {"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"customized":customized,"idle_before_entry":idle,"resource_load_ms":load_ms,"instrumented_reload_ms":reload_ms,"startup_ms":(Time.get_ticks_usec()-began)/1000.0,"startup_max_frame_ms":max_frame_ms,"marks":app._review_marks.duplicate(true),"header_captures":app.header_car_cache.captures,"header_disk_hits":app.header_car_cache.disk_hits}
	check(app.screen == "account" and not app.online.configured,"offline guest startup")
	check(preload("res://ui/header_car_icons.gd").ready("compact",records),"exact equipped header ready")
	check(not is_instance_valid(app._retained_garage),"no Garage page during startup")
	var loader: Node = app._garage_preloader
	result.picture_service_at_ready = is_instance_valid(loader.picture_service)
	if idle:
		began = Time.get_ticks_usec()
		while loader.studio == null or not loader.studio.prepared: await process_frame
		result.idle_until_studio_ready_ms = (Time.get_ticks_usec()-began)/1000.0
		result.preload_draws = loader.studio.warm_draws
		result.preload_max_draw_ms = loader.studio.max_draw_ms
	began = Time.get_ticks_usec()
	reset_frames()
	app._navigate_menu_page("garage")
	result.garage_dispatch_ms = (Time.get_ticks_usec()-began)/1000.0
	var page: GaragePage = app._retained_garage
	check(is_instance_valid(page) and app.screen == "garage","Garage opens immediately")
	if not is_instance_valid(page): quit(1); return
	result.progressive_entry = page.progressive_entry
	while page.progressive_entry and page.showroom.preparing: await process_frame
	while app.menu_page_motion != null and app.menu_page_motion.is_running(): await process_frame
	result.garage_live_ms = (Time.get_ticks_usec()-began)/1000.0
	result.garage_max_frame_ms = max_frame_ms
	check(page.showroom.showroom_ready and page.showroom.car != null,"full live showroom ready")
	check(page.showroom.car.livery == VehicleLivery.for_car(records.settings,"compact"),"exact saved livery")
	check(page.showroom.reflections.views.size() == 2,"both live reflections retained")
	await frames(6)
	var picture_began: int = Time.get_ticks_usec()
	while not loader.pictures_ready(): await process_frame
	result.remaining_pictures_ms = (Time.get_ticks_usec()-picture_began)/1000.0
	result.picture_renders = loader.picture_service.renders + page._preview_service.renders
	result.picture_disk_hits = loader.picture_service.cache_hits + page._preview_service.cache_hits
	app._show_screen("settings")
	await frames(4)
	began = Time.get_ticks_usec()
	app._show_screen("garage")
	result.retained_reopen_dispatch_ms = (Time.get_ticks_usec()-began)/1000.0
	check(app._retained_garage == page,"reopen retains Garage")
	# Drain already admitted image writes so the same-profile restart is valid.
	var deadline: int = Time.get_ticks_msec()+15000
	while not app.header_car_cache.idle() or loader.picture_service.worker != null or not loader.picture_service.pending_writes.is_empty() or page._preview_service.worker != null or not page._preview_service.pending_writes.is_empty():
		if Time.get_ticks_msec() > deadline: break
		await process_frame
	result.writes_drained = app.header_car_cache.idle() and loader.picture_service.worker == null and loader.picture_service.pending_writes.is_empty() and page._preview_service.worker == null and page._preview_service.pending_writes.is_empty()
	check(result.writes_drained,"image persistence finishes")
	result.checks = checks
	result.failures = failures
	var file := FileAccess.open(OS.get_environment("BMT_LOADING_OUTPUT"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "))
	file.close()
	print("LOADING_REVIEW ",JSON.stringify(result))
	app.queue_free()
	app = null
	await frames(12)
	quit(1 if failures else 0)
