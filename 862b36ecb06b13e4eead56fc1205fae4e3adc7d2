extends SceneTree
## Offline visual review of the actual Garage with disposable local records.
var page: GaragePage
var output: String

func _initialize() -> void: run.call_deferred()

func settle() -> void:
	while page._workbench_focus_pending or page._menu_motion != null or page.showroom.camera_motion != null and page.showroom.camera_motion.is_running():
		await process_frame
	await create_timer(0.85).timeout
	for frame: int in range(10): await process_frame
	await RenderingServer.frame_post_draw

func run() -> void:
	OS.set_environment("BMT_API_URL", "")
	GameSoundtrack.instance().music_enabled = false
	output = OS.get_cmdline_user_args()[0].trim_prefix("--evidence-root=")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	var directory: String = "user://palette_review_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var app: Node = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.library = TrackLibrary.new(directory)
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	VehicleCatalog.selected = "compact"
	app._show_screen("garage")
	while page == null or not page.is_visible_in_tree():
		if is_instance_valid(app.root_ui): page = app.root_ui.find_child("GaragePage",true,false)
		await process_frame
	page.open_car(0)
	await settle()
	page._set_customise_tab("colours")
	await settle()
	var menu: GarageLiveryMenu = page.livery_menu
	var palette: GridContainer = menu.find_child("LiveryColourPalette",true,false)
	print("PALETTE_REVIEW: chips=",palette.get_child_count()," columns=",palette.columns)
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1720,960),Vector2i(540,960)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await settle()
		var scroll: ScrollContainer = palette.get_parent().get_parent()
		scroll.ensure_control_visible(palette.get_child(palette.get_child_count()-1))
		await settle()
		print("PALETTE_LAYOUT: window=",dimensions," palette=",palette.get_global_rect()," scroll=",scroll.get_global_rect())
		var result: Error = root.get_texture().get_image().save_png(output.path_join("colours-%dx%d.png" % [dimensions.x,dimensions.y]))
		if result != OK:
			push_error("Could not capture palette")
			quit(1)
			return
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	await settle()
	for slot: String in VehicleLivery.SLOTS:
		menu._select_slot(slot)
		for chip: LiveryColourChip in menu.colour_chips.slice(15):
			chip.pressed.emit()
			var reopened := LocalRecords.new(app.records.path)
			reopened.load_records()
			print("PALETTE_SAVED: ",slot,"=",VehicleLivery.for_car(reopened.settings,"compact").colors[slot]," chosen=",chip.colour.to_html(false))
	await settle()
	root.get_texture().get_image().save_png(output.path_join("new-colours-applied.png"))
	app.queue_free()
	await process_frame
	quit()
