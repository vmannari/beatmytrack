class_name ContainerColorButton
extends RefCounted
## One picker transaction on close, avoiding repeated full-track rebuilds while dragging.
static func make(color: String, committed: Callable) -> ColorPickerButton:
	var button := ColorPickerButton.new()
	button.name = "ContainerColour"
	button.text = ""
	button.accessibility_name = GameText.message("Container colour")
	button.tooltip_text = "Container colour"
	button.edit_alpha = false
	button.color = Color(color)
	button.custom_minimum_size = Vector2(112,56)
	EditorStyle.apply(button)
	var caption: Label = MenuStyle.label("Colour",16)
	caption.name = "ToolCaption"
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_color_override("font_color",EditorStyle.INK)
	button.add_child(caption)
	caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	caption.offset_left = 4; caption.offset_right = -4
	caption.offset_top = -25; caption.offset_bottom = -3
	button.get_picker().color_modes_visible = false
	button.get_picker().sliders_visible = false
	button.get_picker().sampler_visible = false
	for swatch: String in ContainerPaint.SWATCHES: button.get_picker().add_preset(Color(swatch))
	preload("res://ui/popup_style.gd").watch(button.get_popup())
	var popup: PopupPanel = button.get_popup()
	popup.add_theme_stylebox_override("panel",EditorStyle.panel())
	var theme: Theme = MenuStyle.theme().duplicate()
	for type: String in ["Label","Button","LineEdit","OptionButton"]:
		theme.set_font("font",type,EditorStyle.FONT)
		theme.set_font_size("font_size",type,16)
		theme.set_color("font_color",type,EditorStyle.INK)
	popup.theme = theme
	button.popup_closed.connect(func() -> void: committed.call(ContainerPaint.encode(button.color)))
	return button
