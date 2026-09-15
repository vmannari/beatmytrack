class_name RaceHUDStyle
extends RefCounted
## Illustrated-menu typography and ink colours, with compact racing spacing.

const INK := Color("091923")
const TEXT := Color("f1eee3")
const MUTED := Color("a4bac7")
const GOLD := Color("ffd15c")
const DISPLAY: Font = preload("res://assets/fonts/BarlowCondensed-SemiBold.ttf")
const BODY: Font = preload("res://assets/fonts/Barlow-Regular.ttf")

static func panel(accent: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("091923e8")
	style.border_color = GOLD if accent else Color("344e5d")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(12)
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

static func theme() -> Theme:
	var value := Theme.new()
	value.default_font = BODY
	value.default_font_size = 16
	value.set_font("font", "Button", DISPLAY)
	value.set_font_size("font_size", "Button", 20)
	for type: String in ["Button", "MenuButton"]:
		value.set_font("font", type, DISPLAY)
		value.set_font_size("font_size", type, 20)
		value.set_stylebox("normal", type, panel())
		value.set_stylebox("hover", type, panel(true))
		var pressed := panel(true)
		pressed.bg_color = GOLD
		value.set_stylebox("pressed", type, pressed)
		value.set_stylebox("focus", type, panel(true))
		value.set_color("font_color", type, TEXT)
		value.set_color("font_hover_color", type, TEXT)
		value.set_color("font_pressed_color", type, INK)
	value.set_stylebox("panel", "PopupMenu", panel())
	value.set_color("font_color", "PopupMenu", TEXT)
	return value
