class_name MenuBackdrop
extends Control
## Original restrained contour motif, drawn locally with no raster dependencies.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),MenuStyle.INK)
	draw_rect(Rect2(Vector2(size.x*0.74,0),Vector2(size.x*0.26,size.y)),Color("131d23"))
