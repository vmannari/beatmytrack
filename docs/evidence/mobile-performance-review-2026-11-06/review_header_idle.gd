extends SceneTree
## Fresh private profile: first menu, idle header work and first Garage entry.
var app: Node
var checks: int = 0
var failures: int = 0
var result: Dictionary = {}
var phase: String = "startup"
var phase_max: Dictionary = {}
const Icons = preload("res://ui/header_car_icons.gd")
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("HEADER_GARAGE_FAIL ",label)
func frame() -> void:
	var frame_began: int = Time.get_ticks_usec()
	app._publishing_slots_foreground = true
	app._garage_preloader.foreground = true
	await process_frame
	phase_max[phase] = maxf(float(phase_max.get(phase,0.0)),(Time.get_ticks_usec()-frame_began)/1000.0)
func run() -> void:
	create_timer(180,true,false,true).timeout.connect(func() -> void: printerr("HEADER_GARAGE_TIMEOUT"); quit(1))
	root.size = Vector2i(1280,720)
	Engine.max_fps = 60
	var began: int = Time.get_ticks_msec()
	app = load("res://core/app.gd").new()
	var records := LocalRecords.new("user://header-garage/records.json")
	DirAccess.make_dir_recursive_absolute(records.path.get_base_dir())
	var paint: Dictionary = VehicleLivery.defaults("compact")
	paint.colors.body = "32b5d7"
	records.settings = {"music_enabled":false,"selected_car":"compact","vehicle_liveries":{"compact":paint}}
	if "--picker" in OS.get_cmdline_user_args():
		for id: String in VehicleCatalog.IDS:
			var custom: Dictionary = VehicleLivery.defaults(id)
			custom.colors.body = "32b5d7"
			records.settings.vehicle_liveries[id] = custom
	check(records.save_records()==OK,"private appearance saved")
	app.records = records
	app.library = TrackLibrary.new("user://header-garage/tracks")
	app.cloud_root_override = "user://header-garage/cloud"
	root.add_child(app)
	while not app.startup_complete: await frame()
	result.first_menu_ms = Time.get_ticks_msec()-began
	check(app.screen=="account" and not app.online.configured,"offline initial menu")
	check(app.header_car_cache.peak_worlds==0,"first menu remains independent of native header construction")
	phase = "idle"
	var idle_began: int = Time.get_ticks_msec()
	var deadline: int = idle_began+30000
	if "--settled" in OS.get_cmdline_user_args(): deadline = idle_began+90000
	if "--early" in OS.get_cmdline_user_args(): deadline = idle_began
	result.header_ready_ms = -1
	while Time.get_ticks_msec()<deadline:
		await frame()
		if Icons.ready("compact",records) and result.header_ready_ms<0: result.header_ready_ms = Time.get_ticks_msec()-idle_began
		if Icons.ready("compact",records) and app._garage_preloader.studio!=null and app._garage_preloader.studio.prepared: break
	result.idle_ms = Time.get_ticks_msec()-idle_began
	result.idle_header_captures = app.header_car_cache.captures
	result.idle_garage_prepared = app._garage_preloader.studio!=null and app._garage_preloader.studio.prepared
	if "--expect-ready" in OS.get_cmdline_user_args():
		check(Icons.ready("compact",records),"custom header resolves without visiting Garage")
		check(result.idle_garage_prepared,"idle initial menu prepares live Garage")
	if "--picker" in OS.get_cmdline_user_args():
		for id: String in VehicleCatalog.IDS: check(Icons.ready(id,records),"picker resolves saved "+id+" without visiting its Garage")
	phase = "garage"
	var entering: int = Time.get_ticks_msec()
	app._show_screen("garage")
	result.entry_call_ms = Time.get_ticks_msec()-entering
	deadline = Time.get_ticks_msec()+100000
	while Time.get_ticks_msec()<deadline:
		await frame()
		var showroom: Control = app._retained_garage.showroom
		if showroom.showroom_ready and showroom.get("preparing")!=true and Icons.ready("compact",records) and not is_instance_valid(app._header_capture_cover): break
	result.garage_and_header_ms = Time.get_ticks_msec()-entering
	check(Icons.ready("compact",records),"exact custom header ready")
	check(app._retained_garage.showroom.showroom_ready and app._retained_garage.showroom.get("preparing")!=true,"interactive Garage ready")
	check(app.header_car_cache.peak_worlds<=1,"single bounded header world")
	if "--expect-ready" in OS.get_cmdline_user_args(): check(not ResourceLoader.has_cached("res://garage/parking_hall_drive.tscn"),"ordinary Garage entry leaves Test drive scene unloaded")
	result.captures = app.header_car_cache.captures
	result.disk_hits = app.header_car_cache.disk_hits
	if DisplayServer.get_name()!="headless":
		while app.menu_page_motion!=null and app.menu_page_motion.is_running(): await frame()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("BMT_GRAPHICS_EVIDENCE").path_join("garage.png"))
		Icons.texture("compact",records).get_image().save_png(OS.get_environment("BMT_GRAPHICS_EVIDENCE").path_join("header.png"))
		if "--picker" in OS.get_cmdline_user_args():
			app.account_button.get_node("MenuCarPicker").show_popup()
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OS.get_environment("BMT_GRAPHICS_EVIDENCE").path_join("picker.png"))
	result.max_frame_ms = phase_max
	result.checks = checks
	result.failures = failures
	FileAccess.open(OS.get_environment("BMT_LOADING_OUTPUT"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("HEADER_GARAGE ",JSON.stringify(result))
	app.queue_free()
	app = null
	for _i: int in range(24): await process_frame
	quit(1 if failures else 0)
