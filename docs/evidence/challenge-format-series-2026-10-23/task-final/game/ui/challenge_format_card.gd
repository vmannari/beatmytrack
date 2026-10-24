extends Button
## Focusable format posters: one optical grid, original vector art, no extra textures.
var format_id: String = "duel"
var caption: String = "Head to head"
var description: PackedStringArray = ["One rival. Your time to beat."]
var audience: String = "You + one rival"
var tries: String = "Unlimited tries"
var chosen: bool = false
var scenery: Texture2D

func _ready() -> void:
	custom_minimum_size = Vector2(180,260)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	text = caption
	for state: String in ["font_color","font_hover_color","font_focus_color","font_pressed_color","font_disabled_color"]:
		add_theme_color_override(state,Color.TRANSPARENT)
	add_theme_font_size_override("font_size",1)
	set_meta("audio_cue","select")
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	resized.connect(queue_redraw)
	refresh()

func refresh() -> void:
	tooltip_text = caption+". "+" ".join(description)+" "+audience+". "+tries
	var style := MenuStyle.box(Color("172c36") if chosen else Color("10232f"),0)
	style.set_corner_radius_all(0)
	style.border_color = MenuStyle.ACCENT if chosen else Color("3b5462")
	style.set_border_width_all(2 if chosen else 1)
	add_theme_stylebox_override("normal",style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color("1c3540")
	hover.border_color = MenuStyle.ACCENT if chosen else Color("9bb4be")
	add_theme_stylebox_override("hover",hover)
	add_theme_stylebox_override("pressed",hover)
	var inactive := style.duplicate() as StyleBoxFlat
	inactive.bg_color = Color("13232d")
	add_theme_stylebox_override("disabled",inactive)
	button_pressed = chosen
	queue_redraw()

func artwork_rect() -> Rect2:
	return Rect2(1,1,size.x-2,maxf(92,size.y-2))

func _draw() -> void:
	var inset: float = 19 if size.x >= 250 else 15
	var tint := Color(1,1,1,0.45 if disabled else 1.0)
	var art: Rect2 = artwork_rect()
	if scenery != null:
		# Crop instead of squeezing an entire biome into a shallow strip.
		var source := Rect2(Vector2.ZERO,scenery.get_size())
		var ratio: float = art.size.x/art.size.y
		if source.size.x/source.size.y > ratio:
			source.position.x = (source.size.x-source.size.y*ratio)*0.5
			source.size.x = source.size.y*ratio
		else:
			source.position.y = (source.size.y-source.size.x/ratio)*0.5
			source.size.y = source.size.x/ratio
		draw_texture_rect_region(scenery,art,source,(Color.WHITE if chosen else Color(0.62,0.68,0.72))*tint)
	draw_rect(art,Color(0.025,0.065,0.09,0.42))
	for side: int in [-1,1]:
		var x: float = size.x*0.5+side*minf(88,size.x*0.30)
		draw_line(Vector2(x,33),Vector2(x,art.end.y-10),Color(0.57,0.72,0.76,0.12),1,true)
	var index: int = ["duel","group","three","custom"].find(format_id)+1
	draw_string(MenuStyle.DISPLAY,Vector2(inset,25),"0"+str(index),HORIZONTAL_ALIGNMENT_LEFT,-1,15,MenuStyle.ACCENT*tint if chosen else Color("78929e")*tint)
	var center := Vector2(size.x*0.5,(size.y-80)*0.5)
	var graphic_scale: float = minf(1.65,minf((art.size.y-100)/88.0,(size.x-40)/205.0))
	match format_id:
		"duel":
			_draw_car(center+Vector2(-55*graphic_scale,1),-0.13,graphic_scale*0.84,Color("d7dfda")*tint)
			_draw_car(center+Vector2(55*graphic_scale,-1),PI-0.13,graphic_scale*0.84,Color("819fac")*tint)
			draw_string(MenuStyle.DISPLAY,center+Vector2(-16,12),"VS",HORIZONTAL_ALIGNMENT_LEFT,-1,31,MenuStyle.ACCENT*tint)
		"group":
			for i: int in range(4):
				var point := center+Vector2((i%2)*62-31,(i/2)*45-22)
				point.y += -5 if i%2 == 0 else 5
				draw_line(point+Vector2(-18,22),point+Vector2(18,22),Color("607a85")*0.6,1,true)
				_draw_car(center+(point-center)*graphic_scale,0,graphic_scale*0.42,(Color("d7dfda") if i == 0 else Color("819fac"))*tint)
		"three":
			for i: int in range(3):
				var rect := Rect2(center+Vector2((i-1)*56-24,-36)*graphic_scale,Vector2(48,72)*graphic_scale)
				var color: Color = MenuStyle.ACCENT if i == 2 else Color("d2dfe2")
				draw_rect(rect,Color(0.03,0.08,0.11,0.8))
				draw_rect(rect,color*0.65,false,1.5)
				draw_string(MenuStyle.DISPLAY,rect.position+Vector2(13,43)*graphic_scale,str(i+1),HORIZONTAL_ALIGNMENT_LEFT,-1,int(34*graphic_scale),color*tint)
				for dot: int in range(3): draw_circle(rect.position+Vector2(13+dot*11,58)*graphic_scale,3*graphic_scale,color,true,-1,true)
		"custom":
			for i: int in range(3):
				var y: float = center.y+(i-1)*24*graphic_scale
				var half: float = 69*graphic_scale
				draw_line(Vector2(center.x-half,y),Vector2(center.x+half,y),Color("8ea8b2")*tint,3,true)
				var knob := Vector2(center.x+[-30,28,-6][i]*graphic_scale,y)
				draw_circle(knob,9*graphic_scale,Color("10232f"),true,-1,true)
				draw_circle(knob,7*graphic_scale,(MenuStyle.ACCENT if i == 1 else Color("d7e1df"))*tint,true,-1,true)
	var strip := Rect2(8,size.y-72,size.x-16,64)
	draw_rect(strip,MenuStyle.ACCENT if chosen else Color("091720f2"))
	var label_color: Color = MenuStyle.INK if chosen else MenuStyle.TEXT
	var title_width: float = MenuStyle.DISPLAY.get_string_size(caption.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,28).x
	draw_string(MenuStyle.DISPLAY,Vector2(maxf(20,(size.x-title_width)*0.5),size.y-31),caption.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,size.x-40,28,label_color*tint)
	if chosen:
		var marker := Vector2(size.x-21,21)
		draw_circle(marker,10,MenuStyle.ACCENT,true,-1,true)
		draw_texture_rect(MenuIcon.texture("check",true),Rect2(marker-Vector2(6,6),Vector2(12,12)),false,MenuStyle.INK)

func _draw_car(center: Vector2, angle: float, extent: float, color: Color) -> void:
	draw_set_transform(center,angle,Vector2.ONE*extent)
	var body := PackedVector2Array([Vector2(-12,-41),Vector2(12,-41),Vector2(17,-29),Vector2(18,30),Vector2(13,40),Vector2(-13,40),Vector2(-18,30),Vector2(-17,-29)])
	draw_colored_polygon(body,Color(0.015,0.035,0.045,0.9))
	for side: int in [-1,1]:
		draw_rect(Rect2(side*18-3,-24,6,14),Color("050e14"))
		draw_rect(Rect2(side*18-3,18,6,14),Color("050e14"))
	var painted := body.duplicate()
	for i: int in range(painted.size()): painted[i] *= Vector2(0.88,0.95)
	draw_colored_polygon(painted,color)
	var outline := painted.duplicate()
	outline.append(outline[0])
	draw_polyline(outline,color,1.0,true)
	draw_colored_polygon(PackedVector2Array([Vector2(-11,-16),Vector2(11,-16),Vector2(13,-6),Vector2(-13,-6)]),Color("213d4b"))
	draw_rect(Rect2(-11,-3,22,21),color.darkened(0.14))
	draw_colored_polygon(PackedVector2Array([Vector2(-12,20),Vector2(12,20),Vector2(10,27),Vector2(-10,27)]),Color("213d4b"))
	draw_line(Vector2(-9,-31),Vector2(9,-31),color.lightened(0.35),2,true)
	draw_line(Vector2(-12,33),Vector2(-7,33),Color("b87b68"),2,true)
	draw_line(Vector2(7,33),Vector2(12,33),Color("b87b68"),2,true)
	draw_set_transform(Vector2.ZERO)
