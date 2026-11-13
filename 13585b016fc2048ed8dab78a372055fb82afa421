extends RefCounted
## Original model-space surfaces. Immutable meshes are shared; finishes stay private.
const ASSET_ROOT: String = "res://assets/vehicles/hovercraft_sport_v4"
static var meshes: Dictionary = {}
static var use_baked: bool = true
static var source_signature: String = ""

static func signature() -> String:
	if source_signature.is_empty():
		source_signature = FileAccess.get_sha256("res://vehicle/hovercraft_model.gd")+FileAccess.get_sha256("res://vehicle/hovercraft_sport_surface.gd")+FileAccess.get_sha256("res://vehicle/hovercraft_sport_hull.gd")+FileAccess.get_sha256("res://vehicle/hovercraft_sport_drive.gd")
	return source_signature

static func _key(label: String, simple: bool) -> String:
	return ("race_" if simple else "full_")+label

static func _cached(key: String) -> ArrayMesh:
	if meshes.has(key): return meshes[key]
	var path: String = ASSET_ROOT.path_join(key+".res")
	if use_baked and ResourceLoader.exists(path):
		var saved: ArrayMesh = load(path)
		if not OS.has_feature("editor") or saved.get_meta("hovercraft_sources","") == signature():
			meshes[key] = saved
			return saved
	return null

static func instance(parent: Node3D, mesh: ArrayMesh, material: Material, label: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = material
	parent.add_child(node)
	return node

static func surface(parent: Node3D, label: String, columns: int, rows: int, point: Callable, hint: Callable, material: Material, simple: bool) -> MeshInstance3D:
	var key: String = _key(label,simple)
	var mesh: ArrayMesh = _cached(key)
	if mesh == null:
		mesh = ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,_arrays(columns,rows,point,hint))
		meshes[key] = mesh
	return instance(parent,mesh,material,label)

static func _arrays(columns: int, rows: int, point: Callable, hint: Callable) -> Array:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	for row: int in range(rows+1):
		for column: int in range(columns+1):
			var u: float = float(column)/columns
			var v: float = float(row)/rows
			var p: Vector3 = point.call(u,v)
			var du: Vector3 = point.call(u+0.0001,v)-point.call(u-0.0001,v)
			var dv: Vector3 = point.call(u,v+0.0001)-point.call(u,v-0.0001)
			var n: Vector3 = du.cross(dv).normalized()
			var expected: Vector3 = hint.call(u,v)
			if n.length_squared() < 0.5: n = expected.normalized()
			if n.dot(expected) < 0.0: n = -n
			vertices.append(p)
			normals.append(n)
			uv.append(Vector2(u,v))
	for row: int in range(rows):
		for column: int in range(columns):
			var a: int = row*(columns+1)+column
			for tri: Vector3i in [Vector3i(a,a+1,a+columns+2),Vector3i(a,a+columns+2,a+columns+1)]:
				var cross: Vector3 = (vertices[tri.y]-vertices[tri.x]).cross(vertices[tri.z]-vertices[tri.x])
				if cross.length_squared() < 1e-16: continue
				indices.append(tri.x)
				if cross.dot(normals[tri.x]+normals[tri.y]+normals[tri.z]) > 0.0:
					indices.append(tri.z); indices.append(tri.y)
				else:
					indices.append(tri.y); indices.append(tri.z)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays

static func rounded_box(parent: Node3D, label: String, size: Vector3, center: Vector3, radius: float, material: Material, simple: bool) -> MeshInstance3D:
	var key: String = _key(label,simple)
	var mesh: ArrayMesh = _cached(key)
	if mesh == null:
		var steps: int = 1 if simple else 2
		var columns: int = 2*steps+1
		var vertices := PackedVector3Array()
		var normals := PackedVector3Array()
		var uv := PackedVector2Array()
		var indices := PackedInt32Array()
		var half: Vector3 = size*0.5
		var inner: Vector3 = half-Vector3.ONE*radius
		for face: Array in [[Vector3.RIGHT,Vector3.UP,Vector3.BACK],[Vector3.LEFT,Vector3.UP,Vector3.FORWARD],[Vector3.UP,Vector3.BACK,Vector3.RIGHT],[Vector3.DOWN,Vector3.FORWARD,Vector3.RIGHT],[Vector3.BACK,Vector3.RIGHT,Vector3.UP],[Vector3.FORWARD,Vector3.LEFT,Vector3.UP]]:
			var n: Vector3 = face[0]
			var a: Vector3 = face[1]
			var b: Vector3 = face[2]
			var point: Callable = func(u: float,v: float) -> Vector3:
				var p: Vector3 = n*half+a*_bevel_coordinate(u,half.dot(a.abs()),radius,steps)+b*_bevel_coordinate(v,half.dot(b.abs()),radius,steps)
				var q: Vector3 = p.clamp(-inner,inner)
				return q+(p-q).normalized()*radius
			var arrays: Array = _arrays(columns,columns,point,func(_u: float,_v: float) -> Vector3: return n)
			var offset: int = vertices.size()
			vertices.append_array(arrays[Mesh.ARRAY_VERTEX])
			normals.append_array(arrays[Mesh.ARRAY_NORMAL])
			uv.append_array(arrays[Mesh.ARRAY_TEX_UV])
			for index: int in arrays[Mesh.ARRAY_INDEX]: indices.append(index+offset)
		var joined: Array = []
		joined.resize(Mesh.ARRAY_MAX)
		joined[Mesh.ARRAY_VERTEX] = vertices
		joined[Mesh.ARRAY_NORMAL] = normals
		joined[Mesh.ARRAY_TEX_UV] = uv
		joined[Mesh.ARRAY_INDEX] = indices
		mesh = ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,joined)
		meshes[key] = mesh
	var node: MeshInstance3D = instance(parent,mesh,material,label)
	node.position = center
	return node

