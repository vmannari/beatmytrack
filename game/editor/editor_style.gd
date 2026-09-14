class_name EditorStyle
extends RefCounted
const FONT: Font = preload("res://assets/fonts/Barlow-Regular.ttf")
const INK := Color("e4eded")
const ACCENT := Color("18c8d7")

static func box(selected: bool = false, hover: bool = false, radius: int = 10) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = Color("075766") if selected else Color("192c33") if hover else Color(0.035,0.065,0.078,0.96)
	result.border_color = ACCENT if selected else Color("42575d")
	result.set_border_width_all(2 if selected else 1)
	result.set_corner_radius_all(radius)
	result.set_content_margin_all(8)
	result.shadow_color=Color(0,0,0,0.18)
	result.shadow_size=3
	result.shadow_offset=Vector2(0,2)
	return result

static func apply(control: Control, selected: bool = false) -> void:
	control.add_theme_font_override("font",FONT)
	control.add_theme_font_size_override("font_size",16)
	for state: String in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
		var style: StyleBoxFlat=box(selected or state in ["pressed","hover_pressed"],state=="hover")
		if state=="disabled":
			style.bg_color=Color(0.045,0.07,0.08,0.9)
			style.border_color=Color("33464b")
		if state=="focus": style.bg_color=Color.TRANSPARENT; style.border_color=ACCENT
		control.add_theme_stylebox_override(state,style)
	for state: String in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color"]: control.add_theme_color_override(state,INK)
	control.add_theme_color_override("font_disabled_color",Color("75888b"))
	control.add_theme_color_override("font_placeholder_color",Color("8a9a9d"))

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
