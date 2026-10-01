extends ScrollContainer
## One gesture owner keeps a swipe from activating a card or its favorite action.
var snap_stride: int = 202
var snap_tween: Tween
var snap_destination: int = 0
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
		var direction: int = 0
		if event.button_index in [MOUSE_BUTTON_WHEEL_DOWN,MOUSE_BUTTON_WHEEL_RIGHT]: direction = 1
		elif event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_LEFT]: direction = -1
		else: return
		settle_cards(direction)
		get_viewport().set_input_as_handled()
		return
	else: return
	if down and pointer == -2 and get_global_rect().has_point(location):
		# Leave the native scrollbar available for precise desktop positioning.
		if get_h_scroll_bar().is_visible_in_tree() and get_h_scroll_bar().get_global_rect().has_point(location): return
		_stop_snap()
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
		settle_cards()
	get_viewport().set_input_as_handled()

func _button_at(location: Vector2) -> BaseButton:
	var buttons: Array[Node] = find_children("*","BaseButton",true,false)
	buttons.reverse()
	for node: Node in buttons:
		var button := node as BaseButton
		if button.is_visible_in_tree() and button.get_global_rect().has_point(location): return button
	return null

func _stop_snap() -> void:
	if snap_tween != null: snap_tween.kill()

func settle_cards(direction: int = 0) -> void:
	var start: int = snap_destination if direction != 0 and snap_tween != null and snap_tween.is_running() else scroll_horizontal
	_stop_snap()
	var maximum: int = maxi(0,roundi(get_h_scroll_bar().max_value-get_h_scroll_bar().page))
	var destination: int = clampi((roundi(float(start)/snap_stride)+direction)*snap_stride,0,maximum)
	snap_destination = destination
	snap_tween = create_tween()
	snap_tween.tween_property(self,"scroll_horizontal",destination,0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
