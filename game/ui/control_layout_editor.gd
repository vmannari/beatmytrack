class_name ControlLayoutEditor
extends Control
signal closed
var records: LocalRecords
var preview: PlaygroundHUD
var touch: TouchControls
var selected: String = "steer_left"
var drag_finger: int = -2
var drag_offset := Vector2.ZERO
var heading: Label
var size_slider: HSlider
var opacity_slider: HSlider
var size_value: Label
var opacity_value: Label
var method: OptionButton
var presets: OptionButton
var status: Label
var toolbar: PanelContainer
var selection_panel: PanelContainer
var selected_art: TouchControlArt
var overlay: Control
var dirty: bool = false
var save_timer: Timer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = MenuStyle.theme()
	save_timer = Timer.new()
	save_timer.one_shot = true
	save_timer.wait_time = 0.35
	save_timer.timeout.connect(_save)
	add_child(save_timer)
	var background := ColorRect.new()
	background.color = Color("101a22")
	MenuStyle.fill(background)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	preview = PlaygroundHUD.new()
	preview.production_mode = true
	preview.editor_test = true
	preview.config = HandlingConfig.new()
	preview.driver = DriverInput.new()
	add_child(preview)
	touch = preview.touch
	touch.enabled = false
	touch.layout = ControlLayout.from_settings(records.settings)
	touch.show_labels = bool(records.settings.get("control_labels", true))
	selected = _steering_selection()
	# Retain the actual driving controls without unrelated race/practice messages.
	for child: Node in touch.get_parent().get_children():
		if child is Control and child != touch: (child as Control).hide()
	_ignore(preview)
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	overlay = Control.new()
	overlay.theme = theme
	MenuStyle.fill(overlay)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(overlay)
	overlay.draw.connect(_draw_handles)
	touch.draw.connect(overlay.queue_redraw)
	_build_toolbar()
	_build_selection_panel()
	status = MenuStyle.label("", 16, true)
	status.visible = false
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.add_child(status)
	_refresh()
	resized.connect(_place_toolbar.call_deferred)
	touch.resized.connect(_place_toolbar.call_deferred)
	_place_toolbar.call_deferred()

