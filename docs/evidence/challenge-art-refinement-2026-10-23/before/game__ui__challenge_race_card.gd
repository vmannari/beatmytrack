extends Button
## One bounded, keyboard-accessible race destination; no live world per card.
var item: Dictionary
var chosen: bool = false
var target_ms: Variant
var remaining: String
var reward: String
var route: PackedVector2Array
var accent: Color = Color("a8b795")
var _route_size := Vector2(-1,-1)
var _route_points: PackedVector2Array

func _ready() -> void:
	custom_minimum_size = Vector2(218,226)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_contents = true
	text = str(item.entry.name)
	tooltip_text = text+" · "+str(item.creator)+" · "+VehicleCatalog.title(str(item.vehicle_id))+" · "+remaining
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	set_meta("audio_cue","select")
	for state: String in ["font_color","font_hover_color","font_focus_color","font_pressed_color"]:
		add_theme_color_override(state,Color.TRANSPARENT)
	add_theme_font_size_override("font_size",1)
	var style := MenuStyle.box(Color("101f2a"),0)
	style.border_color = MenuStyle.ACCENT if chosen else Color("344653")
	style.set_border_width_all(2 if chosen else 1)
	add_theme_stylebox_override("normal",style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.border_color = MenuStyle.ACCENT if chosen else Color("a4bac7")
	add_theme_stylebox_override("hover",hover)
	add_theme_stylebox_override("pressed",hover)
	resized.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)

func _draw() -> void:
	var art := Rect2(3,3,size.x-6,96)
	ChallengeGraphic.draw_map_background(self,art,accent)
	_project_route(art.size)
	if _route_points.size() > 1:
		draw_polyline(_route_points,Color("08131bcc"),5,true)
		draw_polyline(_route_points,Color("f4eee0"),2,true)
		draw_circle(_route_points[0],3,MenuStyle.ACCENT,true,-1,true)
	var format: String = "TIME ATTACK" if item.mode == "beat" else "3×3 SERIES" if item.mode == "3x3" else "GROUP RACE"
	var badge_width: float = MenuStyle.DISPLAY.get_string_size(format,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x+16
	draw_style_box(MenuStyle.box(Color("08151eeb"),0),Rect2(10,10,badge_width,24))
	draw_string(MenuStyle.DISPLAY,Vector2(18,28),format,HORIZONTAL_ALIGNMENT_LEFT,badge_width-12,14,MenuStyle.TEXT)
	if chosen:
		draw_circle(Vector2(size.x-20,22),8,MenuStyle.ACCENT,true,-1,true)
		draw_texture_rect(MenuIcon.texture("check",true),Rect2(size.x-25,17,10,10),false,MenuStyle.INK)
	draw_string(MenuStyle.DISPLAY,Vector2(14,125),str(item.entry.name),HORIZONTAL_ALIGNMENT_LEFT,size.x-28,23,MenuStyle.TEXT)
	draw_string(MenuStyle.BODY,Vector2(14,145),"by "+str(item.creator),HORIZONTAL_ALIGNMENT_LEFT,size.x-28,14,MenuStyle.MUTED)
	var target: String = MenuStyle.time_text(float(target_ms)/1000.0) if target_ms != null else "Set the first time"
	draw_string(MenuStyle.DISPLAY,Vector2(14,177),target,HORIZONTAL_ALIGNMENT_LEFT,size.x-28,29 if target_ms != null else 24,MenuStyle.ACCENT)
	var car: String = VehicleCatalog.title(str(item.vehicle_id))
	draw_string(MenuStyle.BODY,Vector2(14,198),car+" · "+("3 tracks" if item.mode == "3x3" else "5 laps"),HORIZONTAL_ALIGNMENT_LEFT,size.x-28,14,MenuStyle.MUTED)
	draw_string(MenuStyle.BODY,Vector2(14,218),remaining,HORIZONTAL_ALIGNMENT_LEFT,size.x-28,13,MenuStyle.MUTED)
	var remaining_width: float = MenuStyle.BODY.get_string_size(remaining,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x
	if size.x >= 250 and remaining_width+MenuStyle.BODY.get_string_size(reward,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x+36 <= size.x:
		var reward_width: float = minf(size.x*0.55,MenuStyle.BODY.get_string_size(reward,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x)
		draw_string(MenuStyle.BODY,Vector2(size.x-14-reward_width,218),reward,HORIZONTAL_ALIGNMENT_LEFT,reward_width,13,MenuStyle.POSITIVE)

func _project_route(art_size: Vector2) -> void:
	if _route_size == art_size: return
	_route_size = art_size
	_route_points = PackedVector2Array()
	if route.size() < 2: return
	var bounds := Rect2(Vector2(route[0].x,-route[0].y),Vector2.ZERO)
	for point: Vector2 in route: bounds = bounds.expand(Vector2(point.x,-point.y))
	var area := Rect2(22,40,art_size.x-38,48)
	var scale: float = minf(area.size.x/maxf(1,bounds.size.x),area.size.y/maxf(1,bounds.size.y))
	for point: Vector2 in route: _route_points.append(area.get_center()+(Vector2(point.x,-point.y)-bounds.get_center())*scale)
	if _route_points[0].distance_to(_route_points[-1]) > 0.01: _route_points.append(_route_points[0])
