class_name MenuBackdrop
extends Control
## Original illustrated workshop; only menu presentation consumes this texture.
const ART: Texture2D = preload("res://assets/menu/discovery-workshop.png")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var factor: float = maxf(size.x/ART.get_width(),size.y/ART.get_height())
	var drawn: Vector2 = ART.get_size()*factor
	draw_texture_rect(ART,Rect2((size-drawn)*0.5,drawn),false)
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.015,0.035,0.05,0.72))
	draw_rect(Rect2(0,0,size.x,99),Color(0.02,0.04,0.06,0.8))
