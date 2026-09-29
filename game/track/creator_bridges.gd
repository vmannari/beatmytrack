class_name CreatorBridges
extends RefCounted
## Straight authorable spans. Ground and deck remain separate native layers.
const HEIGHT: float = 3.5
const RAMP: float = 8.0
const RAIL: float = 0.75
const UNDERPASS_CLEARANCE: float = 2.20 # Tallest local car (~1.73 m), 0.42 m deck, small clearance.

static var base_footprints: Dictionary = {}

static func road_polygon(span: Dictionary) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	var origin := Vector2(span.position[0],span.position[1])
	var half: float = float(span.width)*0.5
	for p: Vector2 in [Vector2(0,-half),Vector2(span.length,-half),Vector2(span.length,half),Vector2(0,half)]:
		polygon.append(origin+p.rotated(deg_to_rad(float(span.heading))))
	return polygon

static func rail_runs(span: Dictionary, bridges: Array, a: float, b: float, side: float) -> Array[Vector2]:
	# Cut rail bands at the union boundary, including oblique intersections.
	var runs: Array[Vector2] = [Vector2(a,b)]
	var inner: float = float(span.width)*0.5*side
	var outer: float = (float(span.width)*0.5+RAIL)*side
	var band := PackedVector2Array([Vector2(a,inner),Vector2(b,inner),Vector2(b,outer),Vector2(a,outer)])
	for other: Dictionary in bridges:
		if other == span: continue
		var polygon := PackedVector2Array()
		for point: Vector2 in road_polygon(other): polygon.append(local_point(span,point))
		for overlap: PackedVector2Array in Geometry2D.intersect_polygons(band,polygon):
			var low: float = b
			var high: float = a
			for point: Vector2 in overlap:
				low = minf(low,point.x)
				high = maxf(high,point.x)
			var remaining: Array[Vector2] = []
			for run: Vector2 in runs:
				if low > run.x: remaining.append(Vector2(run.x,minf(low,run.y)))
				if high < run.y: remaining.append(Vector2(maxf(high,run.x),run.y))
			runs = remaining
	return runs

static func clip_runs(runs: Array, a: float, b: float) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for run: Vector2 in runs:
		var low: float = maxf(a,run.x)
		var high: float = minf(b,run.y)
		if high > low: result.append(Vector2(low,high))
	return result

static func validate(pieces: Array, base_id: String = "") -> Array[String]:
	var footprints: Array[PackedVector2Array] = []
	var spans: Array[Dictionary] = []
	var legacy: Array = _base_polygons(base_id) if pieces.any(func(p: Dictionary) -> bool: return p.kind == "bridge") else []
	for piece: Dictionary in pieces:
		if piece.kind != "bridge": continue
		var polygon := PackedVector2Array()
		var origin := Vector2(piece.position[0],piece.position[1])
		var half: float = float(piece.width)*0.5+RAIL
		for p: Vector2 in [Vector2(0,-half),Vector2(piece.length,-half),Vector2(piece.length,half),Vector2(0,half)]:
			polygon.append(origin+p.rotated(deg_to_rad(float(piece.heading))))
		for other: Dictionary in spans:
			for overlap: PackedVector2Array in Geometry2D.intersect_polygons(road_polygon(other),road_polygon(piece)):
				for index: int in range(overlap.size()):
					for point: Vector2 in [overlap[index],overlap[index].lerp(overlap[(index+1)%overlap.size()],0.5)]:
						if absf(height(other,point)-height(piece,point)) > 0.01:
							return ["Join bridges at matching heights: move the crossing onto their flat decks, away from the ramps."]
		spans.append(piece)
		for existing: PackedVector2Array in legacy:
			if not Geometry2D.intersect_polygons(existing,polygon).is_empty(): return ["Move this span away from the existing elevated road."]
		footprints.append(polygon)
	if footprints.size() > 16: return ["Use up to 16 bridge spans."]
	return []

static func local_point(bridge: Dictionary, point: Vector2) -> Vector2:
	return (point-Vector2(bridge.position[0],bridge.position[1])).rotated(-deg_to_rad(float(bridge.heading)))

static func contains(bridge: Dictionary, point: Vector2, margin: float = 0.0) -> bool:
	var p: Vector2 = local_point(bridge,point)
	return p.x >= -margin and p.x <= float(bridge.length)+margin and absf(p.y) <= float(bridge.width)*0.5+RAIL+margin

static func height(bridge: Dictionary, point: Vector2) -> float:
	var u: float = local_point(bridge,point).x
	return HEIGHT*minf(smoothstep(0.0,RAMP,u),1.0-smoothstep(float(bridge.length)-RAMP,float(bridge.length),u))

static func initial_layer(bridges: Array, point: Vector2, heading: float) -> bool:
	var forward := Vector2(sin(heading),cos(heading))
	for bridge: Dictionary in bridges:
		if contains(bridge,point) and absf(forward.dot(Vector2.RIGHT.rotated(deg_to_rad(float(bridge.heading))))) > 0.75: return true
	return false

