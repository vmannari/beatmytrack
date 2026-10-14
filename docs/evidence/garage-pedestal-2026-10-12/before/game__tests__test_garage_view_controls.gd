extends SceneTree
## Dispatch through the real menu: orbit, pinch transitions, bounds and buttons.
var checks: int = 0
var failures: int = 0
var output: String = "res://../docs/evidence/garage-view-controls-2026-10-10"

func _initialize() -> void: _run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: " + label)

func settle() -> void:
	for i: int in range(8): await process_frame
	await RenderingServer.frame_post_draw

func touch(index: int, point: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	event.canceled = canceled
	root.push_input(event, true)

func drag(index: int, point: Vector2, movement: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	event.relative = movement
	root.push_input(event, true)

func screenshot(label: String) -> void:
	await settle()
	check(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK, "capture " + label)

func _run() -> void:
	OS.set_environment("BMT_API_URL", "")
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	var directory: String = "user://garage_view_" + TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var app: Node = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.library = TrackLibrary.new(directory)
	app.cloud_root_override = directory.path_join("cloud")
	root.size = Vector2i(1280,720)
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app._show_screen("garage")
	await create_timer(0.45).timeout
	await settle()
	var view: CarShowroom = app.root_ui.find_child("GarageShowroom",true,false)
	var center: Vector2 = view.get_global_rect().get_center()
	var old_yaw: float = view.yaw
	var old_elevation: float = view.elevation
	touch(0, center, true)
	drag(0, center + Vector2(40,30), Vector2(40,30))
	touch(0, center + Vector2(40,30), false)
	check(view.yaw != old_yaw and view.elevation > old_elevation and app.screen == "garage", "touch changes both angles without navigating")
	check(view.touches.is_empty(), "orbit release clears fingers")
	view.reset_view()
	var mouse_press := InputEventMouseButton.new()
	mouse_press.position = center
	mouse_press.button_index = MOUSE_BUTTON_LEFT
	mouse_press.pressed = true
	root.push_input(mouse_press,true)
	var mouse := InputEventMouseMotion.new()
	mouse.position = center
	mouse.relative = Vector2(-30,-10)
	mouse.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(mouse, true)
	mouse_press = mouse_press.duplicate() as InputEventMouseButton
	mouse_press.pressed = false
	root.push_input(mouse_press,true)
	check(view.yaw > old_yaw and view.elevation < old_elevation, "mouse changes both angles")
	view.reset_view()
	var wheel := InputEventMouseButton.new()
	wheel.position = center
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	root.push_input(wheel, true)
	check(view.zoom < 1.0, "wheel zooms in")
	wheel = wheel.duplicate() as InputEventMouseButton
	wheel.pressed = false
	root.push_input(wheel,true)
	wheel = wheel.duplicate() as InputEventMouseButton
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	root.push_input(wheel, true)
	check(is_equal_approx(view.zoom,1.0), "wheel zooms out")
	wheel = wheel.duplicate() as InputEventMouseButton
	wheel.pressed = false
	root.push_input(wheel,true)
	var trackpad := InputEventMagnifyGesture.new()
	trackpad.position = center
	trackpad.factor = 1.25
	view.gui_input.emit(trackpad)
	check(is_equal_approx(view.zoom,0.8), "trackpad magnification")
	view.reset_view()
	var left: Vector2 = center - Vector2(60,0)
	var right: Vector2 = center + Vector2(60,0)
	touch(0, left, true)
	touch(1, right, true)
	check(view.touches.size() == 2, "real menu delivers both pinch fingers")
	drag(1, right + Vector2(40,0), Vector2(40,0))
	check(is_equal_approx(view.zoom,0.75) and view.yaw == old_yaw and view.elevation == old_elevation, "pinch spreads to zoom without orbiting")
	drag(1, right, Vector2(-40,0))
	check(is_equal_approx(view.zoom,1.0), "pinch closes to zoom out")
	# Emulated mouse movement during touch must not duplicate camera motion.
	mouse.device = InputEvent.DEVICE_ID_EMULATION
	view.gui_input.emit(mouse)
	check(view.yaw == old_yaw and view.elevation == old_elevation, "touch ignores emulated mouse motion")
	touch(1, right, false)
	drag(0, left + Vector2(20,0), Vector2(20,0))
	check(view.yaw == old_yaw, "pinch release cannot jump into rotation")
	drag(0, left + Vector2(40,0), Vector2(20,0))
	check(view.yaw != old_yaw, "remaining finger resumes rotation")
	touch(0, left + Vector2(40,0), false)
	check(view.pointer == -1 and view.touches.is_empty(), "pinch clears every pointer")
	view.reset_view()
	touch(0,left,true)
	touch(1,right,true)
	touch(1,right,false,true)
	check(view.touches.is_empty() and view.pointer == -1, "canceled pinch clears all gesture state")
	var stable_zoom: float = view.zoom
	drag(0,left+Vector2(100,0),Vector2(100,0))
	check(view.zoom == stable_zoom and view.yaw == old_yaw, "late drag after cancellation is ignored")
	touch(0,left,false)
	for name: String in ["GarageZoomIn","GarageZoomOut","GarageResetView"]:
		var button: Button = app.root_ui.find_child(name,true,false)
		if name == "GarageResetView":
			view.rotate_view(Vector2(40,30))
			view.set_zoom(0.6)
		check(button.custom_minimum_size.x >= 48 and button.custom_minimum_size.y >= 48, name + " touch size")
		check(app.root_ui.get_node("MenuPageSwipe")._owns_gesture(app.root_ui,button.get_global_rect().get_center()), name + " gesture ownership")
		var click := InputEventMouseButton.new()
		click.position = button.get_global_rect().get_center()
		click.global_position = click.position
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		var hover := InputEventMouseMotion.new()
		hover.position = click.position
		hover.global_position = click.position
		root.push_input(hover,true)
		await process_frame
		root.push_input(click,true)
		await process_frame
		click = click.duplicate() as InputEventMouseButton
		click.pressed = false
		root.push_input(click,true)
		await process_frame
		if name == "GarageZoomIn": check(view.zoom < 1.0,"actual zoom-in button")
		elif name == "GarageZoomOut": check(is_equal_approx(view.zoom,1.0),"actual zoom-out button")
		else: check(view.yaw == old_yaw and view.elevation == old_elevation and view.zoom == 1.0,"actual reset button")
	var zoom_button: Control = app.root_ui.find_child("GarageZoomIn",true,false)
	touch(0,zoom_button.get_global_rect().get_center(),true)
	touch(0,zoom_button.get_global_rect().get_center(),false)
	check(view.zoom < 1.0 and app.screen == "garage","touch zoom button without menu navigation")
	view.reset_view()
	touch(0,left,true)
	view.hide()
	check(view.touches.is_empty() and view.pointer == -1,"hidden preview clears held gesture")
	view.show()
	touch(0,left,false)
	check(view.zoom == 1.0 and view.yaw == old_yaw,"showing preview retains view without stale pointer")
	for id: String in VehicleCatalog.IDS:
		VehicleCatalog.selected = id
		app._show_screen("garage")
		await create_timer(0.4).timeout
		view = app.root_ui.find_child("GarageShowroom",true,false)
		view.rotate_view(Vector2(100000,100000))
		view.set_zoom(-100)
		check(is_equal_approx(view.elevation,CarShowroom.MAX_ELEVATION) and is_equal_approx(view.zoom,CarShowroom.MIN_ZOOM),id + " upper angle and near zoom bounded")
		check(is_finite(view.camera.position.x) and view.camera.position.y > 0,id + " finite camera above floor")
		view.rotate_view(Vector2(-100000,-100000))
		view.set_zoom(100)
		check(is_equal_approx(view.elevation,CarShowroom.MIN_ELEVATION) and is_equal_approx(view.zoom,CarShowroom.MAX_ZOOM),id + " lower angle and far zoom bounded")
		view.reset_view()
		check(view.yaw == old_yaw and view.elevation == old_elevation and view.zoom == 1.0,id + " factory view restored")
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720)]:
		root.size = dimensions
		VehicleCatalog.selected = "compact"
		app._show_screen("garage")
		await create_timer(0.4).timeout
		view = app.root_ui.find_child("GarageShowroom",true,false)
		await screenshot("default-" + str(dimensions.x))
		view.rotate_view(Vector2(90,60))
		view.set_zoom(0.65)
		await screenshot("high-close-" + str(dimensions.x))
		view.reset_view()
		view.rotate_view(Vector2(-80,-20))
		view.set_zoom(1.4)
		await screenshot("low-wide-" + str(dimensions.x))
		for name: String in ["GarageZoomIn","GarageZoomOut","GarageResetView"]:
			check(app.root_ui.get_global_rect().encloses(app.root_ui.find_child(name,true,false).get_global_rect()),name + " within " + str(dimensions))
	app.queue_free()
	await process_frame
	print("GARAGE_VIEW_CONTROLS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
