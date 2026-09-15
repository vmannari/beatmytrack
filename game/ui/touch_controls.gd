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
	var font: Font = RaceHUDStyle.DISPLAY
	for i: int in range(rectangles.size()):
		var pressed: bool = driver != null and driver.touches.values().has(ACTIONS[i])
		var style := StyleBoxFlat.new()
		style.bg_color = RaceHUDStyle.GOLD if pressed else Color("091923c7")
		style.border_color = RaceHUDStyle.GOLD if pressed or i == 3 else Color("557080")
		style.set_border_width_all(1)
		style.set_corner_radius_all(4)
		draw_style_box(style, rectangles[i])
		var text_size: Vector2 = font.get_string_size(LABELS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
		draw_string(font, rectangles[i].get_center() + Vector2(-text_size.x * 0.5, rectangles[i].size.y * 0.30), LABELS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, RaceHUDStyle.INK if pressed else RaceHUDStyle.MUTED)

		var center: Vector2 = rectangles[i].get_center() - Vector2(0, 13)
		var ink: Color = RaceHUDStyle.INK if pressed else RaceHUDStyle.TEXT
		if i < 2:
			var direction: float = -1.0 if i == 0 else 1.0
			draw_polyline(PackedVector2Array([center+Vector2(-8*direction,-16), center+Vector2(5*direction,0), center+Vector2(-8*direction,16)]), ink, 4.0, true)
		elif i == 2:
			draw_arc(center, 15, 0, TAU, 32, ink, 2.0, true)
			draw_line(center, center+Vector2(9,-13), ink, 3.0, true)
			draw_circle(center, 3, ink)
		else:
			draw_style_box(_pedal_style(ink), Rect2(center-Vector2(10,17),Vector2(20,34)))
			for x: float in [-3.0,3.0]: draw_line(center+Vector2(x,-11),center+Vector2(x,11),ink,2.0,true)


func _pedal_style(ink: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = ink
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	return style
