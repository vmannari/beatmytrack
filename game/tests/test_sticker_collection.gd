extends SceneTree
## Offline production-menu and shared-art review; all writes use a private fixture.
var failures: int = 0
var checks: int = 0
var output: String
var before: bool

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
	if DisplayServer.get_name() == "headless": return
	check(root.get_texture().get_image().save_png(output.path_join(filename+".png")) == OK,"capture "+filename)

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	output = OS.get_environment("BMT_STICKER_OUTPUT")
	before = output.contains("/before/") or output.contains("\\before\\")
	DirAccess.make_dir_recursive_absolute(output)
	if not before:
		check(LiveryCatalog.stickers.size() == 12,"one twelve-sticker collection")
		check(LiveryCatalog.sticker_index("crest") == 0 and LiveryCatalog.sticker_index("sun") == 11,"retained emblem IDs and indices")
		check(LiveryCatalog.sticker_index("zelvora") == -1,"sponsors are retired")
		var atlas: Texture2D = LiveryCatalog.texture("stickers")
		check(atlas.get_size() == Vector2(1024,768) and atlas.get_image().has_mipmaps(),"compact filtered atlas")
		for sticker: Dictionary in LiveryCatalog.stickers:
			var texture: Texture2D = LiveryCatalog.texture(sticker.id+"_sticker")
			check(texture.get_size() == Vector2(256,256) and texture.get_image().has_mipmaps(),sticker.id+" full-resolution filtered preview")
		# Old local/cloud appearances remain valid; only their retired marks disappear.
		for retired: String in ["zelvora","vorqen","talvexa","orynth","keldrift","velqor","myrvanta","quorven","draxelle","selyth","auvrion","rhexori"]:
			var old: Dictionary = VehicleLivery.defaults("compact")
			old.pattern = "apex_twin"
			old.colors.body = "a44844"
			old.stickers.hood.id = retired
			old.stickers.hood.x = 0.37
			old.stickers.roof.id = "compass"
			var expected: Dictionary = old.duplicate(true)
			expected.stickers.hood.id = "none"
			check(VehicleLivery.valid(old) and VehicleLivery.normalize(old,"compact") == expected,"retirement preserves paint, placement and other panel: "+retired)
			check(old.stickers.hood.id == retired,"normalization does not mutate input: "+retired)
		var bad: Dictionary = VehicleLivery.defaults("compact")
		bad.stickers.hood.id = "unknown"
		check(not VehicleLivery.valid(bad),"unknown IDs stay rejected")
	root.size = Vector2i(1280,720)
	var directory: String = "user://sticker_review_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var records := LocalRecords.new(directory.path_join("records.json"))
	var app: Node = load("res://core/app.tscn").instantiate()
	app.records = records
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
	var showroom: CarShowroom = page.showroom
	page.livery_menu.sticker_tiles.crest.pressed.emit()
	check(page.showroom.car.livery == page.draft,"first sticker reaches the actual car, even with an aliased initial draft")
	if not before: check(page.draft.stickers.hood.rotation == 180.0,"new emblem faces the front")
	# Let the real camera focus and the first-customisation achievement finish.
	if DisplayServer.get_name() != "headless": await create_timer(4.5).timeout
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(844,390)]:
		root.size = dimensions
		await settle()
		check(app.root_ui.get_global_rect().encloses(page.tools_panel.get_global_rect()),"tools fit "+str(dimensions))
		if not before: check(page.livery_menu.find_children("StickerCategory_*","",true,false).is_empty(),"no redundant category row")
		await capture("gallery-%dx%d" % [dimensions.x,dimensions.y])
	root.size = Vector2i(1280,720)
	page._edit_sticker_position(true)
	await settle()
	var board: StickerPlacement = page._sticker_board
	check(is_instance_valid(board),"Place sticker opens real editor")
	var point: Vector2 = board.global_position+board.panel_rect().get_center()
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = point
	touch.pressed = true
	root.push_input(touch,true)
	await process_frame
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = point+Vector2(12,5)
	drag.relative = Vector2(12,5)
	root.push_input(drag,true)
	await process_frame
	touch.pressed = false
	touch.position = drag.position
	root.push_input(touch,true)
	await settle()
	check(app.screen == "garage" and page.draft.stickers.hood.x > 0.5,"real touch places sticker without navigation")
	page._sticker_property(0.76,"size")
	page._sticker_property(-12.0,"rotation")
	page._save()
	await capture("placement")
	var hood: Dictionary = page.draft.stickers.hood.duplicate(true)
	page._edit_sticker_position(false)
	page._choose_sticker_surface("roof")
	await settle()
	page.livery_menu.sticker_tiles.compass.pressed.emit()
	var roof_content: Control = page.livery_menu._content
	page._choose_sticker_surface("hood")
	await settle()
	check(page.livery_menu.sticker_tiles.crest.selected and page.draft.stickers.hood == hood,"cached hood keeps exact placement and selection")
	page._choose_sticker_surface("roof")
	await settle()
	check(page.livery_menu._content == roof_content and page.livery_menu.sticker_tiles.compass.selected,"cached roof keeps independent selection")
	check(page.showroom == showroom,"browsing keeps actual showroom")
	var reopened := LocalRecords.new(records.path)
	reopened.load_records()
	var saved: Dictionary = VehicleLivery.for_car(reopened.settings,"compact")
	check(saved.colors == page.draft.colors and saved.pattern == page.draft.pattern,"file reload keeps paint")
	for surface: String in VehicleLivery.SURFACES:
		check(saved.stickers[surface].id == page.draft.stickers[surface].id,"file reload keeps "+surface+" sticker")
		for field: String in ["x","y","size","rotation"]:
			check(is_equal_approx(float(saved.stickers[surface][field]),float(page.draft.stickers[surface][field])),"file reload keeps "+surface+" "+field)
	# Review every emblem on the actual production car, using the same camera before/after.
	page._choose_sticker_surface("hood")
	page._choose_sticker(0)
	page._choose_sticker_surface("roof")
	page._sticker_property(0.95,"size")
	page._sticker_property(180.0,"rotation")
	page._move_sticker(Vector2(0.5,0.5))
	page.showroom.elevation = 0.93
	page.showroom._orbit()
	if DisplayServer.get_name() != "headless":
		var sheet: Image = Image.create(1600,768,false,Image.FORMAT_RGB8)
		var previous: String = ""
		for index: int in range(12):
			page._choose_sticker(index+1)
			await settle()
			check(page.showroom.car.livery == page.draft,"live car has selected "+str(LiveryCatalog.stickers[index].id))
			var image: Image = page.showroom.showroom_viewport.get_texture().get_image()
			var image_hash: String = image.get_data().hex_encode().sha256_text()
			check(image_hash != previous,"actual car visibly changes for "+str(LiveryCatalog.stickers[index].id))
			previous = image_hash
			image.resize(400,256,Image.INTERPOLATE_LANCZOS)
			image.convert(Image.FORMAT_RGB8)
			sheet.blit_rect(image,Rect2i(0,0,400,256),Vector2i(index%4*400,index/4*256))
		check(sheet.save_png(output.path_join("all-stickers-on-car.png")) == OK,"twelve actual-car views")
	page._choose_sticker(0)
	check(page.draft.stickers.roof.id == "none" and page.livery_menu.active_control("PlaceSticker").disabled,"removal disables placement")
	for id: String in VehicleCatalog.IDS:
		page.open_car(VehicleCatalog.IDS.find(id))
		page._show_section("customise")
		page._set_customise_tab("stickers")
		await settle()
		check(page.livery_menu.sticker_tiles.size() == 12,id+" has the same twelve designs")
		check((page.livery_menu.active_control("StickerRoof") != null) == LiveryCatalog.has_roof(id),id+" physical panel choices")
		page._choose_sticker_surface("hood")
		page._choose_sticker(0)
		page.livery_menu.sticker_tiles.crest.pressed.emit()
		await settle()
		check(page.showroom.car.livery == page.draft,id+" live sticker matches draft")
		if not before: check(page.draft.stickers.hood.rotation == (0.0 if id == "forklift" else 180.0),id+" upright initial orientation")
		await capture(id+"-stickers")
	app.queue_free()
	await process_frame
	# Native SVG gallery at a useful inspection scale.
	root.size = Vector2i(1024,840)
	root.content_scale_size = Vector2i(1024,840)
	root.content_scale_factor = 1.0
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel",MenuStyle.box(Color("23313b"),0))
	root.add_child(panel)
	var grid := GridContainer.new()
	grid.columns = 4
	panel.add_child(grid)
	for index: int in range(12):
		var tile: LiveryTile = LiveryTile.make(LiveryCatalog.stickers[index].title,LiveryCatalog.texture(LiveryCatalog.stickers[index].id+"_sticker"),func() -> void: pass,true)
		tile.size_flags_vertical = Control.SIZE_EXPAND_FILL
		grid.add_child(tile)
	await capture("artwork")
	panel.queue_free()
	await process_frame
	print("Sticker collection: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
