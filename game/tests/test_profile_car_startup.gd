extends SceneTree
## Real startup with an on-disk equipped appearance, before any menu navigation.
const Icons = preload("res://ui/header_car_icons.gd")
const Profile = preload("res://ui/profile_car.gd")
var checks: int = 0
var failures: int = 0
var app: Node
var output: String
var profile: String
var phase: String = "seed"
var vehicle: String = "compact"
var wrong_draws: int = 0
var metrics: Dictionary = {}

class StartupMenuApp extends "res://core/app.gd":
	func _show_screen(next: String) -> void:
		# Offline guests normally start on sign-in, which has no header. Route
		# only that startup destination to the normal menu, without real auth.
		super._show_screen("tracks" if not startup_complete and next == "account" else next)

func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; print("FAIL: ",label)
func frames(count: int = 4) -> void:
	for _frame: int in range(count): await process_frame
func picture() -> Texture2D:
	return app.account_button.get_node("MenuProfileCar").preview.texture
func monitor_draw() -> void:
	if not is_instance_valid(app) or not is_instance_valid(app._retained_profile_car): return
	var icon: Control = app._retained_profile_car
	if icon.is_visible_in_tree() and icon.preview != null and icon.preview.texture != null and icon.preview.texture == Icons.texture(VehicleCatalog.selected): wrong_draws += 1
