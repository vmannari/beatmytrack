class_name SnowBanks
extends RoadKerbs
## Packed snow ridges along exposed road contours. Shared deterministic contact mesh.
const BANK_HEIGHT: float = 0.32
const WIDTH: float = 1.25
const CONTACT_BUCKET: float = 0.5
var _contact_buckets: Dictionary = {}

func build(track: NativeTrack) -> void:
	triangles.clear()
	buckets.clear()
	_contact_buckets.clear()
	extent = track.half_extent
	cell_size = track.cell_size
	grid = Vector2i(track.grid_width,track.grid_height)
	maximum_height = BANK_HEIGHT
	blocked.resize(track.cells.size())
	blocked.fill(0)
	if track.metadata.get("theme", "pine") != "winter": return
	var edges: Array[Dictionary] = []
	var starts: Dictionary = {}
	for y: int in range(grid.y):
		for x: int in range(grid.x):
			if track.cells[y*grid.x+x] != 0: continue
			var nodes: Array[Vector2i] = [Vector2i(x,y),Vector2i(x+1,y),Vector2i(x+1,y+1),Vector2i(x,y+1)]
			var neighbors: Array[Vector2i] = [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]
			for side: int in range(4):
				var neighbor := Vector2i(x,y)+neighbors[side]
				if neighbor.x >= 0 and neighbor.y >= 0 and neighbor.x < grid.x and neighbor.y < grid.y and track.cells[neighbor.y*grid.x+neighbor.x] == 0: continue
				if not starts.has(nodes[side]): starts[nodes[side]] = []
				starts[nodes[side]].append(edges.size())
				edges.append({"a":nodes[side],"b":nodes[(side+1)%4]})
	var visited := PackedByteArray()
	visited.resize(edges.size())
	for first: int in range(edges.size()):
		if visited[first] != 0: continue
		var polygon := PackedVector2Array()
		var current: int = first
		while current >= 0 and visited[current] == 0:
			visited[current] = 1
			var edge: Dictionary = edges[current]
			polygon.append(Vector2(edge.a.x*cell_size-extent.x,extent.y-edge.a.y*cell_size))
			current = -1
			for next: int in starts.get(edge.b,[]):
				if visited[next] == 0:
					current = next
					break
		if polygon.size() < 3: continue
		# Keep only corners before two corner-cutting passes; straight runs stay
		# straight and raster stair-steps become rounded continuous contours.
		var corners := PackedVector2Array()
		for i: int in range(polygon.size()):
			var a: Vector2 = polygon[i]-polygon[(i-1+polygon.size())%polygon.size()]
			var b: Vector2 = polygon[(i+1)%polygon.size()]-polygon[i]
			if absf(a.cross(b)) > 0.00001: corners.append(polygon[i])
		# Bound smoothing on long straight edges so it cannot cut off a corner.
		polygon = PackedVector2Array()
		for i: int in range(corners.size()):
			var a: Vector2 = corners[i]
			var b: Vector2 = corners[(i+1)%corners.size()]
			var count: int = maxi(1,ceili(a.distance_to(b)/cell_size))
			for j: int in range(count): polygon.append(a.lerp(b,float(j)/count))
		for pass_index: int in range(2):
			var rounded := PackedVector2Array()
			for i: int in range(polygon.size()):
				var a: Vector2 = polygon[i]
				var b: Vector2 = polygon[(i+1)%polygon.size()]
				rounded.append(a.lerp(b,0.25))
				rounded.append(a.lerp(b,0.75))
			polygon = rounded
		for i: int in range(polygon.size()):
			var j: int = (i+1)%polygon.size()
			var a: Vector2 = polygon[i]
			var b: Vector2 = polygon[j]
			var outward: Vector2 = -(b-a).normalized().orthogonal()
			var midpoint: Vector2 = (a+b)*0.5
			if track.cell_at(midpoint+outward*0.7) not in [1,2,5]: continue
			if CreatorBridges.at_any(track.creator_bridges,midpoint): continue
			var na: Vector2 = _normal(polygon,i)
			var nb: Vector2 = _normal(polygon,j)
			var offsets: Array[float] = [0.0,0.35,0.80,WIDTH]
			var heights: Array[float] = [0.0,0.25,BANK_HEIGHT,0.0]
			for band: int in range(3):
				var p: Vector2 = a+na*offsets[band]
				var q: Vector2 = b+nb*offsets[band]
				var r: Vector2 = a+na*offsets[band+1]
				var t: Vector2 = b+nb*offsets[band+1]
				_add(p,q,t,heights[band],heights[band],heights[band+1],Vector2.ZERO,Vector2.ZERO,Vector2.ZERO)
				_add(p,t,r,heights[band],heights[band+1],heights[band+1],Vector2.ZERO,Vector2.ZERO,Vector2.ZERO)
	# Preserve the prepared triangles and their order; a finer index avoids
	# scanning hundreds of unrelated triangles at every body/wheel contact.
	for index: int in range(triangles.size()):
		var points: PackedVector2Array = triangles[index].points
		var lo := Vector2i(((points[0].min(points[1]).min(points[2])-Vector2.ONE*0.001)/CONTACT_BUCKET).floor())
		var hi := Vector2i(((points[0].max(points[1]).max(points[2])+Vector2.ONE*0.001)/CONTACT_BUCKET).floor())
		for y: int in range(lo.y,hi.y+1):
			for x: int in range(lo.x,hi.x+1):
				var key := Vector2i(x,y)
				if not _contact_buckets.has(key): _contact_buckets[key] = []
				_contact_buckets[key].append(index)

