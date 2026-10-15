extends SceneTree
## Catalogue, actual opaque surfaces, local migration, dirt/wash and native UI.
var failures: int = 0
var checks: int = 0
var output: String
var renderer: String

func _initialize() -> void: _run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func settle() -> void:
	for tick: int in range(10): await process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw

func art_value(id: String, index: int) -> Dictionary:
	var value: Dictionary = VehicleLivery.defaults(id)
	var pattern: Dictionary = LiveryCatalog.patterns[index]
	value.pattern = pattern.id
	for slot: int in range(3): value.colors[VehicleLivery.SLOTS[slot]] = pattern.colours[slot]
	return value

func capture(file: String) -> Image:
	await settle()
	var pixels: Image = root.get_texture().get_image()
	check(pixels.save_png(output.path_join(file+".png")) == OK,"capture "+file)
	return pixels

func _run() -> void:
	OS.set_environment("BMT_API_URL", "")
	renderer = RenderingServer.get_current_rendering_method()
	output = ProjectSettings.globalize_path("res://../docs/evidence/livery-expansion-2026-10-14/"+renderer)
	DirAccess.make_dir_recursive_absolute(output)
	check(GaragePage.LIVERY_NAMES == ["Midnight"],"Midnight is the sole plain-paint preset")
	check(LiveryCatalog.patterns.size() == 32,"thirty-two original patterns")
	check(LiveryCatalog.stickers.size() == 24,"twelve emblems plus twelve fictional sponsors")
	check(LiveryCatalog.stickers.filter(func(item: Dictionary) -> bool: return item.category == "sponsors").size() == 12,"dedicated fictional sponsor collection")
	var atlas: Texture2D = LiveryCatalog.texture("stickers")
	check(atlas.get_size() == Vector2(1024,1536) and atlas.get_image().has_mipmaps(),"expanded filtered atlas has six rows")
	check(LiveryCatalog.sticker_index("crest") == 0 and LiveryCatalog.sticker_index("sun") == 11 and LiveryCatalog.sticker_index("rhexori") == 23,"old decal indices retained and final sponsor addressable")
	var hashes: Dictionary = {}
	for item: Dictionary in LiveryCatalog.patterns:
		var image: Image = LiveryCatalog.texture(item.id).get_image()
		var hash_value: String = image.get_data().hex_encode().sha256_text()
		check(not hashes.has(hash_value),"distinct artwork "+item.id)
		hashes[hash_value] = true
		check(image.has_mipmaps(),"filtered artwork "+item.id)
	var legacy: Dictionary = {"version":1,"colors":{"body":"9a3e50","accent":"e4b74c"}}
	check(VehicleLivery.valid(legacy),"legacy save accepted")
	var migrated: Dictionary = VehicleLivery.for_car({"vehicle_liveries":{"compact":legacy}},"compact")
	check(migrated.version == 2 and migrated.colors.body == "9a3e50" and migrated.colors.accent == "e4b74c" and migrated.pattern == "plain","legacy pigments retained")
	for field: String in ["id","x","size","rotation"]:
		var malformed: Dictionary = VehicleLivery.defaults("compact")
		malformed.stickers.hood[field] = {"id":"unknown","x":NAN,"size":5.0,"rotation":INF}[field]
		check(not VehicleLivery.valid(malformed),"reject sticker "+field)
	var bad: Dictionary = VehicleLivery.defaults("compact")
	bad.pattern = "../unknown"
	check(not VehicleLivery.valid(bad),"allowlisted patterns only")
	var records_path: String = ProjectSettings.globalize_path("res://../build/livery-test-"+TrackLibrary.unique_id()+"/records.json")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(records_path.get_base_dir()))
	var records := LocalRecords.new(records_path)
	var expected: Dictionary = {}
	for id: String in VehicleCatalog.IDS:
		var car := CarVisual.new()
		car.vehicle_id = id
		car.simple_model = true
		car.livery = VehicleLivery.defaults(id)
		root.add_child(car)
		var surfaces: int = car.body.find_children("*","MeshInstance3D",true,false).size()
		check(not car.graphics.bindings.is_empty(),id+" existing painted surfaces")
		var wear := VehicleWeathering.new()
		wear.configure(car,"pine",VehicleCatalog.config(id))
		for index: int in range(LiveryCatalog.patterns.size()):
			var value: Dictionary = art_value(id,index)
			var emblem_index: int = index%LiveryCatalog.stickers.size()
			value.stickers.hood.id = LiveryCatalog.stickers[emblem_index].id
			value.stickers.roof.id = LiveryCatalog.stickers[(index+3)%LiveryCatalog.stickers.size()].id
			value.stickers.hood.rotation = 23.0
			car.apply_livery(value)
			wear.refresh_paint()
			check(VehicleLivery.valid(value),id+" bounded cosmetics "+str(index))
			var active: ShaderMaterial = car.graphics.bindings[0].node.get_active_material(car.graphics.bindings[0].index) as ShaderMaterial
			check(active != null and active.get_shader_parameter("pattern_enabled") and active.get_shader_parameter("hood_emblem") == emblem_index and active.get_shader_parameter("sticker_atlas_size") == atlas.get_size(),id+" actual shader art "+str(index))
		check(car.body.find_children("*","MeshInstance3D",true,false).size() == surfaces,id+" no added geometry")
		wear.dirt_amount = 0.85
		wear.slow_dirt_amount = 0.2
		wear._update_finish()
		car.apply_livery(art_value(id,3))
		wear.refresh_paint()
		check(wear.installed and wear.materials.any(func(material: ShaderMaterial) -> bool: return material.get_shader_parameter("graphics_enabled") == true and material.get_shader_parameter("livery_mask") == LiveryCatalog.texture("rally_blocks")),id+" changed art below dirt")
		wear.reset()
		var restored: Material = car.graphics.bindings[0].node.get_active_material(car.graphics.bindings[0].index)
		check(restored == car.graphics.bindings[0].finish,id+" washing restores current art")
		var plain: Dictionary = VehicleLivery.defaults(id)
		car.apply_livery(plain)
		check(car.graphics.bindings[0].node.get_active_material(car.graphics.bindings[0].index) is StandardMaterial3D,id+" factory fast path restored")
		var saved: Dictionary = art_value(id,VehicleCatalog.IDS.find(id)*3)
		saved.stickers.hood.id = "zelvora"
		saved.stickers.hood.x = 0.37
		saved.stickers.hood.rotation = -19.0
		saved.stickers.roof.id = "rhexori"
		expected[id] = saved
		car.queue_free()
		await process_frame
	records.settings.vehicle_liveries = expected
	check(records.save_records() == OK,"atomic local graphic save")
	var loaded := LocalRecords.new(records_path)
	loaded.load_records()
	check(loaded.settings.get("vehicle_liveries",{}).size() == 5,"local graphic reload")
	for id: String in VehicleCatalog.IDS:
		check(VehicleLivery.for_car(loaded.settings,id) == expected[id],id+" independent graphic/placement reload")
	if DisplayServer.get_name() != "headless": await _graphical(loaded)
	print("Livery patterns: %d checks, %d failures (%s)" % [checks,failures,renderer])
	quit(1 if failures else 0)

