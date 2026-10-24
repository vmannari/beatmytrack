class_name MenuBrand
extends Control
## Original type lockup and racing strokes; the owner's board stays a reference.

func _ready() -> void:
	custom_minimum_size = Vector2(196,64)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	draw_set_transform(Vector2(9,2),-0.065)
	draw_line(Vector2(0,8),Vector2(0,53),MenuStyle.ACCENT,3,true)
	draw_string(MenuStyle.DISPLAY,Vector2(13,26),"BEAT",HORIZONTAL_ALIGNMENT_LEFT,-1,33,MenuStyle.TEXT)
	draw_string(MenuStyle.DISPLAY,Vector2(13,55),"MY",HORIZONTAL_ALIGNMENT_LEFT,-1,33,MenuStyle.ACCENT)
	draw_string(MenuStyle.DISPLAY,Vector2(59,55),"TRACK",HORIZONTAL_ALIGNMENT_LEFT,-1,33,MenuStyle.TEXT)
	draw_line(Vector2(84,15),Vector2(166,10),MenuStyle.ACCENT,2,true)
	draw_line(Vector2(86,21),Vector2(153,17),MenuStyle.TEXT,2,true)