static func layer_at(bridges: Array, point: Vector2, previous: bool, _margin: float = 0.0) -> bool:
	for bridge: Dictionary in bridges:
		# The centre must leave the deck at its ground-level end. Expanding
		# both axes by the car radius joins separate spans in dense tracks and
		# carries the upper layer sideways onto the next bridge (Knit).
		if not contains(bridge,point): continue
		var u: float = local_point(bridge,point).x
		# Enter the upper layer only through ground-level ramp ends. A car
		# already on the deck stays there, even while turning or reversing.
		if previous or u <= 2.0 or u >= float(bridge.length)-2.0: return true
	return false

static func at_any(bridges: Array, point: Vector2, margin: float = 0.0) -> bool:
	for bridge: Dictionary in bridges:
		if contains(bridge,point,margin): return true
	return false

static func span_at(bridges: Array, point: Vector2) -> int:
	for i: int in range(bridges.size()):
		if contains(bridges[i],point): return i
	return -1

static func shares_span(bridges: Array, point: Vector2, center: Vector2) -> bool:
	# Every supporting span contributes its exterior rail at a junction.
	# Nearby disconnected spans still cannot push the car off its own deck.
	for bridge: Dictionary in bridges:
		if contains(bridge,point) and contains(bridge,center): return true
	return false

static func blocks_ground(bridge: Dictionary, point: Vector2) -> bool:
	if not contains(bridge,point): return false
	var p: Vector2 = local_point(bridge,point)
	return height(bridge,point) < UNDERPASS_CLEARANCE and (minf(p.x,float(bridge.length)-p.x) >= 2.0 or absf(p.y) > float(bridge.width)*0.5)

static func stamp(bridges: Array, ground: PackedInt32Array, deck: PackedInt32Array, grid: Vector2i, extent: Vector2, cell: float) -> void:
	for bridge: Dictionary in bridges:
		var start := Vector2(bridge.position[0],bridge.position[1])
		var end: Vector2 = RoadPieces.end_pose(bridge).position
		var reach: float = float(bridge.width)*0.5+RAIL+cell
		var low: Vector2 = start.min(end)-Vector2.ONE*reach
		var high: Vector2 = start.max(end)+Vector2.ONE*reach
		for y: int in range(maxi(0,floori((extent.y-high.y)/cell)),mini(grid.y,ceili((extent.y-low.y)/cell))):
			for x: int in range(maxi(0,floori((low.x+extent.x)/cell)),mini(grid.x,ceili((high.x+extent.x)/cell))):
				var point := Vector2((x+0.5)*cell-extent.x,extent.y-(y+0.5)*cell)
				var p: Vector2 = local_point(bridge,point)
				if p.x < 0 or p.x > float(bridge.length) or absf(p.y) > float(bridge.width)*0.5+RAIL: continue
				# Union the road interiors before rails: a later rail must never
				# close an earlier span's road at an elevated intersection.
				if absf(p.y) <= float(bridge.width)*0.5:
					deck[y*grid.x+x] = 0
				elif deck[y*grid.x+x] != 0:
					deck[y*grid.x+x] = 4
				# Only ramp approaches alter the ground. Water/road beneath
				# the middle of a span remains exactly as authored.
				if (p.x < 2.0 or p.x > float(bridge.length)-2.0) and absf(p.y) <= float(bridge.width)*0.5:
					ground[y*grid.x+x] = 0
				# Ground cars cannot enter the low underside from the tunnel or
				# side. The upper ramp remains independently drivable. Preserve
				# the open middle, where the deck has full vehicle clearance.
				if blocks_ground(bridge,point):
					ground[y*grid.x+x] = 4

static func rectangles(cells: PackedInt32Array, grid: Vector2i) -> Array:
	var result: Array = []
	for y: int in range(grid.y):
		var begin: int = 0
		for x: int in range(1,grid.x+1):
			if x == grid.x or cells[y*grid.x+x] != cells[y*grid.x+begin]:
				if cells[y*grid.x+begin] >= 0: result.append([begin,y,x-begin,1,cells[y*grid.x+begin]])
				begin = x
	return result

static func _base_polygons(base_id: String) -> Array:
	if base_id == "" or BuiltinTracks.metadata(base_id).is_empty(): return []
	if base_footprints.has(base_id): return base_footprints[base_id]
	if base_footprints.size() >= 2: base_footprints.clear()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/tracks/"+base_id+".json"))
	var cell: float = data.cell_size
	var extent := Vector2(data.grid_size[0],data.grid_size[1])*cell*0.5
	var result: Array = []
	for rect: Array in data.deck:
		var low := Vector2(float(rect[0])*cell-extent.x,extent.y-float(rect[1]+rect[3])*cell)
		var high := Vector2(float(rect[0]+rect[2])*cell-extent.x,extent.y-float(rect[1])*cell)
		result.append(PackedVector2Array([low,Vector2(high.x,low.y),high,Vector2(low.x,high.y)]))
	base_footprints[base_id] = result
	return result
