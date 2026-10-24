extends RefCounted
## Original shared reel, grip, continuous tube template and spray ribbon.
const Base = preload("res://ui/garage_wash_geometry.gd")
static var meshes: Dictionary = {}

static func _box(tool: SurfaceTool, at: Vector3, size: Vector3, rotation: Basis = Basis.IDENTITY) -> void:
	var box := BoxMesh.new()
	box.size = size
	Base._append(tool,box,Transform3D(rotation,at))

static func reel() -> ArrayMesh:
	if meshes.has("reel"): return meshes.reel
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z: float in [-0.19,0.19]:
		var rim := TorusMesh.new()
		rim.inner_radius = 0.30
		rim.outer_radius = 0.34
		rim.rings = 32
		rim.ring_segments = 8
		Base._append(tool,rim,Transform3D(Basis(Vector3.RIGHT,PI*0.5),Vector3(0,0.43,z)))
		for index: int in range(4):
			var angle: float = float(index)*PI*0.5
			_box(tool,Vector3(cos(angle)*0.16,0.43+sin(angle)*0.16,z),Vector3(0.29,0.028,0.025),Basis(Vector3.BACK,angle))
		_box(tool,Vector3(0,0.23,z),Vector3(0.045,0.45,0.045))
		_box(tool,Vector3(0,0.025,z),Vector3(0.62,0.05,0.09))
	_box(tool,Vector3(0,0.43,0),Vector3(0.10,0.10,0.52))
	_box(tool,Vector3(0.16,0.43,0.29),Vector3(0.30,0.035,0.035))
	_box(tool,Vector3(0.30,0.43,0.34),Vector3(0.055,0.055,0.13))
	tool.index()
	meshes.reel = tool.commit()
	return meshes.reel

static func coil() -> ArrayMesh:
	if meshes.has("coil"): return meshes.coil
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in range(6):
		var ring := TorusMesh.new()
		ring.inner_radius = 0.225
		ring.outer_radius = 0.278
		ring.rings = 32
		ring.ring_segments = 8
		Base._append(tool,ring,Transform3D(Basis(Vector3.RIGHT,PI*0.5),Vector3(0,0.43,-0.135+float(index)*0.054)))
	tool.index()
	meshes.coil = tool.commit()
	return meshes.coil

static func grip() -> ArrayMesh:
	if meshes.has("grip"): return meshes.grip
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(tool,Vector3(0,-0.07,0.045),Vector3(0.055,0.16,0.058),Basis(Vector3.RIGHT,-0.22))
	_box(tool,Vector3(0,-0.05,-0.018),Vector3(0.018,0.095,0.018),Basis(Vector3.RIGHT,0.28))
	tool.index()
	meshes.grip = tool.commit()
	return meshes.grip

static func cable() -> ArrayMesh:
	if meshes.has("cable"): return meshes.cable
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in range(48):
		for side: int in range(10):
			var points: Array[Vector3] = []
			var uv: Array[Vector2] = []
			for cell: Vector2i in [Vector2i(side,index),Vector2i(side+1,index),Vector2i(side+1,index+1),Vector2i(side,index+1)]:
				var angle: float = float(cell.x)*TAU/10.0
				points.append(Vector3(cos(angle)*0.025,float(cell.y)/48.0,sin(angle)*0.025))
				uv.append(Vector2(float(cell.x)/10.0,float(cell.y)/48.0))
			Base._face(tool,points,Vector3(cos(float(side)*TAU/10.0),0,sin(float(side)*TAU/10.0)),uv)
	tool.index()
	meshes.cable = tool.commit()
	return meshes.cable

static func ribbon() -> ArrayMesh:
	if meshes.has("ribbon"): return meshes.ribbon
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	Base._face(tool,[Vector3(-0.5,0,0),Vector3(0.5,0,0),Vector3(0.5,1,0),Vector3(-0.5,1,0)],Vector3.BACK,[Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN])
	meshes.ribbon = tool.commit()
	return meshes.ribbon

static func mist() -> ArrayMesh:
	if meshes.has("mist"): return meshes.mist
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for band: int in range(8):
		for side: int in range(32):
			var points: Array[Vector3] = []
			var uv: Array[Vector2] = []
			for cell: Vector2i in [Vector2i(side,band),Vector2i(side+1,band),Vector2i(side+1,band+1),Vector2i(side,band+1)]:
				var angle: float = float(cell.x)*TAU/32.0
				var along: float = float(cell.y)/8.0
				points.append(Vector3(cos(angle)*along,along,sin(angle)*along))
				uv.append(Vector2(float(cell.x)/32.0,along))
			Base._face(tool,points,Vector3(cos(float(side)*TAU/32.0),0,sin(float(side)*TAU/32.0)),uv)
	tool.index()
	meshes.mist = tool.commit()
	return meshes.mist
