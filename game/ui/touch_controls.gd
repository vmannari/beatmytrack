class_name TouchControls
extends Control

const ACTIONS: Array[StringName] = [&"steer_left", &"steer_right", &"brake", &"accelerate"]
const LABELS: Array[String] = ["LEFT", "RIGHT", "BRAKE", "THROTTLE"]
var driver: DriverInput
var enabled: bool = true
var control_scale: float = 1.0
var left_handed: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func zones() -> Array[Rect2]:
	var result: Array[Rect2] = [Rect2(24, size.y - 156, 100, 92), Rect2(136, size.y - 156, 100, 92),
		Rect2(size.x - 248, size.y - 156, 100, 92), Rect2(size.x - 136, size.y - 184, 112, 120)]
	for i: int in range(result.size()):
		var rect: Rect2 = result[i]
		var anchor: Vector2 = Vector2(24 if i < 2 else size.x - 24, size.y - 64)
		rect.position = anchor + (rect.position - anchor) * control_scale
		rect.size *= control_scale
		if left_handed: rect.position.x = size.x - rect.end.x
		result[i] = rect
	return result


func action_at(point: Vector2) -> StringName:
	var rectangles: Array[Rect2] = zones()
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
	queue_redraw()


func _draw() -> void:
	var rectangles: Array[Rect2] = zones()
	var font: Font = ThemeDB.fallback_font
	for i: int in range(rectangles.size()):
		var pressed: bool = driver != null and driver.touches.values().has(ACTIONS[i])
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.17, 0.19, 0.8 if pressed else 0.45)
		style.border_color = Color(0.8, 0.85, 0.83, 0.85 if pressed else 0.4)
		style.set_border_width_all(1)
		style.set_corner_radius_all(8)
		draw_style_box(style, rectangles[i])
		var text_size: Vector2 = font.get_string_size(LABELS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
		draw_string(font, rectangles[i].get_center() + Vector2(-text_size.x * 0.5, 5), LABELS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("e3e8e4"))
