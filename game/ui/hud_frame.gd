class_name HUDFrame
extends Control
## Scalable inked instrument silhouettes, drawn behind real UI controls.
var kind: String = "clock"
var speed_fraction: float = 0.0:
	set(value):
		var changed: bool = floori(value*60.0) != floori(speed_fraction*60.0)
		speed_fraction = value
		if changed and speed_ticks != null: speed_ticks.queue_redraw()
var speed_ticks: Control
var draw_count: int = 0
var lap_status: Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_parent().resized.connect(queue_redraw)
	if kind == "speed":
		speed_ticks = Control.new()
		speed_ticks.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(speed_ticks)
		speed_ticks.draw.connect(_draw_speed_ticks)

func _draw() -> void:
	draw_count += 1
	var extent: Vector2 = (get_parent() as Control).size
	if kind == "map":
		var center := Vector2(76,extent.y*0.5)-position
		draw_circle(center,64,Color("12201a77"))
		_soft_backing(lap_backing_rect())
		draw_arc(center,64,0,TAU,96,Color("bac6c077"),1.5,true)
		draw_line(Vector2(152,36)-position,Vector2(152,extent.y-36)-position,Color("ccd2ceaa"),1,true)
	elif kind == "plain":
		_soft_backing(lap_backing_rect())
	elif kind == "clock":
		_soft_backing(Rect2(-position-Vector2(12,6),extent+Vector2(24,12)))
	elif kind == "speed":
		var center := Vector2(extent.x*0.5,extent.y-16)-position
		var radius: float = extent.x*0.48
		_soft_backing(Rect2(center-Vector2(radius,radius),Vector2(radius*2,radius+38)))
		draw_arc(center,radius,PI+0.06,TAU-0.06,96,Color("e8eee0bb"),1.6,true)
		draw_arc(center,radius,TAU-0.43,TAU-0.06,20,Color("dd4244"),3,true)
		if speed_ticks != null: speed_ticks.queue_redraw()

func _draw_speed_ticks() -> void:
	var extent: Vector2 = (get_parent() as Control).size
	var center := Vector2(extent.x*0.5,extent.y-16)-position
	var radius: float = extent.x*0.48
	for tick: int in range(61):
		var angle: float = lerpf(PI+0.10,TAU-0.10,tick/60.0)
		var direction := Vector2(cos(angle),sin(angle))
		var color := Color("e7ecd6aa") if tick/60.0 <= speed_fraction else Color("c4ceac55")
		if tick > 53: color = Color("d5534b99")
		speed_ticks.draw_line(center+direction*(radius-10),center+direction*(radius-(17 if tick % 5 == 0 else 14)),color,1,true)

func lap_backing_rect() -> Rect2:
	if lap_status == null: return Rect2()
	return Rect2(lap_status.global_position-global_position,lap_status.size).grow_individual(16,10,16,10)


func _soft_backing(rect: Rect2) -> void:
	# Feathered charcoal scrim: no hard card edge over the racing world.
	for layer: int in range(20):
		var inset: float = layer * 0.016
		var radii: Vector2 = rect.size * (0.5-inset)
		var points := PackedVector2Array()
		for segment: int in range(64):
			var angle: float = TAU*segment/64.0
			points.append(rect.get_center()+Vector2(cos(angle),sin(angle))*radii)
		draw_colored_polygon(points,Color(0.035,0.065,0.06,0.027))


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
