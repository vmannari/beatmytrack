extends SceneTree
## Real menu navigation with saved paint/condition and an empty image cache.
var checks: int = 0
var failures: int = 0
var output: String = "res://../docs/evidence/garage-entry-carousel-2026-10-26"
var baseline: bool = false
var metrics: Dictionary = {}

func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: ",label)
func frames(count: int = 4) -> void:
	for _index: int in range(count): await process_frame
func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(RenderingServer.get_current_rendering_method()+"-"+label+".png")) == OK,"capture "+label)
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	create_timer(145).timeout.connect(func() -> void: print("FAIL: Garage entry deadline"); quit(1))
	baseline = "--staged-baseline" in OS.get_cmdline_user_args()
	root.size = Vector2i(1280,720)
	var app: Node = load("res://core/app.tscn").instantiate()
	var folder: String = "user://garage-entry-"+TrackLibrary.unique_id()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.records.settings.music_enabled = false
	var conditions: Dictionary = {}
	var paints: Dictionary = {}
	for id: String in VehicleCatalog.IDS:
		var wear := VehicleWeathering.new()
		var condition: Dictionary = wear.snapshot()
		condition.dirt = 0.35
		condition.slow_dirt = 0.2
		conditions[id] = condition
		var paint: Dictionary = VehicleLivery.for_car({},id)
		paint.colors.body = "c72d34"
		paints[id] = paint
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override = folder.path_join("cloud")
	var began: int = Time.get_ticks_usec()
	root.add_child(app)
	while not app.startup_complete: await process_frame
	var music: GameSoundtrack=GameSoundtrack.instance()
	music.music_enabled=false
	music.menu_player.stop()
	music.menu_player.stream=null
	metrics.startup_ms = (Time.get_ticks_usec()-began)/1000.0
	check(app.screen=="account" and not is_instance_valid(app._retained_garage),"guest startup remains independent of Garage")
	# Startup loads the profile. Seed its local cosmetics after that load.
	check(app.records.save_vehicle_conditions(conditions)==OK,"seed real local saved conditions for all seven cars")
	app.records.settings.vehicle_liveries = paints
	app._show_screen("tracks")
	await frames()
	began = Time.get_ticks_usec()
	app._show_screen("garage")
	metrics.entry_dispatch_ms = (Time.get_ticks_usec()-began)/1000.0
	check(app.screen=="garage","cold Garage entry opens the normal menu without a loading screen")
	# In the baseline the screen remains restoring until covered preparation ends.
	while app.screen != "garage": await process_frame
	var page: GaragePage = app._retained_garage
	check(page!=null and page.cached_carousel and page.thumbnails.size()==7,"actual Garage contains all seven catalogue cars")
	for id: String in VehicleCatalog.IDS:
		var card: CarShowroom = page.thumbnails[id]
		check(card.condition==conditions[id],"saved condition retained "+id)
		check(card._image.texture!=null,"cold cache has an immediate car picture "+id)
		check(card.car==null and card.showroom_viewport==null,"carousel picture owns no world "+id)
		if not baseline:
			check(card.displayed_key=="","catalogue fallback is distinct from exact saved appearance "+id)
	await frames(2)
	metrics.first_garage_draw_ms = (Time.get_ticks_usec()-began)/1000.0
	print("GARAGE_FIRST_DRAW: ",JSON.stringify(metrics))
	await capture("baseline-saved-cars" if baseline else "saved-cars-immediate")
	if page.progressive_entry:
		while page.showroom.preparing: await process_frame
		await frames(2)
	check(page.showroom.find_children("*","SubViewport",true,false).size()==3,"main live studio owns exactly three viewports after preparation")
	if DisplayServer.get_name()=="headless":
		check(page.find_children("*","SubViewport",true,false).size()==3,"one live Garage retains exactly three viewports")
	await create_timer(0.4).timeout
	await frames()
	await capture("baseline-saved-cars-settled" if baseline else "saved-cars-settled")
	if not baseline and DisplayServer.get_name() != "headless":
		# Keep the service focused on one miss while exercising both stale-job
		# protection and exact publication after a nonblank catalogue fallback.
		page._preview_service.queued.clear()
		var prior_renders: int = page._preview_service.renders
		for id: String in page.thumbnails:
			if id!="compact": page.thumbnails[id].hide()
		var card: CarShowroom = page.thumbnails.compact
		var paint: Dictionary = card.livery.duplicate(true)
		paint.colors.body = "d23735"
		card.apply_livery(paint)
		var superseded: String = card.preview_key
		paint.colors.body = "3d7acf"
		card.apply_livery(paint)
		check(card._image.texture!=null,"changing a saved finish never blanks the car picture")
		card.publish_preview(superseded,GradientTexture2D.new())
		check(card.displayed_key!=superseded,"superseded capture cannot replace the current car picture")
		var deadline: int = Time.get_ticks_msec()+45000
		while card.displayed_key!=card.preview_key and Time.get_ticks_msec()<deadline: await process_frame
		check(card.displayed_key==card.preview_key,"exact saved paint and condition replace the catalogue fallback")
		check(page._preview_service.renders-prior_renders<=1,"superseded queued finish does not build an extra showroom")
		await frames(3)
		check(page._preview_service.renderer==null,"temporary capture showroom is released")
		check(page.find_children("*","SubViewport",true,false).size()==3,"one live Garage retains exactly three viewports")
		for id: String in page.thumbnails: page.thumbnails[id].show()
		await capture("saved-appearance-resolved")
	var retained: CarShowroom = page.showroom
	app._show_screen("settings")
	app._show_screen("garage")
	check(app.screen=="garage" and app._retained_garage==page and page.showroom==retained,"warm navigation retains the exact interactive showroom")
	app._show_screen("tracks")
	await create_timer(0.4).timeout
	await frames()
	check(app.screen=="tracks" and not page.is_visible_in_tree(),"leaving Garage parks the old page after the normal slide")
	app.records = LocalRecords.new(folder.path_join("other-records.json"))
	app._show_screen("garage")
	check(app.screen=="garage","new owner also enters Garage without a loading screen")
	while app.screen != "garage": await process_frame
	check(app._retained_garage!=page and app._retained_garage.records==app.records,"owner change releases the prior page and appearance cache")
	await frames(6)
	await capture("clean-cars")
	app.queue_free()
	await frames(4)
	metrics.checks = checks
	metrics.failures = failures
	var mode: String = "baseline" if baseline else "fixed"
	var file := FileAccess.open(output.path_join(mode+"-"+RenderingServer.get_current_rendering_method()+".json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics,"  "))
	print("GARAGE_ENTRY_CAROUSEL: ",JSON.stringify(metrics))
	quit(1 if failures else 0)
