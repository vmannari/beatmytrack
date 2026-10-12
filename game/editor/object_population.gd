class_name ObjectPopulation
extends RefCounted
## Editor-only placement. Saved objects, never a race-time generator.
## Exact Euclidean distance transform on a coarse road mask, then bounded
## random sequential inhibition (minimum spacing) with clustered woodland.

const CELL: float = 2.0
const MASK_ERROR: float = 3.0 # Conservative raster/sample uncertainty.
const CLEARANCE: float = 4.0
const MAX_OBJECTS: int = 96
const BIN: float = 12.0
const NATURE: Array[String] = ["tree", "broadleaf", "rock", "boulder"]
const ROADSIDE: Array[String] = ["shed", "hut", "car_wreck", "container", "parked_car", "barrel", "crate"]

var source: Dictionary
var terrain: NativeTrack
var extent: Vector2
var grid: Vector2i
var distances: PackedFloat32Array
var sites: PackedVector2Array
var occupied: Array
var start: Vector2
var error: String = ""
var prepare_usec: int = 0
var sample_usec: int = 0

func prepare(document: Dictionary, track: NativeTrack) -> void:
	var began: int = Time.get_ticks_usec()
	source = document.duplicate(true)
	terrain = track
	occupied = source.objects.duplicate(true)
	# Populate replaces the implicit backdrop. Hand-placed/adopted objects stay.
	var pose: Array = source.get("start_line",source.get("practice_start",{})).get("position",source.points[0])
	start = Vector2(pose[0],pose[1])
	var sections: Array[Dictionary] = []
	if not source.layout.is_empty():
		var layout: Dictionary = TrackDocument.route_data(source.layout)
		sections.append({"points":layout.points,"widths":layout.widths,"closed":true})
	var topology: Dictionary = RoadPieces.prepare_endpoints(source.pieces)
	for index: int in range(source.pieces.size()):
		var geometry: Dictionary = RoadPieces.section_geometry(source.pieces,index,topology)
		sections.append({"points":geometry.points,"widths":geometry.widths,"closed":false})
	if source.base_track != "" and track != null: extent = track.half_extent
	for section: Dictionary in sections:
		for index: int in range(section.points.size()):
			extent = extent.max(section.points[index].abs()+Vector2.ONE*float(section.widths[index])*0.5)
	for stroke: Dictionary in source.paint:
		if int(stroke.surface) != 0: continue
		for point: Array in stroke.points: extent = extent.max(Vector2(point[0],point[1]).abs()+Vector2.ONE*float(stroke.width)*0.5)
	if extent == Vector2.ZERO:
		error = "Add a road before populating the track."
		return
	extent = ((extent+Vector2.ONE*38.0).min(Vector2.ONE*110.0)/CELL).ceil()*CELL
	grid = Vector2i(roundi(extent.x*2.0/CELL),roundi(extent.y*2.0/CELL))
	var mask := PackedInt32Array()
	mask.resize(grid.x*grid.y); mask.fill(1)
	if source.base_track != "" and track != null:
		for y: int in range(grid.y):
			for x: int in range(grid.x):
				var point: Vector2 = _point(x,y)
				if point.abs().x < track.half_extent.x-1.0 and point.abs().y < track.half_extent.y-1.0 and track.cell_at(point) in [0,2,5]: mask[y*grid.x+x] = 0
	for section: Dictionary in sections:
		# Include bridges as protected road at every elevation.
		TrackCompiler._raster_road(section.points,section.widths,0,mask,grid,extent,CELL,section.closed)
	var road_paint: Array = []
	for stroke: Dictionary in source.paint:
		if int(stroke.surface) == 0:
			var copy: Dictionary = stroke.duplicate(true)
			copy.protect_road = false
			road_paint.append(copy)
	TrackCompiler._paint(road_paint,mask,grid,extent,CELL,mask.duplicate())
	if not mask.has(0):
		error = "Add a road before populating the track."
		return
	distances = _distance_field(mask,grid)
	for y: int in range(grid.y):
		for x: int in range(grid.x):
			if distances[y*grid.x+x] > CLEARANCE+MASK_ERROR and distances[y*grid.x+x] < 38.0: sites.append(_point(x,y))
	prepare_usec = Time.get_ticks_usec()-began

