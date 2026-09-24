extends SceneTree
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func press(control: TouchControls, finger: int, point: Vector2, down: bool = true) -> void:
	var event := InputEventScreenTouch.new()
	event.index = finger; event.position = point; event.pressed = down
	control._input(event)
func drag(control: TouchControls, finger: int, point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = finger; event.position = point
	control._input(event)
func same_layout(a: Dictionary,b: Dictionary) -> bool:
	if a.steering_type != b.steering_type: return false
	for key: String in ControlLayout.KEYS:
		for field: String in ["x","y","scale","opacity"]:
			if not is_equal_approx(float(a[key][field]),float(b[key][field])): return false
	return true
func run() -> void:
	var control := TouchControls.new()
	control.driver = DriverInput.new()
	root.add_child(control)
	await process_frame
	for dimensions: Vector2 in [Vector2(1280,720),Vector2(1600,720),Vector2(960,540)]:
		control.size = dimensions
		control.safe_override = Rect2(Vector2(44,24),dimensions-Vector2(70,48))
		for mirrored: bool in [false,true]:
			for method: String in ControlLayout.METHODS:
				control.layout = ControlLayout.preset(mirrored)
				control.layout.steering_type = method
				for key: String in ControlLayout.KEYS: control.layout[key].scale = 1.6
				var rectangles: Dictionary = control.group_rects()
				for key: String in rectangles:
					check(control.usable_area().encloses(rectangles[key]),"safe bounds at every aspect/scale")
					for other: String in rectangles:
						if key != other: check(not rectangles[key].intersects(rectangles[other]),"controls remain independently reachable")
	control.size = Vector2(1280,720)
	control.safe_override = Rect2()
	control.layout = ControlLayout.preset()
	var zones: Array[Rect2] = control.zones()
	press(control,1,zones[0].get_center())
	press(control,2,zones[3].get_center())
	check(control.driver.sample().steer == -127 and control.driver.sample().throttle == 255,"steering and gas simultaneous")
	press(control,3,zones[2].get_center())
	check(control.driver.sample().brake == 255,"third finger brake simultaneous")
	press(control,2,Vector2.ZERO,false)
	check(control.driver.sample().throttle == 0 and control.driver.sample().brake == 255,"release independent")
	press(control,4,zones[2].get_center())
	press(control,3,Vector2.ZERO,false)
	check(control.driver.sample().brake == 255,"replacement finger retains brake")
	drag(control,4,Vector2(zones[2].get_center().x,control.touch_zones()[2].end.y+4))
	check(control.driver.sample().brake > 0 and control.driver.sample().brake < 255,"pedal analog excursion remains held")
	control.enabled = false
	check(control.driver.sample().brake == 0 and control.driver.sample().steer == 0,"disable releases all owned fingers")
	control.enabled = true
	for method: String in ["horizontal","joystick"]:
		control.layout = ControlLayout.preset()
		control.layout.steering_type = method
		var rect: Rect2 = control.group_rects()[method]
		press(control,1,rect.get_center())
		drag(control,1,rect.get_center()+Vector2(rect.size.x*0.2,0))
		check(control.driver.sample().steer > 40 and control.driver.sample().steer < 90,"analog half right")
		drag(control,1,Vector2(rect.position.x-100,rect.get_center().y))
		check(control.driver.sample().steer == -127,"captured analog saturates outside bounds")
		press(control,1,Vector2.ZERO,false)
		check(control.driver.sample().steer == 0,"analog releases immediately")
	# Keyboard/input-map analog values coexist with touch commands.
	Input.action_press(&"accelerate",0.4)
	check(control.driver.sample().throttle > 90 and control.driver.sample().throttle < 120,"input-map analog throttle preserved")
	press(control,2,control.zones()[3].get_center())
	check(control.driver.sample().throttle == 255,"touch combines with mapped sources")
	press(control,2,Vector2.ZERO,false)
	check(control.driver.sample().throttle > 90,"touch release does not cancel mapped source")
	Input.action_release(&"accelerate")
	var steer: Rect2 = control.group_rects()[control.layout.steering_type]
	press(control,7,steer.position+Vector2(4,steer.size.y/2))
	press(control,8,steer.end-Vector2(4,steer.size.y/2))
	press(control,7,Vector2.ZERO,false)
	check(control.driver.sample().steer == 127,"new analog finger owns steering after old finger releases")
	var cancel := InputEventScreenTouch.new()
	cancel.index = 8; cancel.canceled = true
	control._input(cancel)
	check(control.driver.sample().steer == 0,"canceled analog finger releases")
	press(control,8,steer.end-Vector2(4,steer.size.y/2))
	control._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(control.driver.sample().steer == 0 and control.owners.is_empty(),"focus loss clears ownership")
	var axis := InputEventJoypadMotion.new()
	axis.device = 0; axis.axis = JOY_AXIS_LEFT_X; axis.axis_value = 0.7
	Input.parse_input_event(axis)
	Input.flush_buffered_events()
	check(control.driver.sample().steer > 50 and control.driver.sample().steer < 127,"gamepad stick maps to analog steering")
	axis = axis.duplicate()
	axis.axis_value = 0.0
	Input.parse_input_event(axis)
	Input.flush_buffered_events()
	var path: String = "user://control-layout-test.json"
	var store := LocalRecords.new(path)
	store.settings.control_layout = control.layout.duplicate(true)
	check(store.save_records() == OK,"atomic save accepts control settings")
	var reloaded := LocalRecords.new(path)
	reloaded.load_records()
	check(same_layout(ControlLayout.from_settings(reloaded.settings),control.layout),"all fields survive new store instance")
	store.settings.control_layout.brake.opacity = -1
	check(store.save_records() == ERR_INVALID_DATA,"invalid setting cannot overwrite saved layout")
	control.queue_free()
	await process_frame
	var probe: Node = load("res://diagnostics/mobile_control_probe.gd").new()
	probe.set("report_path",path+".probe")
	root.add_child(probe)
	var report: Dictionary = await probe.finished
	check(report.failures.is_empty() and int(report.checks) == 72,"device probe dispatches 72 checks through viewport input")
	await process_frame
	DirAccess.remove_absolute(path+".probe")
	var editor := ControlLayoutEditor.new()
	editor.records = reloaded
	root.add_child(editor)
	await process_frame
	await process_frame
	check(editor.touch.layout == ControlLayout.from_settings(reloaded.settings),"editor uses saved race geometry")
	var before: Rect2 = editor.touch.group_rects().brake
	var event := InputEventScreenTouch.new()
	event.index = 8; event.position = before.get_center(); event.pressed = true
	editor._input(event)
	var motion := InputEventScreenDrag.new()
	motion.index = 8; motion.position = before.get_center()+Vector2(-200,-80)
	editor._input(motion)
	check(editor.touch.group_rects().brake.position.distance_to(before.position) > 100,"direct drag moves selected pedal")
	event.pressed = false; editor._input(event)
	reloaded.load_records()
	check(same_layout(reloaded.settings.control_layout,editor.touch.layout),"drag completion persists")
	var old_joystick: Dictionary = editor.touch.layout.joystick.duplicate(true)
	editor.method.item_selected.emit(1)
	check(editor.selected == "horizontal","method selection applies immediately")
	editor.size_slider.value = 1.3
	editor.opacity_slider.value = 0.55
	editor.method.item_selected.emit(2)
	check(editor.touch.layout.joystick == old_joystick,"method-specific configuration retained")
	check(is_equal_approx(editor.touch.layout.horizontal.scale,1.3) and is_equal_approx(editor.touch.layout.horizontal.opacity,0.55),"size and opacity change only selected control")
	editor._save()
	reloaded.load_records()
	check(same_layout(reloaded.settings.control_layout,editor.touch.layout),"all steering variants persist")
	var reset: Button = _button(editor.toolbar,"Reset to default")
	reset.pressed.emit()
	check(editor.touch.layout == ControlLayout.preset(),"reset restores every method and pedal")
	var preset_picker: OptionButton = editor.toolbar.get_child(0).get_child(0).get_child(1)
	preset_picker.item_selected.emit(1)
	check(editor.touch.layout == ControlLayout.preset(true),"left-handed preset applies immediately")
	preset_picker.item_selected.emit(2)
	check(editor.touch.layout == ControlLayout.preset(),"right-handed preset applies immediately")
	# Capture all methods at each window size using the actual editor and HUD.
	if DisplayServer.get_name() != "headless":
		for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(960,540)]:
			root.size = dimensions
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			check(editor.toolbar.get_global_rect().end.x <= editor.size.x,"toolbar fits viewport")
			var directory: String = ProjectSettings.globalize_path("res://../docs/evidence/control-layout")
			DirAccess.make_dir_recursive_absolute(directory)
			root.get_texture().get_image().save_png(directory+"/editor-%dx%d.png" % [dimensions.x,dimensions.y])
			for index: int in [1,2]:
				editor.method.select(index)
				editor.method.item_selected.emit(index)
				await process_frame
				await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(directory+"/%s-%dx%d.png" % [ControlLayout.METHODS[index],dimensions.x,dimensions.y])
			editor.method.select(0)
			editor.method.item_selected.emit(0)
	editor.touch.layout.accelerator.x = 0.66
	editor._changed()
	editor._save()
	editor.queue_free()
	await process_frame
	var app: Node = load("res://core/app.tscn").instantiate()
	app.set("records",LocalRecords.new(path))
	root.add_child(app)
	await process_frame
	app.call("_show_screen","settings")
	await process_frame
	var customize: Button = _button(app.get("root_ui"),"Customize layout")
	check(customize != null,"Settings exposes Customize layout")
	customize.pressed.emit()
	await process_frame
	var active: ControlLayoutEditor
	for child: Node in app.get_children():
		if child is ControlLayoutEditor: active = child
	check(active != null and not app.get("root_ui").visible,"Settings opens full-screen controls")
	var saved_layout: Dictionary = active.touch.layout.duplicate(true)
	_button(active.toolbar,"Done").pressed.emit()
	await process_frame
	check(app.get("root_ui").visible,"Done returns to Settings")
	app.call("_start_race",app.get("selected_track"),false)
	await process_frame
	var race_hud: PlaygroundHUD = app.get("game").get("hud")
	check(same_layout(race_hud.touch.layout,saved_layout),"new race receives persisted editor layout")
	app.call("_leave_race")
	app.queue_free()
	await process_frame
	for suffix: String in ["",".bak",".tmp"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	print("CONTROL_LAYOUT: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _button(node: Node, caption: String) -> Button:
	if node is Button and node.text == caption: return node
	for child: Node in node.get_children():
		var found: Button = _button(child,caption)
		if found != null: return found
	return null
