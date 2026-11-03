extends CheckBox
## Small machined-brass membership mark inside a full-sized touch target.

func _ready() -> void:
	var empty := ImageTexture.create_from_image(Image.create_empty(1,1,false,Image.FORMAT_RGBA8))
	for icon_name: String in ["checked","unchecked","checked_disabled","unchecked_disabled","radio_checked","radio_unchecked","radio_checked_disabled","radio_unchecked_disabled"]:
		add_theme_icon_override(icon_name,empty)
	for state: String in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
		add_theme_stylebox_override(state,StyleBoxEmpty.new())
	for event: Signal in [toggled,mouse_entered,mouse_exited,focus_entered,focus_exited]:
		event.connect(func(_value: Variant = null) -> void: queue_redraw())

func _draw() -> void:
	var centre: Vector2 = size*0.5
	var hovered: bool = is_hovered() and not disabled
	var brass := Color("d8bd7f")
	var rim: Color = brass if button_pressed else Color("91a6ae") if hovered else Color("526b76")
	if hovered: draw_circle(centre,18,Color(0.74,0.65,0.43,0.10),true,-1,true)
	if has_focus(): draw_arc(centre,18,0,TAU,64,Color("9b895e"),1,true)
	if button_pressed: draw_circle(centre,10,Color("283a36"),true,-1,true)
	draw_arc(centre,10,0,TAU,48,rim,1.2,true)
	if button_pressed:
		draw_polyline(PackedVector2Array([centre+Vector2(-4,0),centre+Vector2(-1,3),centre+Vector2(5,-4)]),brass,1.8,true)
	else:
		draw_line(centre+Vector2(-4,0),centre+Vector2(4,0),rim,1.2,true)
		draw_line(centre+Vector2(0,-4),centre+Vector2(0,4),rim,1.2,true)
