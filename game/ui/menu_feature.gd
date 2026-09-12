class_name MenuFeature
extends Button
## Secondary destinations share a compact footer, below the race decision.

var heading: String
var description: String

func _ready() -> void:
	custom_minimum_size = Vector2(200,92)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_contents = true
	add_theme_stylebox_override("normal",MenuStyle.box(Color.TRANSPARENT))
	add_theme_stylebox_override("hover",MenuStyle.box(Color(1,1,1,0.06)))
	tooltip_text = heading+". "+description

func _draw() -> void:
	draw_line(Vector2(0,0),Vector2(size.x-20,0),Color("455057"),1)
	draw_string(MenuStyle.DISPLAY,Vector2(0,37),heading,HORIZONTAL_ALIGNMENT_LEFT,size.x-25,28,MenuStyle.TEXT)
	draw_string(MenuStyle.BODY,Vector2(0,68),description,HORIZONTAL_ALIGNMENT_LEFT,size.x-20,17,MenuStyle.MUTED)
