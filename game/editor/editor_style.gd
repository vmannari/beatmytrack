class_name EditorStyle
extends RefCounted
const FONT: Font = preload("res://assets/fonts/Barlow-Regular.ttf")
const INK := Color("e8eef0")
const MUTED := Color("a1afb5")
const ACCENT := Color("18c8d7")
const SHELL := Color("121d22")
const TILE := Color("1c2b32")
const HOVER := Color("263a43")
const EDGE := Color("354851")

static func box(selected: bool = false, hover: bool = false, radius: int = 6) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = HOVER if hover else TILE
	result.border_color = ACCENT if selected else EDGE
	result.set_border_width_all(2 if selected else 1)
	result.set_corner_radius_all(radius)
	result.set_content_margin_all(8)
	return result

static func apply(control: Control, selected: bool = false) -> void:
	control.add_theme_font_override("font",FONT)
	control.add_theme_font_size_override("font_size",16)
	for state: String in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
		var active: bool = selected or (control is BaseButton and control.toggle_mode and state in ["pressed","hover_pressed"])
		var style: StyleBoxFlat = box(active,state in ["hover","pressed","hover_pressed"])
		if control is ColorPickerButton and state != "focus":
			var inset: float = maxf(8,(maxf(control.custom_minimum_size.x,control.size.x)-26)*0.5)
			style.content_margin_left = inset; style.content_margin_right = inset
			style.content_margin_top = 5; style.content_margin_bottom = 25
		if state == "disabled": style.border_color = Color(EDGE,0.45)
		if state == "focus":
			style.bg_color = Color.TRANSPARENT
			style.border_color = INK
		control.add_theme_stylebox_override(state,style)
	for state: String in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color"]: control.add_theme_color_override(state,INK)
	control.add_theme_color_override("font_disabled_color",MUTED)
	control.add_theme_color_override("font_placeholder_color",MUTED)
	if control is EditorButton:
		for state: String in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_disabled_color"]:
			control.add_theme_color_override(state,Color.TRANSPARENT)

static func button(text: String, action: Callable, selected: bool = false) -> Button:
	var result := Button.new()
	result.text=text
	result.toggle_mode = selected
	result.button_pressed = selected
	result.custom_minimum_size=Vector2(66,48)
	result.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	apply(result,selected)
	result.pressed.connect(action)
	return result


static func transparent_button(control: Control) -> void:
	for state: String in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
		control.add_theme_stylebox_override(state,StyleBoxEmpty.new())

static func panel() -> StyleBoxFlat:
	var result: StyleBoxFlat = box(false,false,8)
	result.bg_color = SHELL
	return result

static func workspace_panel() -> StyleBoxFlat:
	var result: StyleBoxFlat = panel()
	result.content_margin_top = 4
	result.content_margin_bottom = 4
	return result

static func quiet(control: Control, selected: bool = false) -> void:
	apply(control,selected)
	for state: String in ["normal","disabled"]:
		if selected: continue
		var style: StyleBoxFlat = control.get_theme_stylebox(state).duplicate()
		style.bg_color = Color.TRANSPARENT
		style.border_color = Color.TRANSPARENT
		control.add_theme_stylebox_override(state,style)

static func integrated(control: Control, selected: bool = false) -> void:
	card(control,selected)

static func card(control: Control, selected: bool = false) -> void:
	apply(control,selected)

static func popup(popup_menu: PopupMenu) -> void:
	popup_menu.set_meta("menu_popup_custom",true)
	popup_menu.add_theme_stylebox_override("panel",panel())
	popup_menu.add_theme_stylebox_override("hover",box(true,true))
	popup_menu.add_theme_font_override("font",FONT)
	popup_menu.add_theme_font_size_override("font_size",16)
	popup_menu.add_theme_color_override("font_color",INK)
	popup_menu.add_theme_color_override("font_hover_color",INK)
	popup_menu.add_theme_color_override("font_disabled_color",MUTED)
	popup_menu.add_theme_constant_override("v_separation",30)

static func menu_tree(parent: Node) -> void:
	for control: Node in parent.get_children():
		if control is BaseButton:
			card(control,control.button_pressed)
			control.custom_minimum_size.y = maxf(48,control.custom_minimum_size.y)
			if control is OptionButton: popup(control.get_popup())
		elif control is LineEdit: apply(control)
		elif control is Label:
			control.add_theme_font_override("font",FONT)
			control.add_theme_font_size_override("font_size",16)
			control.add_theme_color_override("font_color",INK)
		menu_tree(control)
