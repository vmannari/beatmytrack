extends PanelContainer
## A persistent in-game receipt banner. Pending data stays in the local workflow.
signal open_requested(item: Dictionary)
signal dismissed(item: Dictionary)
var app: Node
var entries: Array[Dictionary] = []
var track_name: Label
var view_button: Button
var dismiss_button: Button
var row: HBoxContainer
var actions: HBoxContainer
var _pointer: int = -1
var _press_position: Vector2
var _pressed_button: Button

func _ready() -> void:
	name = "PublicationNotification"
	theme = MenuStyle.theme()
	z_index = 4094
	var style: StyleBoxFlat = MenuStyle.card(16)
	style.border_color = MenuStyle.POSITIVE
	add_theme_stylebox_override("panel",style)
	var column := VBoxContainer.new()
	add_child(column)
	row = HBoxContainer.new()
	column.add_child(row)
	var check := TextureRect.new()
	check.texture = MenuIcon.texture("check")
	check.modulate = MenuStyle.POSITIVE
	check.custom_minimum_size = Vector2(36,36)
	check.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	check.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	check.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(check)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation",2)
	row.add_child(copy)
	var title: Label = MenuStyle.label("Track published",24)
	title.add_theme_color_override("font_color",MenuStyle.POSITIVE)
	copy.add_child(title)
	track_name = MenuStyle.label("",19,true)
	track_name.name = "PublishedTrackName"
	track_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	track_name.clip_text = true
	copy.add_child(track_name)
	view_button = MenuStyle.button("View track",func() -> void: if not entries.is_empty(): open_requested.emit(entries[0]),true)
	view_button.name = "ViewPublishedTrack"
	view_button.custom_minimum_size = Vector2(132,52)
	view_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(view_button)
	dismiss_button = MenuStyle.button("",func() -> void: if not entries.is_empty(): dismissed.emit(entries[0]))
	dismiss_button.name = "DismissPublication"
	dismiss_button.icon = MenuIcon.texture("close")
	dismiss_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dismiss_button.tooltip_text = "Dismiss notification"
	dismiss_button.custom_minimum_size = Vector2(52,52)
	dismiss_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dismiss_button)
	actions = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(actions)
	get_viewport().size_changed.connect(_layout)
	_layout()
	hide()

func set_entries(values: Array[Dictionary]) -> void:
	entries = values
	if entries.is_empty():
		hide()
		return
	track_name.text = str(entries[0].name)
	track_name.tooltip_text = track_name.text

func _process(_delta: float) -> void:
	if entries.is_empty(): return
	# Receive overlay touches before the underlying menu's swipe handlers.
	if get_index() != get_parent().get_child_count()-1: get_parent().move_child(self,get_parent().get_child_count()-1)
	var allowed: bool = app.startup_complete and is_instance_valid(app.root_ui) and app.root_ui.is_visible_in_tree() and app.screen not in ["account","restoring"]
	allowed = allowed and not is_instance_valid(app.game) and not is_instance_valid(app.race_loading) and not app._publication_request_active
	allowed = allowed and app.lifecycle != null and entries[0].scope == app.lifecycle.scope()
	if allowed:
		for child: Node in app.root_ui.get_children():
			if child is Window and child.visible:
				allowed = false
				break
	visible = allowed
	if not allowed:
		_pointer = -1
		_pressed_button = null

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		if get_global_rect().has_point(event.position): get_viewport().set_input_as_handled()
		return
	var pointer: int = -1
	var pressed: bool = false
	var canceled: bool = false
	if event is InputEventScreenTouch:
		pointer = event.index
		pressed = event.pressed
		canceled = event.canceled
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pointer = -2
		pressed = event.pressed
	elif (event is InputEventScreenDrag and event.index == _pointer) or (event is InputEventMouseMotion and _pointer == -2):
		if event.position.distance_to(_press_position) > 10: _pressed_button = null
		get_viewport().set_input_as_handled()
		return
	else: return
	if pressed and get_global_rect().has_point(event.position):
		if _pointer != -1:
			_pressed_button = null
		else:
			_pointer = pointer
			_press_position = event.position
			_pressed_button = view_button if view_button.get_global_rect().has_point(event.position) else dismiss_button if dismiss_button.get_global_rect().has_point(event.position) else null
		get_viewport().set_input_as_handled()
	elif not pressed and pointer == _pointer:
		var button: Button = _pressed_button
		_pointer = -1
		_pressed_button = null
		get_viewport().set_input_as_handled()
		if not canceled and is_instance_valid(button) and button.get_global_rect().has_point(event.position) and event.position.distance_to(_press_position) <= 10:
			button.grab_focus()
			button.pressed.emit()

func _layout() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var inset := Vector2(24,104)
	if OS.has_feature("mobile"):
		var safe: Rect2i = DisplayServer.get_display_safe_area()
		var window: Vector2i = DisplayServer.window_get_size()
		var scale: float = viewport_size.y/maxf(1,window.y)
		inset.x = maxf(inset.x,(window.x-safe.end.x)*scale+16)
		inset.y = maxf(inset.y,safe.position.y*scale+96)
	var width: float = minf(660,viewport_size.x-inset.x-16)
	var compact: bool = width < 560
	var parent: Node = actions if compact else row
	if view_button.get_parent() != parent:
		view_button.reparent(parent)
		if not compact: row.move_child(view_button,row.get_child_count()-2)
	actions.visible = compact
	reset_size()
	size.x = width
	position = Vector2(viewport_size.x-inset.x-width,inset.y)
