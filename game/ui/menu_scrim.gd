class_name MenuScrim
extends Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	# Soft edge shading leaves the scene open while the framed controls stay opaque.
	var dark := Color(0.025,0.065,0.09,0.78)
	var clear := Color(0.025,0.065,0.09,0)
	draw_polygon(PackedVector2Array([Vector2.ZERO,Vector2(size.x,0),Vector2(size.x,190),Vector2(0,190)]),PackedColorArray([dark,dark,clear,clear]))
	draw_polygon(PackedVector2Array([Vector2(0,size.y-190),Vector2(size.x,size.y-190),size,Vector2(0,size.y)]),PackedColorArray([clear,clear,dark,dark]))
