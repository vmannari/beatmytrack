extends Control
## Race-only overlay. Simulation pausing is owned by the game, never the scene tree.
var hud: PlaygroundHUD
var column: VBoxContainer
var frozen: TextureRect
var drawer: PanelContainer
var settings_overlay: Control
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
	dim.color = MenuStyle.POPUP_DIM
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
	preload("res://ui/popup_style.gd").decorate_panel(drawer)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	drawer.add_child(scroll)
	var content := MarginContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("margin_right",16)
	scroll.add_child(content)
	column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",12)
	content.add_child(column)
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
	close.custom_minimum_size = Vector2(52,52)
	close.flat = true
	close.pressed.connect(func() -> void: hud.pause_requested.emit())
	header.add_child(close)
	var line := HSeparator.new()
	column.add_child(line)

func show_main() -> void:
	close_settings()
	_clear("PAUSED")
	_row("Resume","Continue driving" if hud.free_drive_mode else "Continue the race","play",func() -> void: hud.pause_requested.emit(), MenuStyle.ACCENT)
	_row("Restart","Return the car to the hall entrance" if hud.free_drive_mode else "Start this race again","restart",func() -> void: hud.restart_requested.emit())
	_row("Settings","Camera, sound and controls","gear",_settings)
	if hud.map_track != null and hud.map_track.metadata.has("cloud_version") and is_instance_valid(hud.community_client):
		_row("Report track","Send a private content report","flag",func() -> void: preload("res://ui/community_safety_ui.gd").open(self,hud.community_client,"report",preload("res://ui/community_safety_ui.gd").track_target(hud.map_track)))
	_row("Help","Driving tips and controls","help",_help)
	column.add_child(HSeparator.new())
	_row("Quit","Return to garage" if hud.free_drive_mode else "Return to editor" if hud.editor_test else "Return to main menu","quit",func() -> void: hud.exit_requested.emit(),Color("ef6268"))

func _row(title: String, subtitle: String, icon: String, action: Callable, accent: Color = Color("91a8b8")) -> Button:
	var button := preload("res://ui/content_fit_button.gd").new()
	button.name = title.replace(" ","")
	button.custom_minimum_size = Vector2(0,70)
	button.pressed.connect(action)
	for state: String in ["normal","hover","pressed","focus","disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("0d202e") if state == "normal" else Color("18394f")
		if title == "Resume": style.bg_color = MenuStyle.ACCENT.lightened(0.06) if state == "hover" else MenuStyle.ACCENT
		if state == "disabled": style.bg_color = Color("0b1924")
		if title == "Quit": style.bg_color = Color("2b1923")
		style.set_corner_radius_all(10)
		style.set_border_width_all(1)
		style.border_color = accent if title in ["Resume","Quit"] or state == "hover" else Color("203746")
		button.add_theme_stylebox_override(state,style)
	column.add_child(button)
	# Button children do not contribute to its minimum size. Let the padded
	# content determine the row height after fonts or wrapped text change.
	var content := MarginContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_theme_constant_override("margin_left",18)
	content.add_theme_constant_override("margin_right",18)
	content.add_theme_constant_override("margin_top",10)
	content.add_theme_constant_override("margin_bottom",10)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(content)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(row)
	var glyph := TextureRect.new()
	glyph.texture = preload("res://ui/icons/rewind.svg") if icon == "restart" else MenuIcon.texture(icon)
	# Mirror the return arrow for a clockwise restart, distinct from rewind.
	glyph.flip_h = icon == "restart"
	glyph.custom_minimum_size = Vector2(30,30)
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.modulate = MenuStyle.INK if title == "Resume" else accent if title == "Quit" else Color.WHITE
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(glyph)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation",2)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)
	var heading := MenuStyle.label(title,24)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if title == "Resume": heading.add_theme_color_override("font_color",MenuStyle.INK)
	heading.add_theme_font_override("font",MenuStyle.DISPLAY)
	words.add_child(heading)
	var description := MenuStyle.label(subtitle,14,true)
	if title == "Resume": description.add_theme_color_override("font_color",MenuStyle.INK)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(description)
	var arrow := MenuStyle.label("›",28)
	if title == "Resume": arrow.add_theme_color_override("font_color",MenuStyle.INK)
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(arrow)
	for label: Control in [heading,description,arrow]: label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.watch_content(content,70)
	return button

func _help() -> void:
	_clear("DRIVING HELP")
	var text := MenuStyle.label("Steer with the on-screen controls or A / D and the arrow keys.\n\nUse the accelerator to drive and the brake to slow down or reverse. Keyboard: W / S and Space.\n\nPass every checkpoint in order. If you miss one, return to it to continue your lap.\n\nPress C to cycle camera views. Esc opens and closes this menu. Restart begins a fresh attempt.",20)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if hud.free_drive_mode:
		text.text = "Drive freely with the on-screen controls or W / A / S / D and the arrow keys. Brake to slow down or reverse; Space applies the handbrake.\n\nExplore the parking bays, slalom and open turning area. The long marked lane is for acceleration and braking. There is no timer or lap target.\n\nReset car returns to the entrance. Press C to cycle cameras and Esc to pause. Garage returns to your car."
	column.add_child(text)
	_row("Back","Return to pause menu","arrow",show_main)

func _settings() -> void:
	close_settings()
	drawer.hide()
	settings_overlay = preload("res://ui/race_settings_overlay.gd").new()
	settings_overlay.game = hud.get_parent()
	settings_overlay.closed.connect(show_main)
	add_child(settings_overlay)

func settings_open() -> bool:
	return is_instance_valid(settings_overlay)

func settings_back() -> void:
	if settings_open(): settings_overlay.go_back()

func close_settings() -> void:
	if settings_open():
		remove_child(settings_overlay)
		settings_overlay.queue_free()
		settings_overlay = null
	if is_instance_valid(drawer): drawer.show()

func capture_race() -> void:
	if DisplayServer.get_name() == "headless": return
	var snapshot: Image = get_viewport().get_texture().get_image()
	if snapshot != null and not snapshot.is_empty(): frozen.texture = ImageTexture.create_from_image(snapshot)
