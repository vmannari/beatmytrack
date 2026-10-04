extends Control
## Transient start result in the checkpoint notice visual language.
var label: Label
var last_text: String = ""
var last_alpha: float = -1.0
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _process(_delta: float) -> void:
	if label == null: return
	if label.text == last_text and label.modulate.a == last_alpha: return
	last_text = label.text
	last_alpha = label.modulate.a
	queue_redraw()
func _draw() -> void:
	if label == null or label.text.is_empty(): return
	var warning: bool = label.text == "JUMPED START"
	var accent: Color = CheckpointNotice.AMBER if warning else Color("79d4aa")
	accent.a = label.modulate.a
	var center: Vector2 = size*0.5 + Vector2(0,-120)
	var p: Vector2 = center - Vector2(186,27)
	var polygon := PackedVector2Array([p+Vector2(28,0),p+Vector2(372,0),p+Vector2(344,54),p+Vector2(28,54)])
	var fill := Color("101c22eb")
	fill.a *= label.modulate.a
	draw_colored_polygon(polygon,fill)
	var border: PackedVector2Array = polygon.duplicate()
	border.append(polygon[0])
	draw_polyline(border,accent,1.5,true)
	for offset: float in ([0.0,12.0] if warning else []):
		draw_colored_polygon(PackedVector2Array([p+Vector2(378+offset,0),p+Vector2(386+offset,0),p+Vector2(358+offset,54),p+Vector2(350+offset,54)]),accent)
	var badge: Vector2 = p+Vector2(28,27)
	var badge_fill := Color("111e22f2")
	badge_fill.a *= label.modulate.a
	draw_circle(badge,33,badge_fill)
	draw_arc(badge,33,0,TAU,64,accent,2.5,true)
	if warning:
		draw_line(badge+Vector2(0,-14),badge+Vector2(0,4),accent,5,true)
		draw_circle(badge+Vector2(0,13),3,accent)
	else:
		draw_polyline(PackedVector2Array([badge+Vector2(-12,0),badge+Vector2(-3,10),badge+Vector2(14,-12)]),accent,4,true)
