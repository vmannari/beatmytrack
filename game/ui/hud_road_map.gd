class_name HUDRoadMap
extends Control
## Only placed road-piece geometry. No waypoint, painted-surface or legacy fallback.
var player := Vector2.ZERO:
	set(value):
		var previous: Vector2 = _marker_position()
		player = value
		if not outlines.is_empty() and _marker_position() != previous: queue_redraw()
var outlines: Array[PackedVector2Array] = []
var world_bounds := Rect2()

func _ready() -> void:
	custom_minimum_size = Vector2(128,128)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	road_layer = RoadLayer.new()
	road_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	road_layer.show_behind_parent = true
	add_child(road_layer)
	resized.connect(_rebuild_roads)
	_rebuild_roads()

class RoadLayer extends Control:
	var paths: Array[PackedVector2Array] = []
	var draw_count: int = 0
	func _draw() -> void:
		draw_count += 1
		for path: PackedVector2Array in paths: draw_polyline(path,Color("080e12"),3.0,true)
		for path: PackedVector2Array in paths: draw_polyline(path,Color("e4e8e5"),2.5,true)

var road_layer: RoadLayer
var cached_scale: float = 1.0
var rebuild_count: int = 0

func _rebuild_roads() -> void:
	if road_layer == null: return
	rebuild_count += 1
	road_layer.paths.clear()
	cached_scale = minf((size.x-40)/maxf(world_bounds.size.x,1),(size.y-40)/maxf(world_bounds.size.y,1))
	for outline: PackedVector2Array in outlines:
		var path := PackedVector2Array()
		var count: int = outline.size()/2
		for i: int in range(count):
			# Pair the actual placed road's edges; do not read race waypoints.
			var middle: Vector2 = (outline[i]+outline[outline.size()-1-i])*0.5
			var local: Vector2 = (middle-world_bounds.get_center())*cached_scale
			var point: Vector2 = size*0.5+Vector2(local.x,-local.y)
			if path.is_empty() or path[-1].distance_squared_to(point) >= 0.25 or i == count-1:
				path.append(point)
		if path.size() > 1: road_layer.paths.append(path)
	road_layer.queue_redraw()
	queue_redraw()

func _marker_position() -> Vector2:
	var offset: Vector2 = (player-world_bounds.get_center())*cached_scale
	return (size*0.5+Vector2(offset.x,-offset.y)).clamp(Vector2(6,6),size-Vector2(6,6))

func _draw() -> void:
	if outlines.is_empty(): return
	var marker: Vector2 = _marker_position()
	draw_circle(marker,5,Color("f1eee3"))
	draw_circle(marker,3.5,Color("55a9d9"))

func configure(track: NativeTrack, authored: bool) -> void:
	outlines.clear()
	world_bounds = Rect2()
	if authored:
		var pieces: Array = track.metadata.creator_document.get("pieces",[])
		for index: int in range(pieces.size()):
			var outline: PackedVector2Array = RoadPieces.section_outline(pieces,index)
			if outline.size() < 3: continue
			if outlines.is_empty(): world_bounds = Rect2(outline[0],Vector2.ZERO)
			for point: Vector2 in outline: world_bounds = world_bounds.expand(point)
			outlines.append(outline)
	_rebuild_roads()
