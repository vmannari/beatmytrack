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
	var page: GaragePage = root.find_child("GaragePage",true,false)
	while page != null and (page._workbench_focus_pending or (page.showroom != null and page.showroom.get("preparing")==true)): await process_frame
	for frame: int in range(6): await process_frame
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
func _run() -> void:
	OS.set_environment("BMT_API_URL","")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CompactKits.ASSET_ROOT.path_join("manifest.json")))
	var counts_match: bool = manifest.category_counts.size()==4
	for category: String in VehicleCustomisation.CATEGORIES:
		if manifest.category_counts.get(category,-1)!=(13 if category=="aero" else 10): counts_match = false
	check(manifest.version==3 and counts_match and manifest.meshes.size()<1400,"bounded expanded authored mesh catalog")
	for key: String in manifest.meshes:
		var resource: ArrayMesh = load(CompactKits.ASSET_ROOT.path_join("meshes/"+str(manifest.meshes[key].file)))
		check(resource!=null and digest(var_to_bytes(resource.surface_get_arrays(0)))==manifest.meshes[key].surface_sha256,"prepared arrays exact "+key)
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
	var camera: Transform3D = page._customisation_camera._home
	page._set_customise_tab("colours")
	var picker: ColorPickerButton = page.pickers.body
	for pass_index: int in range(4):
		for tab: String in ["stickers","livery","colours"]:
			page._set_customise_tab(tab)
			check(page.livery_menu==menu and menu.pattern_scroll==patterns,"same native workbench/gallery retained")
			check(page.showroom.car==car and page._customisation_camera._home==camera,"menu switch retains actual car and return-camera while editing focus changes")
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
	page.open_car(VehicleCatalog.IDS.find("kart"))
	page._set_customise_tab("stickers")
	check(page.livery_menu!=menu and page.livery_menu.find_child("StickerRoof",true,false)==null,"car switch invalidates physical-panel tools")
	page.open_car(0)
	page._show_section("tuning")
	for category: String in VehicleCustomisation.CATEGORIES:
		page._select_kit_category(category)
		check(page.kit_cards.get_child_count()==VehicleCustomisation.options(category,page.vehicle_id).size(),"actual Parts list contains every "+category+" choice")
		for card: Control in page.kit_cards.get_children():
			check(card.get_script()==preload("res://ui/garage_part_option.gd") and card.find_children("*","SubViewport",true,false).is_empty(),"actual option is a row without an extra car/world")
	page._select_kit_category("hood")
	page._select_kit("hood","louvres")
	var installed: CarVisual = page.showroom.car
	page.showroom.apply_customisation(page.kit_draft)
	check(page.showroom.car==installed,"unchanged fitted selection avoids rebuilding car")
	app.queue_free()
	await process_frame
	print("GARAGE_CUSTOMISATION_SPEED: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
