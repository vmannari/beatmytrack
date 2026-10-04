extends Control
## Race-only overlay. Simulation pausing is owned by the game, never the scene tree.
var hud: PlaygroundHUD
var column: VBoxContainer
var frozen: TextureRect
var drawer: PanelContainer
const BLUE := Color("35c4ff")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = MenuStyle.theme()
	frozen = TextureRect.new()
	frozen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frozen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){ vec4 c = texture(TEXTURE, UV); float gray = dot(c.rgb, vec3(0.299,0.587,0.114)); COLOR = vec4(vec3(gray),c.a); }"
	var material := ShaderMaterial.new()
	material.shader = shader
	frozen.material = material
	add_child(frozen)
	var dim := ColorRect.new()
	dim.color = Color(0.015,0.025,0.04,0.18)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	drawer = PanelContainer.new()
	drawer.name = "PauseDrawer"
	drawer.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	drawer.offset_left = -370
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("061421")
	panel.border_color = Color("24536b")
	panel.border_width_left = 1
	panel.content_margin_left = 22
	panel.content_margin_right = 22
	panel.content_margin_top = 22
	panel.content_margin_bottom = 22
	drawer.add_theme_stylebox_override("panel",panel)
	add_child(drawer)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	drawer.add_child(scroll)
	column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",12)
	scroll.add_child(column)
	resized.connect(_resize)
	_resize()
	show_main()

func _resize() -> void:
	drawer.offset_left = -clampf(size.x * 0.29, 340, 470)

func _clear(title: String) -> void:
	for child: Node in column.get_children():
		column.remove_child(child)
		child.queue_free()
	var header := HBoxContainer.new()
	column.add_child(header)
	var brand := MenuStyle.label(title,34)
	brand.add_theme_font_override("font",MenuStyle.DISPLAY)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(brand)
	var close := Button.new()
	close.name = "ClosePauseMenu"
	close.icon = MenuIcon.texture("close")
	close.expand_icon = true
	close.custom_minimum_size = Vector2(48,48)
	close.flat = true
	close.pressed.connect(func() -> void: hud.pause_requested.emit())
	header.add_child(close)
	var line := HSeparator.new()
	column.add_child(line)

func show_main() -> void:
	_clear("BEAT\nMY TRACK.")
	_row("Resume","Continue the race","play",func() -> void: hud.pause_requested.emit(), BLUE)
	_row("Restart","Start this race again","restart",func() -> void: hud.restart_requested.emit())
	_row("Settings","Camera, sound and controls","gear",_settings)
	var report := _row("Report track","Reporting is not available yet","flag",func() -> void: pass)
	report.disabled = true
	_row("Help","Driving tips and controls","help",_help)
	column.add_child(HSeparator.new())
	_row("Quit","Return to editor" if hud.editor_test else "Return to main menu","quit",func() -> void: hud.exit_requested.emit(),Color("ef6268"))

func _row(title: String, subtitle: String, icon: String, action: Callable, accent: Color = Color("91a8b8")) -> Button:
	var button := Button.new()
	button.name = title.replace(" ","")
	button.custom_minimum_size = Vector2(0,70)
	button.pressed.connect(action)
	for state: String in ["normal","hover","pressed","focus","disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("0d202e") if state == "normal" else Color("18394f")
		if title == "Resume": style.bg_color = Color("0d304d")
		if state == "disabled": style.bg_color = Color("0b1924")
		if title == "Quit": style.bg_color = Color("2b1923")
		style.set_corner_radius_all(10)
		style.set_border_width_all(1)
		style.border_color = accent if title in ["Resume","Quit"] or state == "hover" else Color("203746")
		button.add_theme_stylebox_override(state,style)
	column.add_child(button)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 18
	row.offset_right = -18
	row.add_theme_constant_override("separation",18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)
	var glyph := TextureRect.new()
	glyph.texture = preload("res://ui/icons/rewind.svg") if icon == "restart" else MenuIcon.texture(icon)
	# Mirror the return arrow for a clockwise restart, distinct from rewind.
	glyph.flip_h = icon == "restart"
	glyph.custom_minimum_size = Vector2(30,30)
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.modulate = accent if title in ["Resume","Quit"] else Color.WHITE
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(glyph)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)
	var heading := MenuStyle.label(title,24)
	heading.add_theme_font_override("font",MenuStyle.DISPLAY)
	words.add_child(heading)
	var description := MenuStyle.label(subtitle,14,true)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(description)
	var arrow := MenuStyle.label("›",28)
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(arrow)
	for label: Control in [heading,description,arrow]: label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return button

