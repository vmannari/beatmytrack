class_name CheckpointNotice
extends Control
## Persistent missed-checkpoint banner with one live direction arrow.
const AMBER := Color("ffb632")
var label: Label
var bearing: Vector2 = Vector2.UP
var banner_rect := Rect2()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label = Label.new()
	label.name = "ShortcutNotice"
	label.text = "MISSED CHECKPOINT"
	label.add_theme_font_override("font",RaceHUDStyle.DISPLAY)
	label.add_theme_font_size_override("font_size",26)
	label.add_theme_color_override("font_color",RaceHUDStyle.TEXT)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	clear()

func clear() -> void:
	visible = false
	label.visible = false

func present(marker: CheckpointMarker, camera: Camera3D, source_screen: Vector2 = Vector2.INF) -> void:
	var was_visible: bool = visible
	var previous_bearing: Vector2 = bearing
	var previous_rect: Rect2 = banner_rect
	var active: bool = marker.visible
	visible = active
	label.visible = active
	if not active: return
	var target: Vector3 = marker.global_position
	var projected: Vector2 = camera.unproject_position(target)
	var view_size: Vector2 = camera.get_viewport().get_visible_rect().size
	var source: Vector2 = view_size*0.5 if source_screen == Vector2.INF else source_screen
	var delta: Vector2 = projected-source
	if camera.projection == Camera3D.PROJECTION_PERSPECTIVE and camera.is_position_behind(target): delta = -delta
	bearing = delta.normalized() if delta.length_squared() > 0.01 else Vector2.UP
	banner_rect = Rect2(Vector2((size.x-386)*0.5,174),Vector2(386,54))
	label.position = banner_rect.position+Vector2(70,0)
	label.size = Vector2(254,54)
	if not was_visible or previous_bearing != bearing or previous_rect != banner_rect: queue_redraw()

func _draw() -> void:
	if not visible: return
	var p: Vector2 = banner_rect.position
	var polygon := PackedVector2Array([p+Vector2(28,0),p+Vector2(372,0),p+Vector2(344,54),p+Vector2(28,54)])
	draw_colored_polygon(polygon,Color("101c22eb"))
	var border: PackedVector2Array = polygon.duplicate()
	border.append(polygon[0])
	draw_polyline(border,AMBER,1.5,true)
	for offset: float in [0.0,12.0]:
		draw_colored_polygon(PackedVector2Array([p+Vector2(378+offset,0),p+Vector2(386+offset,0),p+Vector2(358+offset,54),p+Vector2(350+offset,54)]),AMBER)
	var warning: Vector2 = p+Vector2(28,27)
	draw_circle(warning,33,Color("111e22f2"))
	draw_arc(warning,33,0,TAU,64,AMBER,2.5,true)
	draw_line(warning+Vector2(0,-14),warning+Vector2(0,4),AMBER,5,true)
	draw_circle(warning+Vector2(0,13),3,AMBER)
	_arrow(p+Vector2(326,27),13)

func _arrow(center: Vector2, radius: float) -> void:
	var side: Vector2 = bearing.orthogonal()
	draw_colored_polygon(PackedVector2Array([center+bearing*radius,center-bearing*radius*0.65+side*radius*0.7,center-bearing*radius*0.25,center-bearing*radius*0.65-side*radius*0.7]),AMBER)
