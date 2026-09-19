class_name TouchControls
extends Control

const ACTIONS: Array[StringName] = [&"steer_left", &"steer_right", &"brake", &"accelerate"]
const LABELS: Array[String] = ["LEFT", "RIGHT", "BRAKE", "THROTTLE"]
var vehicle_id: String = "compact":
	set(value):
		vehicle_id = value
		queue_redraw()
var driver: DriverInput
var enabled: bool = true
var control_scale: float = 1.0:
	set(value):
		control_scale = value
		queue_redraw()
var left_handed: bool = false:
	set(value):
		left_handed = value
		queue_redraw()
var mobile_layout: bool = OS.has_feature("android") or OS.has_feature("ios")
var draw_count: int = 0
var last_pressed_mask: int = -1
var artwork: Array[TouchControlArt] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for index: int in range(4):
		# Draw both variants once under the normal variant during loading.
		# Subsequent presses switch opacity; hide/show invalidates Godot's draw list.
		for pressed: bool in [true,false]:
			var art := TouchControlArt.new()
			art.button_index = index
			art.pressed = pressed
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			artwork.append(art)
			add_child(art)
	resized.connect(queue_redraw)


func zones() -> Array[Rect2]:
	var result: Array[Rect2] = [Rect2(24, size.y - 156, 100, 92), Rect2(136, size.y - 156, 100, 92),
		Rect2(size.x - 248, size.y - 156, 100, 92), Rect2(size.x - 136, size.y - 184, 112, 120)]
	var scale_value: float = control_scale * (1.15 if mobile_layout else 1.0)
	for i: int in range(result.size()):
		var rect: Rect2 = result[i]
		var anchor: Vector2 = Vector2(24 if i < 2 else size.x - 24, size.y - 64)
		rect.position = anchor + (rect.position - anchor) * scale_value
		rect.size *= scale_value
		if left_handed: rect.position.x = size.x - rect.end.x
		result[i] = rect
	return result


func touch_zones() -> Array[Rect2]:
	var artwork: Array[Rect2] = zones()
	var result: Array[Rect2] = []
	for i: int in range(artwork.size()):
		var rect: Rect2 = artwork[i].grow_individual(42, 48, 42, 72)
		var neighbor: Rect2 = artwork[i ^ 1]
		var split: float = (artwork[i].get_center().x + neighbor.get_center().x) * 0.5
		if artwork[i].get_center().x < split:
			rect.size.x = minf(rect.end.x, split) - rect.position.x
		else:
			var right: float = rect.end.x
			rect.position.x = maxf(rect.position.x, split)
			rect.size.x = right - rect.position.x
		result.append(rect.intersection(Rect2(Vector2.ZERO, size)))
	return result


func action_at(point: Vector2) -> StringName:
	var rectangles: Array[Rect2] = touch_zones()
	for i: int in range(rectangles.size()):
		if rectangles[i].has_point(point):
			return ACTIONS[i]
	return &""


func _input(event: InputEvent) -> void:
	if driver == null:
		return
	if event is InputEventScreenTouch:
		if not event.pressed or event.canceled:
			driver.release_touch(event.index)
		elif enabled:
			driver.set_touch(event.index, action_at(event.position))
	elif event is InputEventScreenDrag and enabled and driver.touches.has(event.index):
		driver.set_touch(event.index, action_at(event.position))


func pressed_mask() -> int:
	var held: Array = driver.touches.values() if driver != null else []
	var result: int = 0
	if enabled:
		for i: int in range(ACTIONS.size()):
			if Input.is_action_pressed(ACTIONS[i]) or held.has(ACTIONS[i]): result |= 1 << i
	return result


func _process(_delta: float) -> void:
	# Input state stays immediate. Retain the drawing commands while fingers
	# move within a held button; also observe keyboard and external clear().
	var mask: int = pressed_mask()
	last_pressed_mask = mask
	for art: TouchControlArt in artwork:
		# Waiting for both first draws keeps the visible normal art unchanged.
		if artwork[art.button_index*2].draw_count == 0 or artwork[art.button_index*2+1].draw_count == 0: continue
		art.modulate.a = 1.0 if art.pressed == ((mask & (1 << art.button_index)) != 0) else 0.0


# All artwork is drawn in local 100 x 100 units; touch geometry stays independent.
func _draw() -> void:
	draw_count += 1
	last_pressed_mask = pressed_mask()
	var rectangles: Array[Rect2] = zones()
	for art: TouchControlArt in artwork:
		var rect: Rect2 = rectangles[art.button_index]
		if art.artwork_rect != rect:
			art.artwork_rect = rect
			art.queue_redraw()
		if art.vehicle_id != vehicle_id:
			art.vehicle_id = vehicle_id
			art.queue_redraw()
