extends RefCounted
## Original fitted hardware. Immutable meshes share the kart's offline bake/cache.
const G = preload("res://vehicle/kart_geometry.gd")

static func _triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	tool.set_normal(normal)
	tool.set_uv(Vector2.ZERO)
	if (b-a).cross(c-a).dot(normal) > 0:
		tool.add_vertex(c); tool.add_vertex(b); tool.add_vertex(a)
	else:
		tool.add_vertex(a); tool.add_vertex(b); tool.add_vertex(c)

static func plate(parent: Node3D, label: String, center: Vector3, size: Vector3, radius: float, material: Material) -> MeshInstance3D:
	# Thin machined plates need a bevel at the perimeter, not a dense six-face grid.
	var node: MeshInstance3D = G.attach(parent,label+"|bevel-plate-v1|"+str(size)+"|"+str(radius),material,func() -> ArrayMesh:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var bevel: float = minf(size.y*0.23,radius*0.5)
		var rings: Array[PackedVector3Array] = []
		for layer: int in range(4):
			var inset: float = bevel if layer in [0,3] else 0.0
			var y: float = [-size.y*0.5,-size.y*0.5+bevel,size.y*0.5-bevel,size.y*0.5][layer]
			var x: float = size.x*0.5-inset
			var z: float = size.z*0.5-inset
			var r: float = maxf(0.0001,radius-inset)
			var ring := PackedVector3Array()
			for point: Vector2 in [Vector2(-x+r,-z),Vector2(x-r,-z),Vector2(x,-z+r),Vector2(x,z-r),Vector2(x-r,z),Vector2(-x+r,z),Vector2(-x,z-r),Vector2(-x,-z+r)]:
				ring.append(Vector3(point.x,y,point.y))
			rings.append(ring)
		for layer: int in range(3):
			for index: int in range(8):
				var next: int = (index+1)%8
				var a: Vector3 = rings[layer][index]
				var b: Vector3 = rings[layer][next]
				var c: Vector3 = rings[layer+1][next]
				var normal: Vector3 = (b-a).cross(c-a).normalized()
				var expected := Vector3((a+b).x,0,(a+b).z)
				if normal.dot(expected)<0: normal = -normal
				_triangle(tool,a,b,c,normal)
				_triangle(tool,a,c,rings[layer+1][index],normal)
		for layer: int in [0,3]:
			for index: int in range(1,7):
				_triangle(tool,rings[layer][0],rings[layer][index],rings[layer][index+1],Vector3.DOWN if layer==0 else Vector3.UP)
		tool.index()
		return tool.commit())
	node.position = center
	return node

static func fastener(parent: Node3D, label: String, center: Vector3, normal: Vector3, radius: float, material: Material) -> void:
	var node: MeshInstance3D = G.attach(parent,label+"|socket-v1|"+str(radius),material,func() -> ArrayMesh:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		# Washer, chamfered hex head and a real recessed hex socket, all one solid mesh.
		var rings: Array[PackedVector3Array] = []
		for section: Vector2 in [Vector2(radius,0),Vector2(radius,0.0015),Vector2(radius*0.72,0.002),Vector2(radius*0.67,0.005),Vector2(radius*0.30,0.005),Vector2(radius*0.30,0.0025)]:
			var ring := PackedVector3Array()
			for corner: int in range(6):
				var angle: float = TAU*corner/6
				ring.append(Vector3(cos(angle)*section.x,section.y,sin(angle)*section.x))
			rings.append(ring)
		for row: int in range(rings.size()-1):
			for index: int in range(6):
				var next: int = (index+1)%6
				var a: Vector3 = rings[row][index]
				var b: Vector3 = rings[row][next]
				var c: Vector3 = rings[row+1][next]
				var n: Vector3 = (c-a).cross(b-a).normalized()
				_triangle(tool,a,b,c,n)
				_triangle(tool,a,c,rings[row+1][index],n)
		for row: int in [0,rings.size()-1]:
			for index: int in range(1,5):
				_triangle(tool,rings[row][0],rings[row][index],rings[row][index+1],Vector3.DOWN if row==0 else Vector3.UP)
		tool.index()
		return tool.commit())
	node.position = center
	node.quaternion = Quaternion(Vector3.UP,normal.normalized())

static func _shell_fasteners(shell: MeshInstance3D, label: String, locations: Array[Vector2], material: Material, simple: bool) -> void:
	# The hit is evaluated only on a cache miss/bake. Both LODs fit their actual skin.
	G.attach(shell,label+"|fitted-v1|"+str(locations)+("|simple" if simple else "|full"),material,func() -> ArrayMesh:
		var triangles: TriangleMesh = shell.mesh.generate_triangle_mesh()
		var carrier := Node3D.new()
		for location: Vector2 in locations:
			var hit: Dictionary = triangles.intersect_ray(Vector3(location.x,2,location.y),Vector3.DOWN)
			assert(not hit.is_empty(),"Kart fairing fastener requires actual bodywork backing")
			fastener(carrier,"FairingSocket",hit.position+hit.normal*0.0003,hit.normal,0.010,material)
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part: MeshInstance3D in carrier.get_children(): tool.append_from(part.mesh,0,part.transform)
		carrier.free()
		return tool.commit())

