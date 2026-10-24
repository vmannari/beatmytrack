extends Button
## Native circuit diagrams with the existing track selection label.
var entry: Dictionary = {}
var chosen: bool = false

func _ready() -> void:
	name = "ChallengeTrack_"+str(entry.get("version_id",""))
	custom_minimum_size = Vector2(180,230)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	clip_contents = true
	tooltip_text = str(entry.get("name",""))+" · "+str(entry.get("creator",""))
	text = str(entry.get("name",""))
	add_theme_font_size_override("font_size",1)
	for state: String in ["font_color","font_hover_color","font_focus_color","font_pressed_color","font_disabled_color"]: add_theme_color_override(state,Color.TRANSPARENT)
	var style := MenuStyle.box(Color.TRANSPARENT,0)
	style.set_corner_radius_all(0)
	style.set_border_width_all(1)
	style.border_color = MenuStyle.ACCENT if chosen else MenuStyle.BORDER
	add_theme_stylebox_override("normal",style)
	resized.connect(queue_redraw)
	set_meta("audio_cue","select")
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _draw() -> void:
	ChallengeGraphic.draw_map_background(self,Rect2(1,1,size.x-2,size.y-2),ChallengeGraphic.biome_accent(str(entry.get("theme","pine"))))
	var points: PackedVector2Array = ChallengesPage._card_outline(entry.get("points",[]))
	if points.size() >= 2:
		var bounds := Rect2(points[0],Vector2.ZERO)
		for point: Vector2 in points: bounds = bounds.expand(point)
		var area := Vector2(size.x-88,maxf(60,size.y-156))
		var extent: float = minf(area.x/maxf(1,bounds.size.x),area.y/maxf(1,bounds.size.y))
		for index: int in range(points.size()): points[index] = (points[index]-bounds.get_center())*extent+Vector2(size.x*0.5,(size.y-80)*0.5)
		draw_polyline(points,Color(0.01,0.04,0.07,0.65),7,true)
		draw_polyline(points,MenuStyle.ACCENT if chosen else Color("d9e4e5"),3,true)
	var strip := Rect2(8,size.y-72,size.x-16,64)
	draw_rect(strip,MenuStyle.ACCENT if chosen else Color("091720f2"))
	var color: Color = MenuStyle.INK if chosen else MenuStyle.TEXT
	draw_string(MenuStyle.DISPLAY,strip.position+Vector2(16,29),str(entry.get("name","")),HORIZONTAL_ALIGNMENT_LEFT,strip.size.x-32,26,color)
	draw_string(MenuStyle.BODY,strip.position+Vector2(16,49),"By "+str(entry.get("creator","")),HORIZONTAL_ALIGNMENT_LEFT,strip.size.x-32,13,color)
	if chosen: draw_texture_rect(MenuIcon.texture("check",true),Rect2(size.x-36,16,20,20),false,MenuStyle.ACCENT)
