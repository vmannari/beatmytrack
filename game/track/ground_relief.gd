class_name GroundRelief
extends RefCounted
## Cached cosmetic meadow heights. Never supplies canonical collision or forces.
const VERSION: String = "meadow-relief-1"
const MAX_VERTICES: int = 32768
const SPACING: float = 0.75
const TILE_SIZE: float = 32.0
const CLEARANCE: float = 2.6
const FADE_END: float = 5.0
const CACHE_LIMIT: int = 4
static var _cache: Dictionary = {}
static var _order: Array[String] = []

var extent := Vector2.ZERO
var size := Vector2i.ZERO
var spacing := Vector2.ONE
var heights := PackedFloat32Array()
var meshes: Array[ArrayMesh] = []
var peak: float = 0.0

static func for_track(track: NativeTrack) -> GroundRelief:
	if track == null or TrackTheme.normalized(str(track.metadata.get("theme","pine"))) != "pine": return GroundRelief.new()
	var key: String = track.content_hash+":"+VERSION
	if _cache.has(key): return _cache[key]
	var field := GroundRelief.new()
	field._build(track)
	while _order.size() >= CACHE_LIMIT:
		_cache.erase(_order.pop_front())
	_order.append(key)
	_cache[key] = field
	return field

func height_at(point: Vector2) -> float:
	if heights.is_empty(): return 0.0
	var p: Vector2 = (Vector2(point.x,-point.y)+extent)/spacing
	if p.x < 0.0 or p.y < 0.0 or p.x >= size.x-1 or p.y >= size.y-1: return 0.0
	var cell := Vector2i(floori(p.x),floori(p.y))
	var f: Vector2 = p-Vector2(cell)
	var first: int = cell.y*size.x+cell.x
	# Match the rendered triangle diagonal, including between grid vertices.
	if f.x+f.y <= 1.0:
		return heights[first]+(heights[first+1]-heights[first])*f.x+(heights[first+size.x]-heights[first])*f.y
	return heights[first+size.x+1]+(heights[first+size.x]-heights[first+size.x+1])*(1.0-f.x)+(heights[first+1]-heights[first+size.x+1])*(1.0-f.y)

func contacts(point: Vector2, heading: float, wheelbase: float, track_width: float) -> Vector4:
	var axle := Vector2(sin(heading),cos(heading))*wheelbase*0.5
	var side := Vector2(cos(heading),-sin(heading))*track_width*0.5
	return Vector4(height_at(point+axle-side),height_at(point+axle+side),height_at(point-axle-side),height_at(point-axle+side))

static func pose(contacts_value: Vector4, wheelbase: float, track_width: float, center_height: float = 0.0) -> Vector3:
	# A narrow crest must not enter a low chassis between its axles. Individual
	# tyres still follow their own heights through presentation suspension.
	return Vector3(maxf(center_height,(contacts_value.x+contacts_value.y+contacts_value.z+contacts_value.w)*0.25),
		atan2((contacts_value.x+contacts_value.y-contacts_value.z-contacts_value.w)*0.5,wheelbase),
		atan2((contacts_value.y+contacts_value.w-contacts_value.x-contacts_value.z)*0.5,track_width))

