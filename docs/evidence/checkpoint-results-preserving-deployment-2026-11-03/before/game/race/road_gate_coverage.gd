class_name RoadGateCoverage
extends RefCounted
## Exact road-strip and kerb cross-sections, prepared once per gate layout.
var ground: Array[PackedVector2Array] = []
var decks: Array[PackedVector2Array] = []
var ground_bins: Dictionary = {}
var deck_bins: Dictionary = {}
var reach: float = 0.0
const CELL_M: float = 8.0

func _init(track: NativeTrack) -> void:
	reach = track.half_extent.length()*2.0
	var pieces: Array = track.metadata.get("creator_document",{}).get("pieces",[])
	var topology: Dictionary = RoadPieces.prepare_endpoints(pieces)
	for index: int in range(pieces.size()):
		var polygons: Array[PackedVector2Array] = decks if pieces[index].kind == "bridge" else ground
		var contours: Array[PackedVector2Array]
		if pieces[index].kind == "spline":
			# Use the same cleaned folded borders and painted edge as the road.
			contours = SplineBorders.surface(RoadEdges.section_contours(pieces,index,0.16,topology))
		else:
			var shape: Dictionary = VisualRoadJoin.build(pieces,index,0.0,topology)
			contours = SplineBorders.surface(SplineBorders.offset(shape.contours,0.16)) if shape.get("swept",false) else Geometry2D.offset_polygon(shape.contours[0],0.16,Geometry2D.JOIN_ROUND)
		for contour: PackedVector2Array in contours:
			var indices: PackedInt32Array = Geometry2D.triangulate_polygon(contour)
			for i: int in range(0,indices.size(),3): polygons.append(PackedVector2Array([contour[indices[i]],contour[indices[i+1]],contour[indices[i+2]]]))
	for triangle: Dictionary in track.kerbs.triangles: ground.append(triangle.points)
	_index(ground,ground_bins)
	_index(decks,deck_bins)

func _index(polygons: Array[PackedVector2Array], bins: Dictionary) -> void:
	for index: int in range(polygons.size()):
		var low: Vector2 = polygons[index][0]
		var high: Vector2 = low
		for point: Vector2 in polygons[index]: low = low.min(point); high = high.max(point)
		var first := Vector2i((low/CELL_M).floor())
		var last := Vector2i((high/CELL_M).floor())
		for y: int in range(first.y,last.y+1):
			for x: int in range(first.x,last.x+1):
				var key := Vector2i(x,y)
				if not bins.has(key): bins[key] = PackedInt32Array()
				bins[key].append(index)

func spans(center: Vector2, direction: Vector2, raster: Vector2, elevated: bool) -> Vector2:
	var normal: Vector2 = direction.orthogonal()
	var intervals: Array[Vector2] = [Vector2(-raster.x,raster.y)]
	var polygons: Array[PackedVector2Array] = decks if elevated else ground
	var bins: Dictionary = deck_bins if elevated else ground_bins
	var candidates: Dictionary = {}
	var visited: Dictionary = {}
	for step: int in range(-ceili(reach/(CELL_M*0.5)),ceili(reach/(CELL_M*0.5))+1):
		var key := Vector2i(((center+normal*step*CELL_M*0.5)/CELL_M).floor())
		for y: int in range(-1,2):
			for x: int in range(-1,2):
				var cell: Vector2i = key+Vector2i(x,y)
				if visited.has(cell): continue
				visited[cell] = true
				for index: int in bins.get(cell,PackedInt32Array()): candidates[index] = true
	for index: int in candidates:
		var polygon: PackedVector2Array = polygons[index]
		var low: float = INF
		var high: float = -INF
		for i: int in range(polygon.size()):
			var a: Vector2 = polygon[i]-center
			var b: Vector2 = polygon[(i+1)%polygon.size()]-center
			var before: float = a.dot(direction)
			var after: float = b.dot(direction)
			if absf(before) < 0.00001:
				low = minf(low,a.dot(normal)); high = maxf(high,a.dot(normal))
			if (before < 0.0 and after > 0.0) or (before > 0.0 and after < 0.0):
				var lateral: float = a.lerp(b,-before/(after-before)).dot(normal)
				low = minf(low,lateral); high = maxf(high,lateral)
		if high >= low: intervals.append(Vector2(low,high))
	intervals.sort_custom(func(a: Vector2,b: Vector2) -> bool: return a.x < b.x)
	var connected: Vector2 = intervals[0]
	# Merge only the connected road through this gate. A returning arm across
	# an actual gap cannot enlarge the checkpoint, even on the same layer.
	for interval: Vector2 in intervals:
		if interval.x > connected.y+0.0001:
			if connected.x <= 0.0 and connected.y >= 0.0: break
			connected = interval
		else: connected.y = maxf(connected.y,interval.y)
	return Vector2(-connected.x,connected.y)
