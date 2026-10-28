extends Button
## A momentary hold, with release/cancel ownership even outside the button.
signal comparing_changed(active: bool)
var pointer: int = -2

func _init() -> void:
	name = "GarageHoldToCompare"
	GameText.bind(self,"Hold to compare")
	custom_minimum_size = Vector2(172,48)
	add_theme_font_size_override("font_size",17)
	add_theme_font_override("font",MenuStyle.DISPLAY)
	for state: String in ["normal","hover","pressed","disabled","focus"]:
		var style: StyleBoxFlat = MenuStyle.box(Color("10212be6"),8)
		style.set_corner_radius_all(5)
		style.border_width_bottom = 1
		style.border_color = MenuStyle.ACCENT if state=="focus" else Color("425762")
		add_theme_stylebox_override(state,style)

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or disabled:
		stop()
		return
	var at := Vector2.ZERO
	var id: int = -1
	var down: bool = false
	var up: bool = false
	if event is InputEventMouse and event.device==InputEvent.DEVICE_ID_EMULATION: return
	if event is InputEventScreenTouch:
		at = event.position
		id = event.index
		down = event.pressed and not event.canceled
		up = not event.pressed or event.canceled
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		at = event.position
		down = event.pressed
		up = not event.pressed
	elif event is InputEventKey and (has_focus() or pointer== -3) and event.is_action("ui_accept"):
		id = -3
		at = get_global_rect().get_center()
		down = event.pressed and not event.echo
		up = not event.pressed
	else: return
	if down and pointer== -2 and get_global_rect().has_point(at):
		pointer = id
		grab_focus()
		comparing_changed.emit(true)
		get_viewport().set_input_as_handled()
	elif up and pointer==id:
		stop()
		get_viewport().set_input_as_handled()

func stop() -> void:
	if pointer== -2: return
	pointer = -2
	comparing_changed.emit(false)

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_FOCUS_EXIT,NOTIFICATION_EXIT_TREE] or what==NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree(): stop()
