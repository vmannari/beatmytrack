class_name PlaygroundHUD
extends CanvasLayer

signal restart_requested
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
var pause_glyph: HUDGlyph
var lap_label: Label
var race_timer: Label
var pause_button: Button
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
	root.add_child(touch)
	root.theme = RaceHUDStyle.theme()
	var race_card := PanelContainer.new()
	race_card.name = "RaceCard"
	race_card.position = Vector2(24, 20)
	race_card.custom_minimum_size = Vector2(248, 106)
	race_card.add_theme_stylebox_override("panel", _panel_style())
	race_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	race_card.visible = not editor_test
	root.add_child(race_card)
	race_frame = HUDFrame.attach(race_card,"map")
	var overview := HBoxContainer.new()
	overview.add_theme_constant_override("separation",8)
	race_card.add_child(overview)
	road_map = HUDRoadMap.new()
	overview.add_child(road_map)
	var status := VBoxContainer.new()
	status.add_theme_constant_override("separation", 0)
	overview.add_child(status)
	var lap_row := HBoxContainer.new()
	status.add_child(lap_row)
	var lap_caption := _label("LAP" if production_mode else "TEST",18)
	lap_row.add_child(lap_caption)
	lap_label = _label("1 / 5" if production_mode else "DRIVE",32)
	lap_label.add_theme_color_override("font_color", RaceHUDStyle.GOLD)
	lap_row.add_child(lap_label)
	title = _label("HANDLING YARD", 17)
	title.custom_minimum_size.x = 112
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.visible = not editor_test
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
	var clock_caption := _label("RACE TIME", 14)
	clock_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock_caption.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var caption_back := StyleBoxFlat.new()
	caption_back.bg_color = Color("1c2931")
	caption_back.content_margin_left = 4
	caption_back.content_margin_right = 4
	clock_caption.add_theme_stylebox_override("normal",caption_back)
	clock_caption.add_theme_color_override("font_color", RaceHUDStyle.MUTED)
	clock_info.add_child(clock_caption)
	race_timer = _label("00:00.00", 36)
	race_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	race_timer.visible = production_mode and not editor_test
	var clock_row := HBoxContainer.new()
	clock_info.add_child(clock_row)
	var watch := Control.new()
	watch.custom_minimum_size = Vector2(30,40)
	clock_row.add_child(watch)
	var symbol := HUDGlyph.new()
	symbol.kind = "clock"
	watch.add_child(symbol)
	race_timer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clock_row.add_child(race_timer)
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
	top.add_theme_constant_override("separation", 8)
	actions.add_child(top)
	if editor_test:
		var practice := HBoxContainer.new()
		practice.position = Vector2(24, 20)
		root.add_child(practice)
		_button(practice, "Practice (untimed)", func() -> void: pause_requested.emit())
		pause_button = practice.get_child(0) as Button
		pause_button.name = "PracticeStatus"
		pause_button.tooltip_text = "Pause practice"
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
		_button(top, "", func() -> void: pause_requested.emit())
		pause_button = top.get_child(top.get_child_count() - 1) as Button
		pause_button.custom_minimum_size.x = 60
		pause_button.tooltip_text = "Pause / resume (Esc)"
		pause_glyph = HUDGlyph.new()
		pause_button.add_child(pause_glyph)
		var menu := MenuButton.new()
		menu.name = "RaceMenu"
		menu.flat = false
		menu.custom_minimum_size = Vector2(60,52)
		menu.tooltip_text = "Race menu: restart or return to tracks"
		top.add_child(menu)
		var icon := HUDGlyph.new()
		icon.kind = "menu"
		menu.add_child(icon)
		var popup: PopupMenu = menu.get_popup()
		popup.add_item("Restart",0)
		if production_mode: popup.add_item("Tracks",1)
		popup.about_to_popup.connect(func() -> void: handling_menu_opened.emit())
		popup.popup_hide.connect(func() -> void: handling_menu_closed.emit())
		popup.id_pressed.connect(func(id: int) -> void:
			if id == 0: restart_requested.emit()
			else: exit_requested.emit())
	var secondary := HBoxContainer.new()
	secondary.alignment = BoxContainer.ALIGNMENT_END
	actions.add_child(secondary)
	handling_button = MenuButton.new()
	handling_button.name = "HandlingSelector"
	handling_button.flat = false
	handling_button.text = "Handling"
	handling_button.custom_minimum_size = Vector2(196, 52)
	handling_button.tooltip_text = "Compare handling; selecting a preset restarts this drive"
	secondary.add_child(handling_button)
	var choices: PopupMenu = handling_button.get_popup()
	choices.add_theme_constant_override("v_separation", 16)
	for entry: Array in [["Original+ (slide and drive)", 4], ["Original (unchanged)", 3], ["Planted", 0], ["Balanced", 1], ["Playful", 2]]:
		choices.add_radio_check_item(entry[0], entry[1])
	choices.add_separator("Selecting restarts the drive")
	choices.id_pressed.connect(func(index: int) -> void: profile_requested.emit(index))
	choices.about_to_popup.connect(func() -> void: handling_menu_opened.emit())
	choices.popup_hide.connect(func() -> void: handling_menu_closed.emit())
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
	panel.offset_left = -122
	panel.offset_right = 122
	panel.offset_top = -140
	panel.offset_bottom = -64
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = not editor_test
	root.add_child(panel)
	instrument = HUDFrame.attach(panel,"speed")
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 0)
	panel.add_child(info)
	speed_label = _label("0", 38)
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_child(speed_label)
	var units := _label("KM/H", 14)
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
	var help := _label("WASD / arrows: drive    Space: brake / reverse    R: restart    F1: telemetry    1 / 2 / 3 / 4 / 5: handling", 14)
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
		_button(profiles, ["1 Planted", "2 Balanced", "3 Playful", "4 Original", "5 Original+"][i], func() -> void: profile_requested.emit(i))
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
	pause_button.text = ("Paused · Resume" if paused else "Practice (untimed)") if editor_test else ("Resume" if paused else ("Pause" if production_mode else "Pause  Esc"))
	if pause_glyph != null:
		pause_button.text = ""
		pause_glyph.kind = "resume" if paused else "pause"
		pause_glyph.queue_redraw()
	road_map.player = state.position
	road_map.queue_redraw()
	instrument.speed_fraction = clampf(state.velocity.length()*3.6/180.0,0,1)
	instrument.queue_redraw()
	speed_label.text = "%d" % (state.velocity.length() * 3.6)
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
	label.add_theme_font_override("font", RaceHUDStyle.DISPLAY)
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
	card.custom_minimum_size = Vector2(248,106) if authored else Vector2(176,76)
	card.size = card.custom_minimum_size
	race_frame.queue_redraw()
