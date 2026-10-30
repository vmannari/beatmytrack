extends SceneTree
## Offline actual-App proof: placement stays visible independently of the gallery.
var checks: int = 0
var failures: int = 0
var output: String
var baseline: bool

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func settle() -> void:
	for tick: int in range(12): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func capture(filename: String) -> void:
	await settle()
	if DisplayServer.get_name() != "headless":
		check(root.get_texture().get_image().save_png(output.path_join(filename+".png")) == OK,"capture "+filename)

func tap(point: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = point
	event.pressed = true
	root.push_input(event,true)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	root.push_input(event,true)
	await settle()

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	output = OS.get_environment("BMT_STICKER_OUTPUT")
	baseline = output.contains("/before/") or output.contains("\\before\\")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	var directory: String = "user://sticker_workbench_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var app: Node = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.library = TrackLibrary.new(directory.path_join("tracks"))
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	VehicleCatalog.selected = "compact"
	app._show_screen("garage")
	await settle()
	var page: GaragePage = app.root_ui.find_child("GaragePage",true,false)
	page.open_car(0)
	page._show_section("customise")
	page._set_customise_tab("stickers")
	await settle()
	var original_car: CarVisual = page.showroom.car
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(844,390),Vector2i(1600,900)]:
		root.size = dimensions
		await settle()
		var scroll: ScrollContainer = page.livery_menu._content.find_children("*","ScrollContainer",true,false)[0]
		var place: Button = page.livery_menu.active_control("PlaceSticker")
		var remove: Button = page.livery_menu.active_control("RemoveSticker")
		var initial_rect: Rect2
		for edge: int in [0,1]:
			scroll.scroll_vertical = 0 if edge == 0 else 100000
			await settle()
			var rect: Rect2 = place.get_global_rect()
			check(place.is_visible_in_tree() and app.root_ui.get_global_rect().encloses(rect) and page.tools_panel.get_global_rect().encloses(rect),"Place sticker visible at gallery edge %d / %s" % [edge,dimensions])
			check(not scroll.is_ancestor_of(place),"placement action outside scroll content")
			check(not scroll.get_global_rect().intersects(rect),"gallery does not overlap placement action")
			check(app.root_ui.get_global_rect().encloses(remove.get_global_rect()),"remove action stays visible")
			check(place.size.y >= 48,"placement keeps touch height")
			if edge == 0: initial_rect = rect
			else: check(rect == initial_rect,"placement does not move when gallery scrolls")
			await capture("gallery-%dx%d-%s" % [dimensions.x,dimensions.y,"top" if edge == 0 else "bottom"])
		if not baseline:
			# Tap a real artwork tile, then the fixed action while the gallery is at its end.
			scroll.scroll_vertical = 0
			await settle()
			var tile: LiveryTile = page.livery_menu.sticker_tiles.crest
			await tap(tile.get_global_rect().intersection(scroll.get_global_rect()).get_center())
			check(page.draft.stickers.hood.id == "crest","native artwork tap selects exact ID")
			scroll.scroll_vertical = 100000
			await settle()
			check(not place.disabled,"selected sticker enables fixed action")
			await tap(place.get_global_rect().get_center())
			check(page._sticker_editing and is_instance_valid(page._sticker_board),"native tap opens placement without scrolling to action")
			page._edit_sticker_position(false)
			await settle()
			page._choose_sticker(0)
			check(page.livery_menu.active_control("PlaceSticker").disabled,"empty panel retains visible disabled action")
	root.size = Vector2i(1280,720)
	for surface: String in ["hood","roof"]:
		page._choose_sticker_surface(surface)
		await settle()
		page.livery_menu.sticker_tiles.compass.pressed.emit()
		check(page.draft.stickers[surface].id == "compass","independent cached "+surface+" selection")
		if not baseline:
			var place: Button = page.livery_menu.active_control("PlaceSticker")
			check(not place.disabled and not place.get_parent().is_class("ScrollContainer"),"cached panel retains enabled action")
	check(page.showroom.car == original_car,"sticker browsing retains the actual car")
	await capture("selected-artwork-on-car")
	app.queue_free()
	await process_frame
	root.size = Vector2i(1024,840)
	root.content_scale_size = Vector2i(1024,840)
	root.content_scale_factor = 1.0
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel",MenuStyle.box(Color("1c2830"),0))
	root.add_child(panel)
	var grid := GridContainer.new()
	grid.columns = 4
	panel.add_child(grid)
	for sticker: Dictionary in LiveryCatalog.stickers:
		var tile: LiveryTile = LiveryTile.make(sticker.title,LiveryCatalog.texture(sticker.id+"_sticker"),func() -> void: pass,true)
		tile.size_flags_vertical = Control.SIZE_EXPAND_FILL
		grid.add_child(tile)
	await capture("artwork")
	panel.queue_free()
	await process_frame
	print("STICKER_WORKBENCH: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
