class_name CompactGrille
extends RefCounted
## Original bowed, fabricated grille. Geometry is cosmetic and immutable.
const HALF: float = 0.492
const BOTTOM: float = 0.696
const TOP: float = 0.900
const RADIUS: float = 0.024
static var meshes: Dictionary = {}
static var opening: Array[Vector2] = []

static func outline(half: float, bottom: float, top: float, radius: float, spans: bool = false, span_segments: int = 10) -> Array[Vector2]:
	var result: Array[Vector2] = []
	# Counter-clockwise in X/Y. Straight rails also follow the nose's bow.
	var centers: Array[Vector2] = [Vector2(half-radius,bottom+radius),Vector2(half-radius,top-radius),Vector2(-half+radius,top-radius),Vector2(-half+radius,bottom+radius)]
	for corner: int in range(4):
		for step: int in range(5):
			var angle: float = -PI*0.5+corner*PI*0.5+step*PI/8.0
			result.append(centers[corner]+Vector2(cos(angle),sin(angle))*radius)
		if spans and corner in [1,3]:
			var start: Vector2 = result[-1]
			var finish: Vector2 = centers[(corner+1)%4]+Vector2(cos(corner*PI*0.5),sin(corner*PI*0.5))*radius
			for station: int in range(1,span_segments): result.append(start.lerp(finish,float(station)/span_segments))
	return result

static func hole() -> Array[Vector2]:
	if opening.is_empty(): opening = outline(HALF,BOTTOM,TOP,RADIUS)
	return opening

static func overlaps(points: Array[Vector3]) -> bool:
	var left: float = INF
	var right: float = -INF
	var bottom: float = INF
	var top: float = -INF
	for p: Vector3 in points:
		left = minf(left,p.x)
		right = maxf(right,p.x)
		bottom = minf(bottom,p.y)
		top = maxf(top,p.y)
	return left<HALF and right>-HALF and bottom<TOP and top>BOTTOM

static func cut_quad(tool: SurfaceTool, points: Array[Vector3], normals: Array[Vector3], uv: Array[Vector2], write_uv: bool = true) -> void:
	# Subtract the same convex opening from steel AND fascia. Each clipping
	# plane emits its exterior once; remaining interior proceeds to the next.
	# Interpolation retains the original shell/UV/normal samples at the join.
	var boundary: Array[Vector2] = hole()
	for indices: Array in [[0,2,1],[0,3,2]]:
		var remaining: Array[Dictionary] = []
		for index: int in indices: remaining.append({"p":points[index],"n":normals[index],"uv":uv[index]})
		for edge: int in range(boundary.size()):
			if remaining.size()<3: break
			var a: Vector2 = boundary[edge]
			var direction: Vector2 = boundary[(edge+1)%boundary.size()]-a
			var inside: Array[Dictionary] = []
			var outside: Array[Dictionary] = []
			for index: int in range(remaining.size()):
				var p: Dictionary = remaining[index]
				var q: Dictionary = remaining[(index+1)%remaining.size()]
				var dp: float = direction.cross(Vector2(p.p.x,p.p.y)-a)
				var dq: float = direction.cross(Vector2(q.p.x,q.p.y)-a)
				if dp>=0: inside.append(p)
				else: outside.append(p)
				if (dp<0)!=(dq<0):
					var t: float = dp/(dp-dq)
					var crossing: Dictionary = {"p":(p.p as Vector3).lerp(q.p,t),"n":(p.n as Vector3).lerp(q.n,t).normalized(),"uv":(p.uv as Vector2).lerp(q.uv,t)}
					inside.append(crossing)
					outside.append(crossing)
			_emit_polygon(tool,outside,write_uv)
			remaining = inside

static func _emit_polygon(tool: SurfaceTool, polygon: Array[Dictionary], write_uv: bool) -> void:
	for index: int in range(1,polygon.size()-1):
		var a: Vector3 = polygon[0].p
		var b: Vector3 = polygon[index].p
		var c: Vector3 = polygon[index+1].p
		if (b-a).cross(c-a).length_squared()<1e-18: continue
		for vertex: Dictionary in [polygon[0],polygon[index],polygon[index+1]]:
			tool.set_normal(vertex.n)
			if write_uv: tool.set_uv(vertex.uv)
			tool.add_vertex(vertex.p)

static func point(p: Vector2, depth: float) -> Vector3:
	return Vector3(p.x,p.y,CompactCoachwork.front_skin(p.x,p.y)+depth)

static func prepare(cooperate: Callable) -> bool:
	for key: String in ["FrontGrilleSurround","FrontGrilleLouvers","FrontGrilleCooling","FrontGrilleLattice"]:
		_mesh(key)
		if cooperate.is_valid() and not await cooperate.call(): return false
	return true

static func _mesh(key: String) -> ArrayMesh:
	if not meshes.has(key):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		match key:
			"FrontGrilleSurround": _surround(tool)
			"FrontGrilleLouvers": _louvers(tool)
			"FrontGrilleCooling": _cooling(tool)
			"FrontGrilleLattice": _lattice(tool)
		tool.index()
		tool.generate_tangents()
		meshes[key] = tool.commit()
		meshes[key].set_meta("car_authored_far",true)
	return meshes[key]

