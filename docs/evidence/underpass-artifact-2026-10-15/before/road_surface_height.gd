extends RefCounted
## Asphalt-only cosmetic rise. Loose surfaces retain their original geometry.
const ROAD: float = 0.012
const RISE: float = 0.05
const TERRAIN: float = -0.06
const BUCKET: float = 8.0
var track: NativeTrack
var floors: Array[PackedVector2Array] = []
var floor_bins: Dictionary = {}
var lift: float = 0.0

func _init(data: NativeTrack) -> void:
	track = data
	lift = RISE if is_asphalt(track) else 0.0
	if lift == 0.0: return
	var pieces: Array = track.metadata.get("creator_document",{}).get("pieces",[])
	var topology: Dictionary = RoadPieces.prepare_endpoints(pieces)
	for index: int in range(pieces.size()):
		if pieces[index].kind == "bridge": continue
		var shape: Dictionary = VisualRoadJoin.build(pieces,index,0.0,topology)
		var contours: Array[PackedVector2Array] = RoadEdges.section_contours(pieces,index,0.0,topology) if pieces[index].kind == "spline" else shape.contours
		var swept: bool = pieces[index].kind == "spline" or shape.get("swept",false)
		var surfaces: Array[PackedVector2Array] = SplineBorders.surface(SplineBorders.offset(contours,0.16)) if swept else Geometry2D.offset_polygon(contours[0],0.16,Geometry2D.JOIN_ROUND)
		for polygon: PackedVector2Array in surfaces:
			polygon = clip_bridge_mouths(polygon,pieces,index,topology)
			if polygon.size() < 3: continue
			var slot: int = floors.size()
			floors.append(polygon)
			var bounds := Rect2(polygon[0],Vector2.ZERO)
			for p: Vector2 in polygon: bounds = bounds.expand(p)
			for y: int in range(floori(bounds.position.y/BUCKET),floori(bounds.end.y/BUCKET)+1):
				for x: int in range(floori(bounds.position.x/BUCKET),floori(bounds.end.x/BUCKET)+1):
					var cell := Vector2i(x,y)
					if not floor_bins.has(cell): floor_bins[cell] = []
					floor_bins[cell].append(slot)

static func is_asphalt(data: NativeTrack) -> bool:
	return str(data.metadata.get("theme","pine")) not in ["desert","winter"] and data.metadata.get("creator_document",{}).get("surface","asphalt") == "asphalt"

static func clip_bridge_mouths(polygon: PackedVector2Array, pieces: Array, index: int, topology: Dictionary) -> PackedVector2Array:
	for cut: Dictionary in RoadEdges._join_cuts(pieces,index,topology):
		var links: Array = RoadPieces._matches(topology,index,int(cut.endpoint))
		if links.size() != 1 or pieces[int(links[0][0])].kind != "bridge": continue
		var result := PackedVector2Array()
		for i: int in range(polygon.size()):
			var a: Vector2 = polygon[i]
			var b: Vector2 = polygon[(i+1)%polygon.size()]
			var da: float = (a-Vector2(cut.point)).dot(cut.normal)
			var db: float = (b-Vector2(cut.point)).dot(cut.normal)
			if da >= 0.0: result.append(a)
			if da*db < 0.0: result.append(a.lerp(b,da/(da-db)))
		polygon = result
	return polygon

func on_floor(point: Vector2) -> bool:
	for index: int in floor_bins.get(Vector2i(floori(point.x/BUCKET),floori(point.y/BUCKET)),[]):
		if Geometry2D.is_point_in_polygon(point,floors[index]): return true
	return false

static func width(point: Vector2, theme: String) -> float:
	return (3.0 if theme == "desert" else 1.35) + sin(point.x*0.43+point.y*0.19)*0.20 + sin(point.y*0.91-point.x*0.57)*0.08 + sin(point.x*2.1+point.y*1.7)*0.02

static func bridge_offset(along: float, length: float, original: float = 0.025, raised: float = 0.0) -> float:
	# Match ground asphalt exactly at both mouths, retaining the deck finish.
	return raised+lerpf(ROAD, original, smoothstep(0.0, 1.0, minf(along, length-along)))

func ground(point: Vector2) -> float:
	if lift == 0.0: return 0.0
	var kind: int = track.cell_at(point)
	if kind == 0 or (kind == 5 and track.kerbs.height_at(point) > 0.0): return lift
	# Explicit paint wins over authored road geometry, exactly as in rendering.
	var cell := Vector2i(floori((point.x+track.half_extent.x)/track.cell_size),floori((track.half_extent.y-point.y)/track.cell_size))
	var slot: int = cell.y*track.grid_width+cell.x
	var painted: bool = cell.x >= 0 and cell.y >= 0 and cell.x < track.grid_width and cell.y < track.grid_height and slot < track.kerbs.blocked.size() and track.kerbs.blocked[slot] != 0
	return lift if not painted and on_floor(point) else 0.0
