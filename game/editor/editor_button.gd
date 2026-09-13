class_name EditorButton
extends Button
## Small original vector glyphs: readable controls without covering the world.

const CYAN := Color("16c2cf")
var glyph: String = ""
var caption: String = ""

static func make(label: String, icon: String, action: Callable, chosen: bool = false) -> EditorButton:
	var button := EditorButton.new()
	button.caption = label
	button.text = label
	button.glyph = icon
	button.tooltip_text = label
	button.custom_minimum_size = Vector2(76,68) if not label.is_empty() else Vector2(52,52)
	button.toggle_mode = chosen
	button.button_pressed = chosen
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size",16)
	for state: String in ["normal","hover","pressed","disabled","focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.045,0.075,0.09,0.90) if state != "pressed" else Color(0.015,0.35,0.41,0.97)
		box.border_color = CYAN if state in ["pressed","focus"] else Color(0.65,0.78,0.78,0.35)
		box.set_border_width_all(2 if state in ["pressed","focus"] else 1)
		box.set_corner_radius_all(10 if not label.is_empty() else 26)
		box.content_margin_left = 6
		box.content_margin_right = 6
		button.add_theme_stylebox_override(state,box)
	button.add_theme_color_override("font_color",Color.TRANSPARENT)
	button.add_theme_color_override("font_hover_color",Color.TRANSPARENT)
	button.add_theme_color_override("font_pressed_color",Color.TRANSPARENT)
	button.add_theme_color_override("font_disabled_color",Color.TRANSPARENT)
	button.pressed.connect(action)
	return button

func _draw() -> void:
	var center := Vector2(size.x*0.5,26 if not caption.is_empty() else size.y*0.5)
	var ink := Color(0.94,0.97,0.97,0.35 if disabled else 1.0)
	var path := PackedVector2Array()
	if glyph in ["straight","curve","s_bend","hairpin","road"]:
		for i: int in range(25):
			var t: float = float(i)/24
			var p := Vector2(lerpf(-23,23,t),0)
			if glyph == "curve": p = Vector2(-18+36*sin(t*PI*0.5),12-24*(1-cos(t*PI*0.5)))
			if glyph == "s_bend": p.y = -sin(t*TAU)*8
			if glyph == "hairpin": p = Vector2(-cos(t*PI)*20,10-sin(t*PI)*22)
			if glyph == "road": p = Vector2(lerpf(-5,5,t),lerpf(13,-13,t))
			path.append(center+p)
		draw_polyline(path,ink,12,true)
		draw_polyline(path,Color("64797d"),8,true)
		draw_polyline(path,ink,1,true)
	elif glyph == "surface":
		for y: int in [5,-2,-9]: draw_polyline(PackedVector2Array([center+Vector2(-13,y),center+Vector2(0,y-6),center+Vector2(13,y),center+Vector2(0,y+6),center+Vector2(-13,y)]),ink,2,true)
	elif glyph in ["tree","objects"]:
		draw_line(center,center+Vector2(0,14),ink,4,true)
		for p: Vector2 in [Vector2(0,-10),Vector2(-6,-3),Vector2(6,-3)]: draw_circle(center+p,7,ink)
	elif glyph == "rock": draw_colored_polygon(PackedVector2Array([center+Vector2(-13,9),center+Vector2(-8,-9),center+Vector2(4,-13),center+Vector2(13,3),center+Vector2(8,12)]),ink)
	elif glyph in ["barrier","tyre_wall","fence"]:
		for x: int in [-16,-5,6,17]:
			if glyph == "tyre_wall": draw_circle(center+Vector2(x,0),6,ink,false,3,true)
			else: draw_line(center+Vector2(x,-9),center+Vector2(x,10),ink,4,true)
		if glyph != "tyre_wall":
			draw_line(center+Vector2(-20,-4),center+Vector2(20,-4),ink,4,true)
			draw_line(center+Vector2(-20,5),center+Vector2(20,5),ink,4,true)
	elif glyph == "race":
		draw_line(center+Vector2(-11,14),center+Vector2(-11,-15),ink,2,true)
		for x: int in range(4):
			for y: int in range(3): draw_rect(Rect2(center+Vector2(-10+x*6,-14+y*6),Vector2(6,6)),ink if (x+y)%2 == 0 else Color("52666a"))
	else:
		var symbol: String = {"back":"‹","undo":"↶","redo":"↷","test":"▶","confirm":"✓","rotate":"↻","flip":"⇄","snap":"⊙","move":"✥","more":"•••","minus":"−","plus":"+","fit":"⌗","delete":"×","issue":"!","width":"↔"}.get(glyph,glyph)
		draw_string(ThemeDB.fallback_font,center+Vector2(-ThemeDB.fallback_font.get_string_size(symbol,HORIZONTAL_ALIGNMENT_LEFT,-1,28).x*0.5,10),symbol,HORIZONTAL_ALIGNMENT_LEFT,-1,28,ink)
	if not caption.is_empty():
		var font: Font = get_theme_font("font")
		draw_string(font,Vector2((size.x-font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x)*0.5,size.y-9),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,16,ink)
