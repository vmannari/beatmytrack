class_name SettingsPage
extends HBoxContainer
## Presentation and staged preferences; canonical driving stays outside this page.
signal customize_requested
signal account_requested

var records: LocalRecords
var signed_in: bool = false
var player_name: String = "Guest"
var section: String = "controls"
var draft_layout: Dictionary
var draft_haptics: float = 0.2
var draft_camera: String = "overhead"
var draft_speed_zoom: bool = true
var draft_labels: bool = true
var body: VBoxContainer
var heading: Label
var subtitle: Label
var status: Label
var categories: Dictionary = {}
var reset_button: Button

const TITLES: Dictionary = {
	"controls": ["Controls", "Choose how you steer and arrange your touch controls."],
	"camera": ["Camera", "Choose the view you prefer while driving."],
	"haptics": ["Haptics", "Adjust the feedback from your steering buttons."],
	"account": ["Account", "Manage the profile you race with."],
}

func _ready() -> void:
	name = "SettingsPage"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 16)
	draft_layout = ControlLayout.from_settings(records.settings)
	draft_haptics = float(records.settings.get("steering_haptics", 0.2))
	draft_camera = CameraProfile.valid_mode(str(records.settings.get("camera_mode", "overhead")))
	draft_speed_zoom = bool(records.settings.get("camera_speed_zoom", true))
	draft_labels = bool(records.settings.get("control_labels", true))
	_build_sidebar()
	_build_panel()
	_show_section(section)

func _build_sidebar() -> void:
	var panel := PanelContainer.new()
	panel.name = "SettingsSidebar"
	panel.custom_minimum_size.x = 292
	panel.add_theme_stylebox_override("panel", _surface(16, 0.9))
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation", 14)
	column.add_child(title)
	title.add_child(_icon("gear", 32))
	title.add_child(MenuStyle.label("SETTINGS", 32))
	column.add_child(_label("Make yourself comfortable.", 16, true))
	var space := Control.new()
	space.custom_minimum_size.y = 12
	column.add_child(space)
	for item: Array in [
		["controls", "Controls", "Steering and layout", "controller"],
		["camera", "Camera", "View and road ahead", "compass"],
		["haptics", "Haptics", "Feedback and vibration", "phone"],
		["account", "Account", "Profile and sign-in", "person"],
	]:
		var id: String = item[0]
		var button: Button = MenuStyle.button("", _show_section.bind(id))
		button.name = "SettingsCategory_" + id
		button.tooltip_text = item[1]
		button.custom_minimum_size.y = 82
		column.add_child(button)
		var margin := MarginContainer.new()
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		MenuStyle.fill(margin)
		for edge: String in ["left", "right"]: margin.add_theme_constant_override("margin_" + edge, 16)
		button.add_child(margin)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 14)
		margin.add_child(row)
		var glyph: TextureRect = _icon(item[3], 28)
		row.add_child(glyph)
		var copy := VBoxContainer.new()
		copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		copy.add_theme_constant_override("separation", 3)
		row.add_child(copy)
		var caption: Label = _label(item[1], 23)
		caption.add_theme_font_override("font", MenuStyle.DISPLAY)
		copy.add_child(caption)
		copy.add_child(_label(item[2], 15, true))
		var arrow: TextureRect = _icon("arrow", 18)
		row.add_child(arrow)
		categories[id] = {"button": button, "caption": caption, "glyph": glyph, "arrow": arrow}
	var air := Control.new()
	air.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(air)
	reset_button = MenuStyle.button("Reset controls", _reset)
	reset_button.name = "ResetSettings"
	reset_button.icon = MenuIcon.texture("restart")
	reset_button.add_theme_stylebox_override("normal", _surface(12, 1.0))
	column.add_child(reset_button)

func _build_panel() -> void:
	var panel := PanelContainer.new()
	panel.name = "SettingsContent"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _surface(20, 0.88))
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 3)
	column.add_child(header)
	heading = MenuStyle.label("", 32)
	header.add_child(heading)
	subtitle = _label("", 18, true)
	header.add_child(subtitle)
	var scroll := ScrollContainer.new()
	scroll.name = "SettingsScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)
	var footer := HBoxContainer.new()
	column.add_child(footer)
	status = _label("Changes are saved when you apply them.", 16, true)
	status.name = "SettingsStatus"
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(status)
	var apply: Button = MenuStyle.button("Apply settings", _apply, true)
	apply.name = "ApplySettings"
	apply.icon = MenuIcon.texture("check")
	apply.add_theme_color_override("icon_normal_color", MenuStyle.INK)
	apply.add_theme_color_override("icon_hover_color", MenuStyle.INK)
	apply.custom_minimum_size.x = 230
	footer.add_child(apply)

