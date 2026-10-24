extends Button
## Four ordinary focusable buttons, with bounded original menu graphics.
var format_id: String = "duel"
var caption: String = "Head to head"
var description: PackedStringArray = ["One rival. Your time to beat."]
var audience: String = "You + one rival"
var tries: String = "Unlimited tries"
var chosen: bool = false
var scenery: Texture2D
var vehicle_art: Texture2D

func _ready() -> void:
	custom_minimum_size = Vector2(180,190)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text = caption
	tooltip_text = caption+". "+" ".join(description)+" "+audience+". "+tries
	for state: String in ["font_color","font_hover_color","font_focus_color","font_pressed_color","font_disabled_color"]:
		add_theme_color_override(state,Color.TRANSPARENT)
	add_theme_font_size_override("font_size",1)
	set_meta("audio_cue","select")
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	resized.connect(queue_redraw)
	refresh()

func refresh() -> void:
	tooltip_text = caption+". "+" ".join(description)+" "+audience+". "+tries
	var style := MenuStyle.box(Color("183039") if chosen else Color("122936"),0)
	style.border_color = MenuStyle.ACCENT if chosen else Color("48616d")
	style.set_border_width_all(2 if chosen else 1)
	add_theme_stylebox_override("normal",style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color("203b45")
	hover.border_color = MenuStyle.ACCENT if chosen else Color("91abb5")
	add_theme_stylebox_override("hover",hover)
	add_theme_stylebox_override("pressed",hover)
	var inactive := style.duplicate() as StyleBoxFlat
	inactive.bg_color = Color("13232d")
	add_theme_stylebox_override("disabled",inactive)
	button_pressed = chosen
	queue_redraw()

func _draw() -> void:
	var inset: float = 14.0
	var art_height: float = 70.0
	var available: float = size.x-inset*2.0
	var tint := Color(1,1,1,0.45 if disabled else 1.0)
	if scenery != null:
		draw_texture_rect(scenery,Rect2(3,3,size.x-6,art_height),false,Color(0.7,0.8,0.85,0.32)*tint)
	draw_rect(Rect2(3,3,size.x-6,art_height),Color(0.03,0.08,0.11,0.56))
	var center := Vector2(size.x*0.5,art_height*0.5+4)
	match format_id:
		"duel":
			var extent := Vector2(minf(78.0,size.x*0.28),51)
			if vehicle_art != null:
				draw_texture_rect(vehicle_art,Rect2(center-Vector2(extent.x+18,extent.y*0.5),extent),false,tint)
				draw_texture_rect(vehicle_art,Rect2(center+Vector2(18,-extent.y*0.5),extent),false,tint)
			draw_string(MenuStyle.DISPLAY,center+Vector2(-11,7),"VS",HORIZONTAL_ALIGNMENT_LEFT,-1,23,MenuStyle.ACCENT*tint)
		"group":
			for index: int in range(6):
				var origin := center+Vector2((index%3-1)*42-14,(index/3)*28-24)
				var color: Color = MenuStyle.ACCENT if index == 0 else MenuStyle.MUTED
				draw_line(origin+Vector2(0,19),origin+Vector2(30,19),color*0.7,1.5,true)
				draw_texture_rect(MenuIcon.texture("car"),Rect2(origin+Vector2(4,0),Vector2(24,20)),false,color*tint)
		"three":
			for index: int in range(3):
				var rect := Rect2(center+Vector2((index-1)*43-18,-23),Vector2(36,43))
				var color: Color = MenuStyle.ACCENT if index == 2 else MenuStyle.MUTED
				draw_rect(rect,color*0.6,false,1.0)
				draw_string(MenuStyle.DISPLAY,rect.position+Vector2(5,32),"0"+str(index+1),HORIZONTAL_ALIGNMENT_LEFT,-1,29,color*tint)
		"custom":
			draw_texture_rect(MenuIcon.texture("settings",true),Rect2(center-Vector2(23,23),Vector2(46,46)),false,MenuStyle.TEXT*tint)
	var font_size: int = 29 if size.x >= 250 else 25
	draw_string(MenuStyle.DISPLAY,Vector2(inset,art_height+36),caption,HORIZONTAL_ALIGNMENT_LEFT,available,font_size,(MenuStyle.ACCENT if chosen else MenuStyle.TEXT)*tint)
	var y: float = art_height+58
	for line: String in description:
		draw_string(MenuStyle.BODY,Vector2(inset,y),line,HORIZONTAL_ALIGNMENT_LEFT,available,12,MenuStyle.MUTED*tint)
		y += 16
	var base: float = size.y-28
	draw_line(Vector2(inset,base-11),Vector2(size.x-inset,base-11),Color("39515a"),1.0)
	draw_string(MenuStyle.BODY,Vector2(inset,base+5),audience,HORIZONTAL_ALIGNMENT_LEFT,available,11,MenuStyle.MUTED*tint)
	draw_string(MenuStyle.BODY,Vector2(inset,base+20),tries,HORIZONTAL_ALIGNMENT_LEFT,available,11,MenuStyle.TEXT*tint)
	var marker := Vector2(size.x-17,17)
	draw_circle(marker,9,MenuStyle.ACCENT if chosen else Color("102631"),true,-1,true)
	if chosen:
		draw_texture_rect(MenuIcon.texture("check"),Rect2(marker-Vector2(6,6),Vector2(12,12)),false,MenuStyle.INK)
	else: draw_arc(marker,9,0,TAU,24,Color("718c98"),1,true)
