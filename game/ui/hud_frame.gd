class_name HUDFrame
extends Control
## Scalable inked instrument silhouettes, drawn behind real UI controls.
var kind: String = "clock"
var speed_fraction: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_parent().resized.connect(queue_redraw)

func _draw() -> void:
	var extent: Vector2 = (get_parent() as Control).size
	var points: PackedVector2Array
	match kind:
		"plain": points = PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)])
		"map": points = PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,0.72),Vector2(0.59,0.72),Vector2(0.53,1),Vector2(0,1)])
		"speed": points = PackedVector2Array([Vector2(0,1),Vector2(0.06,0.38),Vector2(0.29,0.34),Vector2(0.37,0.05),Vector2(0.63,0.05),Vector2(0.71,0.34),Vector2(0.94,0.38),Vector2(1,1)])
		_: points = PackedVector2Array([Vector2(0,0),Vector2(0.28,0),Vector2(0.33,0.17),Vector2(0.67,0.17),Vector2(0.72,0),Vector2(1,0),Vector2(0.96,1),Vector2(0.04,1)])
	for i: int in range(points.size()): points[i] = points[i] * (extent-Vector2(6,6)) + Vector2(3,3) - position
	points = rounded(points,5.0)
	var shadow := points.duplicate()
	for i: int in range(shadow.size()): shadow[i] += Vector2(0,3)
	draw_colored_polygon(shadow,Color("080e12"))
	draw_colored_polygon(points,Color("1c2931f5"))
	points.append(points[0])
	draw_polyline(points,Color("080e12"),5,true)
	draw_polyline(points,Color("607882"),1.5,true)
	if kind == "speed":
		for side: int in [-1,1]:
			var center := Vector2(extent.x*(0.5+side*0.18),extent.y*0.94)-position
			for tick: int in range(7):
				var angle: float = (-PI*0.5+tick*0.17) if side == 1 else (-PI*0.5-tick*0.17)
				var direction := Vector2(cos(angle),sin(angle))
				draw_line(center+direction*25,center+direction*35,Color("a6c2ce") if tick/7.0 < speed_fraction else Color("42545f"),3.5,true)

static func attach(panel: PanelContainer, shape: String) -> HUDFrame:
	var frame := HUDFrame.new()
	frame.kind = shape
	panel.add_child(frame)
	panel.move_child(frame,0)
	var empty := StyleBoxEmpty.new()
	empty.set_content_margin_all(12)
	empty.content_margin_top = 6
	empty.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel",empty)
	return frame

static func rounded(points: PackedVector2Array, radius: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i: int in range(points.size()):
		var corner: Vector2 = points[i]
		var a: Vector2 = corner.move_toward(points[posmod(i-1,points.size())],radius)
		var b: Vector2 = corner.move_toward(points[(i+1)%points.size()],radius)
		for step: int in range(5):
			var t: float = step/4.0
			result.append(a.lerp(corner,t).lerp(corner.lerp(b,t),t))
	return result
