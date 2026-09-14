class_name TrackTile
extends Button
## Original route artwork drawn from bounded metadata; no live 3D per result.

var entry: Dictionary
var favorite: bool = false
var selected: bool = false

func _ready() -> void:
	clip_contents = true
	custom_minimum_size = Vector2(200,166)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = str(entry.name)+" — "+str(entry.creator)
	resized.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)

func _draw() -> void:
	var palette: Dictionary = {"pine":Color("405647"),"coast":Color("3c5961"),"desert":Color("78654e")}
	var base: Color = palette.get(entry.theme,Color("405647"))
	var frame := MenuStyle.box(Color("24323a"),0)
	frame.border_color = MenuStyle.TEXT if selected else Color("42525b")
	frame.set_border_width_all(2 if selected or is_hovered() else 1)
	draw_style_box(frame,Rect2(Vector2.ZERO,size))
	draw_rect(Rect2(Vector2(2,2),Vector2(size.x-4,100)),base)
	var paths: Array[PackedVector2Array] = []
	var pieces: Variant = entry.get("pieces",[])
	if pieces is Array and pieces.size() <= RoadPieces.MAX_PIECES:
		for piece: Variant in pieces:
			if RoadPieces.validate(piece).is_empty(): paths.append(RoadPieces.samples(piece))
	if paths.is_empty():
		var route := PackedVector2Array()
		for p: Array in entry.points: route.append(Vector2(p[0],p[1]))
		if not route.is_empty(): route.append(route[0])
		paths.append(route)
	var low := Vector2(INF,INF)
	var high := Vector2(-INF,-INF)
	for path: PackedVector2Array in paths:
		for point: Vector2 in path:
			low = low.min(Vector2(point.x,-point.y))
			high = high.max(Vector2(point.x,-point.y))
	var extent: Vector2 = (high-low).max(Vector2.ONE)
	var scale: float = minf((size.x-54)/extent.x,72/extent.y)
	for path: PackedVector2Array in paths:
		if path.size() < 2: continue
		var points := PackedVector2Array()
		for point: Vector2 in path: points.append((Vector2(point.x,-point.y)-(low+high)*0.5)*scale+Vector2(size.x*0.5,51))
		draw_polyline(points,Color("172129"),9,true)
		draw_polyline(points,Color("e1e7df"),3,true)
		draw_circle(points[0],4,Color("172129"))
	var font: Font = get_theme_default_font()
	draw_string(MenuStyle.DISPLAY,Vector2(14,128),str(entry.name).to_upper(),HORIZONTAL_ALIGNMENT_LEFT,size.x-28,26,MenuStyle.TEXT)
	draw_string(font,Vector2(14,150),str(entry.creator),HORIZONTAL_ALIGNMENT_LEFT,size.x-28,14,MenuStyle.MUTED)
	if favorite: draw_string(font,Vector2(size.x-29,26),"★",HORIZONTAL_ALIGNMENT_LEFT,22,19,MenuStyle.TEXT)
