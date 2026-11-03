extends SceneTree
## Real offline App: startup ownership, early entry, grey masks and exact reveal.
const Ghost = preload("res://ui/garage_loading_car.gd")
var checks: int = 0
var failures: int = 0
var output: String
var timings: Dictionary = {}
var app: Node

func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; printerr("DEFERRED_GARAGE_FAIL ",label)
func frames(count: int = 4) -> void:
	for _frame: int in range(count): await process_frame
func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"capture "+label)
func motion_finished() -> void:
	while app.menu_page_motion != null and app.menu_page_motion.is_running(): await process_frame
func run() -> void:
	OS.set_environment("BMT_API_URL","")
	output = OS.get_environment("BMT_GARAGE_DEFERRED_EVIDENCE")
	DirAccess.make_dir_recursive_absolute(output)
	create_timer(240).timeout.connect(func() -> void: printerr("DEFERRED_GARAGE_TIMEOUT"); quit(1))
	root.size = Vector2i(1280,720)
	var folder: String = "user://deferred-garage-"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var records := LocalRecords.new(folder.path_join("records.json"))
	var liveries: Dictionary = {}
	for id: String in VehicleCatalog.IDS:
		var paint: Dictionary = VehicleLivery.defaults(id)
		paint.colors.body = "32b5d7"
		liveries[id] = paint
	records.settings = {"music_enabled":false,"selected_car":"compact","vehicle_liveries":liveries}
	check(records.save_records() == OK,"private customized-car fixture saved")
	app = load("res://core/app.tscn").instantiate()
	check(app.get_script() != null,"App script loads")
	if app.get_script() == null: quit(1); return
	app.records = records
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override = folder.path_join("cloud")
	var began: int = Time.get_ticks_usec()
	root.add_child(app)
	var garage_started_early: bool = false
	while not app.startup_complete:
		app._publishing_slots_foreground = true
		if is_instance_valid(app._garage_preloader) and (is_instance_valid(app._garage_preloader.picture_service) or app._garage_preloader.studio != null): garage_started_early = true
		await process_frame
	timings.startup_ms = (Time.get_ticks_usec()-began)/1000.0
	check(not garage_started_early,"Garage pictures and studio do not start during startup")
	check(app.screen == "account" and not app.online.configured,"startup reaches the offline account screen")
	check(not is_instance_valid(app._retained_garage),"startup does not create a Garage page")
	if DisplayServer.get_name() != "headless":
		check(preload("res://ui/header_car_icons.gd").ready("compact",records),"equipped header is ready before startup releases")
		check(app.header_car_cache.captures == 1,"startup retains the one required equipped-header capture")
	var loader: Node = app._garage_preloader
	loader.set_process(false)
	app._publishing_slots_foreground = false
	began = Time.get_ticks_usec()
	app._navigate_menu_page("garage")
	timings.entry_dispatch_ms = (Time.get_ticks_usec()-began)/1000.0
	var page: GaragePage = app._retained_garage
	check(app.screen == "garage" and is_instance_valid(page),"missing pictures never block Garage navigation")
	check(page.progressive_entry and page.showroom.car == null,"early navigation defers actual native construction")
	var cover: Control = page.showroom.get_node("GarageOpeningPicture")
	check(cover.get_script() == Ghost and cover.vehicle_id == "compact","main view immediately shows the selected car's neutral mask")
	check(page.showroom.achievement_service == app.achievements,"saved wall contents participate in deferred scene preparation")
	check(page.thumbnails.size() == VehicleCatalog.IDS.size(),"all current car cards are present")
	for id: String in VehicleCatalog.IDS:
		var thumbnail: Control = page.thumbnails[id]
		check(thumbnail._placeholder.get_script() == Ghost and thumbnail._placeholder.vehicle_id == id,"model-specific thumbnail ghost "+id)
		check(thumbnail._image.texture == null and thumbnail._placeholder.visible,"missing custom picture never substitutes factory paint "+id)
	check(not page.preview.get_node("GarageViewControls").visible,"orbit hint waits for the actual interactive studio")
	await motion_finished()
	await frames()
	check(page.showroom.car == null,"background/foreground fence preserves the placeholder")
	for pixels: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1600,900)]:
		root.size = pixels
		await frames(4)
		await capture("loading-"+str(pixels.x)+"x"+str(pixels.y))
	root.size = Vector2i(1280,720)
	for id: String in VehicleCatalog.IDS:
		page.preview_car(VehicleCatalog.IDS.find(id))
		check(cover.vehicle_id == id,"rapid preview updates the loading identity "+id)
	check(VehicleCatalog.selected == "compact" and records.settings.selected_car == "compact","previews do not equip or save another car")
	page.preview_car(VehicleCatalog.IDS.find("compact"))
	page._show_section("tuning")
	check(page._opening_section == "tuning" and page.section == "cars","early workshop action waits for the live car")
	page._show_section("cars")
	check(page._opening_section.is_empty(),"returning to Cars cancels the queued workshop destination")
	app.cloud_starting = true
	app._publishing_slots_foreground = true
	await frames(5)
	check(page.showroom.car == null,"race loading pauses studio preparation")
	app.cloud_starting = false
	app._show_screen("settings")
	await motion_finished()
	await frames()
	check(page.showroom.car == null,"leaving before construction keeps the hidden studio parked")
	app._show_screen("garage")
	await motion_finished()
	began = Time.get_ticks_usec()
	while page.showroom.preparing:
		app._publishing_slots_foreground = true
		await process_frame
	timings.live_preparation_ms = (Time.get_ticks_usec()-began)/1000.0
	check(page.showroom.interaction_ready and page.showroom.showroom_ready,"live studio becomes ready")
	check(page.showroom.car.vehicle_id == "compact" and page.showroom.car.livery == liveries.compact,"first live reveal has the exact saved car and paint")
	check(page.showroom.get_node_or_null("GarageOpeningPicture") == null,"temporary ghost releases after readiness")
	check(page.showroom.find_children("*","SubViewport",true,false).size() == 3,"temporary warming viewport releases; original three remain")
	check(page.showroom.reflections.views.size() == 2 and bool(page.showroom.reflections.deck_material.get_shader_parameter("reflection_enabled")),"live floor and pedestal reflections remain enabled")
	check(page.showroom.find_child("GarageTrophyWall",true,false).has_meta("achievement_signature"),"first live reveal includes the actual achievement wall contents")
	check(page.preview.get_node("GarageViewControls").visible,"live orbit hint becomes available")
	var yaw: float = page.showroom.yaw
	page.showroom.rotate_view(Vector2(15,0))
	check(page.showroom.yaw != yaw,"live rotation works after reveal")
	page.showroom.reset_view()
	await frames(6)
	await capture("live-1280x720")
	var service: Node = page._preview_service
	root.size = Vector2i(1600,900)
	await frames(6)
	var next_status: int = 0
	while DisplayServer.get_name() != "headless" and not service.pictures_ready():
		# A page service has visible thumbnail owners, rather than warm_views.
		var ready: bool = true
		var visible_missing: bool = false
		var offscreen_missing: int = -1
		for id: String in page.thumbnails:
			var thumbnail: Control = page.thumbnails[id]
			if thumbnail._image.texture != null: continue
			ready = false
			if service._on_screen(thumbnail): visible_missing = true
			else: offscreen_missing = VehicleCatalog.IDS.find(id)
		if ready: break
		if not visible_missing and offscreen_missing >= 0:
			page.gallery.scroll_horizontal = offscreen_missing*page.tile_stride
		if Time.get_ticks_msec() >= next_status:
			next_status = Time.get_ticks_msec()+3000
			var status: Dictionary = {}
			for id: String in page.thumbnails:
				var thumbnail: Control = page.thumbnails[id]
				status[id] = {"ready":thumbnail._image.texture != null,"visible":service._on_screen(thumbnail),"rect":str(thumbnail.get_global_rect())}
			print("DEFERRED_PICTURES ",JSON.stringify({"cars":status,"active":service.active.get("vehicle",""),"queued":service.queued.size(),"allowed":service._render_allowed(),"renders":service.renders}))
		app._publishing_slots_foreground = true
		await process_frame
	if DisplayServer.get_name() != "headless":
		for id: String in VehicleCatalog.IDS:
			var thumbnail: Control = page.thumbnails[id]
			check(thumbnail._image.texture != null and not thumbnail._placeholder.visible,"finished picture replaces the ghost "+id)
			check(thumbnail.displayed_key == thumbnail.preview_key,"only the current appearance publishes "+id)
	root.size = Vector2i(1280,720)
	page.gallery.scroll_horizontal = 0
	await frames(6)
	await capture("pictures-ready-1280x720")
	loader.evict()
	check(is_instance_valid(page.showroom.car) and page.showroom.interaction_ready,"optional cache eviction preserves the visible live studio")
	var previous: WeakRef = weakref(page)
	app._show_screen("account")
	app.records = LocalRecords.new(folder.path_join("other-owner.json"))
	app._publishing_slots_foreground = false
	app._show_screen("garage")
	check(app._retained_garage != page and app._retained_garage.records == app.records,"another owner gets a new Garage with independent picture ownership")
	check(app._retained_garage.showroom.get_node("GarageOpeningPicture").get_script() == Ghost,"another owner also opens immediately with a neutral ghost")
	page = null
	await frames(8)
	check(previous.get_ref() == null,"old owner's studio and pending work release")
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"timings":timings},"  "))
	file.close()
	app.queue_free()
	await frames(16)
	print("DEFERRED_GARAGE_COMPLETE ",checks," checks, ",failures," failures ",JSON.stringify(timings))
	quit(1 if failures else 0)
