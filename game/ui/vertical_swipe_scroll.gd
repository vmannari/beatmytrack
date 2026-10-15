extends ScrollContainer
## Own a gallery gesture before its buttons, so dragging never selects a card.
const NO_POINTER: int = -2
const DRAG_DISTANCE: float = 12.0
var pointer: int = NO_POINTER
var origin := Vector2.ZERO
var initial_scroll: int = 0
var dragged: bool = false
var rejected: bool = false
var target: BaseButton

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree(): _clear_gesture()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_EXIT_TREE: _clear_gesture()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or get_mouse_filter_with_override() == Control.MOUSE_FILTER_IGNORE:
		_clear_gesture()
		return
	# Emulated mouse DOWN precedes touch DOWN. Reserve both streams for one
	# owner, including release after the touch has already cleared its pointer.
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		if pointer != NO_POINTER or _can_start(event.position): get_viewport().set_input_as_handled()
		return
	if event is InputEventMouse and pointer >= 0:
		if event is InputEventMouseMotion or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
			get_viewport().set_input_as_handled()
		return
	var location := Vector2.ZERO
	var id: int = -1
	var down: bool = false
	var up: bool = false
	var motion: bool = false
	var canceled: bool = false
	if event is InputEventScreenTouch:
		location = event.position
		id = event.index
		down = event.pressed
		up = not event.pressed
		canceled = event.canceled
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
	else: return
	if down:
		if pointer != NO_POINTER:
			if id != pointer: rejected = true
			get_viewport().set_input_as_handled()
			return
		if canceled or not _can_start(location): return
		pointer = id
		origin = location
		initial_scroll = scroll_vertical
		dragged = false
		rejected = false
		target = _button_at(location)
	elif pointer != id: return
	var distance: Vector2 = location-origin
	if distance.length() >= DRAG_DISTANCE: dragged = true
	if motion and dragged and not rejected:
		var maximum: float = maxf(0.0,get_v_scroll_bar().max_value-get_v_scroll_bar().page)
		scroll_vertical = roundi(clampf(initial_scroll-distance.y,0.0,maximum))
	get_viewport().set_input_as_handled()
	if up:
		var tap: BaseButton = target
		var activate: bool = not canceled and not dragged and not rejected and is_instance_valid(tap) and is_ancestor_of(tap) and tap.is_visible_in_tree() and not tap.disabled and tap.get_mouse_filter_with_override() != Control.MOUSE_FILTER_IGNORE and tap.get_global_rect().has_point(location)
		_clear_gesture()
		if activate:
			tap.grab_focus()
			if tap.toggle_mode: tap.button_pressed = not tap.button_pressed
			tap.pressed.emit()

func _can_start(location: Vector2) -> bool:
	if not get_global_rect().has_point(location): return false
	var bar: VScrollBar = get_v_scroll_bar()
	if bar.is_visible_in_tree() and bar.get_global_rect().has_point(location): return false
	# Native scrollbars and press-mode controls (including colour popups) keep
	# their original interaction. Sticker placement lives outside these lists.
	for node: Node in find_children("*","Control",true,false):
		var control := node as Control
		if not control.is_visible_in_tree() or control.get_mouse_filter_with_override() == Control.MOUSE_FILTER_IGNORE or not control.get_global_rect().has_point(location): continue
		if control is Range or control is LineEdit or control is TextEdit or control is ColorPickerButton or control is OptionButton or control is MenuButton: return false
		if control is BaseButton and control.action_mode == BaseButton.ACTION_MODE_BUTTON_PRESS: return false
	return true

func _button_at(location: Vector2) -> BaseButton:
	var buttons: Array[Node] = find_children("*","BaseButton",true,false)
	buttons.reverse()
	for node: Node in buttons:
		var button := node as BaseButton
		if button.is_visible_in_tree() and button.get_mouse_filter_with_override() != Control.MOUSE_FILTER_IGNORE and button.get_global_rect().has_point(location): return button
	return null

func _clear_gesture() -> void:
	pointer = NO_POINTER
	target = null
	dragged = false
	rejected = false