func _show_section(id: String) -> void:
	section = id
	heading.text = TITLES[id][0]
	subtitle.text = TITLES[id][1]
	for key: String in categories:
		var item: Dictionary = categories[key]
		var selected: bool = key == id
		var style: StyleBoxFlat = MenuStyle.box(Color("514a24") if selected else Color.TRANSPARENT, 12)
		style.border_color = MenuStyle.ACCENT
		style.border_width_left = 4 if selected else 0
		(item.button as Button).add_theme_stylebox_override("normal", style)
		for field: String in ["caption", "glyph", "arrow"]:
			(item[field] as Control).modulate = MenuStyle.ACCENT if selected else MenuStyle.MUTED
	reset_button.visible = id != "account"
	reset_button.text = "Reset camera" if id == "camera" else "Reset controls"
	for child: Node in body.get_children():
		body.remove_child(child)
		child.queue_free()
	match id:
		"controls": _controls()
		"camera": _camera()
		"haptics": _haptics()
		"account": _account()

func _controls() -> void:
	var steering: HBoxContainer = _row("SteeringSettings", 16)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 10)
	steering.add_child(copy)
	copy.add_child(MenuStyle.label("Steering mode", 24))
	copy.add_child(_label("Choose your on-screen steering control.", 16, true))
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 8)
	copy.add_child(modes)
	var labels: Array[String] = ["Buttons", "Analog slider", "Analog joystick"]
	for index: int in range(ControlLayout.METHODS.size()):
		var method: String = ControlLayout.METHODS[index]
		var option: Button = _choice(labels[index], draft_layout.steering_type == method, func() -> void:
			draft_layout.steering_type = method
			_changed()
			_show_section("controls"))
		option.name = "Steering_" + method
		modes.add_child(option)
	var preview := VBoxContainer.new()
	preview.custom_minimum_size.x = 226
	preview.add_theme_constant_override("separation", 4)
	steering.add_child(preview)
	var art := Control.new()
	art.custom_minimum_size = Vector2(226, 88)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.draw.connect(_draw_steering.bind(art))
	preview.add_child(art)
	var preview_title: Label = _label("Tap left or right" if draft_layout.steering_type == "buttons" else "Slide left or right", 16, true)
	preview_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview.add_child(preview_title)
	var layout_row: HBoxContainer = _row("LayoutSettings", 16)
	layout_row.add_child(_copy("Control layout", "Move and resize your on-screen controls."))
	var label_toggle := CheckButton.new()
	label_toggle.name = "ShowControlLabels"
	label_toggle.text = "Show labels"
	label_toggle.tooltip_text = "Show names below the gas, brake and handbrake controls."
	label_toggle.button_pressed = draft_labels
	label_toggle.custom_minimum_size = Vector2(180, 52)
	label_toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label_toggle.toggled.connect(func(on: bool) -> void:
		draft_labels = on
		_changed())
	layout_row.add_child(label_toggle)
	var customize: Button = MenuStyle.button("Customize layout", _customize)
	customize.name = "CustomizeControls"
	customize.icon = MenuIcon.texture("edit")
	customize.custom_minimum_size.x = 226
	customize.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	customize.add_theme_stylebox_override("normal", _surface(12, 1.0))
	layout_row.add_child(customize)
	var keyboard: HBoxContainer = _row("KeyboardSettings", 16)
	var explanation: VBoxContainer = _copy("Keyboard shortcuts", "Desktop driving controls")
	explanation.size_flags_horizontal = Control.SIZE_FILL
	explanation.custom_minimum_size.x = 220
	keyboard.add_child(explanation)
	var keys := VBoxContainer.new()
	keys.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keys.add_theme_constant_override("separation", 8)
	keyboard.add_child(keys)
	for entry: Array in [["A / D  ·  ← / →", "Steer left / right"], ["W / S  ·  ↑ / ↓", "Accelerate / brake"], ["Space  ·  R  ·  Esc", "Handbrake / retry / pause"]]:
		var line := HBoxContainer.new()
		keys.add_child(line)
		var keycap: Label = _label(entry[0], 16)
		keycap.size_flags_horizontal = Control.SIZE_FILL
		keycap.custom_minimum_size.x = 172
		line.add_child(keycap)
		line.add_child(_label(entry[1], 16, true))

func _camera() -> void:
	for index: int in range(CameraProfile.MODES.size()):
		var mode: String = CameraProfile.MODES[index]
		var row: HBoxContainer = _row("CameraRow_" + mode, 14)
		row.add_child(_copy(CameraProfile.TITLES[index], CameraProfile.DESCRIPTIONS[index]))
		var choice: Button = _choice("Selected" if draft_camera == mode else "Select", draft_camera == mode, func() -> void:
			draft_camera = mode
			_changed()
			_show_section("camera"))
		choice.name = "Camera_" + mode
		choice.size_flags_horizontal = Control.SIZE_FILL
		choice.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		choice.custom_minimum_size.x = 150
		row.add_child(choice)
	var zoom_row: HBoxContainer = _row("SpeedZoomSettings", 14)
	zoom_row.add_child(_copy("Speed zoom", "Pull back slightly as speed increases."))
	var zoom := CheckButton.new()
	zoom.name = "CameraSpeedZoom"
	zoom.text = "On" if draft_speed_zoom else "Off"
	zoom.button_pressed = draft_speed_zoom
	zoom.custom_minimum_size = Vector2(150, 52)
	zoom.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	zoom.toggled.connect(func(on: bool) -> void:
		draft_speed_zoom = on
		zoom.text = "On" if on else "Off"
		_changed())
	zoom_row.add_child(zoom)
	body.add_child(_label("You can also change the view in Pause > Settings, or press C while driving.", 16, true))

