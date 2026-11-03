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
	app._garage_preloader.evict() # Exercise entry before any native preload exists.
	app._show_screen("tracks")
	await frames()
	began = Time.get_ticks_usec()
	app._show_screen("garage")
	metrics.entry_dispatch_ms = (Time.get_ticks_usec()-began)/1000.0
	check(app.screen=="garage","cold Garage entry opens the normal menu without a loading screen")
	# In the baseline the screen remains restoring until covered preparation ends.
	while app.screen != "garage": await process_frame
	var page: GaragePage = app._retained_garage
	check(page!=null and page.cached_carousel and page.thumbnails.size()==VehicleCatalog.IDS.size(),"actual Garage contains all current catalogue cars")
	check(page.progressive_entry,"cold entry defers the live car behind a neutral placeholder")
	var cover: Control=page.showroom.find_child("GarageOpeningPicture",true,false)
	check(cover!=null and cover.get_script()==preload("res://ui/garage_loading_car.gd"),"cold main view uses the car's abstract mask")
	check(page.showroom.livery==paints.compact,"deferred native car starts with its saved livery")
	for id: String in VehicleCatalog.IDS:
		var card: CarShowroom = page.thumbnails[id]
		check(card.condition==conditions[id],"saved condition retained "+id)
		check(card._image.texture==null,"cold custom preview never displays a stock livery "+id)
		var loading: Control=card.get_node_or_null("PreviewLoading")
		check(loading!=null and loading.visible,"uncached custom car visibly loads instead of leaving an empty card "+id)
		check(card.car==null and card.showroom_viewport==null,"carousel picture owns no world "+id)
		if not baseline:
			check(card.displayed_key=="","pending custom preview has no published appearance "+id)
	await frames(2)
	metrics.first_garage_draw_ms = (Time.get_ticks_usec()-began)/1000.0
	print("GARAGE_FIRST_DRAW: ",JSON.stringify(metrics))
	await capture("baseline-saved-cars" if baseline else "saved-cars-immediate")
	if page.progressive_entry:
		while page.showroom.preparing: await process_frame
		await frames(2)
	check(page.showroom.car.livery==paints.compact,"first revealed native car has its saved livery")
	check(page.showroom.find_children("*","SubViewport",true,false).size()==3,"main live studio owns exactly three viewports after preparation")
	if DisplayServer.get_name()=="headless":
		check(page.find_children("*","SubViewport",true,false).size()==3,"one live Garage retains exactly three viewports")
	await create_timer(0.4).timeout
	await frames()
	await capture("baseline-saved-cars-settled" if baseline else "saved-cars-settled")
	if DisplayServer.get_name() != "headless":
		var arrivals: Dictionary={}
		for offset: int in [0, 10000]:
			page.gallery.scroll_horizontal=offset
			await frames(2)
			var until: int=Time.get_ticks_msec()+45000
			while Time.get_ticks_msec()<until:
				var missing: bool=false
				for id: String in page.thumbnails:
					var tile: CarShowroom=page.thumbnails[id]
					if not page._preview_service._on_screen(tile): continue
					if tile.displayed_key!=tile.preview_key: missing=true
					elif not arrivals.has(id):
						arrivals[id]=(Time.get_ticks_usec()-began)/1000.0
						var loading: Control=tile.get_node_or_null("PreviewLoading")
						check(loading!=null and not loading.visible,"exact native image replaces loading state "+id)
				if not missing: break
				await process_frame
			await capture("delivery-"+str(offset))
		for id: String in page.thumbnails:
			check(arrivals.has(id),"natural queue delivers custom car "+id)
		metrics.arrivals_ms=arrivals
		print("DELIVERY_ARRIVALS: ",JSON.stringify(arrivals))
		page.gallery.scroll_horizontal=0
		await frames(2)
	if not baseline and DisplayServer.get_name() != "headless":
		# Keep the service focused on one miss while exercising both stale-job
		# protection and exact publication without a different livery appearing.
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
		check(card._image.texture==null,"changing a saved finish clears a different appearance immediately")
		card.publish_preview(superseded,GradientTexture2D.new())
		check(card.displayed_key!=superseded,"superseded capture cannot replace the current car picture")
		check(card._placeholder.visible,"stale completion cannot dismiss loading for the current appearance")
		var deadline: int = Time.get_ticks_msec()+45000
		while card.displayed_key!=card.preview_key and Time.get_ticks_msec()<deadline: await process_frame
		check(card.displayed_key==card.preview_key,"first published picture has the exact saved paint and condition")
		check(page._preview_service.renders-prior_renders<=1,"superseded queued finish does not build an extra showroom")
		await frames(3)
		check(page._preview_service.renderer==null,"temporary capture showroom is released")
		check(page.find_children("*","SubViewport",true,false).size()==3,"one live Garage retains exactly three viewports")
		var exact_image: Image=card._image.texture.get_image()
		while page._preview_service.worker!=null and Time.get_ticks_msec()<deadline: await process_frame
		var repeat: CarShowroom=preload("res://ui/garage_cached_thumbnail.gd").new()
		repeat.preview_service=page._preview_service
		repeat.vehicle_id=card.vehicle_id
		repeat.livery=card.livery.duplicate(true)
		repeat.condition=card.condition.duplicate(true)
		repeat.customisation=card.customisation.duplicate(true)
		repeat.size=Vector2(250,104)
		root.add_child(repeat)
		check(repeat._image.texture==null,"cached custom picture waits for its own decoded image")
		var repeats_before: int=page._preview_service.renders
		while repeat.displayed_key!=repeat.preview_key and Time.get_ticks_msec()<deadline: await process_frame
		check(repeat.displayed_key==repeat.preview_key,"exact saved picture is recovered from disk")
		if repeat._image.texture!=null:
			check(repeat._image.texture.get_image().get_data()==exact_image.get_data(),"recovered preview preserves the actual saved-livery pixels")
		check(page._preview_service.renders==repeats_before,"cached reentry needs no new capture world")
		repeat.queue_free()
		await process_frame
		for id: String in page.thumbnails: page.thumbnails[id].show()
		await capture("saved-appearance-resolved")
	# Stock pictures are valid only for the exact stock appearance. Exercise
	# repaint, worn and fitted-car misses even when no GPU capture is available.
	var test_card: CarShowroom=page.thumbnails.compact
	var service: Node=page._preview_service
	var default_paint: Dictionary=VehicleLivery.for_car({},"compact")
	test_card.condition={}
	test_card.customisation=VehicleCustomisation.defaults()
	test_card.apply_livery(default_paint)
	check(test_card._image.texture==service.catalogue_texture("compact") and test_card.displayed_key==test_card.preview_key,"exact default car immediately shows its matching stock photo")
	var old_key: String=test_card.preview_key
	var old_texture: Texture2D=test_card._image.texture
	test_card.apply_livery(paints.compact)
	check(test_card._image.texture==null and test_card.displayed_key=="","repaint never retains the earlier stock picture")
	test_card.publish_preview(old_key,old_texture)
	check(test_card._image.texture==null and test_card.displayed_key=="","late stock completion cannot fill a customized car slot")
	test_card.publish_preview(test_card.preview_key,old_texture)
	# Publication itself is tested above with a real native capture. Here a
	# sentinel texture lets the headless run cover retained-key invalidation.
	test_card.refresh_thumbnail()
	check(test_card._image.texture==old_texture,"unchanged appearance retains its completed picture")
	test_card.condition=conditions.compact
	test_card.refresh_thumbnail()
	check(test_card._image.texture==null,"condition change clears the previous appearance")
	check(test_card._placeholder.visible,"condition invalidation restores the loading state")
	test_card.condition={}
	test_card.apply_livery(default_paint)
	var parts: Dictionary=VehicleCustomisation.defaults()
	parts.rims="five"
	test_card.apply_customisation(parts)
	check(test_card._image.texture==null,"fitted parts never borrow a stock-car photograph")
	test_card.customisation=VehicleCustomisation.defaults()
	test_card.condition=conditions.compact
	test_card.apply_livery(paints.compact)
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
