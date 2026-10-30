extends RefCounted
## Presentation-only continuity across the editor's short fitted road-edge chords.
const JOIN_TOLERANCE: float = 0.002
const POST_SPACING: float = 3.0
const RAMP_LENGTH: float = 3.0
const METAL := Color("7d8988")
const DARK := Color("354442")

static func prepare(objects: Array) -> Array:
	var result: Array = objects.duplicate()
	var nodes: Array = []
	var buckets: Dictionary = {}
	var edges: Array = []
	for index: int in range(objects.size()):
		var object: Dictionary = objects[index]
		if object.kind != "guardrail" or object.has("_guardrail"): continue
		var scale: float = float(object.get("scale",1.0))
		var length: float = CreatorObjects.size_of(object).x
		var center := Vector2(object.position[0],object.position[1])
		var arm: Vector2 = Vector2.from_angle(deg_to_rad(float(object.rotation)))*length*0.5
		var a: int = _node(nodes,buckets,center-arm,scale)
		var b: int = _node(nodes,buckets,center+arm,scale)
		var edge: int = edges.size()
		edges.append({"index":index,"a":a,"b":b,"length":length,"scale":scale})
		nodes[a].edges.append(edge); nodes[b].edges.append(edge)
	# Start at exposed ends, then handle closed loops. Coordinate ordering makes
	# the stationing independent of saved object order and section direction.
	var seeds: Array = []
	for index: int in range(nodes.size()):
		if nodes[index].edges.size() != 2: seeds.append(index)
	seeds.sort_custom(func(a: int,b: int) -> bool: return _less(nodes[a].point,nodes[b].point))
	var loops: Array = range(nodes.size())
	loops.sort_custom(func(a: int,b: int) -> bool: return _less(nodes[a].point,nodes[b].point))
	seeds.append_array(loops)
	var visited: Dictionary = {}
	for seed: int in seeds:
		for first: int in nodes[seed].edges:
			if visited.has(first): continue
			var chain: Array = []
			var node: int = seed
			var edge: int = first
			var total: float = 0.0
			var closed: bool = false
			while not visited.has(edge):
				visited[edge] = true
				var source: Dictionary = edges[edge]
				var reverse: bool = source.b == node
				chain.append({"source":source,"reverse":reverse,"offset":total})
				total += float(source.length)
				node = source.a if reverse else source.b
				if nodes[node].edges.size() != 2: break
				if node == seed: closed = true; break
				edge = nodes[node].edges[1] if nodes[node].edges[0] == edge else nodes[node].edges[0]
			var scale: float = float(edges[first].scale)
			var count: int = maxi(1,floori(total/(POST_SPACING*scale)))
			var next_post: int = 0
			for part: Dictionary in chain:
				var source: Dictionary = part.source
				var begin: float = float(part.offset)
				var end: float = begin+float(source.length)
				var posts := PackedFloat32Array()
				while next_post < count:
					var distance: float = total*(next_post+0.5)/count
					if distance >= end: break
					var x: float = (distance-begin-float(source.length)*0.5)/scale
					posts.append(-x if part.reverse else x)
					next_post += 1
				posts.sort()
				var object: Dictionary = objects[source.index].duplicate(true)
				object["_guardrail"] = {"start":(end if part.reverse else begin)/scale,"end":(begin if part.reverse else end)/scale,"total":total/scale,"closed":closed,"lower_start":nodes[seed].edges.size() == 1,"lower_end":nodes[node].edges.size() == 1,"posts":posts}
				result[source.index] = object
	return result

static func _less(a: Vector2, b: Vector2) -> bool:
	return a.x < b.x if a.x != b.x else a.y < b.y

static func _node(nodes: Array, buckets: Dictionary, point: Vector2, scale: float) -> int:
	var cell := Vector2i((point/0.01).floor())
	for x: int in range(-1,2):
		for y: int in range(-1,2):
			for index: int in buckets.get(cell+Vector2i(x,y),[]):
				if is_equal_approx(float(nodes[index].scale),scale) and point.distance_to(nodes[index].point) <= JOIN_TOLERANCE: return index
	var index: int = nodes.size()
	nodes.append({"point":point,"scale":scale,"edges":[]})
	if not buckets.has(cell): buckets[cell] = []
	buckets[cell].append(index)
	return index

