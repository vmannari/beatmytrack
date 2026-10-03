class_name PlaygroundHUD
extends CanvasLayer

signal restart_requested
signal rewind_requested
signal pause_requested
signal profile_requested(index: int)
signal handling_menu_opened
signal handling_menu_closed
signal handling_edited
signal record_requested
signal track_requested
signal exit_requested
signal edit_here_requested

var production_mode: bool = false
var editor_test: bool = false
var map_ready: bool = false
var map_track: NativeTrack
var race_frame: HUDFrame
var road_map: HUDRoadMap
var instrument: HUDFrame
var pause_menu: Control
var menu_button: Button
var practice_status: Label
var lap_label: Label
var lap_timer: Label
var lap_total: Label
var race_timer: Label
var shortcut_penalty_label: Label
var shortcut_notice_label: Label
var checkpoint_notice: CheckpointNotice
var rewind_button: RewindHUDButton
var handling_button: MenuButton

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
var title: Label


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	touch = TouchControls.new()
	touch.driver = driver
	touch.vehicle_id = config.vehicle_id
	root.add_child(touch)
	root.theme = RaceHUDStyle.theme()
	var race_card := PanelContainer.new()
	race_card.name = "RaceCard"
	race_card.position = Vector2(24, 20)
	race_card.custom_minimum_size = Vector2(248, 140)
	race_card.add_theme_stylebox_override("panel", _panel_style())
	race_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	race_card.visible = not editor_test
	root.add_child(race_card)
	race_frame = HUDFrame.attach(race_card,"map")
	var overview := HBoxContainer.new()
	overview.add_theme_constant_override("separation",16)
	race_card.add_child(overview)
	road_map = HUDRoadMap.new()
	overview.add_child(road_map)
	var status := VBoxContainer.new()
	race_frame.lap_status = status
	status.resized.connect(race_frame.queue_redraw)
	status.item_rect_changed.connect(race_frame.queue_redraw)
	status.add_theme_constant_override("separation", 0)
	status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	overview.add_child(status)
	var lap_row := HBoxContainer.new()

	var lap_caption := _label("LAP" if production_mode else "TEST",18)
	status.add_child(lap_caption)
	status.add_child(lap_row)
	lap_label = _label("1" if production_mode else "DRIVE",32)
	lap_label.add_theme_color_override("font_color", RaceHUDStyle.GOLD)
	lap_row.add_child(lap_label)
	lap_total = _label("/ 5" if production_mode else "",32)
	lap_row.add_child(lap_total)
	title = _label("HANDLING YARD", 17)
	title.custom_minimum_size.x = 112
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.visible = false
	status.add_child(title)
	var timing := PanelContainer.new()
	timing.name = "TimingCard"
	timing.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	timing.offset_left = -112
	timing.offset_right = 112
	timing.offset_top = 20
	timing.add_theme_stylebox_override("panel", _panel_style())
	timing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timing.visible = production_mode and not editor_test
	root.add_child(timing)
	HUDFrame.attach(timing,"clock")
	var clock_info := VBoxContainer.new()
	clock_info.add_theme_constant_override("separation", 0)
	timing.add_child(clock_info)
	var clock_caption := _label("RACE", 16)
	clock_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock_caption.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	clock_info.add_child(clock_caption)
	race_timer = _timer_label(40)
	race_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	race_timer.visible = production_mode and not editor_test
	var clock_row := HBoxContainer.new()
	clock_info.add_child(clock_row)
	shortcut_penalty_label = _label("", 13)
	shortcut_penalty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shortcut_penalty_label.add_theme_color_override("font_color", RaceHUDStyle.GOLD)
	shortcut_penalty_label.visible = false
	clock_info.add_child(shortcut_penalty_label)
	checkpoint_notice = CheckpointNotice.new()
	root.add_child(checkpoint_notice)
	shortcut_notice_label = checkpoint_notice.label
	race_timer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clock_row.add_child(race_timer)
	var lap_time_caption := _label("LAP",16)
	lap_time_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock_info.add_child(lap_time_caption)
	lap_timer = _timer_label(24)
	lap_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lap_timer.add_theme_color_override("font_color",RaceHUDStyle.MUTED)
	clock_info.add_child(lap_timer)
	var actions := VBoxContainer.new()
	actions.name = "RaceActions"
	actions.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	actions.offset_left = -304
	actions.offset_right = -24
	actions.offset_top = 20
	actions.add_theme_constant_override("separation", 8)
	root.add_child(actions)
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_END
	top.add_theme_constant_override("separation", 16)
	actions.add_child(top)
	if editor_test:
		var practice := HBoxContainer.new()
		practice.position = Vector2(24, 20)
		root.add_child(practice)
		practice_status = _label("Practice (untimed)", 20)
		practice.add_child(practice_status)
		_button(top, "Restart", func() -> void: restart_requested.emit())
		top.get_child(top.get_child_count() - 1).name = "PracticeRestart"
		_button(top, "Edit here", func() -> void: edit_here_requested.emit())
		var edit_button := top.get_child(top.get_child_count() - 1) as Button
		edit_button.name = "EditHere"
		edit_button.custom_minimum_size.x = 124
		var accent := RaceHUDStyle.panel(true)
		accent.bg_color = RaceHUDStyle.GOLD
		edit_button.add_theme_stylebox_override("normal", accent)
		edit_button.add_theme_color_override("font_color", RaceHUDStyle.INK)
	else:
		if production_mode:
			rewind_button = RewindHUDButton.new()
			rewind_button.name = "RewindButton"
			rewind_button.pressed.connect(func() -> void: rewind_requested.emit())
			top.add_child(rewind_button)
			_round_button(rewind_button)
	menu_button = Button.new()
	menu_button.name = "RaceMenu"
	menu_button.custom_minimum_size = Vector2(60,60)
	_round_button(menu_button)
	menu_button.tooltip_text = "Pause / race menu (Esc)"
	top.add_child(menu_button)
	var icon := HUDGlyph.new()
	icon.kind = "menu"
	menu_button.add_child(icon)
	menu_button.pressed.connect(func() -> void: pause_requested.emit())
	if OS.is_debug_build() and not production_mode:
		var tools := HBoxContainer.new()
		tools.position = Vector2(24, 104)
		root.add_child(tools)
		_button(tools, "Track F5", func() -> void: track_requested.emit())
		_button(tools, "Tune  F2", toggle_tuning)
		_button(tools, "Record  F3", func() -> void: record_requested.emit())
	var panel := PanelContainer.new()
	panel.name = "SpeedCard"
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -114
	panel.offset_right = 114
	panel.offset_top = -156
	panel.offset_bottom = -42
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = not editor_test
	root.add_child(panel)
	instrument = HUDFrame.attach(panel,"speed")
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 0)
	panel.add_child(info)
	info.alignment = BoxContainer.ALIGNMENT_END
	speed_label = _label("0", 44)
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_child(speed_label)
	var units := _label("km/h", 18)
	units.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	units.add_theme_color_override("font_color", RaceHUDStyle.MUTED)
	info.add_child(units)
	var telemetry := VBoxContainer.new()
	telemetry.position = Vector2(24, 164)
	root.add_child(telemetry)
	profile_label = _label("Balanced", 17)
	profile_label.visible = not production_mode
	telemetry.add_child(profile_label)
	debug_label = _label("", 15)
	telemetry.add_child(debug_label)
	debug_enabled = OS.is_debug_build() and not production_mode
	var footer := VBoxContainer.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 24
	footer.offset_right = -24
	footer.offset_top = -51
	root.add_child(footer)
	message_label = _label("Brake before the circle. Lift and countersteer to catch a slide.", 16)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_child(message_label)
	var help := _label("WASD / arrows: drive    Space: handbrake    R: restart    F1: telemetry    1 / 2 / 3 / 4 / 5 / 6: handling", 14)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.visible = OS.is_debug_build() and not OS.has_feature("mobile") and not production_mode
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
	pause_menu = preload("res://ui/race_pause_menu.gd").new()
	pause_menu.hud = self
	var pause_layer := CanvasLayer.new()
	pause_layer.layer = 100
	add_child(pause_layer)
	pause_layer.add_child(pause_menu)
	pause_menu.hide()


