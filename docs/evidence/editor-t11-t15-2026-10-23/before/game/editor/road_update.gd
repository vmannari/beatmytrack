extends RefCounted
## Conservative editor-only dirty tiles. Race geometry never uses this path.
const TILE: float = 32.0

static func plan(before: NativeTrack, after: NativeTrack) -> Dictionary:
	if before == null or before.cell_size != after.cell_size: return {}
	var old: Dictionary = before.metadata.get("creator_document",{})
	var next: Dictionary = after.metadata.get("creator_document",{})
	# Sand wear phases, relief and bounded snow deposits can depend on a whole
	# connected component or earlier pieces. Keep their exact full preparation.
	if next.get("theme","pine") in ["desert","winter"] or old.is_empty() or next.is_empty(): return {}
	if next.get("theme","pine") == "pine" and (not reduced_verge(before) or not reduced_verge(after)): return {}
	for key: String in ["theme","surface","base_track","layout","paint","objects","hidden_scenery"]:
		if old.get(key) != next.get(key): return {}
	var maximum_width: float = 0.0
	for piece: Dictionary in old.pieces+next.pieces:
		if piece.kind in ["bridge","spline"]: return {}
		maximum_width = maxf(maximum_width,maxf(RoadPieces.endpoint_width(piece,0),RoadPieces.endpoint_width(piece,1)))
	var tiles: Dictionary = {}
	var changed_bounds: Array[Rect2] = []
	var prefix: int = 0
	while prefix < mini(old.pieces.size(),next.pieces.size()) and old.pieces[prefix] == next.pieces[prefix]: prefix += 1
	var suffix: int = 0
	while suffix < mini(old.pieces.size(),next.pieces.size())-prefix and old.pieces[-1-suffix] == next.pieces[-1-suffix]: suffix += 1
	for pieces: Array in [old.pieces,next.pieces]:
		for index: int in range(prefix,pieces.size()-suffix):
			var piece: Dictionary = pieces[index]
			# Joined normals are capped at four half-widths. Include the widest
			# joined endpoint (also taper exits), plus all cosmetic border reach.
			var bounds: Rect2 = piece_bounds(piece).grow(2.0*maximum_width+16.0)
			changed_bounds.append(bounds); add_bounds(tiles,bounds)
	# A changed join can retriangulate a complete neighbouring curve and move
	# its kerb UV origin. Dirty that whole piece, not just its nearby endpoint.
	for piece: Dictionary in old.pieces+next.pieces:
		var bounds: Rect2 = piece_bounds(piece).grow(2.0*maximum_width+8.0)
		for changed: Rect2 in changed_bounds:
			if changed.intersects(bounds): add_bounds(tiles,bounds); break
	return {"tiles":tiles,"tile_size":TILE}

static func piece_bounds(piece: Dictionary) -> Rect2:
	var points: PackedVector2Array = RoadPieces.samples(piece)
	var bounds := Rect2(points[0],Vector2.ZERO)
	for point: Vector2 in points: bounds = bounds.expand(point)
	return bounds

static func reduced_verge(track: NativeTrack) -> bool:
	var pieces: Array = track.metadata.get("creator_document",{}).get("pieces",[])
	if pieces.size() >= 32: return true
	var length: float = 0.0
	for piece: Dictionary in pieces:
		var points: PackedVector2Array = RoadPieces.samples(piece)
		for i: int in range(1,points.size()): length += points[i-1].distance_to(points[i])
	return length > 240.0

static func add_bounds(tiles: Dictionary, bounds: Rect2) -> void:
	for y: int in range(floori(-bounds.end.y/TILE),floori(-bounds.position.y/TILE)+1):
		for x: int in range(floori(bounds.position.x/TILE),floori(bounds.end.x/TILE)+1): tiles[Vector2i(x,y)] = true

static func intersects(bounds: Rect2, tiles: Dictionary) -> bool:
	for y: int in range(floori(-bounds.end.y/TILE),floori(-bounds.position.y/TILE)+1):
		for x: int in range(floori(bounds.position.x/TILE),floori(bounds.end.x/TILE)+1):
			if tiles.has(Vector2i(x,y)): return true
	return false

static func subset(clipping: ShoulderMesh, tiles: Dictionary) -> PackedInt32Array:
	# Include every cutter of every target triangle, in original order. Rivals
	# outside the tile cannot produce output in it, but still clip its edges.
	var selected: Dictionary = {}
	for index: int in range(clipping.triangles.size()):
		var source: Dictionary = clipping.triangles[index]
		if not intersects(source.bounds,tiles): continue
		selected[index] = true
		for cell: Vector2i in clipping._cells(source.bounds):
			for other: int in clipping.bins.get(cell,[]):
				if source.bounds.intersects(clipping.triangles[other].bounds): selected[other] = true
	var indices := PackedInt32Array(selected.keys()); indices.sort()
	var original: Array[Dictionary] = clipping.triangles
	clipping.triangles = []; clipping.bins = {}
	for index: int in indices: clipping.append_triangle(original[index])
	return indices

static func select(values: Array, indices: PackedInt32Array) -> Array:
	var result: Array = []
	for index: int in indices: result.append(values[index])
	return result

static func tile_of(arrays: Array) -> Vector2i:
	# RoadSections.split puts each whole triangle in its centroid tile.
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var center := Vector3.ZERO
	for i: int in range(3): center += vertices[indices[i] if not indices.is_empty() else i]
	center /= 3.0
	return Vector2i(floori(center.x/(TILE)),floori(center.z/(TILE)))