static func build(car: CarVisual) -> void:
	var graphite := CompactFinish.rubber(Color("141d20"))
	graphite.roughness = 0.67
	var satin := CompactFinish.alloy(Color("c6cbc5"))
	satin.metallic = 0.88
	satin.roughness = 0.24
	var slats := CompactFinish.alloy(Color("8e9a98"))
	slats.metallic = 0.76
	slats.roughness = 0.34
	var lattice := CompactFinish.alloy(Color("263237"))
	lattice.metallic = 0.35
	lattice.roughness = 0.53
	for material: StandardMaterial3D in [graphite,satin,slats,lattice]: material.set_meta("compact_grille_finish",true)
	for key: String in ["FrontGrilleSurround","FrontGrilleLouvers","FrontGrilleCooling","FrontGrilleLattice"]:
		var part := MeshInstance3D.new()
		part.name = key
		part.mesh = _mesh(key)
		part.material_override = {"FrontGrilleSurround":satin,"FrontGrilleLouvers":slats,"FrontGrilleCooling":graphite,"FrontGrilleLattice":lattice}[key]
		car.body.add_child(part)

static func _surround(tool: SurfaceTool) -> void:
	# A thin rolled metal bead frames the recessed mouth, without face screws.
	var rings: Array = [outline(0.507,0.681,0.915,0.039,true,5),outline(0.509,0.679,0.917,0.041,true,5),outline(0.503,0.685,0.911,0.035,true,5),outline(HALF,BOTTOM,TOP,RADIUS,true,5),outline(HALF,BOTTOM,TOP,RADIUS,true,5)]
	var depths: Array[float] = [0.008,-0.028,-0.042,-0.033,0.008]
	for profile: int in range(rings.size()):
		var next: int = (profile+1)%rings.size()
		for index: int in range(rings[profile].size()):
			var station: int = (index+1)%rings[profile].size()
			var a: Vector3 = point(rings[profile][index],depths[profile])
			var b: Vector3 = point(rings[profile][station],depths[profile])
			var c: Vector3 = point(rings[next][station],depths[next])
			var d: Vector3 = point(rings[next][index],depths[next])
			# Profile traverses rear/outer/front/inner/rear; winding owns returns.
			var normals: Array[Vector3]=[]
			for pair: Array in [[profile,index],[next,index],[next,station],[profile,station]]:
				var ring: Array[Vector2]=rings[pair[0]]
				var at: int=pair[1]
				var tangent: Vector3=point(ring[(at+1)%ring.size()],depths[pair[0]])-point(ring[posmod(at-1,ring.size())],depths[pair[0]])
				var across: Vector3=point(rings[next][at],depths[next])-point(rings[profile][at],depths[profile])
				normals.append(across.cross(tangent).normalized())
			_quad_normals(tool,[a,d,c,b],normals)

static func _louvers(tool: SurfaceTool) -> void:
	# Slim rounded leading edge and a dark folded return. The top facet catches
	# the actual showroom/sun lighting instead of painting a highlight stripe.
	var section: Array[Vector2] = [Vector2(-0.0025,-0.033),Vector2(0.0025,-0.033),Vector2(0.0025,0.007),Vector2(-0.0035,0.007)]
	for row: int in range(6):
		var y: float = 0.713+row*0.034
		for station: int in range(5):
			var x0: float = lerpf(-HALF,HALF,station/5.0)
			var x1: float = lerpf(-HALF,HALF,(station+1)/5.0)
			for face: int in range(section.size()):
				var p: Vector2 = section[face]
				var q: Vector2 = section[(face+1)%section.size()]
				var a: Vector3 = point(Vector2(x0,y+p.x),p.y)
				var b: Vector3 = point(Vector2(x1,y+p.x),p.y)
				var c: Vector3 = point(Vector2(x1,y+q.x),q.y)
				var d: Vector3 = point(Vector2(x0,y+q.x),q.y)
				var normals: Array[Vector3]=[]
				for at: Vector3 in [a,b,c,d]:
					var dx: float=(CompactCoachwork.front_skin(at.x+0.0001,at.y)-CompactCoachwork.front_skin(at.x-0.0001,at.y))/0.0002
					var dy: float=(CompactCoachwork.front_skin(at.x,at.y+0.0001)-CompactCoachwork.front_skin(at.x,at.y-0.0001))/0.0002
					var n:=Vector3(0,q.y-p.y,p.x-q.x)
					normals.append(Vector3(-n.z*dx,n.y-n.z*dy,n.z).normalized())
				_quad_normals(tool,[a,b,c,d],normals)
		for side: float in [-1.0,1.0]:
			var cap: Array[Vector3] = []
			for p: Vector2 in section: cap.append(point(Vector2(side*HALF,y+p.x),p.y))
			for index: int in range(1,cap.size()-1): _triangle(tool,cap[0],cap[index],cap[index+1],Vector3(side,0,0))

