extends SceneTree
## Exact prepared geometry/photos and retained native menus, without player IO.
var checks: int = 0
var failures: int = 0
func _initialize() -> void: _run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+label)
func digest(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()
func settle() -> void:
	for frame: int in range(6): await process_frame
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
func _run() -> void:
	OS.set_environment("BMT_API_URL","")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CompactKits.ASSET_ROOT.path_join("manifest.json")))
	check(manifest.version==2 and manifest.options_per_category==10 and manifest.meshes.size()<1400,"bounded expanded authored mesh catalog")
	for key: String in manifest.meshes:
		var resource: ArrayMesh = load(CompactKits.ASSET_ROOT.path_join("meshes/"+str(manifest.meshes[key].file)))
		check(resource!=null and digest(var_to_bytes(resource.surface_get_arrays(0)))==manifest.meshes[key].surface_sha256,"prepared arrays exact "+key)
	CompactKitThumbnail.images.clear()
	for category: String in VehicleCustomisation.CATEGORIES:
		for option: Array in VehicleCustomisation.OPTIONS[category]:
			var card: CompactKitThumbnail = CompactKitThumbnail.make(category,option,false,func() -> void: pass)
			root.add_child(card)
			check(card.viewport==null,"cold preview needs no car/world: "+category+"/"+str(option[0]))
			var path: String = CompactKits.ASSET_ROOT.path_join("previews/"+RenderingServer.get_current_rendering_method()+"/"+category+"_"+str(option[0])+".png")
			var original := Image.new()
			original.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
			var imported: Image = card.image.texture.get_image()
			imported.clear_mipmaps()
			original.convert(Image.FORMAT_RGBA8)
			imported.convert(Image.FORMAT_RGBA8)
			check(original.get_data()==imported.get_data(),"preview pixels exact "+category+"/"+str(option[0]))
			card.queue_free()
			await process_frame
	check(CompactKitThumbnail.images.size()<=16,"preview byte budget retains sixteen images")
	var folder: String = "user://garage_speed_checks_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var app: Node = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.library = TrackLibrary.new(folder)
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	VehicleCatalog.selected = "compact"
	app._show_screen("garage")
	await settle()
	var page: GaragePage = app.root_ui.find_child("GaragePage",true,false)
	page.open_car(0)
	await settle()
	var menu: GarageLiveryMenu = page.livery_menu
	var patterns: Control = menu.pattern_scroll
	var car: CarVisual = page.showroom.car
	var camera: Transform3D = page.showroom.camera.transform
	page._set_customise_tab("colours")
	var picker: ColorPickerButton = page.pickers.body
	for pass_index: int in range(4):
		for tab: String in ["stickers","livery","colours"]:
			page._set_customise_tab(tab)
			check(page.livery_menu==menu and menu.pattern_scroll==patterns,"same native workbench/gallery retained")
			check(page.showroom.car==car and page.showroom.camera.transform==camera,"menu switch retains actual car/camera")
			check(page.pickers.body==picker,"colour picker retained")
		page._show_section("tuning")
		page._show_section("customise")
		check(page.livery_menu==menu,"workbench retained across Tuning")
		check(menu.is_visible_in_tree(),"retained workbench restores visibility")
	check(menu._contents.size()<=4,"one car has bounded native tab roots")
	page._set_customise_tab("stickers")
	page._choose_sticker(1)
	page._edit_sticker_position(true)
	await settle()
	page._set_customise_tab("colours")
	await settle()
	check(page._sticker_board==null and page._sticker_sliders.is_empty(),"leaving placement clears stale controls")
	page.open_car(4)
	page._set_customise_tab("stickers")
	check(page.livery_menu!=menu and page.livery_menu.find_child("StickerRoof",true,false)==null,"car switch invalidates physical-panel tools")
	page.open_car(0)
	page._show_section("tuning")
	page._select_kit("hood","louvres")
	var installed: CarVisual = page.showroom.car
	page.showroom.apply_customisation(page.kit_draft)
	check(page.showroom.car==installed,"unchanged fitted selection avoids rebuilding car")
	app.queue_free()
	await process_frame
	print("GARAGE_CUSTOMISATION_SPEED: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
