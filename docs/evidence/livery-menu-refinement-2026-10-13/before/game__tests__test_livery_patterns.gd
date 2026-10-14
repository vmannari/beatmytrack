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
	output = ProjectSettings.globalize_path("res://../docs/evidence/livery-stickers-2026-10-13/"+renderer)
	DirAccess.make_dir_recursive_absolute(output)
	check(LiveryCatalog.patterns.size() == 20,"twenty new original patterns")
	check(LiveryCatalog.stickers.size() == 12,"twelve original emblems")
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
		for index: int in range(20):
			var value: Dictionary = art_value(id,index)
			value.stickers.hood.id = LiveryCatalog.stickers[index%12].id
			value.stickers.roof.id = LiveryCatalog.stickers[(index+3)%12].id
			value.stickers.hood.rotation = 23.0
			car.apply_livery(value)
			wear.refresh_paint()
			check(VehicleLivery.valid(value),id+" bounded cosmetics "+str(index))
			var active: ShaderMaterial = car.graphics.bindings[0].node.get_active_material(car.graphics.bindings[0].index) as ShaderMaterial
			check(active != null and active.get_shader_parameter("pattern_enabled") and active.get_shader_parameter("hood_emblem") == index%12,id+" actual shader art "+str(index))
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
		saved.stickers.hood.id = "crest"
		saved.stickers.hood.x = 0.37
		saved.stickers.hood.rotation = -19.0
		saved.stickers.roof.id = "compass"
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
	var key: String = records.key_for(app.selected_track,VehicleCatalog.config("compact"))
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1600,720)]:
		root.size = dimensions
		await settle()
		check(app.root_ui.get_global_rect().encloses(page.tools_panel.get_global_rect()),"livery tools fit "+str(dimensions))
		check(app.root_ui.get_global_rect().encloses(page.actions.get_global_rect()),"livery actions fit "+str(dimensions))
		await capture("livery-ui-"+str(dimensions.x))
	root.size = Vector2i(1280,720)
	page.showroom.elevation = 0.63
	page.showroom.zoom = 0.72
	page.showroom.yaw = -0.62
	page.showroom._orbit()
	var contact: Image = Image.create(1600,1280,false,Image.FORMAT_RGB8)
	for index: int in range(20):
		page._select_livery(GaragePage.LIVERY_NAMES.size()+index)
		await settle()
		var image: Image = page.showroom.showroom_viewport.get_texture().get_image()
		check(image.save_png(output.path_join(LiveryCatalog.patterns[index].id+".png")) == OK,"actual car pattern capture "+str(index))
		var crop_width: int = roundi(image.get_height()*400.0/256.0)
		image = image.get_region(Rect2i((image.get_width()-crop_width)/2,0,crop_width,image.get_height()))
		image.resize(400,256)
		image.convert(Image.FORMAT_RGB8)
		contact.blit_rect(image,Rect2i(0,0,400,256),Vector2i(index%4*400,index/4*256))
	check(contact.save_png(output.path_join("twenty-patterns.png")) == OK,"twenty-car contact sheet")
	page._set_customise_tab("stickers")
	await settle()
	page._choose_sticker(1)
	page._move_sticker(Vector2(0.42,0.54))
	page._sticker_property(0.76,"size")
	page._sticker_property(-12,"rotation")
	page._save()
	page._choose_sticker_surface("roof")
	await settle()
	page._choose_sticker(3)
	page._sticker_property(0.74,"size")
	page._save()
	var board: StickerPlacement = page._sticker_board
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
	page._sticker_choice.show_popup()
	await capture("sticker-choices")
	page._sticker_choice.get_popup().hide()
	for id: String in VehicleCatalog.IDS:
		page.open_car(VehicleCatalog.IDS.find(id))
		page.showroom.finish_car_transition()
		page._set_customise_tab("stickers")
		await settle()
		check((page.tools.find_child("StickerRoof",true,false) != null) == LiveryCatalog.has_roof(id),id+" roof only when physically present")
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
