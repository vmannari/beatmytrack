class_name EditorButton
extends Button
## Owner-supplied illustrated assets with vector glyphs for utility controls.

const ILLUSTRATIONS: Dictionary = {
	"straight": preload("res://assets/editor/straight.png"),
	"road": preload("res://assets/editor/straight.png"),
	"curve": preload("res://assets/editor/curve.png"),
	"s_bend": preload("res://assets/editor/s_bend.png"),
	"hairpin": preload("res://assets/editor/hairpin.png"),
	"bridge": preload("res://assets/editor/bridge.png"),
	"surface": preload("res://assets/editor/surfaces.png"),
	"objects": preload("res://assets/editor/objects.png"),
}

const CYAN := Color("16c2cf")
var glyph: String = ""
var caption: String = ""
var horizontal: bool = false

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
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size",16)
	EditorStyle.apply(button,chosen)
	if icon=="confirm":
		for state: String in ["normal","hover","pressed","disabled","focus"]:
			var style: StyleBoxFlat=button.get_theme_stylebox(state).duplicate()
			style.set_corner_radius_all(32)
			button.add_theme_stylebox_override(state,style)
	for state: String in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_disabled_color"]:
		button.add_theme_color_override(state,Color.TRANSPARENT)
	button.pressed.connect(action)
	return button

