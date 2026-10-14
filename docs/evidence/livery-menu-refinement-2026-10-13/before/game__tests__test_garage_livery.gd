extends SceneTree
## Real model/material, persistence, input ownership and graphical layout checks.
var failures: int = 0
var checks: int = 0
var output: String = "res://../docs/evidence/garage-livery-2026-10-10"

func _initialize() -> void: _run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + label)

func settle() -> void:
	for i: int in range(8): await process_frame
	await RenderingServer.frame_post_draw

func _run() -> void:
	OS.set_environment("BMT_API_URL", "")
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	var directory: String = "user://garage_test_" + TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var app: Node = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.library = TrackLibrary.new(directory)
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	await settle()
	var base_key: String = app.records.key_for(app.selected_track, VehicleCatalog.config("compact"))
	for id: String in VehicleCatalog.IDS:
		VehicleCatalog.selected = id
		app.call("_show_screen", "garage")
		await settle()
		var page: GaragePage = app.root_ui.find_child("GaragePage", true, false)
		page.open_car(VehicleCatalog.IDS.find(id))
		page._show_section("customise")
		await settle()
		var car: CarVisual = page.showroom.car
		check(car.vehicle_id == id and car.front_wheels.size() == 2, id + " actual model")
		check(car.paint_materials.size() == 2, id + " cosmetic slots")
		var brake_color: Color = car.brake_material.albedo_color
		page.pickers.body.color = Color("9a3e50")
		page.pickers.body.color_changed.emit(Color("9a3e50"))
		page.pickers.accent.color = Color("e4b74c")
		page.pickers.accent.color_changed.emit(Color("e4b74c"))
		check(car.paint_materials.body.albedo_color.to_html(false) == "9a3e50", id + " live body")
		check(car.paint_materials.accent.albedo_color.to_html(false) == "e4b74c", id + " live accent")
		check(car.brake_material.albedo_color == brake_color, id + " lamps unchanged")
		page.pickers.body.popup_closed.emit()
		var reopened := LocalRecords.new(app.records.path)
		reopened.load_records()
		check(VehicleLivery.for_car(reopened.settings, id).colors.body == "9a3e50", id + " atomic reload")
		check(reopened.settings.vehicle_liveries.size() == VehicleCatalog.IDS.find(id) + 1, id + " independent saved car")
		var fresh := CarVisual.new()
		fresh.vehicle_id = id
		fresh.livery = VehicleLivery.for_car(reopened.settings, id)
		root.add_child(fresh)
		check(fresh.paint_materials.body.albedo_color.to_html(false) == "9a3e50", id + " rebuilt race model color")
		fresh.queue_free()
		var swipe: Node = app.root_ui.get_node("MenuPageSwipe")
		check(swipe.call("_owns_gesture", app.root_ui, page.showroom.get_global_rect().get_center()), id + " rotate owns gesture")
		var motion := InputEventMouseMotion.new()
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		motion.relative = Vector2(40, 0)
		var old_yaw: float = page.showroom.yaw
		page.showroom.gui_input.emit(motion)
		check(page.showroom.yaw != old_yaw, id + " mouse orbit")
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = page.showroom.size * 0.5
		touch.pressed = true
		page.showroom.gui_input.emit(touch)
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.relative = Vector2(-40,0)
		page.showroom.gui_input.emit(drag)
		touch.pressed = false
		page.showroom.gui_input.emit(touch)
		check(is_equal_approx(page.showroom.yaw, old_yaw) and page.showroom.pointer == -1, id + " touch orbit")
		var press := InputEventScreenTouch.new()
		press.index = 0
		press.position = page.showroom.get_global_rect().get_center()
		press.pressed = true
		root.push_input(press, true)
		await process_frame
		var screen_drag := InputEventScreenDrag.new()
		screen_drag.index = 0
		screen_drag.position = press.position + Vector2(40,0)
		screen_drag.relative = Vector2(40,0)
		root.push_input(screen_drag, true)
		await process_frame
		press = press.duplicate() as InputEventScreenTouch
		press.pressed = false
		press.position = screen_drag.position
		root.push_input(press, true)
		check(page.showroom.yaw != old_yaw and app.screen == "garage", id + " real touch rotates without navigation")
		page.showroom.yaw = old_yaw
		page.showroom._orbit()
		for dimensions: Vector2i in [Vector2i(1280,720), Vector2i(960,540), Vector2i(1600,720)]:
			root.size = dimensions
			await settle()
			check(page.showroom.size.x > 250 and page.showroom.size.y > 200, id + " preview dimensions " + str(dimensions))
			check(app.root_ui.get_global_rect().encloses(page.pickers.body.get_global_rect()), id + " paint within screen")
			check(root.get_texture().get_image().save_png(output.path_join(id + "-" + str(dimensions.x) + ".png")) == OK, id + " screenshot")
	check(app.records.key_for(app.selected_track, VehicleCatalog.config("compact")) == base_key, "paint retains PB key")
	var invalid: Dictionary = VehicleLivery.defaults("compact")
	invalid.colors.body = "nan"
	check(not VehicleLivery.valid(invalid), "reject malformed color")
	check(not VehicleLivery.valid_collection({"unknown":VehicleLivery.defaults("compact")}), "reject unknown car")
	var page: GaragePage = app.root_ui.find_child("GaragePage", true, false)
	var picker: ColorPickerButton = page.pickers.body
	root.size = Vector2i(960,540)
	await settle()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = picker.get_global_rect().get_center()
	click.global_position = click.position
	click.pressed = true
	root.push_input(click, true)
	await process_frame
	click = click.duplicate() as InputEventMouseButton
	click.pressed = false
	root.push_input(click, true)
	await settle()
	check(picker.get_popup().visible, "opens actual color picker")
	check(picker.get_popup().size.x <= root.size.x and picker.get_popup().size.y <= root.size.y, "color popup fits")
	check(root.get_texture().get_image().save_png(output.path_join("color-picker.png")) == OK, "picker screenshot")
	picker.get_popup().hide()
	page._reset()
	check(VehicleLivery.for_car(app.records.settings,"kart") == VehicleLivery.defaults("kart"), "reset persists factory colors")
	check(VehicleLivery.for_car(app.records.settings,"compact").colors.body == "9a3e50", "reset leaves other cars")
	var saved_path: String = app.records.path
	app.records.path = directory.path_join("missing/records.json")
	page._preview_color(Color("ffffff"), "body")
	page._save()
	check(page.draft == VehicleLivery.defaults("kart"), "failed write restores committed paint")
	app.records.path = saved_path
	# Exercise the same construction path used when a player starts driving.
	var game: Node = load("res://core/game.tscn").instantiate()
	game.preference_records = app.records
	game.vehicle_id = "compact"
	root.add_child(game)
	check(game.car.paint_materials.body.albedo_color.to_html(false) == "9a3e50", "driving uses saved paint")
	game.queue_free()
	await process_frame
	app.queue_free()
	await process_frame
	print("Garage livery: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