func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"capture "+label)
func wait_cache() -> void:
	var deadline: int = Time.get_ticks_msec()+30000
	while not app.header_car_cache.idle() and Time.get_ticks_msec()<deadline: await process_frame
	check(app.header_car_cache.idle(),"account-screen appearance work finishes")
	await create_timer(0.35).timeout

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--profile="): profile = arg.trim_prefix("--profile=")
		if arg.begins_with("--phase="): phase = arg.trim_prefix("--phase=")
		if arg.begins_with("--car="): vehicle = arg.trim_prefix("--car=")
	if DisplayServer.get_name() == "headless": quit(1); return
	create_timer(150).timeout.connect(func() -> void: print("FAIL: startup regression deadline"); quit(1))
	root.size = Vector2i(1280,720)
	root.gui_embed_subwindows = true
	check(DirAccess.make_dir_recursive_absolute(profile) == OK,"create isolated saved-profile fixture")
	var records := LocalRecords.new(profile.path_join("records.json"))
	var paint: Dictionary = VehicleLivery.defaults(vehicle)
	paint.colors.body = "32b5d7"
	paint.colors.accent = "f4dc52"
	paint.pattern = "offset_gt"
	paint.stickers.hood.id = LiveryCatalog.stickers[0].id
	var parts: Dictionary = VehicleCustomisation.defaults()
	if vehicle == "compact": parts.body = "wide"; parts.hood = "cowl"
	if vehicle == "kart": parts.merge({"hood":"enduro","aero":"blade","rims":"six","body":"wedge"},true)
	if phase == "seed":
		records.settings = {"selected_car":vehicle,"music_enabled":false,"vehicle_liveries":{vehicle:paint},"vehicle_customisation":{vehicle:parts}}
		check(records.save_records() == OK,"save equipped paint, sticker and fitted parts")
	Icons.customized.clear()
	records.load_records()
	check(Icons.texture(vehicle,records) == null,"a missing customized image never substitutes factory paint")
	var stock := LocalRecords.new(profile.path_join("stock.json"))
	check(Icons.texture(vehicle,stock) == Icons.texture(vehicle),"unmodified cars keep their bundled factory picture")
	app = StartupMenuApp.new()
	app.records = records
	app.library = TrackLibrary.new(profile.path_join("tracks"))
	app.cloud_root_override = profile.path_join("cloud")
	RenderingServer.frame_pre_draw.connect(monitor_draw)
	var began: int = Time.get_ticks_usec()
	root.add_child(app)
	while not app.startup_complete:
		app._publishing_slots_foreground = true
		await process_frame
	metrics.startup_ms = (Time.get_ticks_usec()-began)/1000.0
	app._garage_preloader.idle_ms = 100000
	check(app.screen == "tracks","inspect the first startup menu without follow-up navigation")
	check(VehicleCatalog.selected == vehicle and VehicleLivery.for_car(records.settings,vehicle) == paint and VehicleCustomisation.for_car(records.settings,vehicle) == parts,"startup loads the exact saved selection and appearance")
	var key: String = Icons.appearance_key(vehicle,records)
	check(Icons.customized.has(key),"equipped image is ready before startup completes")
	check(picture() != null and picture() == Icons.customized.get(key),"first header picture has the equipped livery")
	check(picture() != Icons.texture(vehicle),"first header picture does not use factory paint")
	check(app._retained_profile_car._change == null,"startup does not fade out a wrong factory picture")
	metrics.startup_captures = app.header_car_cache.captures
	metrics.startup_disk_hits = app.header_car_cache.disk_hits
	check(metrics.startup_captures == (1 if phase == "seed" else 0),"cold startup captures once; separate-process restart reuses PNG")
	check(metrics.startup_disk_hits == (0 if phase == "seed" else 1),"warm startup reads the exact saved PNG")
	await shot("first-menu")
	check(wrong_draws == 0,"no visible frame displays the factory livery")
	if failures == 0:
		await reference(paint,parts)
		app._show_screen("account")
		paint.colors.body = "b137d4"
		records.settings.vehicle_liveries[vehicle] = paint.duplicate(true)
		check(records.save_records() == OK,"commit a new appearance while account stays open")
		await wait_cache()
		check(Icons.customized.has(Icons.appearance_key(vehicle,records)),"appearance finishes while account screen stays open")
		app._show_screen("tracks")
		check(picture() != null and picture() == Icons.customized.get(Icons.appearance_key(vehicle,records)),"account screen receives the newly equipped livery")
		await reference(paint,parts)
		await shot("account-updated")
		# Leave the original appearance on disk for a fresh-process PNG reuse run.
		paint.colors.body = "32b5d7"
		records.settings.vehicle_liveries[vehicle] = paint
		check(records.save_records() == OK,"restore only the fixture's initial equipped appearance")
		await wait_cache()
	check(wrong_draws == 0,"updates never show factory paint for a customized car")
	metrics.merge({"phase":phase,"car":vehicle,"checks":checks,"failures":failures,"wrong_visible_frames":wrong_draws,"captures":app.header_car_cache.captures,"disk_hits":app.header_car_cache.disk_hits,"peak_worlds":app.header_car_cache.peak_worlds})
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(metrics,"  "))
	RenderingServer.frame_pre_draw.disconnect(monitor_draw)
	app.queue_free()
	await frames(10)
	print("PROFILE_CAR_STARTUP: ",JSON.stringify(metrics))
	quit(1 if failures else 0)

func reference(paint: Dictionary, parts: Dictionary) -> void:
	var canvas := SubViewport.new()
	canvas.size = Icons.SIZE
	canvas.disable_3d = true
	canvas.transparent_bg = true
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var view: Control = Profile.make_preview(vehicle,paint,parts)
	view.size = Vector2(Icons.SIZE)
	canvas.add_child(view)
	Profile.apply_presentation(view)
	for _frame: int in range(7): await RenderingServer.frame_post_draw
	var expected: Image = canvas.get_texture().get_image()
	var actual: Image = picture().get_image()
	var difference: float = 0.0
	for y: int in range(Icons.SIZE.y):
		for x: int in range(Icons.SIZE.x):
			var a: Color = actual.get_pixel(x,y)
			var b: Color = expected.get_pixel(x,y)
			if b.a>0 and b.a<1: b = Color(minf(1,b.r/b.a),minf(1,b.g/b.a),minf(1,b.b/b.a),b.a)
			difference += absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)+absf(a.a-b.a)
	var mean: float = difference/float(Icons.SIZE.x*Icons.SIZE.y)
	check(mean<0.02,"header pixels match independently rendered saved paint, sticker and kit: "+str(mean))
	canvas.queue_free()
	await frames()