func _haptics() -> void:
	var row: HBoxContainer = _row("HapticSettings", 18)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 16)
	row.add_child(column)
	column.add_child(_copy("Steering feedback", "Vibration when you press a steering button."))
	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", 8)
	column.add_child(choices)
	var titles: Array[String] = ["Off", "Light", "Medium", "Strong"]
	var values: Array[float] = [0.0, 0.2, 0.5, 1.0]
	for index: int in range(values.size()):
		var value: float = values[index]
		var choice: Button = _choice(titles[index], is_equal_approx(draft_haptics, value), func() -> void:
			draft_haptics = value
			_changed()
			_show_section("haptics"))
		choice.name = "Haptics" + titles[index]
		choices.add_child(choice)
	var info: HBoxContainer = _row("HapticInfo", 18)
	info.add_child(_icon("phone", 32))
	info.add_child(_copy("Feel the steering", "Feedback is available on supported phones. Apply a strength to try it."))

func _account() -> void:
	var row: HBoxContainer = _row("AccountSettings", 18)
	row.add_child(_icon("person", 36))
	row.add_child(_copy(player_name, "Signed in" if signed_in else "Race locally or sign in to share tracks and submit verified times."))
	var manage: Button = MenuStyle.button("Manage account" if signed_in else "Sign in", func() -> void: account_requested.emit())
	manage.name = "SettingsAccount"
	manage.custom_minimum_size.x = 180
	manage.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(manage)

func _changed() -> void:
	status.text = "Unapplied changes"
	status.add_theme_color_override("font_color", MenuStyle.ACCENT)

func _reset() -> void:
	if section == "camera":
		draft_camera = "overhead"
		draft_speed_zoom = true
	else:
		draft_layout = ControlLayout.preset()
		draft_haptics = 0.2
		draft_labels = true
	_changed()
	_show_section(section)

func _apply() -> bool:
	records.settings.control_layout = draft_layout.duplicate(true)
	records.settings.steering_haptics = draft_haptics
	records.settings.camera_mode = draft_camera
	records.settings.camera_speed_zoom = draft_speed_zoom
	records.settings.control_labels = draft_labels
	var error: Error = records.save_records()
	status.text = "Settings applied" if error == OK else "Could not save. Please try again."
	status.add_theme_color_override("font_color", MenuStyle.POSITIVE if error == OK else MenuStyle.ACCENT)
	if error == OK: TouchControls.SteeringHaptics.press(draft_haptics)
	return error == OK

func _customize() -> void:
	if _apply(): customize_requested.emit()

func _row(node_name: String, padding: int) -> HBoxContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.add_theme_stylebox_override("panel", _surface(padding, 0.72))
	body.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	panel.add_child(row)
	return row

func _copy(title: String, description: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	column.add_theme_constant_override("separation", 4)
	column.add_child(MenuStyle.label(title, 24))
	column.add_child(_label(description, 16, true))
	return column

func _choice(title: String, selected: bool, action: Callable) -> Button:
	var button: Button = MenuStyle.button(title, action)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 20)
	var style: StyleBoxFlat = _surface(10, 0.8)
	style.border_color = MenuStyle.ACCENT if selected else MenuStyle.BORDER
	style.set_border_width_all(2 if selected else 1)
	button.add_theme_stylebox_override("normal", style)
	if selected: button.add_theme_color_override("font_color", MenuStyle.ACCENT)
	return button

func _label(text: String, font_size: int, muted: bool = false) -> Label:
	var label: Label = MenuStyle.label(text, font_size, muted)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _icon(kind: String, dimension: int) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = MenuIcon.texture(kind)
	icon.custom_minimum_size = Vector2(dimension, dimension)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

func _surface(padding: int, opacity: float) -> StyleBoxFlat:
	var style: StyleBoxFlat = MenuStyle.card(padding)
	style.bg_color = Color(0.045, 0.09, 0.115, opacity)
	style.border_color = Color("263e4b")
	style.shadow_size = 0
	return style

func _draw_steering(art: Control) -> void:
	var center: Vector2 = art.size * 0.5
	var method: String = draft_layout.steering_type
	if method == "buttons":
		for index: int in range(2):
			art.draw_texture_rect_region(TouchControlArt.STEERING, Rect2(Vector2(40 + index * 84, 14), Vector2(60, 60)), Rect2(356 if index == 0 else 946, 220, 474, 456))
	elif method == "horizontal":
		art.draw_line(center - Vector2(78, 0), center + Vector2(78, 0), MenuStyle.BORDER, 8, true)
		art.draw_line(center - Vector2(78, 0), center, MenuStyle.ACCENT, 6, true)
		art.draw_circle(center, 15, MenuStyle.TEXT)
	else:
		art.draw_circle(center, 36, Color("142a37"))
		art.draw_arc(center, 36, 0, TAU, 48, MenuStyle.BORDER, 2, true)
		art.draw_circle(center, 18, MenuStyle.ACCENT)
