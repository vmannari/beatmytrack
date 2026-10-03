extends SceneTree
## Actual settings navigation, preference commits and captures in disposable profiles.
var checks: int = 0
var failures: int = 0
var app: Node
var directory: String
var output: String

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: " + message)

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-settings="): output = argument.trim_prefix("--capture-settings=")
	check(DisplayServer.get_name() != "headless" and output.is_absolute_path(), "graphical capture with explicit output")
	if failures > 0: quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	directory = "user://settings_capture_" + TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	app = (load("res://core/app.tscn") as PackedScene).instantiate()
	app.set("records", LocalRecords.new(directory.path_join("records.json")))
	app.set("library", TrackLibrary.new(directory))
	root.add_child(app)
	while not app.get("startup_complete"): await process_frame
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(1600, 720)]:
		root.size = dimensions
		app.call("_show_screen", "tracks")
		await _settle()
		await _press("MenuSettings")
		check(app.get("screen") == "settings", "gear opens Settings")
		var page: SettingsPage = _page()
		check(page != null, "settings page mounted")
		if page == null: continue
		var sidebar: Control = page.find_child("SettingsSidebar", true, false)
		var panel: Control = page.find_child("SettingsContent", true, false)
		var panel_rect: Rect2 = panel.get_global_rect()
		check(not sidebar.get_global_rect().intersects(panel_rect), "sidebar and content do not overlap")
		check(root.get_visible_rect().encloses(panel_rect), "content stays within viewport")
		for id: String in ["Steering_buttons", "Steering_horizontal", "Steering_joystick", "ShowControlLabels", "CustomizeControls", "ApplySettings", "ResetSettings"]:
			var button: Button = page.find_child(id, true, false)
			check(button != null and button.is_visible_in_tree() and button.size.y >= 52, "reachable touch target " + id)
		var scroll: Control = page.find_child("SettingsScroll", true, false)
		var keyboard: Control = page.find_child("KeyboardSettings", true, false)
		check(scroll.get_global_rect().encloses(keyboard.get_global_rect()), "keyboard shortcuts fit without scrolling")
		for label: Node in keyboard.find_children("*", "Label", true, false):
			check((label as Label).get_line_count() == 1, "keyboard shortcut text stays on one line")
		await _capture("controls", dimensions)
		await _press("SettingsCategory_camera")
		check(page.section == "camera" and panel.get_global_rect().is_equal_approx(panel_rect), "camera keeps panel geometry")
		for mode: String in CameraProfile.MODES:
			var choice: Button = page.find_child("Camera_" + mode, true, false)
			check(choice != null and choice.is_visible_in_tree() and choice.size.y >= 52, "reachable camera choice " + mode)
		var zoom_choice: CheckButton = page.find_child("CameraSpeedZoom", true, false)
		check(zoom_choice != null and zoom_choice.is_visible_in_tree() and zoom_choice.size.y >= 52, "reachable speed zoom toggle")
		await _capture("camera", dimensions)
		await _press("SettingsCategory_haptics")
		check(page.section == "haptics" and panel.get_global_rect().is_equal_approx(panel_rect), "haptics keeps panel geometry")
		await _capture("haptics", dimensions)
		await _press("SettingsCategory_account")
		check(page.section == "account" and panel.get_global_rect().is_equal_approx(panel_rect), "account keeps panel geometry")
		check(page.find_child("SettingsAccount", true, false) != null and not page.reset_button.visible, "account has sign-in access without control reset")
		await _capture("account", dimensions)
		await _press("SettingsCategory_controls")
		if dimensions == Vector2i(1280, 720): await _preferences()
	await _account_route()
	app.queue_free()
	await process_frame
	for filename: String in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(filename))
	DirAccess.remove_absolute(directory)
	print("Settings capture: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _preferences() -> void:
	var store: LocalRecords = app.get("records")
	store.settings.favorites = ["starter_circuit"]
	check(store.save_records() == OK, "unrelated preference fixture saved")
	await _press("SettingsCategory_camera")
	await _press("Camera_follow_car")
	check(_page().draft_camera == "follow_car" and store.settings.get("camera_mode", "overhead") == "overhead", "camera stages until Apply")
	await _press("CameraSpeedZoom")
	check(not _page().draft_speed_zoom and store.settings.get("camera_speed_zoom", true) == true, "speed zoom stages until Apply")
	await _press("SettingsCategory_controls")
	check(_page().draft_camera == "follow_car", "camera draft survives section switching")
	check(_page().draft_labels, "existing profiles show control labels by default")
	await _press("ShowControlLabels")
	check(not _page().draft_labels and store.settings.get("control_labels", true), "control labels stage until Apply")
	await _press("Steering_joystick")
	check(_page().draft_layout.steering_type == "joystick" and ControlLayout.from_settings(store.settings).steering_type == "buttons", "steering is staged before apply")
	await _press("ApplySettings")
	var reloaded := LocalRecords.new(store.path)
	reloaded.load_records()
	check(ControlLayout.from_settings(reloaded.settings).steering_type == "joystick", "apply persists steering after reload")
	check(reloaded.settings.camera_mode == "follow_car", "apply persists camera after reload")
	check(not reloaded.settings.camera_speed_zoom, "apply persists disabled speed zoom after reload")
	check(not reloaded.settings.control_labels, "apply persists hidden labels after reload")
	await _press("SettingsCategory_haptics")
	await _press("HapticsMedium")
	check(is_equal_approx(_page().draft_haptics, 0.5) and is_equal_approx(float(store.settings.steering_haptics), 0.2), "haptic strength is staged")
	await _press("SettingsCategory_controls")
	check(is_equal_approx(_page().draft_haptics, 0.5), "category switching retains staged strength")
	check(not _page().draft_labels, "hidden label preference survives category switching")
	await _press("ApplySettings")
	reloaded.load_records()
	check(is_equal_approx(float(reloaded.settings.steering_haptics), 0.5), "apply persists haptics")
	await _press("ResetSettings")
	check(ControlLayout.from_settings(store.settings).steering_type == "joystick" and _page().draft_layout.steering_type == "buttons", "reset is staged until apply")
	await _press("ApplySettings")
	reloaded.load_records()
	var restored: Dictionary = ControlLayout.from_settings(reloaded.settings)
	check(restored.steering_type == "buttons" and is_equal_approx(float(reloaded.settings.steering_haptics), 0.2), "reset restores steering method and haptics")
	var preset: Dictionary = ControlLayout.preset()
	for key: String in ControlLayout.KEYS:
		for field: String in ["x", "y", "scale", "opacity"]:
			check(is_equal_approx(float(restored[key][field]), float(preset[key][field])), "reset restores " + key + " " + field)
	check(reloaded.settings.favorites == ["starter_circuit"], "reset preserves favorites")
	check(reloaded.settings.camera_mode == "follow_car", "reset controls preserves camera")
	check(not reloaded.settings.camera_speed_zoom, "reset controls preserves disabled speed zoom")
	check(reloaded.settings.control_labels, "reset controls restores visible labels")
	await _press("SettingsCategory_camera")
	await _press("ResetSettings")
	check(_page().draft_camera == "overhead" and store.settings.camera_mode == "follow_car", "camera reset is staged")
	check(_page().draft_speed_zoom and not store.settings.camera_speed_zoom, "camera zoom reset is staged")
	await _press("ApplySettings")
	reloaded.load_records()
	check(reloaded.settings.camera_mode == "overhead" and reloaded.settings.favorites == ["starter_circuit"], "camera reset commits without changing favorites")
	check(reloaded.settings.camera_speed_zoom, "camera reset restores speed zoom default")
	await _press("SettingsCategory_controls")
	await _press("Steering_horizontal")
	await _press("Tab_tracks")
	await _press("MenuSettings")
	check(_page().draft_layout.steering_type == "buttons", "leaving without apply preserves committed preferences")
	await _press("Steering_horizontal")
	await _press("ShowControlLabels")
	var valid_path: String = store.path
	store.path = directory.path_join("missing_parent/records.json")
	await _press("ApplySettings")
	check(_page().status.text.begins_with("Could not save") and ControlLayout.from_settings(store.settings).steering_type == "buttons", "save failure reports error and rolls back committed preference")
	check(_page().draft_layout.steering_type == "horizontal", "save failure retains draft for retry")
	check(not _page().draft_labels and store.settings.control_labels, "failed label save retains draft and committed preference")
	store.path = valid_path
	await _press("CustomizeControls")
	var editor: ControlLayoutEditor
	for child: Node in app.get_children():
		if child is ControlLayoutEditor: editor = child
	check(editor != null and not (app.get("root_ui") as Control).visible, "customize opens the actual layout editor")
	reloaded.load_records()
	check(ControlLayout.from_settings(reloaded.settings).steering_type == "horizontal", "customize commits selected method before editor")
	if editor != null:
		check(not editor.touch.show_labels and not editor.selected_art.show_labels, "layout preview respects hidden labels")
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output.path_join("layout-no-labels.png")) == OK, "capture hidden layout labels")
		for child: Node in editor.find_children("*", "Button", true, false):
			if (child as Button).text == "Done": await _tap((child as Button).get_global_rect().get_center()); break
		await _settle()
		check((app.get("root_ui") as Control).visible and _page() != null, "layout Done returns to Settings")
	await _press("ResetSettings")
	await _press("ApplySettings")

func _account_route() -> void:
	await _press("SettingsCategory_account")
	await _press("SettingsAccount")
	check(app.get("screen") == "account", "account action reaches existing sign-in screen")

func _page() -> SettingsPage:
	return (app.get("root_ui") as Node).find_child("SettingsPage", true, false) as SettingsPage

func _press(id: String) -> void:
	var button: Button = (app.get("root_ui") as Node).find_child(id, true, false) as Button
	check(button != null and button.is_visible_in_tree(), "visible action " + id)
	if button == null: return
	await _tap(button.get_global_rect().get_center())
	await _settle()

func _tap(point: Vector2) -> void:
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.position = point
	down.pressed = true
	root.push_input(down, true)
	await process_frame
	var up := down.duplicate() as InputEventScreenTouch
	up.pressed = false
	root.push_input(up, true)
	await process_frame

func _settle() -> void:
	for index: int in range(5): await process_frame

func _capture(label: String, dimensions: Vector2i) -> void:
	await RenderingServer.frame_post_draw
	var path: String = output.path_join("settings-%s-%dx%d.png" % [label, dimensions.x, dimensions.y])
	check(root.get_texture().get_image().save_png(path) == OK, "capture " + label)
