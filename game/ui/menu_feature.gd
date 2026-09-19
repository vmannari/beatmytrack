class_name MenuFeature
extends Button
## Secondary destinations share a compact footer, below the race decision.

var heading: String
var description: String

func _ready() -> void:
	custom_minimum_size = Vector2(200,48)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_contents = true
	add_theme_stylebox_override("normal",MenuStyle.card(0))
	add_theme_stylebox_override("hover",MenuStyle.box(Color("284858"),0))
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = heading+". "+description

func _draw() -> void:
	draw_string(MenuStyle.DISPLAY,Vector2(16,34),heading,HORIZONTAL_ALIGNMENT_LEFT,size.x-55,25,MenuStyle.TEXT)
	draw_texture_rect(MenuIcon.texture("arrow"),Rect2(size.x-37,17,20,20),false,MenuStyle.ACCENT)
