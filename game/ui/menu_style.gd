class_name MenuStyle
extends RefCounted
## Shared quiet menu language; logical touch targets are at least 52 units.

const INK := Color("172129")
const PANEL := Color("24333e")
const TEXT := Color("edf1f3")
const MUTED := Color("a6b1b8")

static func box(color: Color, padding: int = 16) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(6)
	style.set_content_margin_all(padding)
	return style

static func theme() -> Theme:
	var value := Theme.new()
	value.default_font_size = 18
	value.set_color("font_color", "Label", TEXT)
	value.set_color("font_color", "Button", TEXT)
	value.set_color("font_hover_color", "Button", TEXT)
	value.set_color("font_pressed_color", "Button", INK)
	value.set_stylebox("normal", "Button", box(PANEL))
	value.set_stylebox("hover", "Button", box(Color("354954")))
	value.set_stylebox("pressed", "Button", box(Color("cbd8dd")))
	var focus := box(Color.TRANSPARENT)
	focus.border_color = Color("cbd8dd")
	focus.set_border_width_all(2)
	value.set_stylebox("focus", "Button", focus)
	for state: String in ["normal","hover","pressed","focus"]:
		value.set_stylebox(state,"OptionButton",value.get_stylebox(state,"Button"))
	value.set_color("font_color","OptionButton",TEXT)
	value.set_stylebox("normal", "LineEdit", box(PANEL))
	value.set_stylebox("focus", "LineEdit", focus)
	value.set_color("font_color", "LineEdit", TEXT)
	value.set_constant("separation", "HBoxContainer", 12)
	value.set_constant("separation", "VBoxContainer", 12)
	return value

static func label(text: String, font_size: int = 18, muted: bool = false) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", font_size)
	if muted: node.add_theme_color_override("font_color", MUTED)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

static func button(text: String, action: Callable, primary: bool = false) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = 54
	node.pressed.connect(action)
	if primary:
		node.add_theme_stylebox_override("normal", box(Color("e0e7ed")))
		node.add_theme_stylebox_override("hover", box(Color("ffffff")))
		node.add_theme_color_override("font_color", INK)
		node.add_theme_color_override("font_hover_color", INK)
	return node

static func fill(node: Control) -> void:
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