func _build_toolbar() -> void:
	toolbar = PanelContainer.new()
	toolbar.name = "ControlToolbar"
	toolbar.add_theme_stylebox_override("panel", _panel(10))
	overlay.add_child(toolbar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	toolbar.add_child(row)
	var back: Button = MenuStyle.button("", _close)
	back.name = "ControlsBack"
	back.icon = MenuIcon.texture("arrow")
	back.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back.custom_minimum_size.x = 54
	var arrow: Image = MenuIcon.texture("arrow").get_image()
	arrow.flip_x()
	back.icon = ImageTexture.create_from_image(arrow)
	row.add_child(back)
	var title := VBoxContainer.new()
	title.add_theme_constant_override("separation", 0)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	title.add_child(MenuStyle.label("CONTROLS", 32))
	title.add_child(MenuStyle.label("Drag controls to reposition", 16, true))
	row.add_child(MenuStyle.label("Preset", 17, true))
	presets = OptionButton.new()
	presets.name = "ControlPreset"
	for label: String in ["Default", "Left-handed", "Right-handed"]: presets.add_item(label)
	presets.custom_minimum_size = Vector2(160, 54)
	presets.item_selected.connect(_preset_selected)
	row.add_child(presets)
	row.add_child(MenuStyle.label("Control scheme", 17, true))
	method = OptionButton.new()
	method.name = "ControlScheme"
	for label: String in ["Left / right buttons", "Analog slider", "Analog joystick"]: method.add_item(label)
	method.custom_minimum_size = Vector2(220, 54)
	method.select(ControlLayout.METHODS.find(touch.layout.steering_type))
	method.item_selected.connect(func(index: int) -> void:
		touch.layout.steering_type = ControlLayout.METHODS[index]
		selected = _steering_selection()
		_refresh()
		_changed())
	row.add_child(method)
	var reset: Button = MenuStyle.button("Reset", _reset)
	reset.name = "ResetControlLayout"
	reset.icon = MenuIcon.texture("restart")
	reset.custom_minimum_size.x = 115
	row.add_child(reset)
	var done: Button = MenuStyle.button("Done", _close, true)
	done.name = "ControlsDone"
	done.icon = MenuIcon.texture("check")
	done.add_theme_color_override("icon_normal_color", MenuStyle.INK)
	done.add_theme_color_override("icon_hover_color", MenuStyle.INK)
	done.custom_minimum_size.x = 125
	row.add_child(done)

func _build_selection_panel() -> void:
	selection_panel = PanelContainer.new()
	selection_panel.name = "SelectedControlPanel"
	selection_panel.add_theme_stylebox_override("panel", _panel(12))
	overlay.add_child(selection_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	selection_panel.add_child(row)
	selected_art = TouchControlArt.new()
	selected_art.show_labels = touch.show_labels
	selected_art.custom_minimum_size = Vector2(54, 54)
	selected_art.artwork_rect = Rect2(5, 2, 44, 50)
	selected_art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	selected_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(selected_art)
	var copy := VBoxContainer.new()
	copy.custom_minimum_size.x = 200
	copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	copy.add_theme_constant_override("separation", 3)
	row.add_child(copy)
	heading = MenuStyle.label("", 24)
	copy.add_child(heading)
	copy.add_child(MenuStyle.label("Adjust size and opacity", 16, true))
	var sliders := VBoxContainer.new()
	sliders.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sliders.add_theme_constant_override("separation", 8)
	row.add_child(sliders)
	var size_row := HBoxContainer.new()
	sliders.add_child(size_row)
	var size_label: Label = MenuStyle.label("Size", 17)
	size_label.custom_minimum_size.x = 70
	size_row.add_child(size_label)
	size_slider = _slider(size_row, 0.65, 1.6, 0.05)
	size_slider.name = "ControlSize"
	size_value = MenuStyle.label("", 17)
	size_value.custom_minimum_size.x = 54
	size_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	size_row.add_child(size_value)
	size_slider.value_changed.connect(_resize_control)
	var opacity_row := HBoxContainer.new()
	sliders.add_child(opacity_row)
	var opacity_label: Label = MenuStyle.label("Opacity", 17)
	opacity_label.custom_minimum_size.x = 70
	opacity_row.add_child(opacity_label)
	opacity_slider = _slider(opacity_row, 0.2, 1.0, 0.05)
	opacity_slider.name = "ControlOpacity"
	opacity_value = MenuStyle.label("", 17)
	opacity_value.custom_minimum_size.x = 54
	opacity_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	opacity_row.add_child(opacity_value)
	opacity_slider.value_changed.connect(func(value: float) -> void:
		touch.layout[selected].opacity = value
		_refresh()
		_changed())
	var reset_position: Button = MenuStyle.button("Reset position", _reset_position)
	reset_position.name = "ResetControlPosition"
	reset_position.custom_minimum_size = Vector2(160, 54)
	reset_position.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reset_position.icon = MenuIcon.texture("restart")
	row.add_child(reset_position)

func _panel(padding: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = MenuStyle.card(padding)
	style.bg_color = Color("0a171ff5")
	style.shadow_size = 0
	return style

func _place_toolbar() -> void:
	if touch == null: return
	var area: Rect2 = touch.usable_area()
	toolbar.position = Vector2(area.position.x, 0)
	toolbar.size.x = area.size.x
	toolbar.size.y = toolbar.get_combined_minimum_size().y
	selection_panel.size.x = minf(980, area.size.x)
	selection_panel.position = Vector2(area.get_center().x-selection_panel.size.x*0.5, toolbar.size.y+8)
	status.position = Vector2(area.position.x, selection_panel.position.y+selection_panel.size.y+8)
	status.size.x = area.size.x
	touch.queue_redraw()

func _steering_selection() -> String:
	return "steer_left" if touch.layout.steering_type == "buttons" else str(touch.layout.steering_type)

func _preset_selected(index: int) -> void:
	touch.layout = ControlLayout.preset(index == 1)
	selected = "steer_left"
	method.select(0)
	_refresh()
	_changed()

func _reset() -> void:
	presets.select(0)
	_preset_selected(0)

func _reset_position() -> void:
	var defaults: Dictionary = ControlLayout.preset(presets.selected == 1)
	var original: Dictionary = touch.layout[selected].duplicate(true)
	touch.layout[selected].x = defaults[selected].x
	touch.layout[selected].y = defaults[selected].y
	if not _selected_fits():
		touch.layout[selected] = original
		status.text = "Move nearby controls to make room for the default position."
		status.show()
		return
	_refresh()
	_changed()

func _resize_control(value: float) -> void:
	var original: Dictionary = touch.layout[selected].duplicate(true)
	# Preserve the selected control's visible center while its size changes.
	var center: Vector2 = touch.group_rects()[selected].get_center()
	touch.layout[selected].scale = value
	var dimensions: Vector2 = ControlLayout.rect(touch.layout, selected, touch.usable_area()).size
	ControlLayout.move(touch.layout, selected, center-dimensions*0.5, touch.usable_area())
	if not _selected_fits():
		touch.layout[selected] = original
		_refresh()
		status.text = "Move this control to make room before enlarging it."
		status.show()
		return
	_refresh()
	_changed()

func _selected_fits() -> bool:
	var candidate: Rect2 = ControlLayout.rect(touch.layout, selected, touch.usable_area())
	for key: String in ControlLayout.active_keys(touch.layout):
		if key != selected and candidate.grow(6).intersects(ControlLayout.rect(touch.layout, key, touch.usable_area())): return false
	return true

func _close() -> void:
	if _save():
		closed.emit()
		queue_free()

func _ignore(node: Node) -> void:
	if node is Control: node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children(): _ignore(child)

func _slider(parent: Node, minimum: float, maximum: float, step_value: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step_value
	slider.custom_minimum_size = Vector2(180, 28)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rail: StyleBoxFlat = MenuStyle.box(Color("263d49"), 0)
	rail.corner_radius_top_left = 3
	rail.set_corner_radius_all(3)
	rail.content_margin_top = 3
	rail.content_margin_bottom = 3
	slider.add_theme_stylebox_override("slider", rail)
	var fill: StyleBoxFlat = rail.duplicate() as StyleBoxFlat
	fill.bg_color = MenuStyle.ACCENT
	for state: String in ["grabber_area", "grabber_area_highlight"]: slider.add_theme_stylebox_override(state, fill)
	var raster := Image.new()
	raster.load_svg_from_string("<svg xmlns='http://www.w3.org/2000/svg' width='24' height='24'><circle cx='12' cy='12' r='9' fill='#f1f4f3' stroke='#a4bac7'/></svg>")
	var grabber := ImageTexture.create_from_image(raster)
	for state: String in ["grabber", "grabber_highlight"]: slider.add_theme_icon_override(state, grabber)
	parent.add_child(slider)
	return slider

func _refresh() -> void:
	heading.text = ControlLayout.TITLES[selected]
	size_slider.set_value_no_signal(touch.layout[selected].scale)
	opacity_slider.set_value_no_signal(touch.layout[selected].opacity)
	size_value.text = "%d%%" % roundi(float(touch.layout[selected].scale)*100)
	opacity_value.text = "%d%%" % roundi(float(touch.layout[selected].opacity)*100)
	selected_art.button_index = ["steer_left", "steer_right", "brake", "accelerator", "handbrake"].find(selected)
	selected_art.visible = selected_art.button_index >= 0
	selected_art.queue_redraw()
	touch.queue_redraw()
	overlay.queue_redraw()

func _changed() -> void:
	dirty = true
	save_timer.start()
	touch.queue_redraw()
	status.text = ""
	status.hide()

func _save() -> bool:
	if not dirty: return true
	records.settings.control_layout = touch.layout.duplicate(true)
	if records.save_records() != OK:
		status.text = "Could not save. Check free storage, then tap Done to retry."
		status.show()
		return false
	dirty = false
	return true

func _draw_handles() -> void:
	for key: String in touch.group_rects():
		var rect: Rect2 = touch.group_rects()[key]
		var color: Color = MenuStyle.ACCENT if key == selected else Color("7895a4")
		var style: StyleBoxFlat = MenuStyle.box(Color(color, 0.06 if key == selected else 0.015), 0)
		style.set_corner_radius_all(12)
		style.set_border_width_all(2 if key == selected else 1)
		style.border_color = Color(color, 1.0 if key == selected else 0.45)
		overlay.draw_style_box(style, rect)
		var grip: Vector2 = rect.position+Vector2(rect.size.x*0.5, 10)
		for y: int in range(3):
			for x: int in range(3): overlay.draw_circle(grip+Vector2((x-1)*6,y*6),1.5,color)

func _input(event: InputEvent) -> void:
	var point := Vector2.ZERO
	var finger: int = -1
	var pressed: bool = false
	var released: bool = false
	var motion: bool = false
	if event is InputEventScreenTouch:
		point = event.position; finger = event.index
		pressed = event.pressed and not event.canceled
		released = not pressed
	elif event is InputEventScreenDrag:
		point = event.position; finger = event.index; motion = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		point = event.position; pressed = event.pressed; released = not pressed
	elif event is InputEventMouseMotion:
		point = event.position; motion = true
	else: return
	point = get_global_transform_with_canvas().affine_inverse()*point
	if released and drag_finger == finger:
		drag_finger = -2
		_save()
		get_viewport().set_input_as_handled()
	elif pressed and drag_finger == -2 and not toolbar.get_global_rect().has_point(event.position) and not selection_panel.get_global_rect().has_point(event.position):
		for key: String in touch.group_rects():
			var rect: Rect2 = touch.group_rects()[key]
			if rect.has_point(point):
				selected = key
				drag_finger = finger
				drag_offset = point-rect.position
				_refresh()
				get_viewport().set_input_as_handled()
				break
	elif motion and drag_finger == finger:
		var original: Dictionary = touch.layout[selected].duplicate(true)
		ControlLayout.move(touch.layout,selected,point-drag_offset,touch.usable_area())
		if _selected_fits(): _changed()
		else: touch.layout[selected] = original
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:
		drag_finger = -2
		if touch != null: _save()