func show_config(handling: HandlingConfig) -> void:
	config = handling
	if tune_fields == null:
		return
	profile_label.text = config.profile_name
	if handling_button != null:
		handling_button.text = "Handling: " + config.profile_name + " ▾"
		var choices: PopupMenu = handling_button.get_popup()
		for index: int in range(HandlingSelection.PROFILE_PATHS.size()):
			choices.set_item_checked(index, choices.get_item_id(index) == HandlingSelection.index)
	for child: Node in tune_fields.get_children():
		tune_fields.remove_child(child)
		child.queue_free()
	tune_fields.add_child(_label("HANDLING · changes reset the car", 17))
	var profiles := GridContainer.new()
	profiles.columns = 2
	tune_fields.add_child(profiles)
	for i: int in range(HandlingSelection.PROFILE_PATHS.size()):
		_button(profiles, ["1 Planted", "2 Balanced", "3 Playful", "4 Original", "5 Original+", "6 Drift+"][i], func() -> void: profile_requested.emit(i))
	var fields: Array[Array] = [
		["Engine force · N", "engine_force", 5000.0, 18000.0, 500.0],
		["Lateral grip · m/s²", "lateral_grip", 8.0, 60.0, 0.5],
		["Rear grip balance", "rear_grip", 0.65, 1.3, 0.05],
		["Steering response · /s", "steering_rate", 2.0, 40.0, 0.5],
		["Countersteer assist", "countersteer_assistance", 0.0, 2.0, 0.1],
		["Brake rotation", "brake_rotation", 0.0, 1.5, 0.05]]
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
	road_map.player = state.position
	road_map.queue_redraw()
	instrument.speed_fraction = clampf(state.velocity.length()*3.6/180.0,0,1)
	speed_label.text = "%d" % (state.velocity.length() * 3.6)
	debug_label.visible = debug_enabled and OS.is_debug_build()
	debug_label.text = "\nForward   %6.2f m/s\nLateral     %6.2f m/s\nSlip          %6.1f°\nSteer       %+6.2f\nThrottle   %6.2f\nBrake       %6.2f\nYaw         %+6.1f°/s\nGrip          %s  %.2f\nFPS          %d\nTick          %d  ·  hits %d" % [
		state.velocity.dot(state.forward()), state.velocity.dot(state.right()), rad_to_deg(state.slip_angle()),
		frame.steer / 127.0, frame.throttle / 255.0, frame.brake / 255.0, rad_to_deg(state.yaw_rate),
		"SLIP" if state.grip < 0.95 else "GRIP", state.grip, Engine.get_frames_per_second(), state.tick, state.collision_count]
	if paused:
		message_label.text = "PAUSED · press Esc or Resume to continue"
	elif recording:
		message_label.text = "Recording input + state · F3 to save (maximum 2 minutes)"


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", RaceHUDStyle.BODY)
	label.add_theme_constant_override("outline_size",0)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", RaceHUDStyle.TEXT)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(parent: Control, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(76, 52)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)


