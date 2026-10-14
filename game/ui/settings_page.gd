class_name SettingsPage
extends HBoxContainer
## Presentation and staged preferences; canonical driving stays outside this page.
signal customize_requested
signal account_requested

var records: LocalRecords
var signed_in: bool = false
var player_name: String = "Guest"
var country_code: String = ""
var section: String = "controls"
var draft_layout: Dictionary
var draft_haptics: float = 0.2
var draft_camera: String = "overhead"
var draft_speed_zoom: bool = true
var draft_speed_zoom_strength: float = CameraProfile.DEFAULT_SPEED_ZOOM_STRENGTH
var draft_labels: bool = true
var draft_ghost: String = "lap"
var draft_show_ads: bool = false
var draft_simple_models: bool = false
var draft_audio: Dictionary = {}
var development_available: bool = OS.is_debug_build()
var ad_test_busy: bool = false
var ad_test_button: Button
var ad_adapter: Node
var purchase_client: Node
var body: VBoxContainer
var heading: Label
var subtitle: Label
var status: Label
var categories: Dictionary = {}
var reset_button: Button

const TITLES: Dictionary = {
	"controls": ["Controls", "Choose how you steer and arrange your touch controls."],
	"camera": ["Camera", "Choose the view you prefer while driving."],
	"graphics": ["Graphics", "Choose car detail while racing."],
	"ghosts": ["Ghosts", "Race against your own locally saved best."],
	"audio": ["Audio", "Balance the soundtrack, car sounds and menu feedback."],
	"haptics": ["Haptics", "Adjust the feedback from your steering buttons."],
	"account": ["Account", "Manage the profile you race with."],
	"development": ["Development", "Test ads and simulate purchases without payment."],
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
	draft_speed_zoom_strength = float(records.settings.get("camera_speed_zoom_strength", CameraProfile.DEFAULT_SPEED_ZOOM_STRENGTH))
	draft_labels = bool(records.settings.get("control_labels", true))
	draft_ghost = str(records.settings.get("ghost_mode", "lap"))
	draft_show_ads = bool(records.settings.get("development_show_ads", false))
	draft_simple_models = bool(records.settings.get("simple_car_models",false))
	for key: String in GameSoundtrack.DEFAULTS: draft_audio[key] = GameSoundtrack.preference(records.settings, key)
	ad_adapter = preload("res://platform/admob_test_ads.gd").new()
	add_child(ad_adapter)
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
	var category_scroll := ScrollContainer.new()
	category_scroll.name = "SettingsCategoryScroll"
	category_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	category_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(category_scroll)
	var category_list := VBoxContainer.new()
	category_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	category_list.add_theme_constant_override("separation", 10)
	category_scroll.add_child(category_list)
	for item: Array in [
		["controls", "Controls", "Steering and layout", "controller"],
		["camera", "Camera", "View and road ahead", "compass"],
		["graphics", "Graphics", "Car detail", "garage"],
		["ghosts", "Ghosts", "Your personal best", "garage"],
		["audio", "Audio", "Music and sound", "headphones"],
		["haptics", "Haptics", "Feedback and vibration", "phone"],
		["account", "Account", "Profile and sign-in", "person"],
		["development", "Development", "Ads and testing", "gear"],
	]:
		var id: String = item[0]
		if id == "development" and not development_available: continue
		var button: Button = MenuStyle.button("", _show_section.bind(id))
		button.name = "SettingsCategory_" + id
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		button.tooltip_text = item[1]
		button.custom_minimum_size.y = 66
		category_list.add_child(button)
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
	if id == "development" and not development_available: return
	section = id
	status.text = "Ad settings use Apply. Simulated purchases take effect immediately." if id == "development" else "Changes are saved when you apply them."
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
	reset_button.text = "Reset graphics" if id == "graphics" else "Reset audio" if id == "audio" else "Reset development" if id == "development" else "Reset ghosts" if id == "ghosts" else "Reset camera" if id == "camera" else "Reset controls"
	for child: Node in body.get_children():
		body.remove_child(child)
		child.queue_free()
	match id:
		"controls": _controls()
		"camera": _camera()
		"graphics": _graphics()
		"ghosts": _ghosts()
		"audio": _audio()
		"haptics": _haptics()
		"account": _account()
		"development": _development()
	_keep_category_visible(id)

func _graphics() -> void:
	var row: HBoxContainer = _row("CarDetailSettings",18)
	row.add_child(_copy("Simpler car models", "Use lighter car models and shadows from the next race. Garage previews keep full detail."))
	var toggle := CheckButton.new()
	toggle.name = "SimpleCarModels"
	toggle.text = "On" if draft_simple_models else "Off"
	toggle.button_pressed = draft_simple_models
	toggle.custom_minimum_size = Vector2(150,52)
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	toggle.toggled.connect(func(on: bool) -> void:
		draft_simple_models = on
		toggle.text = "On" if on else "Off"
		_changed())
	row.add_child(toggle)

func _keep_category_visible(id: String) -> void:
	await get_tree().process_frame
	if section != id or not is_inside_tree(): return
	var scroll: ScrollContainer = find_child("SettingsCategoryScroll", true, false)
	scroll.ensure_control_visible(categories[id].button)

func _development() -> void:
	var row: HBoxContainer = _row("DevelopmentAds", 18)
	row.add_child(_copy("Show ads", "Show AdMob test ads for ad-backed resumes. Off keeps development resumes free."))
	var toggle := CheckButton.new()
	toggle.name = "DevelopmentShowAds"
	toggle.text = "On" if draft_show_ads else "Off"
	toggle.button_pressed = draft_show_ads
	toggle.custom_minimum_size = Vector2(150, 52)
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	toggle.toggled.connect(func(on: bool) -> void:
		draft_show_ads = on
		if not on: ad_adapter.cancel()
		toggle.text = "On" if on else "Off"
		if is_instance_valid(ad_test_button): ad_test_button.disabled = not on or ad_test_busy or not preload("res://platform/admob_test_ads.gd").supported()
		_changed())
	row.add_child(toggle)
	var test_row: HBoxContainer = _row("DevelopmentAdTest", 18)
	test_row.add_child(_copy("Rewarded ad test", "Preview a test ad here. This does not spend or add resumes."))
	ad_test_button = MenuStyle.button("Test rewarded ad", _test_rewarded_ad)
	ad_test_button.name = "TestRewardedAd"
	ad_test_button.custom_minimum_size = Vector2(226, 52)
	ad_test_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ad_test_button.disabled = not draft_show_ads or ad_test_busy or not preload("res://platform/admob_test_ads.gd").supported()
	test_row.add_child(ad_test_button)
	body.add_child(_label("Google test ads only. Banked and daily free resumes are used first. These options are available in development builds.", 16, true))
	if not preload("res://platform/admob_test_ads.gd").supported():
		body.add_child(_label("Ad previews are available on Android with the AdMob development build.", 16, true))
	var purchases := preload("res://ui/purchase_simulator_panel.gd").new()
	purchases.client = purchase_client
	body.add_child(purchases)
	var console: Button = MenuStyle.button("Open backend console",func() -> void:
		if is_instance_valid(purchase_client): OS.shell_open(purchase_client.base_url()+"/admin"))
	console.name = "OpenBackendConsole"
	console.disabled = not is_instance_valid(purchase_client) or purchase_client.base_url().is_empty()
	body.add_child(console)
	body.add_child(_label("The backend console uses a separate administrator credential.",16,true))

func _test_rewarded_ad() -> void:
	if ad_test_busy or not draft_show_ads or not _apply(): return
	ad_test_busy = true
	ad_test_button.disabled = true
	status.text = "Loading test ad…"
	var result: Dictionary = await ad_adapter.show_rewarded()
	ad_test_busy = false
	if is_instance_valid(ad_test_button): ad_test_button.disabled = not draft_show_ads
	status.text = "Test ad completed. No resumes added." if result.ok else str(result.get("error", "Ad unavailable. Please retry."))
	status.add_theme_color_override("font_color", MenuStyle.POSITIVE if result.ok else MenuStyle.ACCENT)

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
	zoom_row.add_child(_copy("Speed zoom", "Show more road as speed increases."))
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
	var strength_row: HBoxContainer = _row("SpeedZoomStrengthSettings", 14)
	strength_row.add_child(_copy("Zoom strength", "Maximum extra view at high speed."))
	var strength_column := VBoxContainer.new()
	strength_column.custom_minimum_size.x = 220
	strength_column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	strength_row.add_child(strength_column)
	var value: Label = _label("%d%%" % roundi(draft_speed_zoom_strength * 100.0), 18)
	value.name = "CameraSpeedZoomStrengthValue"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	strength_column.add_child(value)
	var strength := HSlider.new()
	strength.name = "CameraSpeedZoomStrength"
	strength.max_value = CameraProfile.MAX_SPEED_ZOOM_STRENGTH * 100.0
	strength.step = 1.0
	strength.value = draft_speed_zoom_strength * 100.0
	strength.custom_minimum_size = Vector2(220, 52)
	strength.editable = draft_speed_zoom
	strength.modulate.a = 1.0 if draft_speed_zoom else 0.45
	strength.value_changed.connect(func(amount: float) -> void:
		draft_speed_zoom_strength = amount / 100.0
		value.text = "%d%%" % roundi(amount)
		_changed())
	zoom.toggled.connect(func(on: bool) -> void:
		strength.editable = on
		strength.modulate.a = 1.0 if on else 0.45)
	strength_column.add_child(strength)
	body.add_child(_label("You can also change the view in Pause > Settings, or press C while driving.", 16, true))

func _ghosts() -> void:
	for index: int in range(PersonalGhostRun.MODES.size()):
		var mode: String = PersonalGhostRun.MODES[index]
		var row: HBoxContainer = _row("GhostRow_" + mode, 14)
		row.add_child(_copy(PersonalGhostRun.TITLES[index], PersonalGhostRun.DESCRIPTIONS[index]))
		var choice: Button = _choice("Selected" if draft_ghost == mode else "Select", draft_ghost == mode, func() -> void:
			draft_ghost = mode
			_changed()
			_show_section("ghosts"))
		choice.name = "Ghost_" + mode
		choice.custom_minimum_size.x = 150
		choice.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(choice)
	body.add_child(_label("Ghosts are saved after completed races, separately for each track, car and handling setup. Existing times need a matching or better run to create a ghost. You can change this in Pause > Settings.", 16, true))

func _audio() -> void:
	for item: Array in [
		["music_volume", "Music", "Menus and results."],
		["vehicle_volume", "Vehicle", "Engines, tyres, road and collisions."],
		["interface_volume", "Interface", "Menu selections and confirmations."],
	]:
		var key: String = item[0]
		var row: HBoxContainer = _row("AudioRow_" + key, 18)
		row.add_child(_copy(item[1], item[2]))
		var column := VBoxContainer.new()
		column.custom_minimum_size.x = 250
		column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(column)
		var value: Label = _label("%d%%" % roundi(float(draft_audio[key]) * 100.0), 18)
		value.name = "AudioValue_" + key
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		column.add_child(value)
		var slider := HSlider.new()
		slider.name = "AudioVolume_" + key
		slider.min_value = 0.0
		slider.max_value = 100.0
		slider.step = 1.0
		slider.value = float(draft_audio[key]) * 100.0
		slider.custom_minimum_size = Vector2(250, 52)
		slider.value_changed.connect(func(amount: float) -> void:
			draft_audio[key] = amount / 100.0
			value.text = "%d%%" % roundi(amount)
			_changed())
		column.add_child(slider)


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
	if signed_in: row.add_child(PlayerCountry.flag(country_code,32))
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
	if section == "graphics":
		draft_simple_models = false
	elif section == "audio":
		draft_audio = GameSoundtrack.DEFAULTS.duplicate()
	elif section == "development":
		draft_show_ads = false
		ad_adapter.cancel()
	elif section == "ghosts":
		draft_ghost = "lap"
	elif section == "camera":
		draft_camera = "overhead"
		draft_speed_zoom = true
		draft_speed_zoom_strength = CameraProfile.DEFAULT_SPEED_ZOOM_STRENGTH
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
	records.settings.camera_speed_zoom_strength = draft_speed_zoom_strength
	records.settings.control_labels = draft_labels
	records.settings.ghost_mode = draft_ghost
	records.settings.simple_car_models = draft_simple_models
	for key: String in draft_audio: records.settings[key] = draft_audio[key]
	if development_available: records.settings.development_show_ads = draft_show_ads
	var error: Error = records.save_records()
	status.text = "Settings applied" if error == OK else "Could not save. Please try again."
	status.add_theme_color_override("font_color", MenuStyle.POSITIVE if error == OK else MenuStyle.ACCENT)
	if error == OK: GameSoundtrack.instance().apply_settings(records.settings)
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
