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
	"objects": preload("res://assets/editor/objects.png"),
}

const CYAN := Color("16c2cf")
var glyph: String = ""
var caption: String = ""
var horizontal: bool = false
var compact: bool = false
var surface_tint := Color.TRANSPARENT
var _material_style: StyleBoxFlat
var _caption_label: Label
var _caption_key: Array = []

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

func _ready() -> void:
	_ensure_caption()

func _ensure_caption() -> void:
	if not is_inside_tree() or is_queued_for_deletion(): return
	if is_instance_valid(_caption_label): return
	_caption_label = get_node_or_null("ToolCaption") as Label
	if _caption_label == null:
		_caption_label = Label.new()
		_caption_label.name = "ToolCaption"
		_caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_caption_label.clip_text = true
		_caption_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_caption_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(_caption_label)
	_caption_key.clear()
	_sync_caption()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_TRANSLATION_CHANGED,NOTIFICATION_THEME_CHANGED]:
		_caption_key.clear()
		queue_redraw()

func _sync_caption() -> void:
	if not is_instance_valid(_caption_label):
		_ensure_caption.call_deferred()
		return
	var key: Array = [caption,disabled,horizontal,size,get_theme_font("font"),TranslationServer.get_locale()]
	if key == _caption_key: return
	_caption_key = key
	_caption_label.visible = not caption.is_empty()
	_caption_label.text = GameText.message(caption)
	_caption_label.add_theme_font_override("font",get_theme_font("font"))
	_caption_label.add_theme_font_size_override("font_size",18 if horizontal else 16)
	_caption_label.add_theme_color_override("font_color",EditorStyle.MUTED if disabled else Color("b4ed69") if glyph == "play" else EditorStyle.INK)
	if horizontal:
		_caption_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_caption_label.offset_left = 46; _caption_label.offset_right = -6
		_caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	else:
		_caption_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		_caption_label.offset_left = 4; _caption_label.offset_right = -4
		_caption_label.offset_top = -25; _caption_label.offset_bottom = -3
		_caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _draw() -> void:
	_sync_caption()
	if glyph.begins_with("terrain_"):
		_draw_material()
		return
	var center := Vector2(24,size.y*0.5) if horizontal else Vector2(size.x*0.5,26 if not caption.is_empty() else size.y*0.5)
	if compact and not caption.is_empty() and not horizontal:
		draw_set_transform(Vector2(size.x*0.5,18),0,Vector2(0.72,0.72))
		center = Vector2.ZERO
	var ink := Color(EditorStyle.INK,0.35 if disabled else 1.0)
	if glyph=="play": ink=Color("859095") if disabled else Color("b4ed69")
	var path := PackedVector2Array()
	if glyph == "road_nav":
		for x: int in [-10,10]: draw_polyline(PackedVector2Array([center+Vector2(x-3,13),center+Vector2(x-3,3),center+Vector2(x+3,-3),center+Vector2(x+3,-13)]),ink,2,true)
		for at: Vector2 in [Vector2(-3,9),Vector2(0,0),Vector2(3,-9)]: draw_line(center+at-Vector2(0,2),center+at+Vector2(0,2),ink,1.5,true)
	elif glyph == "objects_nav":
		var outline := PackedVector2Array([center+Vector2(0,-14),center+Vector2(13,-7),center+Vector2(13,8),center+Vector2(0,15),center+Vector2(-13,8),center+Vector2(-13,-7),center+Vector2(0,-14)])
		draw_polyline(outline,ink,2,true)
		draw_polyline(PackedVector2Array([center+Vector2(-13,-7),center,center+Vector2(13,-7)]),ink,2,true)
		draw_line(center,center+Vector2(0,15),ink,2,true)
	elif glyph == "size":
		draw_rect(Rect2(center-Vector2(11,8),Vector2(22,16)),ink,false,2)
		draw_polyline(PackedVector2Array([center+Vector2(-17,0),center+Vector2(-17,-14),center+Vector2(0,-14)]),ink,2,true)
		draw_polyline(PackedVector2Array([center+Vector2(0,14),center+Vector2(17,14),center+Vector2(17,0)]),ink,2,true)
	elif glyph.begins_with("place_"):
		if glyph == "place_single":
			draw_rect(Rect2(center-Vector2(7,6),Vector2(14,12)),ink,false,2)
		else:
			var points := PackedVector2Array()
			for index: int in range(5): points.append(center+Vector2(-22+index*11,8*sin(float(index)*PI/4) if glyph in ["place_curve","place_edge"] else 0.0))
			if glyph == "place_edge":
				draw_polyline(points,Color("596f78"),12,true)
				for index: int in range(points.size()): points[index].y -= 12
			draw_polyline(points,ink,2,true)
			for point: Vector2 in points: draw_circle(point,3,ink)
	elif ILLUSTRATIONS.has(glyph):
		var illustration: Texture2D = ILLUSTRATIONS[glyph]
		var bounds := Vector2(36,36) if horizontal else Vector2(size.x-8,48)
		var image_size: Vector2 = illustration.get_size()
		var fitted_size: Vector2 = image_size * minf(bounds.x/image_size.x,bounds.y/image_size.y)
		draw_texture_rect(illustration,Rect2(center-fitted_size*0.5,fitted_size),false,Color(1,1,1,0.35 if disabled else 1.0))
	elif glyph in ["copy","multi_select","cycle_objects"]:
		if glyph == "cycle_objects":
			for offset: Vector2 in [Vector2(-5,-5),Vector2(5,5)]: draw_rect(Rect2(center+offset-Vector2(10,8),Vector2(20,16)),ink,false,2)
			draw_line(center+Vector2(-17,16),center+Vector2(17,16),ink,2,true)
			draw_polyline(PackedVector2Array([center+Vector2(11,11),center+Vector2(17,16),center+Vector2(11,21)]),ink,2,true)
		elif glyph == "copy":
			draw_rect(Rect2(center+Vector2(-16,-13),Vector2(22,22)),ink,false,2)
			draw_rect(Rect2(center+Vector2(-6,-3),Vector2(22,22)),EditorStyle.ACCENT,false,2)
		else:
			draw_rect(Rect2(center-Vector2(18,15),Vector2(36,30)),ink,false,1.5)
			for offset: Vector2 in [Vector2(-9,-6),Vector2(8,5)]: draw_rect(Rect2(center+offset-Vector2(5,5),Vector2(10,10)),EditorStyle.ACCENT)
	elif glyph == "spline":
		var curve := PackedVector2Array()
		for i: int in range(25):
			var t: float = float(i)/24.0
			curve.append(center+Vector2(lerpf(-20,20,t),-sin(t*TAU)*10))
		draw_polyline(curve,ink,2.5,true)
		for i: int in [0,6,12,18,24]: draw_circle(curve[i],3,CYAN)
	elif glyph == "taper":
		var road := PackedVector2Array([center+Vector2(-18,-15),center+Vector2(18,-7),center+Vector2(18,7),center+Vector2(-18,15)])
		draw_colored_polygon(road,Color("59656a"))
		draw_polyline(road+PackedVector2Array([road[0]]),ink,2,true)
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
	elif glyph=="play":
		draw_colored_polygon(PackedVector2Array([center+Vector2(-7,-10),center+Vector2(10,0),center+Vector2(-7,10)]),ink)
	elif glyph == "publish":
		draw_polyline(PackedVector2Array([center+Vector2(-13,3),center+Vector2(-13,12),center+Vector2(13,12),center+Vector2(13,3)]),ink,2.5,true)
		draw_line(center+Vector2(0,5),center+Vector2(0,-12),ink,2.5,true)
		draw_polyline(PackedVector2Array([center+Vector2(-7,-5),center+Vector2(0,-12),center+Vector2(7,-5)]),ink,2.5,true)
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
	draw_set_transform(Vector2.ZERO)