func _build(track: NativeTrack) -> void:
	extent = track.half_extent
	var step: float = maxf(SPACING,sqrt(extent.x*extent.y*4.0/float(MAX_VERTICES-1024)))
	size = Vector2i(ceili(extent.x*2.0/step)+1,ceili(extent.y*2.0/step)+1)
	while size.x*size.y > MAX_VERTICES:
		step *= 1.02
		size = Vector2i(ceili(extent.x*2.0/step)+1,ceili(extent.y*2.0/step)+1)
	spacing = extent*2.0/Vector2(size-Vector2i.ONE)
	var distance := PackedFloat32Array()
	distance.resize(size.x*size.y)
	distance.fill(INF)
	# Retain all roads, authored sand, water, hazards and solid footprints flat.
	# A conservative coarse-grid expansion also protects triangle interiors.
	for rectangles: Array in [track.rectangles,track.deck_rectangles]:
		for rectangle: Array in rectangles:
			if int(rectangle[4]) == 1 or int(rectangle[4]) < 0: continue
			var low: Vector2 = Vector2(rectangle[0],rectangle[1])*track.cell_size-spacing
			var high: Vector2 = Vector2(rectangle[0]+rectangle[2],rectangle[1]+rectangle[3])*track.cell_size+spacing
			_protect(distance,low,high)
	# Oil and jumps intentionally do not stamp canonical cells. Preserve their
	# authored footprint explicitly instead of changing the surface compiler.
	for object: Dictionary in track.hazard_objects:
		if object.kind not in ["oil","jump"]: continue
		var low := Vector2(INF,INF)
		var high := Vector2(-INF,-INF)
		for point: Vector2 in CreatorObjects.outline(object):
			var p := Vector2(point.x,-point.y)+extent
			low = low.min(p)
			high = high.max(p)
		_protect(distance,low-spacing,high+spacing)
	var diagonal: float = spacing.length()
	for y: int in range(size.y):
		for x: int in range(size.x):
			var i: int = y*size.x+x
			if x > 0: distance[i] = minf(distance[i],distance[i-1]+spacing.x)
			if y > 0:
				distance[i] = minf(distance[i],distance[i-size.x]+spacing.y)
				if x > 0: distance[i] = minf(distance[i],distance[i-size.x-1]+diagonal)
				if x+1 < size.x: distance[i] = minf(distance[i],distance[i-size.x+1]+diagonal)
	for y: int in range(size.y-1,-1,-1):
		for x: int in range(size.x-1,-1,-1):
			var i: int = y*size.x+x
			if x+1 < size.x: distance[i] = minf(distance[i],distance[i+1]+spacing.x)
			if y+1 < size.y:
				distance[i] = minf(distance[i],distance[i+size.x]+spacing.y)
				if x > 0: distance[i] = minf(distance[i],distance[i+size.x-1]+diagonal)
				if x+1 < size.x: distance[i] = minf(distance[i],distance[i+size.x+1]+diagonal)
	heights.resize(distance.size())
	# Stable identity keeps existing bumps in place when a creator edits props.
	var seed_value: int = track.identity.hash() & 0x7fffffff
	for y: int in range(size.y):
		for x: int in range(size.x):
			var p: Vector2 = Vector2(x,y)*spacing-extent
			var boundary: float = minf(extent.x-absf(p.x),extent.y-absf(p.y))
			var amount: float = smoothstep(CLEARANCE,FADE_END,distance[y*size.x+x])*smoothstep(0.0,3.0,boundary)
			heights[y*size.x+x] = _mounds(p,seed_value)*amount
			peak = maxf(peak,heights[y*size.x+x])
	_build_meshes()

func _protect(distance: PackedFloat32Array, low: Vector2, high: Vector2) -> void:
	var a := Vector2i(maxi(0,floori(low.x/spacing.x)),maxi(0,floori(low.y/spacing.y)))
	var b := Vector2i(mini(size.x-1,ceili(high.x/spacing.x)),mini(size.y-1,ceili(high.y/spacing.y)))
	for y: int in range(a.y,b.y+1):
		for x: int in range(a.x,b.x+1): distance[y*size.x+x] = 0.0

static func _mounds(p: Vector2, seed_value: int) -> float:
	var cell := Vector2i(floori(p.x/7.0),floori(p.y/7.0))
	var height: float = 0.0
	for y: int in range(cell.y-1,cell.y+2):
		for x: int in range(cell.x-1,cell.x+2):
			var value: int = (x*73856093 ^ y*19349663 ^ seed_value) & 0x7fffffff
			value = ((value^(value>>16))*0x45d9f3b)&0x7fffffff
			if value%4 == 0: continue
			var center := (Vector2(x,y)+Vector2(0.25+float(value%101)/200.0,0.25+float((value>>8)%101)/200.0))*7.0
			var radius: float = 1.8+float((value>>12)%121)/100.0
			var r: float = p.distance_to(center)/radius
			if r < 1.0: height = maxf(height,(0.20+float((value>>5)%301)/1000.0)*(0.5+0.5*cos(PI*r)))
	return height

func _build_meshes() -> void:
	var tile: int = maxi(1,floori(TILE_SIZE/maxf(spacing.x,spacing.y)))
	for row: int in range(0,size.y-1,tile):
		for column: int in range(0,size.x-1,tile):
			var last := Vector2i(mini(column+tile,size.x-1),mini(row+tile,size.y-1))
			var width: int = last.x-column+1
			var vertices := PackedVector3Array()
			var normals := PackedVector3Array()
			var uv := PackedVector2Array()
			var indices := PackedInt32Array()
			for y: int in range(row,last.y+1):
				for x: int in range(column,last.x+1):
					var p: Vector2 = Vector2(x,y)*spacing-extent
					vertices.append(Vector3(p.x,heights[y*size.x+x],p.y))
					var dx: float = (_height(x+1,y)-_height(x-1,y))/(spacing.x*2.0)
					var dz: float = (_height(x,y+1)-_height(x,y-1))/(spacing.y*2.0)
					normals.append(Vector3(-dx,1,-dz).normalized())
					uv.append((p+extent)/(extent*2.0))
			for y: int in range(last.y-row):
				for x: int in range(width-1):
					var i: int = y*width+x
					indices.append_array(PackedInt32Array([i,i+width,i+1,i+1,i+width,i+width+1]))
			var arrays: Array = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = vertices
			arrays[Mesh.ARRAY_NORMAL] = normals
			arrays[Mesh.ARRAY_TEX_UV] = uv
			arrays[Mesh.ARRAY_INDEX] = indices
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			meshes.append(mesh)

func _height(x: int, y: int) -> float:
	return heights[clampi(y,0,size.y-1)*size.x+clampi(x,0,size.x-1)]
