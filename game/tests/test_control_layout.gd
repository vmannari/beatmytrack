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
	var test_directory: String = "user://control_layout_test_" + TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(test_directory)
	var path: String = test_directory.path_join("records.json")
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
	check(report.failures.is_empty() and int(report.checks) == 90,"device probe dispatches 90 checks through viewport input")
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
	motion.index = 8; motion.position = before.get_center()+Vector2(0,-160)
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
	var reset: Button = _button(editor.toolbar,"Reset")
	reset.pressed.emit()
	check(editor.touch.layout == ControlLayout.preset(),"reset restores every method and pedal")
	var preset_picker: OptionButton = editor.presets
	preset_picker.item_selected.emit(1)
	check(editor.touch.layout == ControlLayout.preset(true),"left-handed preset applies immediately")
	preset_picker.item_selected.emit(2)
	check(editor.touch.layout == ControlLayout.preset(),"right-handed preset applies immediately")
	_test_independent(editor)
	_test_migration()
	# Capture all methods at each window size using the actual editor and HUD.
	if DisplayServer.get_name() != "headless":
		for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1600,720),Vector2i(960,540)]:
			root.size = dimensions
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			check(editor.toolbar.get_global_rect().end.x <= editor.size.x,"toolbar fits viewport")
			check(root.get_visible_rect().encloses(editor.selection_panel.get_global_rect()),"selected-control panel fits viewport")
			check(not editor.toolbar.get_global_rect().intersects(editor.selection_panel.get_global_rect()),"toolbar and inspector remain separate")
			var directory: String = ProjectSettings.globalize_path("res://../docs/evidence/control-customization-2026-10-03")
			DirAccess.make_dir_recursive_absolute(directory)
			root.get_texture().get_image().save_png(directory+"/editor-%dx%d.png" % [dimensions.x,dimensions.y])
			for key: String in ["brake", "handbrake"]:
				editor.selected = key
				editor._refresh()
				await process_frame
				await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(directory+"/selected-%s-%dx%d.png" % [key,dimensions.x,dimensions.y])
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
	app.set("library",TrackLibrary.new(test_directory))
	root.add_child(app)
	while not app.get("startup_complete"): await process_frame
	app.call("_show_screen","settings")
	await process_frame
	var menu_layout_before: Dictionary = ControlLayout.from_settings(app.get("records").settings)
	for choice: String in ["Analog slider","Analog joystick","Buttons","Analog slider"]:
		var mode_button: Button = _button(app.get("root_ui"),choice)
		check(mode_button != null,"Settings exposes "+choice)
		mode_button.pressed.emit()
		await process_frame
		var apply: Button = _button(app.get("root_ui"),"Apply settings")
		check(apply != null,"Settings exposes Apply settings")
		apply.pressed.emit()
		var stored := LocalRecords.new(path)
		stored.load_records()
		var expected: String = "horizontal" if choice == "Analog slider" else "joystick" if choice == "Analog joystick" else "buttons"
		check(stored.settings.control_layout.steering_type == expected,"menu mode persists: "+choice)
		check(stored.settings.control_layout.accelerator == menu_layout_before.accelerator,"changing mode preserves pedal geometry")
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
	# Disposable catalog annotation exercises the offline timed-race path.
	# This is a UI integration fixture, never a real backend publication.
	var race_fixture: NativeTrack = app.get("selected_track")
	race_fixture.metadata.cloud_version = "control-layout-fixture"
	app.call("_start_race",race_fixture,false,true)
	await process_frame
	var race_hud: PlaygroundHUD = app.get("game").get("hud")
	check(same_layout(race_hud.touch.layout,saved_layout),"new race receives persisted editor layout")
	app.call("_leave_race")
	app.queue_free()
	await process_frame
	for suffix: String in ["",".bak",".tmp"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	for file: String in DirAccess.get_files_at(test_directory): DirAccess.remove_absolute(test_directory.path_join(file))
	DirAccess.remove_absolute(test_directory)
	print("CONTROL_LAYOUT: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _button(node: Node, caption: String) -> Button:
	if node is Button and node.text == caption: return node
	for child: Node in node.get_children():
		var found: Button = _button(child,caption)
		if found != null: return found
	return null

func _test_independent(editor: ControlLayoutEditor) -> void:
	for key: String in ["steer_left", "steer_right", "brake", "handbrake", "accelerator"]:
		editor.presets.select(0)
		editor._reset()
		var saved: Dictionary = editor.touch.layout.duplicate(true)
		var bounds: Dictionary = editor.touch.group_rects().duplicate(true)
		var down := InputEventScreenTouch.new()
		down.index = 9
		down.pressed = true
		var selected_bounds: Rect2 = bounds[key]
		down.position = selected_bounds.position + Vector2(selected_bounds.size.x*0.5, 16)
		editor._input(down)
		check(editor.selected == key, "each button can be selected alone: " + key)
		var move_event := InputEventScreenDrag.new()
		move_event.index = 9
		move_event.position = down.position - Vector2(0, 160)
		editor._input(move_event)
		check((editor.touch.group_rects()[key] as Rect2).position.distance_to((bounds[key] as Rect2).position) > 100, "each button moves alone: " + key)
		down.pressed = false
		editor._input(down)
		editor.size_slider.value = 0.85
		editor.opacity_slider.value = 0.55
		check(is_equal_approx(float(editor.touch.layout[key].scale), 0.85) and is_equal_approx(float(editor.touch.layout[key].opacity), 0.55), "individual size and opacity: " + key)
		for other: String in ControlLayout.active_keys(editor.touch.layout):
			if other == key: continue
			check(editor.touch.layout[other] == saved[other], "editing " + key + " preserves " + other + " preferences")
			check((editor.touch.group_rects()[other] as Rect2).is_equal_approx(bounds[other]), "editing " + key + " preserves " + other + " position")
		editor._reset_position()
		check(is_equal_approx(float(editor.touch.layout[key].x), float(saved[key].x)) and is_equal_approx(float(editor.touch.layout[key].y), float(saved[key].y)), "reset position restores just " + key)
		check(is_equal_approx(float(editor.touch.layout[key].scale), 0.85) and is_equal_approx(float(editor.touch.layout[key].opacity), 0.55), "reset position preserves size and opacity")
		check(editor.preview.driver.sample().steer == 0 and editor.preview.driver.sample().throttle == 0 and editor.preview.driver.sample().brake == 0 and editor.preview.driver.sample().handbrake == 0, "editing does not activate driving")
		editor._save()
		var reload := LocalRecords.new(editor.records.path)
		reload.load_records()
		check(same_layout(ControlLayout.from_settings(reload.settings), editor.touch.layout), "independent preferences persist: " + key)
	editor._reset()
	# Moving into a neighbor must never move that neighbor away.
	var layout_before: Dictionary = editor.touch.layout.duplicate(true)
	editor.selected = "steer_left"
	var candidate: Rect2 = editor.touch.group_rects().steer_right
	var down := InputEventScreenTouch.new()
	down.pressed = true; down.index = 9; down.position = (editor.touch.group_rects().steer_left as Rect2).get_center()
	editor._input(down)
	var collision := InputEventScreenDrag.new()
	collision.index = 9; collision.position = candidate.get_center()
	editor._input(collision)
	check(editor.touch.layout == layout_before, "colliding drag cannot displace another control")
	down.pressed = false; editor._input(down)

func _test_migration() -> void:
	var legacy: Dictionary = {"version":1,"steering_type":"buttons"}
	for key: String in ControlLayout.LEGACY_KEYS:
		legacy[key] = {"x":0.05 if key == "buttons" else 0.7,"y":0.8,"scale":1.1,"opacity":0.55}
	var original: Dictionary = legacy.duplicate(true)
	check(ControlLayout.valid(legacy), "existing v1 layout remains valid")
	var converted: Dictionary = ControlLayout.from_settings({"control_layout":legacy})
	check(converted.version == 2 and ControlLayout.valid(converted) and legacy == original, "v1 conversion is valid and leaves saved source intact")
	var directory: String = "user://control_migration_" + TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var store := LocalRecords.new(directory.path_join("records.json"))
	store.settings = {"control_layout":legacy.duplicate(true),"favorites":["starter_circuit"]}
	check(store.save_records() == OK, "existing v1 layout can still be saved")
	var reloaded := LocalRecords.new(store.path)
	reloaded.load_records()
	check(reloaded.settings.control_layout.version == 1 and ControlLayout.from_settings(reloaded.settings).version == 2, "loading v1 supplies independent controls without rewriting the source")
	reloaded.settings.control_layout = converted.duplicate(true)
	check(reloaded.save_records() == OK, "converted v2 layout saves atomically")
	reloaded.load_records()
	check(reloaded.settings.control_layout.version == 2 and reloaded.settings.favorites == ["starter_circuit"], "v2 reload preserves unrelated preferences")
	for file: String in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	for key: String in ["steer_left", "steer_right", "brake", "handbrake"]:
		check(is_equal_approx(float(converted[key].scale), 1.1) and is_equal_approx(float(converted[key].opacity), 0.55), "legacy grouped styling preserved for " + key)
	for key: String in ["horizontal", "joystick", "accelerator"]: check(converted[key] == legacy[key], "legacy standalone control preserved: " + key)
	var area := Rect2(Vector2.ZERO, Vector2(1248, 520))
	check(ControlLayout.rect(converted,"steer_left",area).position.x < ControlLayout.rect(converted,"steer_right",area).position.x, "legacy steering splits left and right")
	check(ControlLayout.rect(converted,"handbrake",area).position.x < ControlLayout.rect(converted,"brake",area).position.x, "legacy brake group splits handbrake and brake")
	converted.erase("handbrake")
	check(not ControlLayout.valid(converted), "v2 rejects missing individual control")
