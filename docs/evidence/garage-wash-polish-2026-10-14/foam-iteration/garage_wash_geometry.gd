extends RefCounted
## Original closed microfiber mitt/cuff and a shallow lather surface; shared menu meshes.
static var meshes: Dictionary = {}

static func mitt() -> ArrayMesh:
	if meshes.has("mitt"): return meshes.mitt
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 32
	sphere.rings = 12
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centre := Vector3(0,0.027,-0.014)
	var axes := Vector3(0.083,0.027,0.117)
	_append(tool,sphere,Transform3D(Basis.from_scale(axes),centre))
	_append(tool,sphere,Transform3D(Basis(Vector3.UP,-0.38)*Basis.from_scale(Vector3(0.034,0.022,0.061)),Vector3(0.073,0.024,0.019)))
	# Closed tiny loops give the nap a soft real silhouette, without extra draws.
	for band: int in range(5):
		var latitude: float = 0.18 + float(band)*0.25
		for index: int in range(16):
			var angle: float = float(index)*TAU/16.0 + float(band)*0.19
			var n := Vector3(cos(angle)*cos(latitude),sin(latitude),sin(angle)*cos(latitude))
			var normal: Vector3 = (n/axes).normalized()
			var at: Vector3 = centre+n*axes
			var tangent: Vector3 = normal.cross(Vector3.FORWARD).normalized()
			var across: Vector3 = normal.cross(tangent)
			var bend: Vector3 = tangent*0.0012
			var tip: Vector3 = at+normal*(0.0035+float(index%3)*0.0007)+bend
			var ring: Array[Vector3] = []
			for side: int in range(3):
				var phase: float = float(side)*TAU/3.0
				ring.append(at+(tangent*cos(phase)+across*sin(phase))*0.0015)
			for side: int in range(3): _face(tool,[ring[side],ring[(side+1)%3],tip],(ring[side]+ring[(side+1)%3])*0.5-at,[Vector2.ZERO,Vector2.RIGHT,Vector2(0.5,1)])
			_face(tool,[ring[0],ring[2],ring[1]],-normal,[Vector2.ZERO,Vector2.RIGHT,Vector2.ONE])
	tool.index()
	meshes.mitt = tool.commit()
	return meshes.mitt

static func cuff() -> ArrayMesh:
	if meshes.has("cuff"): return meshes.cuff
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in range(40):
		var a: float = float(index)*TAU/40.0
		var b: float = float(index+1)*TAU/40.0
		var outer: Array[Vector3] = []
		var inner: Array[Vector3] = []
		for angle: float in [a,b]:
			var rib: float = 1.0+cos(angle*20.0)*0.022
			outer.append(Vector3(cos(angle)*0.065*rib,0.027+sin(angle)*0.021*rib,0.080))
			inner.append(Vector3(cos(angle)*0.058,0.027+sin(angle)*0.014,0.080))
		var span := Vector3(0,0,0.032)
		var radial := Vector3(cos((a+b)*0.5),sin((a+b)*0.5)*2.0,0).normalized()
		var uv: Array[Vector2] = [Vector2(float(index)/40.0,0),Vector2(float(index+1)/40.0,0),Vector2(float(index+1)/40.0,1),Vector2(float(index)/40.0,1)]
		_face(tool,[outer[0],outer[1],outer[1]+span,outer[0]+span],radial,uv)
		_face(tool,[inner[0],inner[1],inner[1]+span,inner[0]+span],-radial,uv)
		_face(tool,[inner[0],inner[1],outer[1],outer[0]],Vector3.FORWARD,uv)
		_face(tool,[inner[0]+span,inner[1]+span,outer[1]+span,outer[0]+span],Vector3.BACK,uv)
	tool.index()
	meshes.cuff = tool.commit()
	return meshes.cuff

static func lather() -> ArrayMesh:
	if meshes.has("lather"): return meshes.lather
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring: int in range(3):
		var inner: float = float(ring)/3.0
		var outer: float = float(ring+1)/3.0
		for index: int in range(24):
			var points: Array[Vector3] = []
			var uv: Array[Vector2] = []
			for polar: Vector2 in [Vector2(inner,index),Vector2(inner,index+1),Vector2(outer,index+1),Vector2(outer,index)]:
				var angle: float = polar.y*TAU/24.0
				var p := Vector2(cos(angle),sin(angle))*polar.x
				points.append(Vector3(p.x,(1.0-polar.x*polar.x)*0.045,p.y))
				uv.append(p*0.5+Vector2.ONE*0.5)
			_face(tool,points,Vector3.UP,uv)
	tool.index()
	meshes.lather = tool.commit()
	return meshes.lather

static func _append(tool: SurfaceTool, mesh: Mesh, pose: Transform3D) -> void:
	var arrays: Array = mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var inverse: Basis = pose.basis.inverse().transposed()
	for index: int in indices:
		tool.set_normal((inverse*normals[index]).normalized())
		tool.set_uv(uv[index])
		tool.add_vertex(pose*points[index])

static func _face(tool: SurfaceTool, points: Array[Vector3], outward: Vector3, uv: Array[Vector2]) -> void:
	var normal: Vector3 = outward.normalized()
	var reverse: bool = (points[1]-points[0]).cross(points[2]-points[0]).dot(normal) > 0.0
	for triangle: int in range(1,points.size()-1):
		for index: int in ([0,triangle+1,triangle] if reverse else [0,triangle,triangle+1]):
			tool.set_normal(normal)
			tool.set_uv(uv[index])
			tool.add_vertex(points[index])
