extends SceneTree
## Timestamp hooks only, injected into an in-memory App copy. Offline private profile.
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; printerr("STARTUP_REVIEW_FAIL ",label)

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	root.size = Vector2i(1280,720)
	create_timer(150).timeout.connect(func() -> void: printerr("STARTUP_REVIEW_TIMEOUT"); quit(1))
	var customized: bool = "--custom" in OS.get_cmdline_user_args()
	var records := LocalRecords.new("user://loading-review/records.json")
	if customized and not FileAccess.file_exists(records.path):
		DirAccess.make_dir_recursive_absolute(records.path.get_base_dir())
		var paint: Dictionary = VehicleLivery.defaults("compact")
		paint.colors.body = "32b5d7"
		records.settings = {"selected_car":"compact","music_enabled":false,"vehicle_liveries":{"compact":paint}}
		check(records.save_records() == OK,"private custom fixture saved")
	var began: int = Time.get_ticks_usec()
	var shipping_scene: PackedScene = load("res://core/app.tscn")
	var resource_load_ms: float = (Time.get_ticks_usec()-began)/1000.0
	check(shipping_scene != null,"shipping App scene loads")
	began = Time.get_ticks_usec()
	var source: String = FileAccess.get_file_as_string("res://core/app.gd").replace("\r\n","\n")
	var begin: int = source.find("func _ready() -> void:")
	var end: int = source.find("\nfunc ",begin+1)
	check(begin >= 0 and end > begin,"startup function located")
	if failures: quit(1); return
	var body: String = source.substr(begin,end-begin)
	var hooks: Array = [
		["\tpreload(\"res://backend/menu_snapshot_writer.gd\").shared().background_allowed", "ready_begin"],
		["\trecords.load_records()", "records_begin"],
		["\tGameSoundtrack.instance().bind_records(records)", "services_begin"],
		["\tselected_track = NativeTrack.read(\"res://resources/tracks/\" + BUILTIN_IDS[0]", "track_begin"],
		["\tmenu_layer = CanvasLayer.new()", "overlays_begin"],
		["\t_show_screen(\"restoring\")", "restoring_begin"],
		["\tif capture_path.is_empty(): await online.start_session()", "session_begin"],
		["\tpreload(\"res://ui/garage_preview_cache.gd\").prefetch_catalogue", "session_end"],
		["\tawait header_car_cache.prepare_selected()", "header_begin"],
		["\tawait _garage_preloader.prepare_pictures()", "garage_pictures_begin"],
		["\t_show_screen(capture_screen if", "final_screen_begin"],
		["\tstartup_complete = true", "menu_ready"]
	]
	for hook: Array in hooks:
		check(body.count(hook[0]) == 1,"unique hook "+hook[1])
		body = body.replace(hook[0],"\t_startup_review_marks.append({\"name\":\""+hook[1]+"\",\"us\":Time.get_ticks_usec()})\n"+hook[0])
	if failures: quit(1); return
	source = source.substr(0,begin)+body+source.substr(end)+"\nvar _startup_review_marks: Array = []\n"
	var script := GDScript.new()
	script.source_code = source
	check(script.reload() == OK,"instrumented App compiles")
	if failures: quit(1); return
	var compile_ms: float = (Time.get_ticks_usec()-began)/1000.0
	var app: Node = script.new()
	app.records = records
	app.library = TrackLibrary.new("user://loading-review/tracks")
	app.cloud_root_override = "user://loading-review/cloud"
	var app_started: int = Time.get_ticks_usec()
	root.add_child(app)
	while not app.startup_complete:
		# This background-launched measurement represents foreground startup.
		# Match the existing equipped-header fixture; do not measure focus parking.
		app._publishing_slots_foreground = true
		await process_frame
	var ready_ms: float = (Time.get_ticks_usec()-app_started)/1000.0
	check(app.screen == "account","offline guest reaches sign-in")
	check(not app.online.configured,"network disabled")
	check(is_instance_valid(app._garage_preloader.picture_service),"picture service installed")
	var pictures: Node = app._garage_preloader.picture_service
	check(pictures.pictures_ready(),"all Garage pictures ready at startup")
	if customized:
		check(preload("res://ui/header_car_icons.gd").ready("compact",records),"equipped header ready")
	var result: Dictionary = {"checks":checks,"failures":failures,"customized":customized,
		"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),
		"shipping_scene_load_ms":resource_load_ms,"instrumented_reload_ms":compile_ms,"app_ready_ms":ready_ms,"marks":app._startup_review_marks,
		"garage_renders":pictures.renders,"garage_disk_hits":pictures.cache_hits,
		"header_captures":app.header_car_cache.captures,"header_disk_hits":app.header_car_cache.disk_hits}
	# Allow already admitted PNG writes to finish outside the startup timing.
	# An immediate test teardown must not manufacture a restart cache miss.
	app._garage_preloader.idle_ms = 100000
	var deadline: int = Time.get_ticks_msec()+10000
	while pictures.worker != null or not pictures.pending_writes.is_empty() or not pictures.io.is_empty() or not app.header_car_cache.idle():
		if Time.get_ticks_msec() >= deadline: break
		app._publishing_slots_foreground = true
		await process_frame
	result.writes_drained = pictures.worker == null and pictures.pending_writes.is_empty() and pictures.io.is_empty() and app.header_car_cache.idle()
	var output: String = OS.get_environment("BMT_LOADING_OUTPUT")
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file == null: printerr("STARTUP_REVIEW_NO_OUTPUT"); quit(1); return
	file.store_string(JSON.stringify(result,"  "))
	file.close()
	print("STARTUP_REVIEW ",JSON.stringify(result))
	app.queue_free()
	for _frame: int in range(10): await process_frame
	quit(1 if failures else 0)
