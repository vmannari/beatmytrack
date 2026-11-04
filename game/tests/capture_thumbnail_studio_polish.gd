extends SceneTree
## Actual offline App with varied saved liveries, full Garage and all five cards.
var app: Node
var checks: int = 0
var failures: int = 0
var output: String
func _initialize() -> void: run.call_deferred()
func check(value: bool,label: String) -> void:
	checks += 1
	if not value: failures += 1; printerr("THUMBNAIL_APP_FAIL ",label)
func run() -> void:
	OS.set_environment("BMT_API_URL","")
	output = OS.get_environment("BMT_THUMBNAIL_OUTPUT")
	DirAccess.make_dir_recursive_absolute(output)
	create_timer(180).timeout.connect(func() -> void: printerr("THUMBNAIL_APP_TIMEOUT"); quit(1))
	root.size = Vector2i(1920,900)
	var folder: String = "user://thumbnail-studio-polish-"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var records := LocalRecords.new(folder.path_join("records.json"))
	var colors: Dictionary = {"compact":"587d2d","kart":"e5b633","forklift":"cf3b33","electric":"683ed4","hovercraft":"c85c42"}
	var paints: Dictionary = {}
	for id: String in VehicleCatalog.IDS:
		var paint: Dictionary = VehicleLivery.defaults(id)
		paint.colors.body = colors[id]
		paint.pattern = "offset_gt"
		paints[id] = paint
	records.settings = {"music_enabled":false,"selected_car":"electric","vehicle_liveries":paints}
	check(records.save_records()==OK,"save private five-color fixture")
	app = load("res://core/app.tscn").instantiate()
	app.records = records
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete:
		app._publishing_slots_foreground = true
		await process_frame
	app._publishing_slots_foreground = true
	app._show_screen("garage")
	var page: GaragePage = app._retained_garage
	page._preview_service.idle_ms = 0
	while page.showroom.preparing: await process_frame
	var ready: bool = false
	while not ready:
		ready = true
		var visible_missing: bool = false
		var offscreen_missing: int = -1
		for id: String in page.thumbnails:
			if page.thumbnails[id]._image.texture==null:
				ready = false
				if page._preview_service._on_screen(page.thumbnails[id]): visible_missing = true
				else: offscreen_missing = VehicleCatalog.IDS.find(id)
		if not visible_missing and offscreen_missing>=0:
			page.gallery.scroll_horizontal = offscreen_missing*page.tile_stride
		await process_frame
	while app.menu_page_motion!=null and app.menu_page_motion.is_running(): await process_frame
	check(page.showroom.reflections.views.size()==2 and page.showroom.find_children("*","SubViewport",true,false).size()==3,"live Garage retains the original full reflection rig")
	check(page.showroom.car.vehicle_id=="electric" and page.showroom.car.livery==paints.electric,"main selected Volt keeps the saved finish")
	for id: String in page.thumbnails:
		var thumbnail: CarShowroom = page.thumbnails[id]
		check(thumbnail.displayed_key==thumbnail.preview_key and not thumbnail._placeholder.visible,"current exact picture replaces loading ghost "+id)
	for dimensions: Vector2i in [Vector2i(1920,900),Vector2i(1280,720),Vector2i(960,540)]:
		root.size = dimensions
		page.gallery.scroll_horizontal = 0
		for _frame: int in range(10): await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output.path_join("garage-"+str(dimensions.x)+"x"+str(dimensions.y)+".png"))==OK,"native Garage capture "+str(dimensions))
	check(not app.online.configured,"capture remains offline")
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method()},"  "))
	app.queue_free()
	for _frame: int in range(16): await process_frame
	print("THUMBNAIL_APP ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
