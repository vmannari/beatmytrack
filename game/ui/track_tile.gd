class_name TrackTile
extends Button
## Original theme artwork and the saved route, kept separate from native scenery.
## The gallery uses bounded metadata and creates no live 3D scenes per result.

signal favorite_requested

const SCENERY: Texture2D = preload("res://assets/menu/discovery-biomes.png")
const STORM_SCENERY: Texture2D = preload("res://assets/menu/discovery-storm.png")
const FOOTER_HEIGHT: float = 61.0
const TITLE_FONT_SIZE: int = 21

var entry: Dictionary
var favorite: bool = false
var personal_rating: int = 0
var selected: bool = false
var draft_mode: bool = false
var preview_only: bool = false
var compact: bool = false
var paths: Array[PackedVector2Array] = []
var route_bounds: Rect2
static var scenery_cache: Dictionary = {}
var _projected_size: Vector2 = Vector2(-1,-1)
var _projected_compact: bool = false
var _projected_paths: Array[PackedVector2Array] = []
var _projected_shadows: Array[PackedVector2Array] = []

static func scenery_texture(theme_id: String) -> Texture2D:
	if theme_id == "storm": return STORM_SCENERY
	if scenery_cache.has(theme_id): return scenery_cache[theme_id]
	var quadrant: Vector2 = {"pine":Vector2(0,0),"desert":Vector2(1,0),"night_city":Vector2(0,1),"winter":Vector2(1,1)}.get(theme_id,Vector2.ZERO)
	var cell: Vector2 = SCENERY.get_size()*0.5
	var atlas := AtlasTexture.new()
	atlas.atlas = SCENERY
	atlas.region = Rect2(quadrant*cell,cell)
	scenery_cache[theme_id] = atlas
	return atlas

func update_entry(value: Dictionary, saved_favorite: bool, saved_rating: int, chosen: bool) -> void:
	if entry == value and favorite == saved_favorite and personal_rating == saved_rating and selected == chosen: return
	var route_changed: bool = entry.get("points",[]) != value.get("points",[]) or entry.get("pieces",[]) != value.get("pieces",[])
	entry = value
	favorite = saved_favorite
	personal_rating = saved_rating
	selected = chosen
	if route_changed: _cache_route()
	_update_tooltip()
	var star: Button = get_node("ToggleFavorite")
	star.icon = MenuIcon.texture("star_filled" if favorite else "star")
	star.tooltip_text = "Remove favorite" if favorite else "Save favorite"
	star.add_theme_color_override("icon_normal_color",MenuStyle.ACCENT if favorite else MenuStyle.TEXT)
	queue_redraw()

func _update_tooltip() -> void:
	tooltip_text = str(entry.name)+" — "+str(entry.creator)
	if entry.get("creator_kind", "source") == "fictional": tooltip_text += " (fictional creator)"
	if not draft_mode: tooltip_text += "\n" + rating_text() + (" — verified racers" if entry.get("source") == "cloud" else " — local votes on this device")

func _ready() -> void:
	clip_contents = true
	custom_minimum_size = Vector2(190,220)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_update_tooltip()
	var star := MenuStyle.button("",func() -> void: favorite_requested.emit())
	star.name = "ToggleFavorite"
	star.icon = MenuIcon.texture("star_filled" if favorite else "star")
	star.tooltip_text = "Remove favorite" if favorite else "Save favorite"
	star.custom_minimum_size = Vector2(48,48)
	star.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	star.offset_left = -52
	star.offset_right = -4
	star.offset_top = 4
	star.offset_bottom = 52
	star.add_theme_stylebox_override("normal",MenuStyle.box(Color("0b202b99"),8))
	star.add_theme_color_override("icon_normal_color",MenuStyle.ACCENT if favorite else MenuStyle.TEXT)
	add_child(star)
	star.visible = not draft_mode
	_cache_route()
	resized.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)

