class_name ControlLayoutEditor
extends Control
signal closed
var records: LocalRecords
var preview: PlaygroundHUD
var touch: TouchControls
var selected: String = "buttons"
var drag_finger: int = -2
var drag_offset := Vector2.ZERO
var heading: Label
var size_slider: HSlider
var opacity_slider: HSlider
var method: OptionButton
var status: Label
var toolbar: PanelContainer
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
	background.color = Color("172827")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	preview = PlaygroundHUD.new()
	preview.production_mode = true
	preview.config = HandlingConfig.new()
	preview.driver = DriverInput.new()
	add_child(preview)
	touch = preview.touch
	touch.enabled = false
	touch.layout = ControlLayout.from_settings(records.settings)
	selected = touch.layout.steering_type
	# Keep the actual race HUD visible; none of its preview buttons are interactive.
	_ignore(preview)
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(overlay)
	overlay.draw.connect(func() -> void:
		for key: String in touch.group_rects():
			var rect: Rect2 = touch.group_rects()[key]
			var color := Color("f5ce62") if key == selected else Color("9eb9b6")
			overlay.draw_rect(rect,Color(color,0.08),true)
			overlay.draw_rect(rect,color,false,3 if key == selected else 1)
			overlay.draw_string(RaceHUDStyle.DISPLAY,rect.position+Vector2(6,22),"STEERING" if key in ControlLayout.METHODS else key.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,16,color))
	touch.draw.connect(overlay.queue_redraw)
	toolbar = PanelContainer.new()
	overlay.add_child(toolbar)
	var panel_style: StyleBoxFlat = MenuStyle.card(12)
	panel_style.bg_color.a = 1.0
	toolbar.add_theme_stylebox_override("panel",panel_style)
	var rows := VBoxContainer.new()
	toolbar.add_child(rows)
	var top := HBoxContainer.new()
	rows.add_child(top)
	top.add_child(MenuStyle.label("CONTROLS",22))
	var presets := OptionButton.new()
	for title: String in ["Default","Left-handed","Right-handed"]: presets.add_item(title)
	presets.custom_minimum_size = Vector2(170,48)
	presets.item_selected.connect(func(index: int) -> void:
		touch.layout = ControlLayout.preset(index == 1)
		selected = "buttons"
		method.select(0)
		_refresh()
		_changed())
	top.add_child(presets)
	method = OptionButton.new()
	for title: String in ["Left / right buttons","Analog slider","Analog joystick"]: method.add_item(title)
	method.custom_minimum_size = Vector2(240,48)
	method.select(ControlLayout.METHODS.find(touch.layout.steering_type))
	method.item_selected.connect(func(index: int) -> void:
		touch.layout.steering_type = ControlLayout.METHODS[index]
		selected = touch.layout.steering_type
		_refresh()
		_changed())
	top.add_child(method)
	top.add_child(MenuStyle.button("Reset to default",func() -> void:
		touch.layout = ControlLayout.preset()
		selected = "buttons"
		method.select(0)
		presets.select(0)
		_refresh()
		_changed()))
	top.add_child(MenuStyle.button("Done",func() -> void:
		if _save(): closed.emit(); queue_free(),true))
	var row := HBoxContainer.new()
	rows.add_child(row)
	heading = MenuStyle.label("Steering",18)
	heading.custom_minimum_size.x = 140
	row.add_child(heading)
	row.add_child(MenuStyle.label("Size",18))
	size_slider = _slider(row,0.65,1.6,0.05)
	size_slider.value_changed.connect(func(value: float) -> void:
		touch.layout[selected].scale = value
		_changed())
	row.add_child(MenuStyle.label("Opacity",18))
	opacity_slider = _slider(row,0.2,1.0,0.05)
	opacity_slider.value_changed.connect(func(value: float) -> void:
		touch.layout[selected].opacity = value
		_changed())
	status = MenuStyle.label("Drag a control to move it. Outlines show its touch area.",16,true)
	rows.add_child(status)
	_refresh()
	resized.connect(_place_toolbar.call_deferred)
	touch.resized.connect(_place_toolbar.call_deferred)
	_place_toolbar()

func _place_toolbar() -> void:
	if touch == null: return
	var area: Rect2 = touch.usable_area()
	toolbar.position = Vector2(area.position.x,maxf(8,area.position.y-172))
	toolbar.size.x = area.size.x
	touch.queue_redraw()

func _ignore(node: Node) -> void:
	if node is Control: node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children(): _ignore(child)

func _slider(parent: Node, minimum: float, maximum: float, step_value: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step_value
	slider.custom_minimum_size = Vector2(160,44)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(slider)
	return slider

func _refresh() -> void:
	heading.text = "Steering" if selected in ControlLayout.METHODS else selected.capitalize()
	size_slider.set_value_no_signal(touch.layout[selected].scale)
	opacity_slider.set_value_no_signal(touch.layout[selected].opacity)
	touch.queue_redraw()

func _changed() -> void:
	dirty = true
	save_timer.start()
	touch.queue_redraw()
	status.text = "Drag to position. Pedals: press for full power, slide down to ease off."

func _save() -> bool:
	if not dirty: return true
	records.settings.control_layout = touch.layout.duplicate(true)
	if records.save_records() != OK:
		status.text = "Could not save. Check free storage, then tap Done to retry."
		return false
	dirty = false
	return true

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
	if released and drag_finger == finger:
		drag_finger = -2
		_save()
		get_viewport().set_input_as_handled()
	elif pressed and drag_finger == -2 and not toolbar.get_global_rect().has_point(point):
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
		ControlLayout.move(touch.layout,selected,point-drag_offset,touch.usable_area())
		_changed()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:
		drag_finger = -2
		if touch != null: _save()
