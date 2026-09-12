class_name TrackCompiler
extends RefCounted
## Pure bounded compiler; native surface cells drive both simulation and art.

const VERSION: String = "creator-compiler-1"
const CELL_SIZE: float = 0.5


static func compile(document: Dictionary) -> NativeTrack:
	if not TrackDocument.validate(document).is_empty():
		return null
	var route: PackedVector2Array = TrackDocument.smooth_points(document)
	var radius: float = float(document.width) * 0.5
	var extent := Vector2.ZERO
	for point: Vector2 in route:
		extent.x = maxf(extent.x, absf(point.x))
		extent.y = maxf(extent.y, absf(point.y))
	extent = (extent + Vector2.ONE * (radius + 12.0)).ceil()
	var grid := Vector2i(roundi(extent.x * 2.0 / CELL_SIZE), roundi(extent.y * 2.0 / CELL_SIZE))
	var cells := PackedInt32Array()
	cells.resize(grid.x * grid.y)
	cells.fill(1)
	var road_kind: int = 2 if document.surface == "dirt" else 0
	for i: int in range(route.size()):
		var a: Vector2 = route[i]
		var b: Vector2 = route[(i+1) % route.size()]
		var margin: float = radius + 1.0
		var x0: int = maxi(0, floori((minf(a.x,b.x)-margin+extent.x)/CELL_SIZE))
		var x1: int = mini(grid.x-1, ceili((maxf(a.x,b.x)+margin+extent.x)/CELL_SIZE))
		var y0: int = maxi(0, floori((extent.y-maxf(a.y,b.y)-margin)/CELL_SIZE))
		var y1: int = mini(grid.y-1, ceili((extent.y-minf(a.y,b.y)+margin)/CELL_SIZE))
		for y: int in range(y0,y1+1):
			for x: int in range(x0,x1+1):
				var p := Vector2((x+0.5)*CELL_SIZE-extent.x,extent.y-(y+0.5)*CELL_SIZE)
				var distance: float = p.distance_squared_to(Geometry2D.get_closest_point_to_segment(p,a,b))
				var at: int = y*grid.x+x
				if distance <= radius*radius:
					cells[at] = road_kind
				elif distance <= margin*margin and cells[at] == 1:
					cells[at] = 5
	# A distant perimeter makes the finite authoring area explicit and keeps
	# accidental off-course driving recoverable with the ordinary restart.
	for y: int in range(grid.y):
		for x: int in range(grid.x):
			if x < 2 or y < 2 or x >= grid.x-2 or y >= grid.y-2:
				cells[y*grid.x+x] = 4
	var surfaces: Array = []
	for y: int in range(grid.y):
		var start: int = 0
		for x: int in range(1,grid.x+1):
			if x == grid.x or cells[y*grid.x+x] != cells[y*grid.x+start]:
				surfaces.append([start,y,x-start,1,cells[y*grid.x+start]])
				start = x
	var route_data: Array = []
	for point: Vector2 in route:
		route_data.append([point.x,point.y])
	var checkpoints: Array = []
	for fraction: float in [0.20,0.40,0.60,0.80]:
		var index: int = floori(route.size()*fraction)
		var center: Vector2 = route[index]
		var tangent: Vector2 = (route[(index+1)%route.size()]-center).normalized()
		var side := Vector2(tangent.y,-tangent.x)
		var half: Vector2 = side.abs() * radius + tangent.abs() * 1.5
		checkpoints.append([center.x-half.x,center.y-half.y,half.x*2.0,half.y*2.0])
	var forward: Vector2 = (route[1]-route[0]).normalized()
	var heading: float = atan2(forward.x,forward.y)
	var data: Dictionary = {"schema":"surface-grid-v2", "identity":"creator_"+document.id, "name":document.name, "title":document.name, "version":VERSION,
		"theme":document.theme, "creator_document":document.duplicate(true), "cell_size":CELL_SIZE, "grid_size":[grid.x,grid.y],
		"origin":[-extent.x,extent.y], "car_width_m":1.584, "representative_width_m":document.width,
		"surfaces":surfaces, "deck":[], "bridges":[], "spawn":route_data[0], "spawn_heading":heading,
		"finish":{"center":route_data[0],"half_width":radius,"heading":heading,"basis":"creator route origin"},
		"route":route_data,"checkpoints":checkpoints, "debug":{"blocks":[]},
		"provenance":{"source":"local creator","use":"original route with built-in track kit"}}
	return NativeTrack.from_data(data,(VERSION+"\n"+JSON.stringify(document,"",true)).sha256_text())
