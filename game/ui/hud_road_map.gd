class_name HUDRoadMap
extends Control
## Only placed road-piece geometry. No waypoint, painted-surface or legacy fallback.
var player := Vector2.ZERO
var outlines: Array[PackedVector2Array] = []
var world_bounds := Rect2()

func _ready() -> void:
	custom_minimum_size = Vector2(104,84)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if outlines.is_empty(): return
	var scale_factor: float = minf((size.x-14)/maxf(world_bounds.size.x,1),(size.y-14)/maxf(world_bounds.size.y,1))
	var projected: Array[PackedVector2Array] = []
	for outline: PackedVector2Array in outlines:
		var points := PackedVector2Array()
		for point: Vector2 in outline:
			var local: Vector2 = (point-world_bounds.get_center())*scale_factor
			points.append(size*0.5+Vector2(local.x,-local.y))
		projected.append(points)
	# Draw all outer ink first, then road faces, so joins do not gain false seams.
	for points: PackedVector2Array in projected:
		var edge := points.duplicate()
		edge.append(edge[0])
		draw_polyline(edge,Color("080e12"),2,true)
	# Each outline contains the forward left edge and reversed right edge.
	# Render its small strip triangles, avoiding triangulation of long,
	# nearly collinear polygons after they shrink to minimap scale.
	for points: PackedVector2Array in projected:
		var count: int = points.size()/2
		for i: int in range(count-1):
			for triangle: PackedVector2Array in [PackedVector2Array([points[i],points[i+1],points[points.size()-1-i]]),PackedVector2Array([points[i+1],points[points.size()-2-i],points[points.size()-1-i]])]:
				if absf((triangle[1]-triangle[0]).cross(triangle[2]-triangle[0])) > 0.001:
					draw_colored_polygon(triangle,Color("bec7c5"))
	var offset: Vector2 = (player-world_bounds.get_center())*scale_factor
	var marker: Vector2 = (size*0.5+Vector2(offset.x,-offset.y)).clamp(Vector2(6,6),size-Vector2(6,6))
	draw_circle(marker,5,Color("f1eee3"))
	draw_circle(marker,3,Color("55a9d9"))

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
	queue_redraw()