func height_at(point: Vector2) -> float:
	if triangles.is_empty(): return 0.0
	# Old prepared snapshots may lack the derived index; retain exact contacts.
	if _contact_buckets.is_empty(): return super.height_at(point)
	var cell := Vector2i(floori((point.x+extent.x)/cell_size),floori((extent.y-point.y)/cell_size))
	if cell.x < 0 or cell.y < 0 or cell.x >= grid.x or cell.y >= grid.y or blocked[cell.y*grid.x+cell.x] != 0: return 0.0
	var height: float = 0.0
	for index: int in _contact_buckets.get(Vector2i((point/CONTACT_BUCKET).floor()),[]):
		var triangle: Dictionary = triangles[index]
		var p: PackedVector2Array = triangle.points
		var d: float = (p[1]-p[0]).cross(p[2]-p[0])
		var b: float = (point-p[0]).cross(p[2]-p[0])/d
		var c: float = (p[1]-p[0]).cross(point-p[0])/d
		if b >= -0.00001 and c >= -0.00001 and b+c <= 1.00001:
			height = maxf(height,clampf((1.0-b-c)*triangle.heights[0]+b*triangle.heights[1]+c*triangle.heights[2],0.0,maximum_height))
	return height

func _normal(polygon: PackedVector2Array, index: int) -> Vector2:
	var a: Vector2 = (polygon[index]-polygon[(index-1+polygon.size())%polygon.size()]).normalized()
	var b: Vector2 = (polygon[(index+1)%polygon.size()]-polygon[index]).normalized()
	var normal: Vector2 = -(a+b).normalized().orthogonal()
	return normal/maxf(0.75,normal.dot(-b.orthogonal()))

func slow_car(state: VehicleState, previous: Vector2, config: HandlingConfig, seconds: float) -> void:
	if triangles.is_empty() or state.track_elevated or state.jump_height > 0.0: return
	var forward: Vector2 = state.forward()
	var right: Vector2 = state.right()
	var contact: float = 0.0
	var steps: int = clampi(ceili(previous.distance_to(state.position)/0.25),1,8)
	for i: int in range(steps+1):
		var point: Vector2 = previous.lerp(state.position,float(i)/steps)
		contact += contact_at(point,forward,right,config)/(steps+1)
	# Packed snow ploughs against the bumper/body, including broadside travel.
	# Speed-dependent resistance makes a fast entry costly; the smaller crawl
	# term still lets every car work forward or reverse out under its own power.
	var speed: float = state.velocity.length()
	var resistance: float = 2.0+speed*10.0+22.0*smoothstep(2.0,12.0,speed)
	state.velocity = state.velocity.move_toward(Vector2.ZERO,resistance*contact*seconds)

func contact_at(center: Vector2, forward: Vector2, right: Vector2, config: HandlingConfig) -> float:
	var axle: Vector2 = forward*config.wheelbase*0.5
	var side: Vector2 = right*config.track_width*0.5
	var bumper: Vector2 = forward*maxf(config.collision_radius,config.wheelbase*0.5+0.80*HandlingConfig.BODY_SCALE)
	var height: float = maxf(maxf(height_at(center+axle-side),height_at(center+axle+side)),maxf(height_at(center-axle-side),height_at(center-axle+side)))
	height = maxf(height,maxf(height_at(center),maxf(height_at(center+bumper),height_at(center-bumper))))
	return clampf(height/BANK_HEIGHT,0.0,1.0)
