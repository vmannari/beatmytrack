extends CanvasLayer
## Lightweight, cancellable feedback before a feature's resource graph loads.
signal cancelled

func _ready() -> void:
	layer = 79
	var surface := PanelContainer.new()
	surface.name = "FeatureLoadingScreen"
	surface.theme = MenuStyle.theme()
	surface.add_theme_stylebox_override("panel",MenuStyle.box(MenuStyle.INK,0))
	add_child(surface)
	MenuStyle.fill(surface)
	var center := CenterContainer.new()
	surface.add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 320
	column.add_theme_constant_override("separation",24)
	center.add_child(column)
	column.add_child(MenuBrand.new())
	var activity := ProgressBar.new()
	activity.name = "FeatureLoadingActivity"
	activity.custom_minimum_size.y = 5
	activity.show_percentage = false
	activity.indeterminate = true
	column.add_child(activity)
	var cancel := MenuStyle.button("Cancel",func() -> void: cancelled.emit())
	cancel.name = "CancelFeatureLoading"
	column.add_child(cancel)
	cancel.grab_focus()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		cancelled.emit()

func _unhandled_key_input(_event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
