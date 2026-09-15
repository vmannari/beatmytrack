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
	for i: int in range(rectangles.size()):
		var pressed: bool = driver != null and driver.touches.values().has(ACTIONS[i])
		var rect: Rect2 = rectangles[i]
		var base := StyleBoxFlat.new()
		base.bg_color = Color("101b21")
		base.border_color = Color("070d11")
		base.set_border_width_all(3)
		base.set_corner_radius_all(12)
		base.shadow_color = Color("00000088")
		base.shadow_size = 3
		base.shadow_offset = Vector2(1,4)
		draw_style_box(base,rect)
		var face := StyleBoxFlat.new()
		face.bg_color = Color("48545a") if i < 2 else Color("a19f93")
		if pressed: face.bg_color = Color("bca765")
		face.border_color = Color("8b9698") if i < 2 else Color("d1cbb7")
		face.set_border_width_all(2)
		face.set_corner_radius_all(9)
		var inset: Rect2 = rect.grow(-6)
		inset.position.y += 3 if pressed else 0
		inset.size.y -= 4
		draw_style_box(face,inset)
		var center: Vector2 = inset.get_center()
		if i < 2:
			var direction: float = -1.0 if i == 0 else 1.0
			var points := PackedVector2Array([center+Vector2(-8*direction,-20),center+Vector2(10*direction,0),center+Vector2(-8*direction,20)])
			draw_polyline(points,Color("0b151c"),11,true)
			draw_polyline(points,Color("e5dfcb"),6,true)
		else:
			var slot := StyleBoxFlat.new()
			slot.bg_color = Color("293740")
			slot.border_color = Color("111c23")
			slot.set_border_width_all(2)
			slot.set_corner_radius_all(3)
			if i == 2:
				for row: int in range(4):
					draw_style_box(slot,Rect2(inset.position+Vector2(10,9+row*(inset.size.y-20)/4),Vector2(inset.size.x-20,(inset.size.y-28)/4)))
			else:
				for column: int in range(4):
					draw_style_box(slot,Rect2(inset.position+Vector2(10+column*(inset.size.x-20)/4,9),Vector2((inset.size.x-30)/4,inset.size.y-18)))
