class_name MenuScrim
extends Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	# Flat contrast surfaces; the car and setting remain visible behind the UI.
	draw_rect(Rect2(Vector2.ZERO,Vector2(size.x,100)),Color(0.045,0.06,0.07,0.92))
	draw_rect(Rect2(Vector2(0,100),Vector2(size.x*0.37,size.y-100)),Color(0.045,0.06,0.07,0.95))
	draw_rect(Rect2(Vector2(0,size.y-142),Vector2(size.x,142)),Color(0.045,0.06,0.07,0.96))