func _cache_route() -> void:
	paths.clear()
	_projected_size = Vector2(-1,-1)
	var pieces: Variant = entry.get("pieces",[])
	if pieces is Array and pieces.size() <= RoadPieces.MAX_PIECES:
		for piece: Variant in pieces:
			if RoadPieces.validate(piece).is_empty(): paths.append(RoadPieces.samples(piece))
	if paths.is_empty() and not draft_mode:
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
	var footer: float = 50.0 if compact else FOOTER_HEIGHT
	var image_area := Rect2(Vector2(2,2),Vector2(size.x-4,size.y-4 if preview_only else size.y-footer-1.0))
	_draw_terrain(image_area)
	_draw_route(image_area)
	if preview_only: return
	# Quiet footer keeps creator attribution separate from the route illustration.
	draw_rect(Rect2(0,size.y-footer,size.x,FOOTER_HEIGHT),Color("091720"))
	draw_line(Vector2(1,size.y-footer),Vector2(size.x-1,size.y-footer),Color("344d56"),1)
	var frame: StyleBoxFlat = MenuStyle.box(Color.TRANSPARENT,0)
	var accent: Color = Color("54cfff") if draft_mode else MenuStyle.ACCENT
	frame.border_color = accent if selected else MenuStyle.BORDER.lightened(0.2) if is_hovered() or has_focus() else MenuStyle.BORDER
	frame.set_border_width_all(2 if selected or has_focus() else 1)
	draw_style_box(frame,Rect2(Vector2.ONE,size-Vector2(2,2)))
	if selected: draw_line(Vector2(14,size.y-2),Vector2(size.x-14,size.y-2),accent,2)
	var title: String = str(entry.name).to_upper()
	var title_size: int = 16 if compact else TITLE_FONT_SIZE
	var rating_width: float = 0.0 if draft_mode else MenuStyle.BODY.get_string_size(rating_text(),HORIZONTAL_ALIGNMENT_LEFT,-1,12).x+27
	var title_width: float = maxf(1.0,size.x-26-rating_width-(8 if not draft_mode else 0))
	while title_size > 12 and MenuStyle.DISPLAY.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,title_size).x > title_width:
		title_size -= 1
	# Anchor the baseline to the footer and actual font ascent, not the card bottom.
	# Compact cards have a shorter footer; the old baseline put capitals over the image.
	var title_baseline: float = size.y-footer+4+MenuStyle.DISPLAY.get_ascent(title_size)
	draw_string(MenuStyle.DISPLAY,Vector2(13,title_baseline),title,HORIZONTAL_ALIGNMENT_LEFT,title_width,title_size,MenuStyle.TEXT)
	var creator: String = str(entry.creator)
	if entry.get("creator_kind", "source") == "fictional": creator += " (fictional)"
	draw_string(MenuStyle.BODY,Vector2(13,size.y-12),str(entry.get("draft_status","Draft")) if draft_mode else "by "+creator,HORIZONTAL_ALIGNMENT_LEFT,size.x-26,13,MenuStyle.MUTED)
	var theme_id: String = str(entry.get("theme","pine"))
	var biome: String = TrackTheme.title(theme_id).to_upper()
	var biome_color: Color = preload("res://ui/biome_badge.gd").color(theme_id)
	var badge: StyleBoxFlat = MenuStyle.box(Color("0b202be8"),0)
	draw_style_box(badge,Rect2(10,10,MenuStyle.BODY.get_string_size(biome,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x+34,23))
	draw_texture_rect(MenuIcon.texture(preload("res://ui/biome_badge.gd").icon(theme_id)),Rect2(16,14,15,15),false,biome_color)
	draw_string(MenuStyle.BODY,Vector2(36,26),biome,HORIZONTAL_ALIGNMENT_LEFT,-1,11,biome_color)
	if draft_mode:
		var status: String = "TESTED" if entry.get("tested",false) else "DRAFT"
		draw_style_box(MenuStyle.box(Color("25565a") if entry.get("tested",false) else Color("0069a0"),0),Rect2(size.x-77,10,67,23))
		draw_string(MenuStyle.DISPLAY,Vector2(size.x-71,27),status,HORIZONTAL_ALIGNMENT_LEFT,60,15,MenuStyle.TEXT)
	if not draft_mode:
		var rating_origin := Vector2(size.x-rating_width-13,title_baseline-MenuStyle.BODY.get_ascent(12))
		var rated: bool = has_rating()
		draw_texture_rect(MenuIcon.texture("star_filled" if rated else "star"),Rect2(rating_origin+Vector2(0,-1),Vector2(16,16)),false,MenuStyle.ACCENT if rated else MenuStyle.MUTED)
		draw_string(MenuStyle.BODY,Vector2(rating_origin.x+22,title_baseline),rating_text(),HORIZONTAL_ALIGNMENT_LEFT,-1,12,MenuStyle.TEXT if rated else MenuStyle.MUTED)

func has_rating() -> bool:
	return int(entry.get("rating_count",0)) > 0 if entry.get("source") == "cloud" else personal_rating > 0

func rating_text() -> String:
	if entry.get("source") == "cloud":
		return "%.1f (%d)" % [float(entry.rating_average),int(entry.rating_count)] if entry.get("rating_average") != null else "Unrated (0)"
	return "%.1f (1)" % personal_rating if personal_rating > 0 else "— (0)"

func _draw_terrain(area: Rect2) -> void:
	var theme_id: String = str(entry.get("theme","pine"))
	var artwork: Texture2D = STORM_SCENERY if theme_id == "storm" else SCENERY
	var cell: Vector2 = artwork.get_size() if theme_id == "storm" else artwork.get_size()*0.5
	var source := Rect2(Vector2.ZERO,cell)
	if theme_id != "storm": source = (scenery_texture(theme_id) as AtlasTexture).region
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
	if _projected_size != size or _projected_compact != compact:
		_project_route(area)
	for index: int in range(_projected_paths.size()):
		var points: PackedVector2Array = _projected_paths[index]
		draw_polyline(_projected_shadows[index],Color(0.025,0.055,0.035,0.4),10,true)
		draw_polyline(points,Color("15202a"),9,true)
		draw_polyline(points,Color("f0ede0"),5,true)
		draw_polyline(points,Color("ffffff"),1.2,true)
		if index == 0 and not draft_mode:
			draw_circle(points[0],5,Color("091720"))
			draw_circle(points[0],2.7,MenuStyle.ACCENT)

func _project_route(area: Rect2) -> void:
	_projected_size = size
	_projected_compact = compact
	_projected_paths.clear()
	_projected_shadows.clear()
	var available := Rect2(area.position+Vector2(26,26),area.size-Vector2(52,52))
	if compact: available = Rect2(area.position+Vector2(46,12),area.size-Vector2(92,24))
	var scale: float = minf(available.size.x/route_bounds.size.x,available.size.y/route_bounds.size.y)
	for path: PackedVector2Array in paths:
		if path.size() < 2: continue
		var points := PackedVector2Array()
		var shadow := PackedVector2Array()
		for point: Vector2 in path:
			var projected: Vector2 = (Vector2(point.x,-point.y)-route_bounds.get_center())*scale+available.get_center()
			points.append(projected)
			shadow.append(projected+Vector2(2,3))
		_projected_paths.append(points)
		_projected_shadows.append(shadow)