func _graphical(records: LocalRecords) -> void:
	root.size = Vector2i(1280,720)
	var app: Node = load("res://core/app.tscn").instantiate()
	app.records = records
	app.library = TrackLibrary.new(records.path.get_base_dir())
	app.cloud_root_override = records.path.get_base_dir().path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	VehicleCatalog.selected = "compact"
	app.call("_show_screen","garage")
	await settle()
	var page: GaragePage = app.root_ui.find_child("GaragePage",true,false)
	page.open_car(0)
	page._show_section("customise")
	await settle()
	check(page.livery_menu.pattern_tiles.size() == 33,"Midnight plus thirty-two named car-preview choices")
	check(page.livery_menu.find_child("Pattern_original",true,false) == null and page.livery_menu.find_child("Pattern_rally",true,false) == null and page.livery_menu.find_child("Pattern_sandstone",true,false) == null and page.livery_menu.pattern_tiles[0].name == "Pattern_midnight","only Midnight remains in plain-paint browser")
	page.draft.stickers = VehicleLivery.defaults("compact").stickers
	page._select_livery(0)
	check(page.draft.pattern == "plain" and page.draft.colors.body == "273b50" and page.draft.colors.accent == "ced7dc","first card applies Midnight pigments")
	check(page.showroom.size.x > page.tools_panel.size.x,"car keeps majority of customiser width")
	var retained_view: CarShowroom = page.showroom
	var retained_car: CarVisual = page.showroom.car
	var retained_camera: Transform3D = page.showroom.camera.transform
	var retained_zoom: float = page.showroom.zoom
	var retained_elevation: float = page.showroom.elevation
	var retained_yaw: float = page.showroom.yaw
	var key: String = records.key_for(app.selected_track,VehicleCatalog.config("compact"))
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1600,720)]:
		root.size = dimensions
		await settle()
		check(app.root_ui.get_global_rect().encloses(page.tools_panel.get_global_rect()),"livery tools fit "+str(dimensions))
		check(app.root_ui.get_global_rect().encloses(page.actions.get_global_rect()),"livery actions fit "+str(dimensions))
		await capture("livery-ui-"+str(dimensions.x))
	page._set_customise_tab("colours")
	await settle()
	check(page.showroom == retained_view and page.showroom.car == retained_car and page.showroom.camera.transform.is_equal_approx(retained_camera) and page.showroom.zoom == retained_zoom,"changing tools retains car, viewport, camera and zoom")
	page.livery_menu._select_slot("accent")
	var unchanged_body: String = page.draft.colors.body
	page.livery_menu.colour_chips[9].pressed.emit()
	check(page.draft.colors.accent == GarageLiveryMenu.PALETTE[9] and page.draft.colors.body == unchanged_body,"palette edits only selected paint role")
	check(VehicleLivery.for_car(records.settings,"compact").colors.accent == GarageLiveryMenu.PALETTE[9],"palette selection commits locally")
	page.livery_menu._select_slot("body")
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1600,720)]:
		root.size = dimensions
		await settle()
		check(app.root_ui.get_global_rect().encloses(page.tools_panel.get_global_rect()),"colour tools fit "+str(dimensions))
		await capture("colours-ui-"+str(dimensions.x))
	page._set_customise_tab("livery")
	await settle()
	var tile: LiveryTile = page.livery_menu.pattern_tiles[GaragePage.LIVERY_NAMES.size()]
	page.livery_menu.pattern_scroll.ensure_control_visible(tile)
	await settle()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = tile.get_global_rect().get_center()
	press.global_position = press.position
	root.push_input(press,true)
	await process_frame
	press = press.duplicate()
	press.pressed = false
	root.push_input(press,true)
	await settle()
	check(page.draft.pattern == "apex_twin" and tile.selected,"actual model card click previews and selects pattern")
	check(VehicleLivery.for_car(records.settings,"compact").pattern == "apex_twin","card click commits selected design")
	page.find_child("GarageTopView",true,false).pressed.emit()
	await settle()
	check(page.showroom.elevation == 0.93 and page.showroom.zoom == retained_zoom and page.showroom.yaw == retained_yaw,"Top view inspects painted panels without resetting zoom or turntable")
	await capture("top-view")
	page.showroom.elevation = retained_elevation
	page.showroom._orbit()
	root.size = Vector2i(1280,720)
	page.showroom.elevation = 0.63
	page.showroom.zoom = 0.72
	page.showroom.yaw = -0.62
	page.showroom._orbit()
	var contact: Image = Image.create(1600,ceili(LiveryCatalog.patterns.size()/4.0)*256,false,Image.FORMAT_RGB8)
	for index: int in range(LiveryCatalog.patterns.size()):
		page._select_livery(GaragePage.LIVERY_NAMES.size()+index)
		await settle()
		var image: Image = page.showroom.showroom_viewport.get_texture().get_image()
		check(image.save_png(output.path_join(LiveryCatalog.patterns[index].id+".png")) == OK,"actual car pattern capture "+str(index))
		var crop_width: int = mini(image.get_width(),roundi(image.get_height()*400.0/256.0))
		var crop_height: int = roundi(crop_width*256.0/400.0)
		image = image.get_region(Rect2i((image.get_width()-crop_width)/2,(image.get_height()-crop_height)/2,crop_width,crop_height))
		image.resize(400,256)
		image.convert(Image.FORMAT_RGB8)
		contact.blit_rect(image,Rect2i(0,0,400,256),Vector2i(index%4*400,index/4*256))
	check(contact.save_png(output.path_join("all-patterns.png")) == OK,"all native-car pattern contact sheet")
	page._set_customise_tab("stickers")
	await settle()
	page._choose_sticker(1)
	check(page.livery_menu.active_control("PlaceSticker").get_global_rect().size.y <= 64,"sticker actions keep compact native icon sizing")
	page._edit_sticker_position(true)
	await settle()
	page._move_sticker(Vector2(0.42,0.54))
	page._sticker_property(0.76,"size")
	page._sticker_property(-12,"rotation")
	page._save()
	page._choose_sticker_surface("roof")
	await settle()
	page._choose_sticker(3)
	page._edit_sticker_position(true)
	await settle()
	page._sticker_property(0.74,"size")
	page._save()
	var board: StickerPlacement = page._sticker_board
	check(not page.showroom.get_global_rect().intersects(board.get_global_rect()),"sticker controls keep the actual car unobstructed")
	var swipe: Node = app.root_ui.get_node("MenuPageSwipe")
	check(swipe.call("_owns_gesture",app.root_ui,board.get_global_rect().get_center()),"sticker drag owns menu gesture")
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = board.get_global_rect().get_center()
	touch.pressed = true
	root.push_input(touch,true)
	await process_frame
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.relative = Vector2(12,5)
	drag.position = touch.position+drag.relative
	root.push_input(drag,true)
	await process_frame
	touch = touch.duplicate()
	touch.pressed = false
	touch.position = drag.position
	root.push_input(touch,true)
	await settle()
	check(app.screen == "garage" and page.draft.stickers.roof.x > 0.5,"actual touch moves sticker without navigation")
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1600,720)]:
		root.size = dimensions
		await settle()
		check(app.root_ui.get_global_rect().encloses(page.tools_panel.get_global_rect()),"sticker tools fit "+str(dimensions))
		await capture("stickers-ui-"+str(dimensions.x))
	check(records.key_for(app.selected_track,VehicleCatalog.config("compact")) == key,"cosmetics preserve PB identity")
	root.size = Vector2i(1280,720)
	page._edit_sticker_position(false)
	await settle()
	check(page.livery_menu.sticker_tiles.size() == 12,"all twelve named stickers directly browsable")
	page._choose_sticker_surface("hood")
	await settle()
	check(page.livery_menu.sticker_tiles.crest.selected,"cached hood gallery restores its own selected emblem")
	page._choose_sticker_surface("roof")
	await settle()
	check(page.livery_menu.sticker_tiles.compass.selected,"cached roof gallery restores its own selected emblem")
	await capture("sticker-choices")
	page._choose_sticker(0)
	check(page.draft.stickers.roof.id == "none" and page.draft.stickers.hood.id == "crest","removal leaves other panel untouched")
	check(page.livery_menu.active_control("PlaceSticker").disabled,"placement is unavailable after sticker removal")
	# Native category buttons, live-car render and independent sponsor persistence.
	page.livery_menu.active_control("StickerCategory_sponsors").pressed.emit()
	await settle()
	check(page.livery_menu.sticker_tiles.size() == 12 and page.livery_menu.sticker_tiles.has("zelvora") and not page.livery_menu.sticker_tiles.has("crest"),"Sponsors shows only the twelve invented brands")
	var sponsor_menu: Control = page.livery_menu._content
	page.livery_menu.sticker_tiles.rhexori.pressed.emit()
	check(page.draft.stickers.roof.id == "rhexori" and page.draft.stickers.hood.id == "crest","native sponsor card changes only selected panel")
	check(page.draft.stickers.roof.rotation == 180.0,"new sponsor wordmark faces the front of the car")
	page._choose_sticker_surface("hood")
	await settle()
	page.livery_menu.sticker_tiles.zelvora.pressed.emit()
	page._sticker_property(0.9,"size")
	check(page.draft.stickers.hood.rotation == -12.0,"replacing an existing emblem retains custom rotation")
	page._sticker_property(180,"rotation")
	page._save()
	page._choose_sticker_surface("roof")
	await settle()
	check(page.livery_menu._content == sponsor_menu and page.livery_menu.sticker_tiles.rhexori.selected,"cached sponsor gallery returns to its own panel and selection")
	check(page.livery_menu._contents.size() == 6,"two paint tools and four panel/category galleries stay bounded")
	check(VehicleLivery.for_car(records.settings,"compact").stickers.hood.id == "zelvora" and VehicleLivery.for_car(records.settings,"compact").stickers.roof.id == "rhexori","both sponsor panels save locally")
	check(page.showroom == retained_view and page.showroom.car == retained_car,"sponsor browsing retains actual car and viewport")
	page._select_livery(GaragePage.LIVERY_NAMES.size()+20)
	page.find_child("GarageTopView",true,false).pressed.emit()
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1600,720)]:
		root.size = dimensions
		await settle()
		check(app.root_ui.get_global_rect().encloses(page.tools_panel.get_global_rect()),"sponsor browser fits "+str(dimensions))
		await capture("sponsors-ui-"+str(dimensions.x))
	root.size = Vector2i(1280,720)
	page._choose_sticker_surface("hood")
	page._choose_sticker(0)
	page._choose_sticker_surface("roof")
	page._sticker_property(0.95,"size")
	page._sticker_property(180,"rotation")
	page._move_sticker(Vector2(0.5,0.5))
	var sponsor_contact: Image = Image.create(1600,768,false,Image.FORMAT_RGB8)
	for index: int in range(12,24):
		page._choose_sticker(index+1)
		await settle()
		var image: Image = page.showroom.showroom_viewport.get_texture().get_image()
		check(image.save_png(output.path_join("sponsor-"+LiveryCatalog.stickers[index].id+".png")) == OK,"actual sponsor capture "+str(index))
		image.resize(400,256)
		image.convert(Image.FORMAT_RGB8)
		sponsor_contact.blit_rect(image,Rect2i(0,0,400,256),Vector2i((index-12)%4*400,(index-12)/4*256))
	check(sponsor_contact.save_png(output.path_join("all-sponsors.png")) == OK,"all sponsor native-car contact sheet")
	page._choose_sticker_surface("hood")
	page._choose_sticker(LiveryCatalog.sticker_index("zelvora")+1)
	page._edit_sticker_position(true)
	await capture("sponsor-placement")
	page._edit_sticker_position(false)
	page.livery_menu.active_control("StickerCategory_emblems").pressed.emit()
	await settle()
	check(page.livery_menu.sticker_tiles.has("crest") and page.draft.stickers.hood.id == "zelvora","category switch retains placed sponsor")
	for id: String in VehicleCatalog.IDS:
		page.open_car(VehicleCatalog.IDS.find(id))
		page.showroom.finish_car_transition()
		page._set_customise_tab("stickers")
		await settle()
		check((page.livery_menu.active_control("StickerRoof") != null) == LiveryCatalog.has_roof(id),id+" roof only when physically present")
		page.showroom.elevation = 0.73
		page.showroom.zoom = 0.55
		page.showroom._orbit()
		await capture(id+"-stickers")
	app.queue_free()
	await process_frame
	# Same saved cosmetics through the ordinary driving construction/camera path.
	var game: Node = load("res://core/game.tscn").instantiate()
	game.preference_records = records
	game.vehicle_id = "compact"
	game.initial_track = NativeTrack.read("res://resources/tracks/starter_circuit.json")
	game.production_mode = true
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.countdown_label.hide()
	game.race_cues.hide()
	game.car.present(game.initial_track.spawn,0.0,VehicleState.new(),DriveFrame.new())
	game.camera.follow(game.initial_track.spawn,Vector2.ZERO,0.0,0.0,true)
	check(game.car.livery == VehicleLivery.for_car(records.settings,"compact"),"race uses saved pattern and panel stickers")
	await capture("gameplay")
	game.queue_free()
	await process_frame
