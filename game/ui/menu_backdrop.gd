class_name MenuBackdrop
extends Control
## Original restrained contour motif, drawn locally with no raster dependencies.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),MenuStyle.INK)
	for index: int in range(14):
		var points := PackedVector2Array()
		for step: int in range(70):
			var t: float = float(step)/69.0
			points.append(Vector2(size.x*(0.35+t*0.8),size.y*(0.16+index*0.048)+sin(t*7.0+0.5)*50))
		draw_polyline(points,Color(0.27,0.35,0.39,0.15),1,true)