static func _bevel_coordinate(u: float, half: float, radius: float, steps: int) -> float:
	var index: float = clampf(u,0.0,1.0)*(2*steps+1)
	if index <= steps: return -half+radius-radius*cos(index/steps*PI*0.5)
	if index >= steps+1: return half-radius+radius*sin((index-steps-1)/steps*PI*0.5)
	return lerpf(-half+radius,half-radius,index-steps)

static func tube(parent: Node3D, label: String, curve: Callable, radius: float, steps: int, material: Material, simple: bool) -> MeshInstance3D:
	var point: Callable = func(u: float,v: float) -> Vector3:
		var center: Vector3 = curve.call(u)
		var tangent: Vector3 = (curve.call(u+0.0001)-curve.call(u-0.0001)).normalized()
		var reference: Vector3 = Vector3.UP if absf(tangent.y) < 0.9 else Vector3.RIGHT
		var a: Vector3 = tangent.cross(reference).normalized()
		var b: Vector3 = tangent.cross(a).normalized()
		return center+(a*cos(v*TAU)+b*sin(v*TAU))*radius
	var hint: Callable = func(u: float,v: float) -> Vector3: return point.call(u,v)-curve.call(u)
	return surface(parent,label,steps,6 if simple else 8,point,hint,material,simple)

static func ring(parent: Node3D, label: String, center: Vector3, radius: float, thickness: float, material: Material, simple: bool) -> MeshInstance3D:
	return tube(parent,label,func(u: float) -> Vector3: return center+Vector3(sin(u*TAU),cos(u*TAU),0)*radius,thickness,40 if simple else 56,material,simple)

static func profile(points: Array[Vector2], t: float, closed: bool = false) -> Vector2:
	var count: int = points.size()
	var scaled: float = t*(count if closed else count-1)
	var index: int = floori(scaled)
	var f: float = scaled-index
	var p: Array[Vector2] = []
	for offset: int in [-1,0,1,2]:
		p.append(points[posmod(index+offset,count) if closed else clampi(index+offset,0,count-1)])
	return 0.5*((2.0*p[1])+(-p[0]+p[2])*f+(2.0*p[0]-5.0*p[1]+4.0*p[2]-p[3])*f*f+(-p[0]+3.0*p[1]-3.0*p[2]+p[3])*f*f*f)

static func monotone_profile(points: Array[Vector2],t: float) -> Vector2:
	# Shape-preserving Hermite interpolation prevents a rolled lip crossing its deck.
	var last: int = points.size()-1
	var scaled: float = t*last
	if scaled < 0.0: return points[0]+(points[1]-points[0])*scaled
	if scaled > last: return points[last]+(points[last]-points[last-1])*(scaled-last)
	var index: int = mini(floori(scaled),last-1)
	var f: float = scaled-index
	var a: Vector2 = points[index]
	var b: Vector2 = points[index+1]
	var delta: Vector2 = b-a
	var previous: Vector2 = a-points[maxi(0,index-1)] if index > 0 else delta
	var following: Vector2 = points[mini(last,index+2)]-b if index+1 < last else delta
	var da := Vector2(_slope(previous.x,delta.x),_slope(previous.y,delta.y))
	var db := Vector2(_slope(delta.x,following.x),_slope(delta.y,following.y))
	return (2*f*f*f-3*f*f+1)*a+(f*f*f-2*f*f+f)*da+(-2*f*f*f+3*f*f)*b+(f*f*f-f*f)*db

static func _slope(a: float,b: float) -> float:
	return 2.0*a*b/(a+b) if a*b > 0.0 else 0.0
