class_name MenuStyle
extends RefCounted
## Shared menu palette and interaction states. Logical touch targets stay >= 52.

const INK := Color("080f16")
const PANEL := Color("101e29")
const TEXT := Color("f1f4f3")
const MUTED := Color("a4bac7")
const ACCENT := Color("ffd348")
const BORDER := Color("344e5d")
const POSITIVE := Color("66dfbb")
const POPUP_BORDER := Color("5c7d8a")
const POPUP_DIM := Color(0,0.015,0.025,0.58)
const DISPLAY: Font = preload("res://assets/fonts/BarlowCondensed-SemiBold.ttf")
const BODY: Font = preload("res://assets/fonts/Barlow-Regular.ttf")
static var _theme: Theme

static func box(color: Color, padding: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(5)
	style.set_content_margin_all(padding)
	return style

static func theme() -> Theme:
	if _theme != null: return _theme
	var value := Theme.new()
	value.default_font_size = 18
	value.default_font = BODY
	value.set_font("font","Button",DISPLAY)
	value.set_font_size("font_size","Button",23)
	value.set_color("font_color", "Label", TEXT)
	value.set_color("font_color", "Button", TEXT)
	value.set_color("font_hover_color", "Button", TEXT)
	value.set_color("font_pressed_color", "Button", INK)
	value.set_color("font_disabled_color", "Button", Color("758792"))
	value.set_stylebox("normal", "Button", box(PANEL))
	value.set_stylebox("hover", "Button", box(Color("284858")))
	value.set_stylebox("pressed", "Button", box(ACCENT.darkened(0.12)))
	value.set_stylebox("disabled", "Button", box(Color("15232d")))
	var focus := box(Color.TRANSPARENT)
	focus.border_color = ACCENT
	focus.set_border_width_all(2)
	value.set_stylebox("focus", "Button", focus)
	for state: String in ["normal","hover","pressed","focus","disabled"]:
		value.set_stylebox(state,"OptionButton",value.get_stylebox(state,"Button"))
	value.set_color("font_color","OptionButton",TEXT)
	value.set_stylebox("normal", "LineEdit", box(PANEL))
	value.set_stylebox("focus", "LineEdit", focus)
	value.set_color("font_color", "LineEdit", TEXT)
	value.set_color("font_placeholder_color", "LineEdit", MUTED)
	value.set_stylebox("panel", "PanelContainer", card())
	value.set_stylebox("panel", "PopupMenu", popup_panel(12))
	value.set_stylebox("panel", "PopupPanel", popup_panel(16))
	value.set_stylebox("panel", "TooltipPanel", popup_panel(10))
	value.set_color("font_color","TooltipLabel",TEXT)
	value.set_font_size("font_size","TooltipLabel",16)
	value.set_stylebox("panel", "AcceptDialog", card())
	value.set_color("font_color", "PopupMenu", TEXT)
	value.set_stylebox("hover", "PopupMenu", box(ACCENT,8))
	value.set_color("font_hover_color","PopupMenu",INK)
	value.set_constant("v_separation","PopupMenu",30)
	var line := StyleBoxLine.new()
	line.color = BORDER
	line.thickness = 1
	value.set_stylebox("separator", "HSeparator", line)
	value.set_stylebox("background", "ProgressBar", box(Color("213d4b"),0))
	value.set_stylebox("fill", "ProgressBar", box(ACCENT,0))
	value.set_constant("separation", "HBoxContainer", 12)
	value.set_constant("separation", "VBoxContainer", 12)
	_theme = value
	return value

static func card(padding: int = 20) -> StyleBoxFlat:
	var style := box(Color(0.035,0.095,0.13,0.95),padding)
	style.border_color = BORDER
	style.set_border_width_all(1)
	style.shadow_color = Color(0,0,0,0.22)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0,4)
	return style

static func popup_panel(padding: int = 20) -> StyleBoxFlat:
	var style := box(Color("071720"),padding)
	style.set_corner_radius_all(12)
	style.border_color = POPUP_BORDER
	style.set_border_width_all(1)
	style.shadow_color = Color(0,0,0,0.3)
	style.shadow_size = 8
	return style

static func label(text: String, font_size: int = 18, muted: bool = false) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", font_size)
	if font_size >= 24: node.add_theme_font_override("font",DISPLAY)
	if muted: node.add_theme_color_override("font_color", MUTED)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

static func button(text: String, action: Callable, primary: bool = false) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = 54
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.pressed.connect(action)
	node.set_meta("audio_cue", "confirm" if primary else "select")
	if primary:
		node.add_theme_stylebox_override("normal", box(ACCENT))
		node.add_theme_stylebox_override("hover", box(Color("ffe499")))
		node.add_theme_stylebox_override("pressed", box(Color("e7b744")))
		node.add_theme_color_override("font_color", INK)
		node.add_theme_color_override("font_hover_color", INK)
	return node

static func fill(node: Control) -> void:
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

static func tab(text: String, action: Callable, selected: bool = false) -> Button:
	var node: Button = button(text,action)
	var normal := box(Color(1,1,1,0.07) if selected else Color.TRANSPARENT,16)
	node.add_theme_stylebox_override("normal",normal)
	node.add_theme_stylebox_override("hover",box(Color(1,1,1,0.07),16))
	node.add_theme_color_override("font_color",ACCENT if selected else MUTED)
	return node

static func navigation(text: String, glyph: String, action: Callable, selected: bool) -> Button:
	var node: Button = tab(text,action,selected)
	# Keep the button's native name/text and focus while centring icon + caption together.
	for state: String in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
		node.add_theme_color_override(state,Color.TRANSPARENT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(center)
	fill(center)
	var group := HBoxContainer.new()
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.add_theme_constant_override("separation",12)
	center.add_child(group)
	var icon := TextureRect.new()
	icon.texture = MenuIcon.texture(glyph)
	icon.custom_minimum_size = Vector2(26,26)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate = ACCENT if selected else MUTED
	group.add_child(icon)
	var caption: Label = label(text,23)
	caption.add_theme_font_override("font",DISPLAY)
	caption.add_theme_color_override("font_color",ACCENT if selected else MUTED)
	group.add_child(caption)
	return node

static func time_text(seconds: float) -> String:
	var millis: int = roundi(seconds*1000.0)
	return "%02d:%02d.%03d" % [millis/60000,(millis/1000)%60,millis%1000]
