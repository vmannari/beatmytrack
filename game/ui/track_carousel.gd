extends ScrollContainer
## One gesture owner keeps a swipe from activating a card or its favorite action.
var pointer: int = -2
var origin := Vector2.ZERO
var initial_scroll: int = 0
var dragging: bool = false
var target: BaseButton

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	var location := Vector2.ZERO
	var down: bool = false
	var up: bool = false
	var motion: bool = false
	var id: int = -1
	if event is InputEventScreenTouch:
		location = event.position
		id = event.index
		down = event.pressed
		up = not event.pressed
	elif event is InputEventScreenDrag:
		location = event.position
		id = event.index
		motion = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		location = event.position
		down = event.pressed
		up = not event.pressed
	elif event is InputEventMouseMotion:
		location = event.position
		motion = true
	elif event is InputEventMouseButton and event.pressed and get_global_rect().has_point(event.position):
		if event.button_index in [MOUSE_BUTTON_WHEEL_DOWN,MOUSE_BUTTON_WHEEL_RIGHT]: scroll_horizontal += 110
		elif event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_LEFT]: scroll_horizontal -= 110
		else: return
		get_viewport().set_input_as_handled()
		return
	else: return
	if down and pointer == -2 and get_global_rect().has_point(location):
		# Leave the native scrollbar available for precise desktop positioning.
		if get_h_scroll_bar().is_visible_in_tree() and get_h_scroll_bar().get_global_rect().has_point(location): return
		pointer = id
		origin = location
		initial_scroll = scroll_horizontal
		dragging = false
		target = _button_at(location)
	elif pointer != id: return
	if motion:
		if absf(location.x-origin.x) >= 12: dragging = true
		if dragging: scroll_horizontal = initial_scroll+roundi(origin.x-location.x)
	if up:
		if not (event is InputEventScreenTouch and event.canceled) and not dragging and is_instance_valid(target) and not target.disabled and target.get_global_rect().has_point(location):
			target.grab_focus()
			target.pressed.emit()
		pointer = -2
		target = null
	get_viewport().set_input_as_handled()

func _button_at(location: Vector2) -> BaseButton:
	var buttons: Array[Node] = find_children("*","BaseButton",true,false)
	buttons.reverse()
	for node: Node in buttons:
		var button := node as BaseButton
		if button.is_visible_in_tree() and button.get_global_rect().has_point(location): return button
	return null