func _panel_style() -> StyleBoxFlat:
	return RaceHUDStyle.panel()


func set_track(track: NativeTrack) -> void:
	if map_ready and map_track == track: return
	map_ready = true
	map_track = track
	var authored: bool = track != null and not track.metadata.get("creator_document",{}).get("pieces",[]).is_empty()
	road_map.configure(track,authored)
	road_map.visible = authored
	road_map.queue_redraw()
	race_frame.kind = "map" if authored else "plain"
	var card := race_frame.get_parent() as PanelContainer
	card.custom_minimum_size = Vector2(248,140) if authored else Vector2(176,76)
	card.size = card.custom_minimum_size
	race_frame.queue_redraw()


func _round_button(button: Button) -> void:
	for state: String in ["normal","hover","pressed","focus"]:
		var style := RaceHUDStyle.panel(state != "normal")
		style.set_corner_radius_all(30)
		button.add_theme_stylebox_override(state,style)


func show_session(session: TrackSession) -> void:
	lap_label.text = str(mini(session.target_laps,session.completed_laps + 1))
	lap_total.text = "/ %d" % session.target_laps
	race_timer.text = _time_text(session.race_time_seconds())
	var current: float = maxf(0.0,float(session.elapsed_ticks)/session.tick_rate-session.lap_start_time)
	if session.finished and not session.lap_times.is_empty(): current = session.lap_times[-1]
	lap_timer.text = _time_text(current)
	shortcut_penalty_label.visible = session.shortcut_count > 0


func _time_text(seconds: float) -> String:
	# Integer centiseconds avoid a rounded 00:60.00 at minute boundaries.
	var centiseconds: int = floori(seconds * 100.0 + 0.00001)
	return "%02d:%02d.%02d" % [centiseconds / 6000,(centiseconds / 100) % 60,centiseconds % 100]


func _timer_label(font_size: int) -> Label:
	var label := _label("00:00.00",font_size)
	var numerals := FontVariation.new()
	numerals.base_font = RaceHUDStyle.BODY
	numerals.opentype_features = {"tnum":1}
	label.add_theme_font_override("font",numerals)
	label.custom_minimum_size = numerals.get_string_size("00:00.00",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
	return label
