extends Node
## Touch ownership is decided at press, so entering/leaving a carousel cannot steal it.
signal page_requested(direction: int)
signal gesture_started
signal drag_changed(distance: float)
signal drag_finished
signal settle_requested

var menu: Control
var modal_root: Node
var pointer: int = -1
var origin := Vector2.ZERO
var dragging: bool = false
var rejected: bool = false
var target: BaseButton
var last_drag_distance: float = 0.0
var commit_direction: int = 0
var intent_sign: float = 0.0
var intent_origin: float = 0.0
var intent_peak: float = 0.0
const CLAIM_DISTANCE: float = 6.0
const PAGE_DISTANCE: float = 20.0
const CANCEL_DISTANCE: float = 6.0
const REVERSE_DISTANCE: float = 20.0

func _input(event: InputEvent) -> void:
	if not is_instance_valid(menu) or not menu.is_visible_in_tree(): return
	if event is InputEventMouse and (event.device == InputEvent.DEVICE_ID_EMULATION or pointer != -1):
		# Godot dispatches emulated mouse input before its touch; some platforms
		# also deliver a parallel mouse stream. During our touch, neither stream
		# may activate a moving button and rebuild the page before touch UP.
		if pointer != -1:
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			settle_requested.emit()
			if not _modal_open(modal_root) and not _owns_gesture(menu,event.position):
				get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if pointer != -1:
				# A second finger belongs to neither page navigation nor a tap.
				rejected = true
				drag_finished.emit()
				return
			# Finish an earlier arrival before hit-testing the new touch. This avoids
			# dropping a whole swipe just because it began during the settling tween.
			settle_requested.emit()
			if event.canceled or _modal_open(modal_root) or _owns_gesture(menu, event.position): return
			pointer = event.index
			origin = event.position
			dragging = false
			rejected = false
			last_drag_distance = 0.0
			commit_direction = 0
			intent_sign = 0.0
			intent_origin = 0.0
			intent_peak = 0.0
			target = _button_at(menu, origin)
			gesture_started.emit()
			# Match the carousel's tap dispatch; a swipe never activates its starting button.
			if is_instance_valid(target): get_viewport().set_input_as_handled()
		elif event.index == pointer:
			var distance: Vector2 = event.position - origin
			# Once horizontal intent is established, vertical finger drift cannot revoke it.
			# UP may contain forward movement absent from the last MOVE. Count that
			# distance for commitment, but never jump the displayed page to it.
			# Backward lift jitter still cannot disarm an already completed stroke.
			if not rejected and not event.canceled and not _modal_open(modal_root):
				var forward_release: bool = absf(distance.x) > absf(last_drag_distance) and (is_zero_approx(last_drag_distance) or distance.x * last_drag_distance > 0.0)
				var horizontal_release: bool = dragging or absf(distance.x) > absf(distance.y) * 1.05
				if forward_release and horizontal_release and absf(distance.x) >= PAGE_DISTANCE:
					dragging = true
					_update_intent(distance.x)
			var navigate: bool = dragging and not rejected and not event.canceled and not _modal_open(modal_root) and commit_direction != 0
			var direction: int = commit_direction
			var tap: BaseButton = target
			var activate: bool = not dragging and not rejected and not event.canceled and distance.length() < CLAIM_DISTANCE and is_instance_valid(tap) and not tap.disabled and tap.get_global_rect().has_point(event.position)
			if dragging and not rejected and not event.canceled: drag_changed.emit(last_drag_distance)
			if dragging or is_instance_valid(target): get_viewport().set_input_as_handled()
			pointer = -1
			target = null
			drag_finished.emit()
			if navigate:
				page_requested.emit(direction)
			elif activate:
				tap.grab_focus()
				if tap.toggle_mode: tap.button_pressed = not tap.button_pressed
				tap.pressed.emit()
	elif event is InputEventScreenDrag and event.index == pointer:
		var distance: Vector2 = event.position - origin
		if not dragging and not rejected and absf(distance.x) >= CLAIM_DISTANCE:
			# Scrollable controls already own their touches. Allow a static-content
			# gesture to establish horizontal intent after initial vertical jitter.
			if absf(distance.x) > absf(distance.y) * 1.05: dragging = true
		if dragging and not rejected:
			_update_intent(distance.x)
			last_drag_distance = distance.x
			drag_changed.emit(distance.x)
		if dragging or is_instance_valid(target): get_viewport().set_input_as_handled()

func _update_intent(distance: float) -> void:
	var direction: float = signf(distance)
	if direction != intent_sign:
		intent_sign = direction
		intent_origin = 0.0
		intent_peak = direction * distance
		commit_direction = 0
	var progress: float = intent_sign * distance
	if commit_direction != 0:
		intent_peak = maxf(intent_peak, progress)
		if progress <= CANCEL_DISTANCE or intent_peak - progress >= REVERSE_DISTANCE:
			# A deliberate backward stroke cancels even far from the press. It
			# takes fresh forward travel to rearm, rather than a noisy UP event.
			commit_direction = 0
			intent_origin = distance
	else:
		if intent_sign * (distance - intent_origin) < 0.0: intent_origin = distance
		if progress >= PAGE_DISTANCE and intent_sign * (distance - intent_origin) >= PAGE_DISTANCE:
			commit_direction = -int(intent_sign)
			intent_peak = progress

func _owns_gesture(node: Node, location: Vector2) -> bool:
	if node is Control:
		var control := node as Control
		if control.mouse_behavior_recursive == Control.MOUSE_BEHAVIOR_DISABLED: return false
		if not control.is_visible_in_tree(): return false
		if control.clip_contents and not control.get_global_rect().has_point(location): return false
		if control is CarShowroom and control.owns_gesture(location): return true
		if control.get_global_rect().has_point(location) and (control is ScrollContainer or control is Range or control is LineEdit or control is TextEdit or control is OptionButton or control is MenuButton or (control is BaseButton and control.action_mode == BaseButton.ACTION_MODE_BUTTON_PRESS)):
			return true
	for child: Node in node.get_children():
		if _owns_gesture(child, location): return true
	return false

func _modal_open(node: Node) -> bool:
	if node == null: return false
	if node is Window and node.visible: return true
	if node is CanvasLayer and node.layer > 20 and node.visible: return true
	for child: Node in node.get_children():
		if _modal_open(child): return true
	return false

func _button_at(node: Node, location: Vector2) -> BaseButton:
	if node is Control:
		var control := node as Control
		if control.mouse_behavior_recursive == Control.MOUSE_BEHAVIOR_DISABLED: return null
		if not control.is_visible_in_tree(): return null
		if control.clip_contents and not control.get_global_rect().has_point(location): return null
	var children: Array[Node] = node.get_children()
	children.reverse()
	for child: Node in children:
		var button: BaseButton = _button_at(child, location)
		if button != null: return button
	if node is BaseButton and node.get_mouse_filter_with_override() != Control.MOUSE_FILTER_IGNORE and node.get_global_rect().has_point(location): return node
	return null
