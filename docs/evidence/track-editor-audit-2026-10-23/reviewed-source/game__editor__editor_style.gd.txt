class_name EditorStyle
extends RefCounted
const FONT: Font = preload("res://assets/fonts/Barlow-Regular.ttf")
const INK := Color("e4eded")
const ACCENT := Color("18c8d7")

static func box(selected: bool = false, hover: bool = false, radius: int = 12) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = Color(0.045,0.23,0.27,0.96) if selected else Color(0.15,0.21,0.24,0.94) if hover else Color(0.055,0.10,0.12,0.93)
	result.border_color = ACCENT if selected else Color(0.55,0.68,0.73,0.25)
	result.set_border_width_all(1)
	result.set_corner_radius_all(radius)
	result.set_content_margin_all(8)
	result.shadow_color=Color(0,0,0,0.25)
	result.shadow_size=12
	result.shadow_offset=Vector2(0,4)
	return result

static func apply(control: Control, selected: bool = false) -> void:
	control.add_theme_font_override("font",FONT)
	control.add_theme_font_size_override("font_size",16)
	for state: String in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
		var style: StyleBoxFlat=box(selected or (control is BaseButton and control.toggle_mode and state in ["pressed","hover_pressed"]),state in ["hover","pressed"])
		if state=="disabled":
			style.bg_color=Color(0.045,0.07,0.08,0.9)
			style.border_color=Color.TRANSPARENT
		if state=="focus":
			style.bg_color=Color.TRANSPARENT; style.border_color=INK
			style.set_border_width_all(1)
		style.shadow_size=4 if selected or (control is BaseButton and control.toggle_mode and state in ["pressed","hover_pressed"]) else 0
		if style.shadow_size>0:
			style.shadow_color=Color(0.06,0.65,0.72,0.16)
			style.shadow_offset=Vector2.ZERO
		control.add_theme_stylebox_override(state,style)
	for state: String in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color"]: control.add_theme_color_override(state,INK)
	control.add_theme_color_override("font_disabled_color",Color("75888b"))
	control.add_theme_color_override("font_placeholder_color",Color("8a9a9d"))
	# Illustrated buttons draw their own caption alongside the glyph.
	if control is EditorButton:
		for state: String in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_disabled_color"]:
			control.add_theme_color_override(state,Color.TRANSPARENT)

static func button(text: String, action: Callable, selected: bool = false) -> Button:
	var result := Button.new()
	result.text=text
	result.custom_minimum_size=Vector2(66,38)
	result.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	apply(result,selected)
	result.pressed.connect(action)
	return result


static func transparent_button(control: Control) -> void:
	for state: String in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
		control.add_theme_stylebox_override(state,StyleBoxEmpty.new())

static func panel() -> StyleBoxFlat:
	var result: StyleBoxFlat = box()
	result.set_border_width_all(1)
	result.set_content_margin_all(8)
	result.border_width_top=2
	return result

static func integrated(control: Control, selected: bool = false) -> void:
	apply(control,selected)
	for state: String in ["normal","disabled"]:
		if not selected:
			var empty := StyleBoxFlat.new()
			empty.bg_color=Color.TRANSPARENT
			empty.set_content_margin_all(8)
			control.add_theme_stylebox_override(state,empty)

static func card(control: Control, selected: bool = false) -> void:
	apply(control,selected)
	for state: String in ["normal","hover"]:
		var surface: StyleBoxFlat=box(selected,state=="hover")
		if not selected:
			surface.bg_color=Color("2a3c43") if state=="hover" else Color("203139")
			surface.border_color=Color(0.47,0.62,0.67,0.22)
		surface.shadow_size=0
		control.add_theme_stylebox_override(state,surface)
