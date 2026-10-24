extends HSlider
## Native range/input/save behavior with a dial matching the turntable hardware.
const Hardware = preload("res://ui/garage_audio_style.gd")

func _ready() -> void:
	custom_minimum_size = Vector2(100,48)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["grabber","grabber_highlight","grabber_disabled"]:
		add_theme_icon_override(state,Hardware.texture("knob_hover" if state == "grabber_highlight" else "knob_disabled" if state == "grabber_disabled" else "knob"))
	var rail := MenuStyle.box(Color("061017"),0)
	rail.set_corner_radius_all(3)
	rail.border_color = Color("344852")
	rail.set_border_width_all(1)
	rail.content_margin_top = 3
	rail.content_margin_bottom = 3
	add_theme_stylebox_override("slider",rail)
	var fill := MenuStyle.box(Color("c6a45c"),0)
	fill.set_corner_radius_all(3)
	fill.content_margin_top = 2
	fill.content_margin_bottom = 2
	add_theme_stylebox_override("grabber_area",fill)
	add_theme_stylebox_override("grabber_area_highlight",fill)
	resized.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)

func _draw() -> void:
	for index: int in range(21):
		var x: float = lerpf(20,size.x-20,index/20.0)
		draw_line(Vector2(x,size.y*0.5+9),Vector2(x,size.y*0.5+12+(2 if index%5==0 else 0)),Color("526770"),1)
	if has_focus():
		var outline := MenuStyle.box(Color.TRANSPARENT,0)
		outline.border_color = MenuStyle.ACCENT
		outline.set_border_width_all(1)
		draw_style_box(outline,Rect2(Vector2.ZERO,size))