func _draw() -> void:
	var center := Vector2(24,size.y*0.5) if horizontal else Vector2(size.x*0.5,26 if not caption.is_empty() else size.y*0.5)
	var ink := Color(0.94,0.97,0.97,0.35 if disabled else 1.0)
	if glyph=="play": ink=Color("859095") if disabled else Color("b4ed69")
	if button_pressed and get_parent() != null and get_parent().name=="EditorRail":
		draw_circle(Vector2(6,size.y*0.5),2.5,EditorStyle.ACCENT)
	var path := PackedVector2Array()
	if ILLUSTRATIONS.has(glyph):
		var illustration: Texture2D = ILLUSTRATIONS[glyph]
		var bounds := Vector2(36,36) if horizontal else Vector2(size.x-8,48)
		var image_size: Vector2 = illustration.get_size()
		var fitted_size: Vector2 = image_size * minf(bounds.x/image_size.x,bounds.y/image_size.y)
		draw_texture_rect(illustration,Rect2(center-fitted_size*0.5,fitted_size),false,Color(1,1,1,0.35 if disabled else 1.0))
	elif glyph == "paint_line":
		draw_line(center+Vector2(-14,13),center+Vector2(14,-13),ink,3.5,true)
	elif glyph == "paint_area":
		for sign_x: int in [-1,1]:
			for sign_y: int in [-1,1]:
				var corner: Vector2 = center+Vector2(sign_x*13,sign_y*12)
				draw_line(corner,corner-Vector2(sign_x*8,0),ink,2.5,true)
				draw_line(corner,corner-Vector2(0,sign_y*7),ink,2.5,true)
	elif glyph == "paint_brush":
		draw_line(center+Vector2(-2,2),center+Vector2(12,-12),ink,8,true)
		draw_circle(center+Vector2(12,-12),4,ink)
		draw_colored_polygon(PackedVector2Array([center+Vector2(-5,2),center+Vector2(1,8),center+Vector2(-8,15),center+Vector2(-16,16),center+Vector2(-11,7)]),ink)
	elif glyph.begins_with("terrain_"):
		var surface: String=glyph.trim_prefix("terrain_")
		var tint: Color={"road":Color("667177"),"grass":Color("65864c"),"dirt":Color("bc985f"),"water":Color("4087a4"),"puddle":Color("619aa6"),"oil":Color("313039")}.get(surface,ink)
		draw_style_box(EditorStyle.box(),Rect2(center-Vector2(22,15),Vector2(44,30)))
		draw_rect(Rect2(center-Vector2(19,12),Vector2(38,24)),tint)
		if surface in ["water","puddle","oil"]:
			for y: int in [-6,2,8]: draw_arc(center+Vector2(0,y),12,0.2,2.9,12,ink*Color(1,1,1,0.6),1.3,true)
		elif surface=="grass":
			for x: int in [-12,0,12]: draw_polyline(PackedVector2Array([center+Vector2(x-3,2),center+Vector2(x,7),center+Vector2(x+2,-5)]),ink,1.3,true)
		elif surface=="dirt":
			for point: Vector2 in [Vector2(-12,-5),Vector2(5,6),Vector2(13,-6),Vector2(-6,7)]: draw_circle(center+point,2,Color("e0c59b"))
		else:
			for x: int in [-12,0,12]: draw_line(center+Vector2(x-3,0),center+Vector2(x+3,0),ink,2,true)
	elif glyph=="play":
		draw_colored_polygon(PackedVector2Array([center+Vector2(-7,-10),center+Vector2(10,0),center+Vector2(-7,10)]),ink)
	elif glyph=="close":
		draw_line(center-Vector2(8,8),center+Vector2(8,8),ink,2.5,true)
		draw_line(center+Vector2(-8,8),center+Vector2(8,-8),ink,2.5,true)
	elif glyph=="pencil":
		draw_polyline(PackedVector2Array([center+Vector2(-9,10),center+Vector2(-6,2),center+Vector2(6,-10),center+Vector2(11,-5),center+Vector2(-1,7),center+Vector2(-9,10)]),ink,2,true)
	elif glyph=="waypoints":
		draw_polyline(PackedVector2Array([center+Vector2(-16,8),center+Vector2(0,-10),center+Vector2(16,6)]),ink,2,true)
		for point: Vector2 in [Vector2(-16,8),Vector2(0,-10),Vector2(16,6)]: draw_circle(center+point,4,ink)
	elif glyph=="biome":
		draw_circle(center+Vector2(10,-9),5,Color("b4ce7f"))
		draw_colored_polygon(PackedVector2Array([center+Vector2(-21,12),center+Vector2(-7,-10),center+Vector2(6,12)]),Color("7c9f79"))
		draw_colored_polygon(PackedVector2Array([center+Vector2(-3,12),center+Vector2(9,-3),center+Vector2(22,12)]),ink)
	elif glyph in ["load","save","next","options"]:
		if glyph=="load":
			draw_polyline(PackedVector2Array([center+Vector2(-10,7),center+Vector2(-10,-7),center+Vector2(-3,-7),center+Vector2(0,-3),center+Vector2(11,-3),center+Vector2(8,7),center+Vector2(-10,7)]),ink,2,true)
		elif glyph=="save":
			draw_rect(Rect2(center-Vector2(9,10),Vector2(18,20)),ink,false,2)
			draw_rect(Rect2(center+Vector2(-5,1),Vector2(10,9)),ink,false,2)
			draw_line(center+Vector2(-4,-7),center+Vector2(4,-7),ink,3,true)
		elif glyph=="next": draw_polyline(PackedVector2Array([center+Vector2(-4,-9),center+Vector2(4,0),center+Vector2(-4,9)]),ink,2.5,true)
		else:
			for y: int in [-7,0,7]:
				draw_line(center+Vector2(-10,y),center+Vector2(10,y),ink,1.5,true)
				draw_circle(center+Vector2(-4 if y==0 else 4,y),3,ink)
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
	if horizontal:
		draw_string(EditorStyle.FONT,Vector2(46,size.y*0.5+6),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,18,ink)
	elif not caption.is_empty():
		var font: Font = get_theme_font("font")
		draw_string(font,Vector2((size.x-font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x)*0.5,size.y-9),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,16,ink)

static func action(label: String, icon: String, callback: Callable, primary: bool = false) -> EditorButton:
	var button: EditorButton=make(label,icon,callback,primary)
	button.horizontal=true
	button.custom_minimum_size=Vector2(108,52)
	return button
