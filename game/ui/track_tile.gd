class_name TrackTile
extends Button
## Original theme artwork and the saved route, kept separate from native scenery.
## The gallery uses bounded metadata and creates no live 3D scenes per result.

const SCENERY: Texture2D = preload("res://assets/menu/discovery-biomes.png")
const STORM_SCENERY: Texture2D = preload("res://assets/menu/discovery-storm.png")

var entry: Dictionary
var favorite: bool = false
var selected: bool = false
var paths: Array[PackedVector2Array] = []
var route_bounds: Rect2

func _ready() -> void:
	clip_contents = true
	custom_minimum_size = Vector2(190,264)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = str(entry.name)+" — "+str(entry.creator)
	if entry.get("creator_kind", "source") == "fictional": tooltip_text += " (fictional creator)"
	_cache_route()
	resized.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)

func _cache_route() -> void:
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
	route_bounds = Rect2(low,(high-low).max(Vector2.ONE)) if low.is_finite() else Rect2(Vector2.ZERO,Vector2.ONE)

func _draw() -> void:
	var image_area := Rect2(Vector2(2,2),Vector2(size.x-4,size.y-78))
	_draw_terrain(image_area)
	_draw_route(image_area)
	# Quiet footer keeps creator attribution separate from the route illustration.
	draw_rect(Rect2(0,size.y-77,size.x,77),Color("091720"))
	draw_line(Vector2(1,size.y-77),Vector2(size.x-1,size.y-77),Color("344d56"),1)
	var frame: StyleBoxFlat = MenuStyle.box(Color.TRANSPARENT,0)
	frame.border_color = MenuStyle.ACCENT if selected else MenuStyle.BORDER.lightened(0.2) if is_hovered() or has_focus() else MenuStyle.BORDER
	frame.set_border_width_all(2 if selected or has_focus() else 1)
	draw_style_box(frame,Rect2(Vector2.ONE,size-Vector2(2,2)))
	if selected: draw_line(Vector2(14,size.y-2),Vector2(size.x-14,size.y-2),MenuStyle.ACCENT,2)
	draw_string(MenuStyle.DISPLAY,Vector2(13,size.y-35),str(entry.name).to_upper(),HORIZONTAL_ALIGNMENT_LEFT,size.x-26,25,MenuStyle.TEXT)
	var creator: String = str(entry.creator)
	if entry.get("creator_kind", "source") == "fictional": creator += " (fictional)"
	draw_string(MenuStyle.BODY,Vector2(13,size.y-14),"by "+creator,HORIZONTAL_ALIGNMENT_LEFT,size.x-26,14,MenuStyle.MUTED)
	var biome: String = TrackTheme.title(str(entry.get("theme","pine"))).to_upper()
	var badge: StyleBoxFlat = MenuStyle.box(Color("0b202be8"),0)
	draw_style_box(badge,Rect2(10,10,MenuStyle.BODY.get_string_size(biome,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x+16,23))
	draw_string(MenuStyle.BODY,Vector2(18,26),biome,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("dce5dc"))
	if favorite:
		draw_circle(Vector2(size.x-23,22),13,Color("0b202be8"))
		draw_texture_rect(MenuIcon.texture("star_filled"),Rect2(size.x-33,12,20,20),false,MenuStyle.ACCENT)
	draw_string(MenuStyle.BODY,Vector2(13,image_area.end.y-10),"5 LAPS",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("e5e8dc"))
	draw_string(MenuStyle.BODY,Vector2(size.x-61,image_area.end.y-10),"LOCAL",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("d2d9ca"))

func _draw_terrain(area: Rect2) -> void:
	var theme_id: String = str(entry.get("theme","pine"))
	var quadrant: Vector2 = {"pine":Vector2(0,0),"desert":Vector2(1,0),"night_city":Vector2(0,1),"winter":Vector2(1,1)}.get(theme_id,Vector2.ZERO)
	var artwork: Texture2D = STORM_SCENERY if theme_id == "storm" else SCENERY
	var cell: Vector2 = artwork.get_size() if theme_id == "storm" else artwork.get_size()*0.5
	var source := Rect2(Vector2.ZERO if theme_id == "storm" else quadrant*cell,cell)
	var ratio: float = area.size.x/area.size.y
	if cell.x/cell.y > ratio:
		source.size.x = cell.y*ratio
	else:
		source.size.y = cell.x/ratio
	source.position += (cell-source.size)*0.5
	if theme_id == "storm": source.position.y = 0.0 # Keep thunderclouds/lightning in the card crop.
	draw_texture_rect_region(artwork,area,source,Color(0.8,0.85,0.9))
	draw_rect(area,Color(0.015,0.04,0.06,0.14))
	# Restrained shadow near the caption improves the small labels on every biome.
	for band: int in range(10):
		draw_rect(Rect2(area.position.x,area.end.y-30+band*3,area.size.x,3),Color(0.02,0.07,0.08,float(band)*0.03))

func _draw_route(area: Rect2) -> void:
	var available := Rect2(area.position+Vector2(26,31),area.size-Vector2(52,52))
	var scale: float = minf(available.size.x/route_bounds.size.x,available.size.y/route_bounds.size.y)
	for path: PackedVector2Array in paths:
		if path.size() < 2: continue
		var points := PackedVector2Array()
		var shadow := PackedVector2Array()
		for point: Vector2 in path:
			var projected: Vector2 = (Vector2(point.x,-point.y)-route_bounds.get_center())*scale+available.get_center()
			points.append(projected)
			shadow.append(projected+Vector2(2,3))
		draw_polyline(shadow,Color(0.025,0.055,0.035,0.4),10,true)
		draw_polyline(points,Color("15202a"),9,true)
		draw_polyline(points,Color("f0ede0"),5,true)
		draw_polyline(points,Color("ffffff"),1.2,true)
		if path == paths[0]:
			draw_circle(points[0],5,Color("091720"))
			draw_circle(points[0],2.7,MenuStyle.ACCENT)