func generate(seed_value: int, density: float, roadside_reach: float) -> Array:
	var began: int = Time.get_ticks_usec()
	var result: Array = []
	if not error.is_empty() or sites.is_empty(): return result
	var target: int = mini(MAX_OBJECTS-source.objects.size(),roundi(lerpf(24.0,80.0,clampf(density,0.0,1.0))))
	if target <= 0: return result
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var noise := FastNoiseLite.new()
	noise.seed = seed_value & 0x7fffffff
	noise.frequency = 0.045
	var buckets: Dictionary = {}
	var largest: float = 0.0
	for object: Dictionary in occupied:
		_insert(buckets,object)
		largest = maxf(largest,radius(object))
	var near_sites := PackedVector2Array()
	var far_sites := PackedVector2Array()
	for point: Vector2 in sites:
		if distance_at(point) < roadside_reach-MASK_ERROR: near_sites.append(point)
		if distance_at(point) > roadside_reach*0.6: far_sites.append(point)
	var centres := PackedVector2Array()
	for index: int in range(5):
		if not far_sites.is_empty(): centres.append(far_sites[rng.randi_range(0,far_sites.size()-1)])
	var near_target: int = mini(target,maxi(1,roundi(target*0.25)))
	for phase: int in range(2):
		var candidates: PackedVector2Array = near_sites if phase == 0 else far_sites
		if candidates.is_empty(): continue
		for attempt: int in range(1600):
			if result.size() >= (near_target if phase == 0 else target): break
			var point: Vector2 = candidates[rng.randi_range(0,candidates.size()-1)]+Vector2(rng.randf_range(-0.8,0.8),rng.randf_range(-0.8,0.8))
			var kind: String
			if phase == 0:
				kind = ROADSIDE[result.size()%ROADSIDE.size()]
			else:
				var cluster: float = 0.0
				for centre: Vector2 in centres: cluster = maxf(cluster,exp(-point.distance_squared_to(centre)/500.0))
				if rng.randf() > clampf(0.2+cluster*0.6+noise.get_noise_2dv(point)*0.35,0.1,0.95): continue
				kind = "rock" if rng.randf() < (0.85 if source.theme == "desert" else 0.3) else "tree"
				if source.theme == "desert": kind = "boulder" if rng.randf() < 0.3 else "rock"
				elif source.theme == "night_city" and kind == "tree": kind = "broadleaf"
			var rotation: float = rng.randf_range(0.0,359.99)
			if phase == 0 and kind != "car_wreck": rotation = road_rotation(point)+float(rng.randi_range(-1,1))*90.0
			var object: Dictionary = {"kind":kind,"position":[snappedf(point.x,0.01),snappedf(point.y,0.01)],"rotation":fposmod(snappedf(rotation,0.01),360.0),"scale":snappedf(rng.randf_range(0.8,1.15),0.01)}
			point = Vector2(object.position[0],object.position[1])
			var reach: float = radius(object)
			var distance: float = distance_at(point)
			if distance-MASK_ERROR-reach < CLEARANCE: continue
			if phase == 0 and distance+MASK_ERROR+reach > roadside_reach: continue
			if point.abs().x+reach > 108.0 or point.abs().y+reach > 108.0: continue
			if point.distance_to(start) < 10.0+reach: continue
			if not _separated(buckets,point,reach,largest) or not _ground_clear(point,reach): continue
			result.append(object)
			_insert(buckets,object)
			largest = maxf(largest,reach)
	sample_usec = Time.get_ticks_usec()-began
	# Use the same numerical representation as the saved authoring JSON.
	return JSON.parse_string(JSON.stringify(result))

static func radius(object: Dictionary) -> float:
	var reach: float = CreatorObjects.size_of(object).length()*0.5
	if object.kind in ["tree","broadleaf"]: reach = maxf(reach,3.0*float(object.get("scale",1.0)))
	return reach

func distance_at(point: Vector2) -> float:
	var x: int = clampi(floori((point.x+extent.x)/CELL),0,grid.x-1)
	var y: int = clampi(floori((extent.y-point.y)/CELL),0,grid.y-1)
	return distances[y*grid.x+x]

