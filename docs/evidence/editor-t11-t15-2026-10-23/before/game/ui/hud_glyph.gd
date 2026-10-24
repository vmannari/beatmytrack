class_name HUDGlyph
extends Control
var kind: String = "pause"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if get_parent() is BaseButton:
		var button := get_parent() as BaseButton
		button.button_down.connect(queue_redraw)
		button.button_up.connect(queue_redraw)

func _draw() -> void:
	var center: Vector2 = size*0.5
	var ink: Color = Color("091923") if get_parent() is BaseButton and (get_parent() as BaseButton).is_pressed() else Color("f1eee3")
	match kind:
		"pause":
			for x: float in [-9,4]: draw_rect(Rect2(center+Vector2(x,-13),Vector2(6,26)),ink)
		"resume": draw_colored_polygon(PackedVector2Array([center+Vector2(-8,-13),center+Vector2(11,0),center+Vector2(-8,13)]),ink)
		"menu":
			for y: float in [-10,0,10]:
				draw_circle(center+Vector2(-13,y),2,ink)
				draw_line(center+Vector2(-5,y),center+Vector2(14,y),ink,3,true)
		"clock":
			draw_arc(center+Vector2(0,3),10,0,TAU,32,ink,2.5,true)
			draw_line(center+Vector2(0,-9),center+Vector2(0,-14),ink,3,true)
			draw_line(center+Vector2(-4,-14),center+Vector2(4,-14),ink,3,true)
			draw_line(center+Vector2(0,3),center+Vector2(3,-4),ink,2,true)
