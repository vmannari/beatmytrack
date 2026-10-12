
extends RefCounted
## Deterministic solid trees. Removed/edited scenery is explicitly suppressed.

static func key(object: Dictionary) -> String:
	return "%.2f:%.2f" % [object.position[0],object.position[1]]

static func generate(document: Dictionary, cells: PackedInt32Array, deck: PackedInt32Array, grid: Vector2i, extent: Vector2, cell: float) -> Array:
	var result: Array = []
	var winter: bool = document.get("theme","pine") == "winter"
	if document.get("theme","pine") != "pine" and not winter: return result
	# A native remix must retain its imported ground/deck geometry exactly.
	if document.base_track != "": return result
	if document.layout.is_empty() and document.pieces.is_empty() and document.base_track == "": return result
	var sites: Array[Vector3i] = []
	for y: int in range(-12,13):
		for x: int in range(-12,13):
			var hash_value: int = ((x*73856093 ^ y*19349663)*0x45d9f3b)&0x7fffffff
			if winter:
				# Spend the bounded kit beside the route before distant empty terrain.
				var point := Vector2(x*8.0,y*8.0)
				var distance: float = INF
				for p: Array in document.points:
					distance = minf(distance,point.distance_squared_to(Vector2(p[0],p[1])))
				hash_value = mini(2147483647,int(distance*8192.0)+hash_value%8192)
			sites.append(Vector3i(hash_value,x,y))
	sites.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		if a.x != b.x: return a.x < b.x
		if a.y != b.y: return a.y < b.y
		return a.z < b.z)
	var candidates: int = 0
	for site: Vector3i in sites:
		var x: int = site.y
		var y: int = site.z
		var seed_value: int = (x*73856093 ^ y*19349663)&0x7fffffff
		if seed_value%3 != 0: continue
		var point := Vector2(x*8.0+(seed_value%5)*0.3,y*8.0+((seed_value/7)%5)*0.3)
		if point.abs().x+5 > extent.x or point.abs().y+5 > extent.y: continue
		var clear: bool = true
		var at := Vector2i(floori((point.x+extent.x)/cell),floori((extent.y-point.y)/cell))
		var radius: int = ceili(4.5/cell)
		for yy: int in range(at.y-radius,at.y+radius+1):
			for xx: int in range(at.x-radius,at.x+radius+1):
				if xx < 0 or yy < 0 or xx >= grid.x or yy >= grid.y or cells[yy*grid.x+xx] != 1 or deck[yy*grid.x+xx] >= 0: clear = false
		if not clear: continue
		candidates += 1
		if candidates > 48: return result
		var object: Dictionary = {"kind":"tree","position":[point.x,point.y],"rotation":float(seed_value%360)}
		if winter:
			object.scale = 0.75+float(seed_value%6)*0.15
			if seed_value%11 == 0:
				object.kind = "fence"
				object.scale = 1.0
			elif seed_value%4 == 0:
				object.kind = "boulder"
				object.scale = 0.65+float(seed_value%4)*0.12
		if key(object) in document.get("hidden_scenery",[]): continue
		var occupied: bool = false
		for placed: Dictionary in document.objects:
			if point.distance_to(Vector2(placed.position[0],placed.position[1])) < CreatorObjects.size_of(placed).length()*0.5+2.0: occupied = true
		if winter:
			for previous: Dictionary in result:
				if point.distance_to(Vector2(previous.position[0],previous.position[1])) < 5.0: occupied = true
		var start: Array = document.get("practice_start",{}).get("position",document.points[0])
		if point.distance_to(Vector2(start[0],start[1])) < 7.0: occupied = true
		if not occupied: result.append(object)
	return result