func _draw_material() -> void:
	var surface: String = glyph.trim_prefix("terrain_")
	var tint: Color = {"road":Color("667177"),"grass":Color("65864c"),"dirt":Color("bc985f"),"snow":Color("d9e8e9"),"water":Color("4087a4"),"puddle":Color("619aa6"),"oil":Color("313039")}.get(surface,Color("65864c"))
	if surface_tint.a > 0: tint = surface_tint
	var alpha: float = 0.35 if disabled else 1.0
	var center := Vector2(size.x*0.5,18)
	if _material_style == null:
		_material_style = StyleBoxFlat.new()
		_material_style.set_corner_radius_all(4)
		_material_style.set_border_width_all(1)
	_material_style.bg_color = Color(tint,alpha)
	_material_style.border_color = Color(tint.lightened(0.18),alpha)
	draw_style_box(_material_style,Rect2(center-Vector2(13,13),Vector2(26,26)))
	var light := Color(tint.lightened(0.38),alpha*0.75)
	var dark := Color(tint.darkened(0.3),alpha*0.65)
	if surface in ["water","puddle","oil"]:
		for row: int in range(3):
			var wave := PackedVector2Array()
			for x: int in range(19): wave.append(center+Vector2(x-9,(row-1)*8+sin(x*0.5+row)*1.5))
			draw_polyline(wave,light,1.2,true)
	elif surface == "grass":
		for offset: Vector2 in [Vector2(-8,-7),Vector2(7,-5),Vector2(-5,8),Vector2(9,8)]:
			draw_line(center+offset-Vector2(1,2),center+offset+Vector2(1,2),light,1.5,true)
			draw_line(center+offset+Vector2(3,-3),center+offset+Vector2(2,1),dark,1.5,true)
	else:
		for i: int in range(13):
			var at := Vector2((i*13)%25-12,(i*7)%25-12)
			draw_circle(center+at,0.9 if surface == "snow" else 1.2,light if i%2 == 0 else dark)

static func action(label: String, icon: String, callback: Callable, primary: bool = false) -> EditorButton:
	var button: EditorButton=make(label,icon,callback,primary)
	button.horizontal=true
	button.custom_minimum_size=Vector2(108,52)
	return button