static func _lattice(tool: SurfaceTool) -> void:
	# A quieter, darker backing lattice leaves the six satin rails readable.
	for column: int in range(24):
		var x: float = lerpf(-0.476,0.476,column/23.0)
		# A cast rib tapers at the back. Its closed triangular return gives the
		# fine front face real thickness using eight triangles per upright.
		var section: Array[Vector2] = [Vector2(-0.0014,-0.010),Vector2(0.0014,-0.010),Vector2(0,0.005)]
		var lower: Array[Vector3] = []
		var upper: Array[Vector3] = []
		for p: Vector2 in section:
			lower.append(point(Vector2(x+p.x,BOTTOM),p.y))
			upper.append(point(Vector2(x+p.x,TOP),p.y))
		for face: int in range(3):
			var next: int = (face+1)%3
			var a: Vector3 = lower[face]
			var b: Vector3 = lower[next]
			var c: Vector3 = upper[next]
			var d: Vector3 = upper[face]
			_quad(tool,[a,b,c,d],(d-a).cross(b-a).normalized())
		_triangle(tool,lower[0],lower[1],lower[2],Vector3.DOWN)
		_triangle(tool,upper[0],upper[1],upper[2],Vector3.UP)

static func _cooling(tool: SurfaceTool) -> void:
	var rim: Array[Vector2] = outline(HALF,BOTTOM,TOP,RADIUS,true,4)
	var center := Vector2(0,(BOTTOM+TOP)*0.5)
	for index: int in range(rim.size()):
		var p: Vector2 = rim[index]
		var q: Vector2 = rim[(index+1)%rim.size()]
		var a: Vector3 = point(p,-0.013)
		var b: Vector3 = point(q,-0.013)
		var c: Vector3 = point(center+(q-center)*0.94,0.108)
		var d: Vector3 = point(center+(p-center)*0.94,0.108)
		_quad(tool,[a,b,c,d],(d-a).cross(b-a).normalized())
	_quad(tool,[point(Vector2(-0.480,BOTTOM),0.112),point(Vector2(0.480,BOTTOM),0.112),point(Vector2(0.480,TOP),0.112),point(Vector2(-0.480,TOP),0.112)],Vector3.FORWARD)
	# Low frequency, folded radiator fins remain behind the open slat gaps.
	for fin: int in range(12):
		var x: float = lerpf(-0.474,0.474,fin/11.0)
		for side: float in [-1.0,1.0]:
			_quad(tool,[point(Vector2(x+side*0.005,0.700),0.108),point(Vector2(x,0.700),0.093),point(Vector2(x,0.891),0.093),point(Vector2(x+side*0.005,0.891),0.108)],Vector3(side*0.70,0,-0.70).normalized())
	for x: float in [-0.312,0.312]:
		_box(tool,Vector3(x,0.795,CompactCoachwork.front_skin(x,0.795)+0.038),Vector3(0.011,0.208,0.025))
	for y: float in [0.699,0.891]:
		_box(tool,Vector3(0,y,CompactCoachwork.front_skin(0,y)+0.085),Vector3(0.925,0.008,0.011))

static func _box(tool: SurfaceTool, center: Vector3, size: Vector3) -> void:
	for axis: int in range(3):
		for side: float in [-1.0,1.0]:
			var normal := Vector3.ZERO
			normal[axis] = side
			var points: Array[Vector3] = []
			for corner: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
				var p := Vector3.ZERO
				p[axis] = size[axis]*side*0.5
				p[(axis+1)%3] = size[(axis+1)%3]*corner.x*0.5
				p[(axis+2)%3] = size[(axis+2)%3]*corner.y*0.5
				points.append(center+p)
			_quad(tool,points,normal)

static func _quad(tool: SurfaceTool, points: Array[Vector3], normal: Vector3) -> void:
	_triangle(tool,points[0],points[1],points[2],normal)
	_triangle(tool,points[0],points[2],points[3],normal)

static func _quad_normals(tool: SurfaceTool, points: Array[Vector3], normals: Array[Vector3]) -> void:
	for triangle: Array in [[0,1,2],[0,2,3]]:
		var order: Array=triangle.duplicate()
		if (points[order[1]]-points[order[0]]).cross(points[order[2]]-points[order[0]]).dot(normals[order[0]]+normals[order[1]]+normals[order[2]])>0:order.reverse()
		for index: int in order:
			tool.set_normal(normals[index]);tool.set_uv(Vector2(points[index].x,points[index].y));tool.add_vertex(points[index])

static func _triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	if (b-a).cross(c-a).length_squared()<1e-18: return
	var points: Array[Vector3] = [a,b,c]
	if (b-a).cross(c-a).dot(normal)>0: points.reverse()
	for p: Vector3 in points:
		tool.set_normal(normal)
		tool.set_uv(Vector2(p.x,p.y))
		tool.add_vertex(p)
