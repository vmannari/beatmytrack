extends RefCounted
## Static wind-aligned lookup: each existing snow window starts at a road edge.
const WIND := Vector2(0.91, 0.414608)
const SIDE := Vector2(WIND.y, -WIND.x) # World-XZ side expressed in simulator XY.
const MAX_SIZE: int = 512
const REACH: float = 15.2 # Twice the unchanged maximum stream radius.
const MAX_CACHE_BYTES: int = 8 * 1024 * 1024
static var entries: Array[Dictionary] = []
static var cache_bytes: int = 0
var texture: ImageTexture
var image: Image
var bounds := Vector4.ZERO
var step := Vector2(2.0, 10.0)
var origins := PackedVector2Array()
var polygons: Array[PackedVector2Array] = []

func prepare(track: NativeTrack) -> void:
	polygons.clear(); origins.clear(); step = Vector2(2.0, 10.0)
	var key: Array = [track.content_hash,track.grid_width,track.grid_height,track.cell_size,track.half_extent,WIND,SIDE,REACH,MAX_SIZE]
	if not track.content_hash.is_empty():
		for index: int in range(entries.size()):
			if entries[index].key != key: continue
			var cached: Dictionary = entries.pop_at(index); entries.append(cached)
			texture = cached.texture; image = cached.image; bounds = cached.bounds; step = cached.step
			origins = cached.origins.duplicate(); polygons.assign(cached.polygons)
			return
	var pieces: Array = track.metadata.get("creator_document", {}).get("pieces", [])
	var topology: Dictionary = RoadPieces.prepare_endpoints(pieces)
	for index: int in range(pieces.size()):
		if pieces[index].kind == "bridge": continue
		var shape: Dictionary = VisualRoadJoin.build(pieces, index, 0.0, topology)
		var contours: Array[PackedVector2Array] = RoadEdges.section_contours(pieces, index, 0.0, topology) if pieces[index].kind == "spline" else shape.contours
		var swept: bool = pieces[index].kind == "spline" or shape.get("swept", false)
		var surfaces: Array[PackedVector2Array] = SplineBorders.surface(SplineBorders.offset(contours, 0.16)) if swept else Geometry2D.offset_polygon(contours[0], 0.16, Geometry2D.JOIN_ROUND)
		for polygon: PackedVector2Array in surfaces: polygons.append(polygon)
	if pieces.is_empty():
		# Current native grids without authored pieces use their actual road runs.
		for y: int in range(track.grid_height):
			var x: int = 0
			while x < track.grid_width:
				if track.cells[y * track.grid_width + x] != 0: x += 1; continue
				var start: int = x
				while x < track.grid_width and track.cells[y * track.grid_width + x] == 0: x += 1
				var a := Vector2(start * track.cell_size - track.half_extent.x, track.half_extent.y - y * track.cell_size)
				var b := Vector2(x * track.cell_size - track.half_extent.x, a.y - track.cell_size)
				polygons.append(PackedVector2Array([a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)]))
	var extent: float = track.half_extent.x * absf(WIND.x) + track.half_extent.y * absf(WIND.y) + REACH
	var across: float = track.half_extent.x * absf(SIDE.x) + track.half_extent.y * absf(SIDE.y) + 10.0
	step.x *= maxi(1, ceili(2.0 * extent / (MAX_SIZE * step.x)))
	step.y *= maxi(1, ceili(2.0 * across / (MAX_SIZE * step.y)))
	var lo := (Vector2(-extent, -across) / step).floor() * step
	var size := Vector2i((Vector2(extent, across) - lo) / step + Vector2.ONE)
	size.x = mini(size.x, MAX_SIZE); size.y = mini(size.y, MAX_SIZE)
	bounds = Vector4(lo.x, lo.y, size.x * step.x, size.y * step.y)
	image = Image.create(size.x, size.y, false, Image.FORMAT_RGBAF)
	image.fill(Color(0, 0, 0, 0))
	for row: int in range(size.y):
		var crosswind: float = lo.y + (row + 0.5) * step.y
		var spans: Array[Vector2] = []
		for polygon: PackedVector2Array in polygons:
			var crossings: Array[float] = []
			for i: int in range(polygon.size()):
				var a: Vector2 = polygon[i]; var b: Vector2 = polygon[(i + 1) % polygon.size()]
				var ay: float = a.dot(SIDE); var by: float = b.dot(SIDE)
				if (ay <= crosswind and by > crosswind) or (by <= crosswind and ay > crosswind):
					crossings.append(a.lerp(b, (crosswind - ay) / (by - ay)).dot(WIND))
			crossings.sort()
			for i: int in range(0, crossings.size() - 1, 2): spans.append(Vector2(crossings[i], crossings[i + 1]))
		spans.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		var merged: Array[Vector2] = []
		for span: Vector2 in spans:
			if not merged.is_empty() and span.x <= merged[-1].y + 0.001: merged[-1].y = maxf(merged[-1].y, span.y)
			else: merged.append(span)
		for span: Vector2 in merged:
			var origin := Vector2(span.x, crosswind)
			var point: Vector2 = WIND * origin.x + SIDE * origin.y
			if CreatorBridges.at_any(track.creator_bridges, point): continue
			origins.append(point)
			for column: int in range(maxi(0, floori((origin.x - lo.x) / step.x)), mini(size.x, ceili((origin.x + REACH - lo.x) / step.x))):
				image.set_pixel(column, row, Color(origin.x, origin.y, 0.0, 1.0))
	texture = ImageTexture.create_from_image(image)
	# CPU pixels plus decoded GPU texture and owned source geometry. Share only
	# this immutable lookup; each race still owns its wind animation/materials.
	var bytes: int = image.get_width()*image.get_height()*32+origins.size()*16+1024
	for polygon: PackedVector2Array in polygons: bytes += polygon.size()*16+64
	if not track.content_hash.is_empty() and bytes <= MAX_CACHE_BYTES:
		trim_cache(MAX_CACHE_BYTES-bytes)
		while entries.size() >= 4: cache_bytes -= int(entries.pop_front().bytes)
		entries.append({"key":key,"texture":texture,"image":image,"bounds":bounds,"step":step,"origins":origins.duplicate(),"polygons":polygons.duplicate(),"bytes":bytes})
		cache_bytes += bytes

static func trim_cache(allowance: int = 0) -> void:
	while not entries.is_empty() and cache_bytes > allowance: cache_bytes -= int(entries.pop_front().bytes)

func bind(material: ShaderMaterial) -> void:
	material.set_shader_parameter("snow_edge_sources", true)
	material.set_shader_parameter("snow_road_sources", texture)
	material.set_shader_parameter("snow_source_bounds", bounds)
