extends RefCounted
## Shared materials and state treatments for the Garage's native workbenches.
const SURFACE := Color("101a22")
const EDGE := Color("36444c")
const SOFT := Color("9eafb7")

static func panel(padding: int = 16) -> StyleBoxFlat:
	var style := MenuStyle.box(Color("0c151d"),padding)
	style.set_corner_radius_all(12)
	style.border_color = EDGE
	style.set_border_width_all(1)
	style.border_width_top = 2
	style.shadow_color = Color(0,0,0,0.28)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0,6)
	return style

static func tile(button: Button, selected: bool, radius: int = 10) -> void:
	for state: String in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
		var style := MenuStyle.box(Color("1d2b34") if selected else SURFACE,0)
		style.set_corner_radius_all(radius)
		style.border_color = MenuStyle.ACCENT if selected else EDGE
		style.set_border_width_all(2 if selected else 1)
		if state in ["hover","hover_pressed"]:
			style.bg_color = Color("2a3942")
			style.border_color = Color("bbc8ca") if not selected else MenuStyle.ACCENT
		elif state == "pressed": style.bg_color = Color("374149")
		elif state == "focus":
			style.bg_color = Color.TRANSPARENT
			style.border_color = MenuStyle.ACCENT
			style.set_border_width_all(2)
			style.set_expand_margin_all(-3)
		button.add_theme_stylebox_override(state,style)
	for state: String in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_hover_pressed_color","icon_normal_color","icon_hover_color","icon_pressed_color","icon_focus_color","icon_hover_pressed_color"]:
		button.add_theme_color_override(state,MenuStyle.TEXT)

static func tab(button: Button, selected: bool) -> void:
	for state: String in ["normal","hover","pressed","hover_pressed","focus"]:
		var style := MenuStyle.box(Color("172832") if selected or state == "hover" else Color("101c25"),4)
		style.set_corner_radius_all(3)
		style.border_color = MenuStyle.ACCENT if selected or state == "focus" else EDGE
		style.set_border_width_all(1)
		style.border_width_bottom = 2 if selected or state == "focus" else 1
		button.add_theme_stylebox_override(state,style)
	for state: String in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_hover_pressed_color"]:
		button.add_theme_color_override(state,MenuStyle.ACCENT if selected else MenuStyle.TEXT)

static func header(parent: Control, title: String, reset: Button) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	parent.add_child(row)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation",1)
	row.add_child(stack)
	var heading: Label = MenuStyle.label(title,30)
	heading.name = "StudioTitle"
	stack.add_child(heading)
	reset.custom_minimum_size = Vector2(48,48)
	tile(reset,false,8)
	row.add_child(reset)
