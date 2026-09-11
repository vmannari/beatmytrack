class_name PlaygroundHUD
extends CanvasLayer

signal restart_requested
signal pause_requested
signal profile_requested(index: int)
signal handling_edited
signal record_requested

var config: HandlingConfig
var driver: DriverInput
var touch: TouchControls
var speed_label: Label
var debug_label: Label
var message_label: Label
var tune_panel: PanelContainer
var tune_fields: VBoxContainer
var profile_label: Label
var debug_enabled: bool = true
var hud_elapsed: float = 0.0


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	touch = TouchControls.new()
	touch.driver = driver
	root.add_child(touch)
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 24
	top.offset_top = 20
	top.offset_right = -24
	top.add_theme_constant_override("separation", 12)
	root.add_child(top)
	var title := _label("CIRCUIT / 01   ·   HANDLING YARD", 19)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	_button(top, "Restart  R", func() -> void: restart_requested.emit())
	_button(top, "Pause  Esc", func() -> void: pause_requested.emit())
	if OS.is_debug_build():
		_button(top, "Tune  F2", toggle_tuning)
		_button(top, "Record  F3", func() -> void: record_requested.emit())
	var panel := PanelContainer.new()
	panel.position = Vector2(24, 82)
	panel.custom_minimum_size = Vector2(265, 0)
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	var info := VBoxContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(info)
	speed_label = _label("0 km/h", 32)
	info.add_child(speed_label)
	profile_label = _label("Balanced", 17)
	info.add_child(profile_label)
	debug_label = _label("", 15)
	info.add_child(debug_label)
	debug_enabled = OS.is_debug_build()
	var footer := VBoxContainer.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 24
	footer.offset_right = -24
	footer.offset_top = -51
	root.add_child(footer)
	message_label = _label("Brake before the circle. Lift and countersteer to catch a slide.", 16)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_child(message_label)
	var help := _label("WASD / arrows: drive    Space: brake / reverse    R: restart    F1: telemetry    1 / 2 / 3: handling", 14)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.visible = OS.is_debug_build() and not OS.has_feature("mobile")
	footer.add_child(help)
	tune_panel = PanelContainer.new()
	tune_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	tune_panel.offset_left = -350
	tune_panel.offset_right = -24
	tune_panel.offset_top = 82
	tune_panel.add_theme_stylebox_override("panel", _panel_style())
	tune_panel.visible = false
	root.add_child(tune_panel)
	tune_fields = VBoxContainer.new()
	tune_panel.add_child(tune_fields)
	show_config(config)


func show_config(handling: HandlingConfig) -> void:
	config = handling
	if tune_fields == null:
		return
	profile_label.text = config.profile_name
	for child: Node in tune_fields.get_children():
		tune_fields.remove_child(child)
		child.queue_free()
	tune_fields.add_child(_label("HANDLING · changes reset the car", 17))
	var profiles := HBoxContainer.new()
	tune_fields.add_child(profiles)
	for i: int in range(3):
		_button(profiles, ["1 Stable", "2 Balanced", "3 Loose"][i], func() -> void: profile_requested.emit(i))
	var fields: Array[Array] = [
		["Engine force · N", "engine_force", 5000.0, 18000.0, 500.0],
		["Lateral grip · m/s²", "lateral_grip", 8.0, 60.0, 0.5],
		["Rear grip balance", "rear_grip", 0.65, 1.3, 0.05],
		["Steering response · /s", "steering_rate", 2.0, 12.0, 0.5],
		["Countersteer assist", "countersteer_assistance", 0.0, 2.0, 0.1],
		["Throttle rotation", "throttle_rotation", 0.0, 1.2, 0.05]]
	for field: Array in fields:
		var row := HBoxContainer.new()
		tune_fields.add_child(row)
		var label := _label(field[0], 15)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var value := SpinBox.new()
		value.min_value = field[2]
		value.max_value = field[3]
		value.step = field[4]
		value.value = config.get(field[1])
		value.custom_minimum_size.x = 105
		row.add_child(value)
		value.value_changed.connect(_change_setting.bind(String(field[1])))
	tune_fields.add_child(_label("F6: reload saved Resource + reset\nAll parameters: resources/balanced.tres", 14))


func _change_setting(value: float, key: String) -> void:
	config.set(key, value)
	profile_label.text = config.profile_name + " · modified"
	handling_edited.emit()


func toggle_tuning() -> void:
	if OS.is_debug_build():
		tune_panel.visible = not tune_panel.visible


func update_values(state: VehicleState, frame: DriveFrame, delta: float, paused: bool, recording: bool) -> void:
	hud_elapsed += delta
	if hud_elapsed < 0.08:
		return
	hud_elapsed = 0.0
	speed_label.text = "%3.0f km/h" % (state.velocity.length() * 3.6)
	debug_label.visible = debug_enabled and OS.is_debug_build()
	debug_label.text = "\nForward   %6.2f m/s\nLateral     %6.2f m/s\nSlip          %6.1f°\nSteer       %+6.2f\nThrottle   %6.2f\nBrake       %6.2f\nYaw         %+6.1f°/s\nGrip          %s  %.2f\nFPS          %d\nTick          %d  ·  hits %d" % [
		state.velocity.dot(state.forward()), state.velocity.dot(state.right()), rad_to_deg(state.slip_angle()),
		frame.steer / 127.0, frame.throttle / 255.0, frame.brake / 255.0, rad_to_deg(state.yaw_rate),
		"SLIP" if state.grip < 0.95 else "GRIP", state.grip, Engine.get_frames_per_second(), state.tick, state.collision_count]
	if paused:
		message_label.text = "PAUSED · press Esc or Pause to resume"
	elif recording:
		message_label.text = "Recording input + state · F3 to save (maximum 2 minutes)"


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("e0e5de"))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(parent: Control, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_stylebox_override("normal", _panel_style())
	button.pressed.connect(callback)
	parent.add_child(button)


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.14, 0.86)
	style.set_content_margin_all(12)
	style.set_corner_radius_all(4)
	return style
