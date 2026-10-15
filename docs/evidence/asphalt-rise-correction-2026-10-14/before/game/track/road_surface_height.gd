extends RefCounted
## Shared cosmetic road datum. Canonical driving remains planar.
const ROAD: float = 0.012
const RISE: float = 0.05
const TERRAIN: float = ROAD - RISE
const BUCKET: float = 8.0
var track: NativeTrack
var floors: Array[PackedVector2Array] = []
var floor_bins: Dictionary = {}
var triangles: Array[Dictionary] = []
var shoulder_bins: Dictionary = {}

func _init(data: NativeTrack) -> void:
	track = data
	var pieces: Array = track.metadata.get("creator_document",{}).get("pieces",[])
	var topology: Dictionary = RoadPieces.prepare_endpoints(pieces)
	var theme: String = str(track.metadata.get("theme","pine"))
	for index: int in range(pieces.size()):
		if pieces[index].kind == "bridge": continue
		var shape: Dictionary = VisualRoadJoin.build(pieces,index,0.0,topology)
		var contours: Array[PackedVector2Array] = RoadEdges.section_contours(pieces,index,0.0,topology) if pieces[index].kind == "spline" else shape.contours
		var swept: bool = pieces[index].kind == "spline" or shape.get("swept",false)
		var surfaces: Array[PackedVector2Array] = SplineBorders.surface(SplineBorders.offset(contours,0.16)) if swept else Geometry2D.offset_polygon(contours[0],0.16,Geometry2D.JOIN_ROUND)
		for polygon: PackedVector2Array in surfaces:
			var slot: int = floors.size()
			floors.append(polygon)
			var bounds := Rect2(polygon[0],Vector2.ZERO)
			for p: Vector2 in polygon: bounds = bounds.expand(p)
			for y: int in range(floori(bounds.position.y/BUCKET),floori(bounds.end.y/BUCKET)+1):
				for x: int in range(floori(bounds.position.x/BUCKET),floori(bounds.end.x/BUCKET)+1):
					var cell := Vector2i(x,y)
					if not floor_bins.has(cell): floor_bins[cell] = []
					floor_bins[cell].append(slot)
		var border: Dictionary = VisualRoadJoin.build(pieces,index,-0.20,topology)
		var borders: Array[PackedVector2Array] = RoadEdges.presentation_contours(pieces,index,-0.20,topology) if pieces[index].kind == "spline" else border.contours
		var cuts: Array[Dictionary] = RoadEdges._join_cuts(pieces,index,topology) if pieces[index].kind == "spline" else border.cuts
		for polygon: PackedVector2Array in borders:
			var hole: bool = swept and Geometry2D.is_polygon_clockwise(polygon)
			for edge: int in range(polygon.size()):
				var a: Vector2 = polygon[edge]
				var b: Vector2 = polygon[(edge+1)%polygon.size()]
				if RoadEdges._on_join_cut(a,b,cuts) or (swept and RoadEdges._on_join_cap(a,b,cuts)): continue
				var na: Vector2 = RoadEdges._roadside_miter(polygon,edge,cuts,swept)
				var nb: Vector2 = RoadEdges._roadside_miter(polygon,(edge+1)%polygon.size(),cuts,swept)
				if hole: na = -na; nb = -nb
				var steps: int = maxi(1,ceili(a.distance_to(b)/(0.28 if theme == "winter" else 0.20)))
				for step: int in range(steps):
					var p: Vector2 = a.lerp(b,float(step)/steps)
					var q: Vector2 = a.lerp(b,float(step+1)/steps)
					var outer_p: Vector2 = p+na.lerp(nb,float(step)/steps)*width(p,theme)
					var outer_q: Vector2 = q+na.lerp(nb,float(step+1)/steps)*width(q,theme)
					_add_triangle(PackedVector2Array([p,outer_q,q]),Vector3(0,1,0))
					_add_triangle(PackedVector2Array([p,outer_p,outer_q]),Vector3(0,1,1))

func _add_triangle(p: PackedVector2Array, weights: Vector3) -> void:
	var u: Vector2 = p[1]-p[0]
	var v: Vector2 = p[2]-p[0]
	var determinant: float = u.cross(v)
	if absf(determinant) < 0.000001: return
	var gradient := Vector2((weights.y-weights.x)*v.y-(weights.z-weights.x)*u.y,u.x*(weights.z-weights.x)-v.x*(weights.y-weights.x))/determinant
	var bounds := Rect2(p[0],Vector2.ZERO).expand(p[1]).expand(p[2])
	var index: int = triangles.size()
	triangles.append({"polygon":p,"gradient":gradient,"offset":weights.x-gradient.dot(p[0])})
	for y: int in range(floori(bounds.position.y/BUCKET),floori(bounds.end.y/BUCKET)+1):
		for x: int in range(floori(bounds.position.x/BUCKET),floori(bounds.end.x/BUCKET)+1):
			var cell := Vector2i(x,y)
			if not shoulder_bins.has(cell): shoulder_bins[cell] = []
			shoulder_bins[cell].append(index)

static func shoulder(fraction: float) -> float:
	return lerpf(ROAD, TERRAIN, clampf(fraction, 0.0, 1.0))

static func width(point: Vector2, theme: String) -> float:
	return (3.0 if theme == "desert" else 1.35) + sin(point.x*0.43+point.y*0.19)*0.20 + sin(point.y*0.91-point.x*0.57)*0.08 + sin(point.x*2.1+point.y*1.7)*0.02

static func bridge_offset(along: float, length: float, original: float = 0.025) -> float:
	# Match ground asphalt exactly at both mouths, retaining the deck finish.
	return lerpf(ROAD, original, smoothstep(0.0, 1.0, minf(along, length-along)))

func ground(point: Vector2) -> float:
	var kind: int = track.cell_at(point)
	if kind in [0,5]: return 0.0
	# Explicit paint wins over authored road geometry, exactly as in rendering.
	var cell := Vector2i(floori((point.x+track.half_extent.x)/track.cell_size),floori((track.half_extent.y-point.y)/track.cell_size))
	var slot: int = cell.y*track.grid_width+cell.x
	var painted: bool = cell.x >= 0 and cell.y >= 0 and cell.x < track.grid_width and cell.y < track.grid_height and slot < track.kerbs.blocked.size() and track.kerbs.blocked[slot] != 0
	if not painted:
		for index: int in floor_bins.get(Vector2i(floori(point.x/BUCKET),floori(point.y/BUCKET)),[]):
			if Geometry2D.is_point_in_polygon(point,floors[index]): return 0.0
		var height: float = -RISE
		for index: int in shoulder_bins.get(Vector2i(floori(point.x/BUCKET),floori(point.y/BUCKET)),[]):
			var triangle: Dictionary = triangles[index]
			if Geometry2D.is_point_in_polygon(point,triangle.polygon): height = maxf(height,shoulder(triangle.gradient.dot(point)+triangle.offset)-ROAD)
		if height > -RISE: return height
	# Four local samples soften the five-centimetre change at raster boundaries.
	# Keep the existing road datum (zero for the car), including painted roads.
	var coverage: float = 0.0
	for offset: Vector2 in [Vector2(-0.15,-0.15),Vector2(0.15,-0.15),Vector2(-0.15,0.15),Vector2(0.15,0.15)]:
		coverage += 0.25 if track.cell_at(point+offset) in [0,5] else 0.0
	return -RISE * (1.0-coverage)