func _help() -> void:
	_clear("DRIVING HELP")
	var text := MenuStyle.label("Steer with the on-screen controls or A / D and the arrow keys.\n\nUse the accelerator to drive and the brake to slow down or reverse. Keyboard: W / S and Space.\n\nPass every checkpoint in order. If you miss one, return to it to continue your lap.\n\nPress C to cycle camera views. Esc opens and closes this menu. Restart begins a fresh attempt.",20)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(text)
	_row("Back","Return to pause menu","arrow",show_main)

func _settings() -> void:
	_clear("RACE SETTINGS")
	var audio := CheckButton.new()
	audio.text = "Sound"
	audio.button_pressed = not AudioServer.is_bus_mute(0)
	audio.toggled.connect(func(on: bool) -> void: AudioServer.set_bus_mute(0,not on))
	column.add_child(audio)
	column.add_child(MenuStyle.label("Camera",22))
	var camera_choice := OptionButton.new()
	camera_choice.name = "RaceCameraMode"
	camera_choice.custom_minimum_size.y = 52
	for title: String in CameraProfile.TITLES: camera_choice.add_item(title)
	var game: Node = hud.get_parent()
	var camera_index: int = CameraProfile.MODES.find(game.camera.mode)
	camera_choice.select(camera_index)
	var camera_description: Label = MenuStyle.label(CameraProfile.DESCRIPTIONS[camera_index], 16, true)
	camera_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	camera_choice.item_selected.connect(func(index: int) -> void:
		var error: Error = game.set_camera_mode(CameraProfile.MODES[index])
		camera_description.text = CameraProfile.DESCRIPTIONS[index]
		status.text = "Camera changed" if error == OK else "Camera changed for this race. Could not save preference."
	)
	column.add_child(camera_choice)
	column.add_child(camera_description)
	var speed_zoom := CheckButton.new()
	speed_zoom.name = "RaceSpeedZoom"
	speed_zoom.text = "Speed zoom"
	speed_zoom.custom_minimum_size.y = 52
	speed_zoom.button_pressed = game.camera.speed_zoom_enabled
	speed_zoom.toggled.connect(func(on: bool) -> void:
		var error: Error = game.set_camera_speed_zoom(on)
		status.text = "Speed zoom changed" if error == OK else "Zoom changed for this race. Could not save preference."
	)
	column.add_child(speed_zoom)
	if game.personal_ghost != null:
		column.add_child(MenuStyle.label("Ghost",22))
		var ghost_choice := OptionButton.new()
		ghost_choice.name = "RaceGhostMode"
		ghost_choice.custom_minimum_size.y = 52
		for title: String in PersonalGhostRun.TITLES: ghost_choice.add_item(title)
		ghost_choice.select(PersonalGhostRun.MODES.find(game.ghost_mode))
		var ghost_description: Label = MenuStyle.label(game.ghost_description(),16,true)
		ghost_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ghost_choice.item_selected.connect(func(index: int) -> void:
			var error: Error = game.set_ghost_mode(PersonalGhostRun.MODES[index])
			ghost_description.text = game.ghost_description()
			status.text = "Ghost changed" if error == OK else "Ghost changed for this race. Could not save preference."
		)
		column.add_child(ghost_choice)
		column.add_child(ghost_description)
	column.add_child(MenuStyle.label("Steering",22))
	var steering := OptionButton.new()
	for title: String in ["Buttons","Horizontal slider","Joystick"]: steering.add_item(title)
	var layout: Dictionary = hud.touch.layout if not hud.touch.layout.is_empty() else ControlLayout.preset()
	steering.select(ControlLayout.METHODS.find(str(layout.steering_type)))
	steering.item_selected.connect(func(index: int) -> void:
		var changed: Dictionary = layout.duplicate(true)
		changed.steering_type = ControlLayout.METHODS[index]
		hud.touch.layout = changed
		var records: LocalRecords = hud.get_parent().rating_records
		if records != null:
			records.settings.control_layout = changed
			if records.save_records() != OK: status.text = "Could not save controls."
	)
	column.add_child(steering)
	status = MenuStyle.label("Sound applies to this session. Driving preferences are saved when available.",16,true)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status)
	_row("Back","Return to pause menu","arrow",show_main)

var status: Label

func capture_race() -> void:
	if DisplayServer.get_name() == "headless": return
	var snapshot: Image = get_viewport().get_texture().get_image()
	if snapshot != null and not snapshot.is_empty(): frozen.texture = ImageTexture.create_from_image(snapshot)