func road_rotation(point: Vector2) -> float:
	var gradient := Vector2(distance_at(point+Vector2.RIGHT*CELL)-distance_at(point-Vector2.RIGHT*CELL),distance_at(point+Vector2.UP*CELL)-distance_at(point-Vector2.UP*CELL))
	return rad_to_deg(Vector2(-gradient.y,gradient.x).angle())

func _point(x: int, y: int) -> Vector2:
	return Vector2((x+0.5)*CELL-extent.x,extent.y-(y+0.5)*CELL)

static func _insert(buckets: Dictionary, object: Dictionary) -> void:
	var point := Vector2(object.position[0],object.position[1])
	var key := Vector2i(floori(point.x/BIN),floori(point.y/BIN))
	if not buckets.has(key): buckets[key] = []
	buckets[key].append(object)

static func _separated(buckets: Dictionary, point: Vector2, reach: float, largest: float) -> bool:
	var margin: float = reach+largest+1.5
	for y: int in range(floori((point.y-margin)/BIN),floori((point.y+margin)/BIN)+1):
		for x: int in range(floori((point.x-margin)/BIN),floori((point.x+margin)/BIN)+1):
			for object: Dictionary in buckets.get(Vector2i(x,y),[]):
				if point.distance_to(Vector2(object.position[0],object.position[1])) < reach+radius(object)+1.5: return false
	return true

func _ground_clear(point: Vector2, reach: float) -> bool:
	if terrain == null: return true
	var cell: float = terrain.cell_size
	for y: int in range(maxi(0,floori((terrain.half_extent.y-point.y-reach)/cell)),mini(terrain.grid_height,ceili((terrain.half_extent.y-point.y+reach)/cell))):
		for x: int in range(maxi(0,floori((point.x-reach+terrain.half_extent.x)/cell)),mini(terrain.grid_width,ceili((point.x+reach+terrain.half_extent.x)/cell))):
			var at: int = y*terrain.grid_width+x
			var sample := Vector2((x+0.5)*cell-terrain.half_extent.x,terrain.half_extent.y-(y+0.5)*cell)
			if sample.distance_to(point) > reach+cell: continue
			if terrain.cells[at] in [3,4,6] or terrain.deck_cells[at] >= 0: return false
	return true

static func _distance_field(mask: PackedInt32Array, size: Vector2i) -> PackedFloat32Array:
	var field := PackedFloat32Array()
	field.resize(mask.size())
	for y: int in range(size.y):
		var row := PackedFloat64Array()
		row.resize(size.x)
		for x: int in range(size.x): row[x] = 0.0 if mask[y*size.x+x] == 0 else 1.0e12
		var transformed: PackedFloat64Array = _edt(row)
		for x: int in range(size.x): field[y*size.x+x] = transformed[x]
	for x: int in range(size.x):
		var column := PackedFloat64Array()
		column.resize(size.y)
		for y: int in range(size.y): column[y] = field[y*size.x+x]
		var transformed: PackedFloat64Array = _edt(column)
		for y: int in range(size.y): field[y*size.x+x] = sqrt(transformed[y])*CELL
	return field

static func _edt(values: PackedFloat64Array) -> PackedFloat64Array:
	# Lower envelope of parabolas: linear time per row/column.
	var vertices := PackedInt32Array()
	vertices.resize(values.size())
	var boundaries := PackedFloat64Array()
	boundaries.resize(values.size()+1)
	boundaries[0] = -INF; boundaries[1] = INF
	var k: int = 0
	for q: int in range(1,values.size()):
		var crossing: float = ((values[q]+q*q)-(values[vertices[k]]+vertices[k]*vertices[k]))/(2.0*(q-vertices[k]))
		while crossing <= boundaries[k]:
			k -= 1
			crossing = ((values[q]+q*q)-(values[vertices[k]]+vertices[k]*vertices[k]))/(2.0*(q-vertices[k]))
		k += 1; vertices[k] = q; boundaries[k] = crossing; boundaries[k+1] = INF
	var result := PackedFloat64Array()
	result.resize(values.size())
	k = 0
	for q: int in range(values.size()):
		while boundaries[k+1] < q: k += 1
		result[q] = (q-vertices[k])*(q-vertices[k])+values[vertices[k]]
	return result