static func collar(parent: Node3D, label: String, center: Vector3, width: float, radius: float, material: Material, simple: bool) -> void:
	var profile: Array[Vector2] = [Vector2(-width*0.5,0.027),Vector2(-width*0.5,radius),Vector2(width*0.5,radius),Vector2(width*0.5,0.027),Vector2(-width*0.5,0.027)]
	var node: MeshInstance3D = G.attach(parent,label+"|collar-v1|"+str(profile)+("|simple" if simple else "|full"),material,func() -> ArrayMesh:
		return G.surface(16 if simple else 24,4,func(u: float,v: float) -> Vector3:
			var at: float = v*4
			var row: int = mini(int(at),3)
			var point: Vector2 = profile[row].lerp(profile[row+1],at-row)
			return Vector3(point.x,sin(u*TAU)*point.y,cos(u*TAU)*point.y),func(u: float,v: float) -> Vector3:
			var row: int = mini(int(v*4),3)
			var d: Vector2 = profile[row+1]-profile[row]
			return Vector3(-d.y,d.x*sin(u*TAU),d.x*cos(u*TAU))))
	node.position = center

static func body(car: CarVisual, trim: Material, metal: Material) -> void:
	var simple: bool = car.simple_model
	_shell_fasteners(car.body.find_child("SculptedFrontFairing",true,false),"NosePanelSockets",[Vector2(-0.46,-1.29),Vector2(0.46,-1.29)],metal,simple)
	_shell_fasteners(car.body.find_child("NassauFairing",true,false),"FairingPanelSockets",[Vector2(-0.125,-0.65),Vector2(0.125,-0.65)],metal,simple)
	# Outboard rub strip follows the real pod; its inset ends avoid floating corners.
	for pod: Node in car.body.get_children():
		if pod is not Node3D or absf(pod.position.x)<0.5: continue
		var shell: MeshInstance3D = pod.find_child("FormedSidePod",true,false)
		if shell==null: continue
		_shell_fasteners(shell,"PodPanelSockets",[Vector2(0,-0.43),Vector2(0,0.29)],metal,simple)
		var side: float = signf(pod.position.x)
		var strip: Array[Vector3] = []
		var profile: Array[Vector4] = [Vector4(-0.60,0.075,0.28,0.045),Vector4(-0.48,0.155,0.28,0.095),Vector4(-0.12,0.160,0.29,0.105),Vector4(0.34,0.147,0.275,0.09),Vector4(0.49,0.10,0.25,0.05)]
		for step: int in range(13):
			var station: Vector4 = G.loft_station(profile,lerpf(0.14,0.86,step/12.0))
			strip.append(Vector3(side*(station.y+0.001),station.z,station.x))
		G.tube(pod,"PodRubStrip",strip,0.008,trim,simple,16)
	# Folded fairing brackets join the chassis instead of leaving a floating cover.
	for side: float in [-1.0,1.0]:
		G.tube(car.body,"FairingChassisBracket",[Vector3(side*0.18,0.17,-0.88),Vector3(side*0.13,0.34,-0.77),Vector3(side*0.10,0.465,-0.74)],0.009,metal,simple,8)

static func mechanical(car: CarVisual, trim: Material, metal: Material, bright: Material) -> void:
	var p: Node3D = car.body
	var simple: bool = car.simple_model
	var cast := CompactFinish.alloy(Color("535b5b"))
	cast.roughness = 0.62
	# Paired steering rods, central bellcrank and small rod-end collars.
	plate(p,"SteeringBellcrank",Vector3(0,0.232,-0.79),Vector3(0.09,0.012,0.10),0.012,cast)
	for side: float in [-1.0,1.0]:
		G.tube(p,"SteeringTieRod",[Vector3(side*0.025,0.235,-0.81),Vector3(side*0.25,0.225,-0.87),Vector3(side*0.48,0.22,-0.89)],0.007,metal,simple,8)
		fastener(p,"TieRodPivot",Vector3(side*0.025,0.24,-0.81),Vector3.UP,0.009,bright)
		# Split pillow blocks visibly support the live axle on the existing rails.
		plate(p,"RearBearingFoot",Vector3(side*0.425,0.177,0.88),Vector3(0.11,0.018,0.15),0.012,cast)
		collar(p,"AxleBearingCarrier",Vector3(side*0.425,0.22,0.88),0.056,0.056,cast,simple)
		for z: float in [0.825,0.935]: fastener(p,"BearingFootSocket",Vector3(side*0.425,0.188,z),Vector3.UP,0.008,bright)
	# The airbox reads as a fitted two-piece moulding, with clips and inlet grille.
	var airbox: MeshInstance3D = p.find_child("Airbox",true,false)
	G.attach(p,"AirboxPartingSeal|fitted-v1"+("|simple" if simple else "|full"),metal,func() -> ArrayMesh:
		var triangles: TriangleMesh = airbox.mesh.generate_triangle_mesh()
		var seam: Array[Vector3] = []
		for step: int in range(49):
			var a: float = TAU*step/48
			var direction := Vector3(cos(a),0,sin(a))
			var hit: Dictionary = triangles.intersect_ray(direction*0.3,-direction)
			assert(not hit.is_empty())
			seam.append(airbox.position+hit.position+hit.normal*0.001)
		var carrier := Node3D.new()
		G.tube(carrier,"AirboxSealTube",seam,0.003,metal,simple,48)
		var result: ArrayMesh = carrier.get_child(0).mesh
		carrier.free()
		return result)
	for z: float in [0.32,0.46]:
		var clip: MeshInstance3D = plate(p,"AirboxSpringClip",Vector3(0.668,0.45,z),Vector3(0.018,0.006,0.033),0.004,metal)
		clip.rotation.z = PI*0.5
	# Mounting hat distinguishes the machined rotor from its live axle.
	collar(p,"BrakeRotorHat",Vector3(-0.34,0.22,0.88),0.024,0.056,cast,simple)
