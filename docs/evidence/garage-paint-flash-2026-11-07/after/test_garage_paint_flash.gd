extends SceneTree
## Actual offline App: saving paint must keep the ready Garage visible.
const Icons = preload("res://ui/header_car_icons.gd")
var app: Node
var page: GaragePage
var checks: int = 0
var failures: int = 0
var cover_frames: int = 0
var garage_captures: int = 0
var watching: bool = false
var output: String

class MenuApp extends "res://core/app.gd":
	func _show_screen(next: String) -> void:
		super._show_screen("tracks" if not startup_complete and next=="account" else next)

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("PAINT_FLASH_FAIL: ",label)

func frames(count: int = 4) -> void:
	for tick: int in range(count):
		app._publishing_slots_foreground = true
		await process_frame

func observe() -> void:
	if not watching or not is_instance_valid(app) or app.screen!="garage": return
	var cover: Node = app.find_child("HeaderPicturePreparation",true,false)
	if is_instance_valid(cover) and cover.is_visible_in_tree(): cover_frames += 1

func capture_started(_vehicle: String) -> void:
	if watching and app.screen=="garage": garage_captures += 1

func shot(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK,"capture "+label)

func settle() -> void:
	var deadline: int = Time.get_ticks_msec()+90000
	while Time.get_ticks_msec()<deadline:
		if not page.showroom.get("preparing") and page._menu_motion==null and not page._workbench_focus_pending and (page.showroom.camera_motion==null or not page.showroom.camera_motion.is_running()): break
		await frames(1)
	check(page.showroom.showroom_ready and not page.showroom.get("preparing"),"actual Garage studio is ready")
	await frames(8)

func wait_reads() -> void:
	var deadline: int = Time.get_ticks_msec()+10000
	while not app.header_car_cache.reads_idle() and Time.get_ticks_msec()<deadline: await frames(1)
	check(app.header_car_cache.reads_idle(),"cheap header disk reads finish")

func run() -> void:
	create_timer(170,true,false,true).timeout.connect(func() -> void: print("PAINT_FLASH_TIMEOUT"); quit(1))
	output = OS.get_environment("BMT_GRAPHICS_EVIDENCE")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	root.gui_embed_subwindows = true
	Icons.customized.clear()
	VehicleCatalog.selected = "compact"
	app = MenuApp.new()
	app.records = LocalRecords.new("user://paint-flash/records.json")
	app.records.settings.music_enabled = false
	app.library = TrackLibrary.new("user://paint-flash/tracks")
	app.cloud_root_override = "user://paint-flash/cloud"
	root.add_child(app)
	while not app.startup_complete: await frames(1)
	GameSoundtrack.instance().music_enabled = false
	GameSoundtrack.instance().menu_player.stop()
	GameSoundtrack.instance().menu_player.stream = null
	check(not app.online.configured,"private offline App")
	app._show_screen("garage")
	page = app._retained_garage
	await settle()
	page.open_car(VehicleCatalog.IDS.find("compact"))
	page._set_customise_tab("colours")
	await settle()
	# An actual deliberate paint interaction starts the normal idle countdown.
	app._garage_preloader.last_input = Time.get_ticks_msec()
	var car: CarVisual = page.showroom.car
	var viewport: SubViewport = page.showroom.showroom_viewport
	var camera: Transform3D = page.showroom.camera.transform
	watching = true
	RenderingServer.frame_pre_draw.connect(observe)
	app.header_car_cache.capture_started.connect(capture_started)
	page.livery_menu._palette_colour(Color("c52d43"))
	var first_key: String = Icons.appearance_key("compact",app.records)
	page.livery_menu._palette_colour(Color("245fd2"))
	var saved_paint: Dictionary = page.draft.duplicate(true)
	var key: String = Icons.appearance_key("compact",app.records)
	check(first_key!=key and VehicleLivery.for_car(app.records.settings,"compact")==saved_paint,"rapid palette choices save the newest paint")
	await create_timer(1.05).timeout
	await frames()
	await shot("paint-applied")
	check(page.showroom.paint_transition==null and page.showroom.car.livery==saved_paint,"repaint finishes on the exact saved finish")
	await wait_reads()
	# This is well past both the save debounce and deliberate-input idle gate.
	await create_timer(1.25).timeout
	await frames()
	await shot("paint-stays-visible")
	check(not app._header_car_capture_allowed("compact"),"ready Garage defers optional native header generation")
	check(garage_captures==0 and cover_frames==0,"no header capture or loading preview replaces the painted Garage")
	check(app.header_car_cache.canvas==null and app.header_car_cache.captures==0,"saving paint adds no native header world in Garage")
	check(page.showroom.car==car and page.showroom.showroom_viewport==viewport and page.showroom.camera.transform.is_equal_approx(camera),"paint keeps the original car, world and view")
	check(page.showroom.car.livery==saved_paint and VehicleLivery.for_car(app.records.settings,"compact")==saved_paint,"idle refresh preserves the applied and saved paint")
	var yaw: float = page.showroom.yaw
	page.showroom.rotate_view(Vector2(32,0))
	check(page.showroom.yaw!=yaw,"ready painted car remains turnable")
	for section: String in ["care","cars"]:
		page._show_section(section)
		await settle()
		check(not app._header_car_capture_allowed("compact"),"ready Garage stays uncovered in "+section)
	check(not Icons.customized.has(first_key),"superseded paint never publishes a header image")
	watching = false
	app._show_screen("tracks")
	while app.menu_page_motion!=null and app.menu_page_motion.is_running(): await frames(1)
	await frames(8)
	check(not page.is_visible_in_tree(),"leaving Garage parks its live showroom")
	if DisplayServer.get_name()!="headless":
		var deadline: int = Time.get_ticks_msec()+60000
		while not Icons.ready("compact",app.records) and Time.get_ticks_msec()<deadline: await frames(1)
		check(Icons.ready("compact",app.records) and app.header_car_cache.captures==1,"settled menu generates exactly one newest saved header picture")
		var header: Control = app.account_button.get_node("MenuProfileCar")
		check(header.preview.texture==Icons.texture("compact",app.records) and not header._placeholder.visible,"header receives the exact saved appearance")
		await shot("header-updated-after-leaving")
		check(not Icons.customized.has(first_key),"deferred work discards superseded paint")
		# Cheap exact PNG reuse remains available inside Garage.
		Icons.customized.clear()
		app.header_car_cache.bind_records(null)
		app._show_screen("garage")
		app.header_car_cache.bind_records(app.records)
		await wait_reads()
		check(Icons.ready("compact",app.records) and app.header_car_cache.disk_hits==1 and app.header_car_cache.captures==1,"Garage reuses the saved PNG without native work")
		check(page.showroom.car.livery==saved_paint,"returning Garage retains the painted car")
		await shot("garage-return")
	var report: Dictionary = {"checks":checks,"failures":failures,"cover_frames":cover_frames,"garage_capture_starts":garage_captures,"captures":app.header_car_cache.captures,"disk_hits":app.header_car_cache.disk_hits,"renderer":RenderingServer.get_current_rendering_method()}
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	RenderingServer.frame_pre_draw.disconnect(observe)
	app.queue_free()
	app = null
	for tick: int in range(12): await process_frame
	print("GARAGE_PAINT_FLASH: ",JSON.stringify(report))
	quit(1 if failures else 0)
