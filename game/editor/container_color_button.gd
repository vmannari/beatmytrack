class_name ContainerColorButton
extends RefCounted
## One picker transaction on close, avoiding repeated full-track rebuilds while dragging.
static func make(color: String, committed: Callable) -> ColorPickerButton:
	var button := ColorPickerButton.new()
	button.name = "ContainerColour"
	button.text = "Colour"
	button.tooltip_text = "Container colour"
	button.edit_alpha = false
	button.color = Color(color)
	button.custom_minimum_size = Vector2(112,48)
	EditorStyle.apply(button)
	button.get_picker().color_modes_visible = false
	button.get_picker().sliders_visible = false
	button.get_picker().sampler_visible = false
	for swatch: String in ContainerPaint.SWATCHES: button.get_picker().add_preset(Color(swatch))
	preload("res://ui/popup_style.gd").watch(button.get_popup())
	button.popup_closed.connect(func() -> void: committed.call(ContainerPaint.encode(button.color)))
	return button
