extends ScrollContainer
## One gesture owner keeps a swipe from activating a card or its favorite action.
var snap_stride: int = 202
var snap_tween: Tween
var snap_destination: int = 0
var pointer: int = -2
var origin := Vector2.ZERO
var initial_scroll: int = 0
var dragging: bool = false
var overscroll_offset: float = 0.0
const EDGE_LIMIT: float = 64.0
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
		if dragging:
			var desired: float = initial_scroll+origin.x-location.x
			var maximum: float = maxf(0.0,get_h_scroll_bar().max_value-get_h_scroll_bar().page)
			scroll_horizontal = roundi(clampf(desired,0.0,maximum))
			var excess: float = desired-clampf(desired,0.0,maximum)
			_set_overscroll(-signf(excess)*EDGE_LIMIT*(1.0-exp(-absf(excess)/160.0)))
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

func _set_overscroll(value: float) -> void:
	# Shift the card grid inside the clipped scroll viewport, not its bounds.
	if get_child_count() > 0 and get_child(0).get_child_count() > 0:
		var cards := get_child(0).get_child(0) as Control
		if cards != null: cards.position.x += value-overscroll_offset
	overscroll_offset = value

func _stop_snap() -> void:
	if snap_tween != null: snap_tween.kill()
	_set_overscroll(0.0)

func settle_cards(direction: int = 0) -> void:
	var start: int = snap_destination if direction != 0 and snap_tween != null and snap_tween.is_running() else scroll_horizontal
	var edge: float = overscroll_offset
	_stop_snap()
	_set_overscroll(edge)
	var maximum: int = maxi(0,roundi(get_h_scroll_bar().max_value-get_h_scroll_bar().page))
	var destination: int = clampi((roundi(float(start)/snap_stride)+direction)*snap_stride,0,maximum)
	snap_destination = destination
	if direction != 0 and destination == start:
		_set_overscroll(-direction*24.0)
	snap_tween = create_tween()
	if not is_zero_approx(overscroll_offset):
		snap_tween.tween_method(_set_overscroll,overscroll_offset,0.0,0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		snap_tween.parallel()
	snap_tween.tween_property(self,"scroll_horizontal",destination,0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
