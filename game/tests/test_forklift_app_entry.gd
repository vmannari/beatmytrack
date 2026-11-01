extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: run.call_deferred()
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+message)
func settle() -> void:
	await create_timer(0.5).timeout
	for i: int in range(4): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
func run() -> void:
	if DisplayServer.get_name() == "headless":
		print("FORKLIFT_APP_ENTRY: skipped; native rendering is required")
		quit()
		return
	OS.set_environment("BMT_API_URL","")
	create_timer(240).timeout.connect(func() -> void: print("FAIL: deadline"); quit(1))
	root.size = Vector2i(1280,720)
	var folder := "user://forklift-entry-"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var records := LocalRecords.new(folder.path_join("records.json"))
	records.load_records()
	records.settings["selected_car"] = "compact"
	VehicleCatalog.selected = "compact"
	records.settings["music_enabled"] = false
	preload("res://backend/menu_snapshot_writer.gd").shared()
	var app: Node = load("res://core/app.tscn").instantiate()
	app.records = records
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete:
		app._publishing_slots_foreground = true
		await process_frame
	app._garage_preloader.idle_ms = 100000
	app._garage_preloader.foreground = true
	GameSoundtrack.instance().music_enabled = false
	GameSoundtrack.instance().menu_player.stop()
	if DisplayServer.get_name() != "headless": check(await app._prepare_garage_pictures(),"prepare carousel")
	print("FORKLIFT_APP_GARAGE")
	app._show_screen("garage")
	var page: GaragePage = app._retained_garage
	await settle()
	print("FORKLIFT_APP_KART_CUSTOMISE")
	page.open_car(VehicleCatalog.IDS.find("kart"))
	await settle()
	check(page.section == "customise" and page.showroom.car.vehicle_id == "kart", "kart customisation opens first")
	page._show_section("tuning")
	await settle()
	page._select_kit_category("body")
	page._preview_kit("body","sprint")
	await settle()
	page._show_section("customise")
	await settle()
	page._show_section("cars")
	await settle()
	print("FORKLIFT_APP_OPEN_CAR")
	page.open_car(VehicleCatalog.IDS.find("forklift"))
	await settle()
	print("FORKLIFT_APP_CUSTOMISE")
	page._show_section("customise")
	await settle()
	check(page.showroom.car.vehicle_id == "forklift","selected forklift")
	check(page.section == "customise","customisation opens")
	# Force a cold thumbnail and switch precisely while its model is being built.
	var icons: Node = page.livery_menu.pattern_icons
	icons._cancel()
	icons.cache_directory = ""
	preload("res://ui/garage_paint_icons.gd").images.clear()
	var row: Button = page.livery_menu.pattern_tiles[0]
	row.icon_key = ""
	icons.request(row,"forklift",page.livery_menu.option_livery(0),page.kit_draft)
	var deadline: int = Time.get_ticks_msec()+5000
	while icons._stage != "build" and Time.get_ticks_msec()<deadline: await process_frame
	check(icons._stage == "build" and is_instance_valid(icons.studio),"cold forklift thumbnail build is in flight")
	print("FORKLIFT_APP_TUNING")
	var parts_button: Button = page._workshop_tabs.find_child("WorkshopParts",true,false)
	check(is_instance_valid(parts_button) and parts_button.is_visible_in_tree(),"Parts button is visible")
	var at: Vector2 = parts_button.get_global_rect().get_center()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = at
	click.pressed = true
	root.push_input(click,true)
	await process_frame
	click = click.duplicate()
	click.pressed = false
	root.push_input(click,true)
	await settle()
	check(page.section == "tuning","click opens Parts")
	check(not icons.busy and icons.studio == null,"switching to parts cancels the in-flight thumbnail")
	check(page.kit_cards.get_child_count() == 4,"forklift kit options")
	check(page.kit_category == "body","kart category carries over to forklift")
	page._select_kit_category("hood")
	page._preview_kit("hood","fork_vent")
	await settle()
	check(page.showroom.car.customisation.hood == "fork_vent","forklift kit preview")
	for iteration: int in range(12):
		print("FORKLIFT_APP_REPEAT "+str(iteration))
		page._show_section("cars")
		page.open_car(VehicleCatalog.IDS.find("compact"))
		await process_frame
		page._show_section("cars")
		page.open_car(VehicleCatalog.IDS.find("forklift"))
		await settle()
		check(page.showroom.car.vehicle_id == "forklift", "rapid vehicle switch")
	app.queue_free()
	for i: int in range(8): await process_frame
	print("FORKLIFT_APP_ENTRY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