static func standalone(span: float) -> Dictionary:
	var posts := PackedFloat32Array()
	var count: int = maxi(1,floori(span/POST_SPACING))
	for i: int in range(count): posts.append(span*((i+0.5)/count-0.5))
	return {"start":0.0,"end":span,"total":span,"closed":false,"lower_start":true,"lower_end":true,"posts":posts}

static func height(x: float, span: float, profile: Dictionary) -> float:
	if profile.closed: return 1.0
	var station: float = lerpf(float(profile.start),float(profile.end),clampf(x/span+0.5,0.0,1.0))
	var ramp: float = minf(RAMP_LENGTH,float(profile.total)*0.5)
	var distance: float = minf(station if profile.lower_start else INF,float(profile.total)-station if profile.lower_end else INF)
	return smoothstep(0.0,ramp,distance)

static func append(tool: SurfaceTool, span: float, context: Dictionary = {}, winter: bool = false) -> void:
	var profile: Dictionary = standalone(span) if context.is_empty() else context
	for x: float in profile.posts: _post(tool,x,height(x,span,profile),winter)
	var section: Array[Vector2] = [Vector2(0.57,0.087),Vector2(0.62,0.11),Vector2(0.72,0.16),Vector2(0.80,0.11),Vector2(0.88,0.16),Vector2(0.98,0.11),Vector2(1.03,0.087)]
	var count: int = maxi(1,ceili(span/0.35))
	for i: int in range(count):
		var x0: float = span*(float(i)/count-0.5)
		var x1: float = span*(float(i+1)/count-0.5)
		var h0: float = height(x0,span,profile)
		var h1: float = height(x1,span,profile)
		for row: int in range(section.size()-1):
			var a: Vector2 = section[row]; var b: Vector2 = section[row+1]
			PropGeometry.face(tool,[Vector3(x0,a.x*h0,a.y),Vector3(x1,a.x*h1,a.y),Vector3(x1,b.x*h1,b.y),Vector3(x0,b.x*h0,b.y)],METAL.lightened(0.12 if row%2 == 0 else 0.02))
			PropGeometry.face(tool,[Vector3(x1,a.x*h1,a.y-0.015),Vector3(x0,a.x*h0,a.y-0.015),Vector3(x0,b.x*h0,b.y-0.015),Vector3(x1,b.x*h1,b.y-0.015)],METAL.darkened(0.15))
		if winter:
			PropGeometry.face(tool,[Vector3(x0,1.075*h0,0.025),Vector3(x1,1.075*h1,0.025),Vector3(x1,1.065*h1,0.14),Vector3(x0,1.065*h0,0.14)],Color("e1eaf0"),Vector3.UP)

static func _post(tool: SurfaceTool, x: float, h: float, winter: bool) -> void:
	if h < 0.18: return
	for z: float in [-0.072,0.025]:
		PropGeometry.beam(tool,Vector3(x,0,z),Vector3(x,1.25*h,z),0.15,0.035,METAL.darkened(0.20))
	PropGeometry.beam(tool,Vector3(x,0,-0.024),Vector3(x,1.25*h,-0.024),0.033,0.10,METAL.darkened(0.1))
	PropGeometry.box(tool,Vector3(x,0.80*h,0.035),Vector3(0.17,0.30*h,0.17),DARK,minf(0.015,0.03*h))
	PropGeometry.tube(tool,Vector3(x,0.80*h,0.146),Vector3(x,0.80*h,0.169),0.040*h,0.040*h,Color("ccd1c6"),8)
	PropGeometry.box(tool,Vector3(x,1.20*h,0.06),Vector3(0.085,0.15*h,0.04),Color("bbab70"),minf(0.012,0.02*h))
	if winter: PropGeometry.box(tool,Vector3(x,1.267*h,-0.024),Vector3(0.18,0.035*h,0.16),Color("e1eaf0"),minf(0.012,0.015*h))
