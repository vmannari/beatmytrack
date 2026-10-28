extends RefCounted
## Original kart surfaces in model metres; immutable full/racing meshes.
const ROOT: String = "res://assets/vehicles/kart_refined_v1"
static var meshes: Dictionary = {}
static var use_baked: bool = true

static func attach(parent: Node3D, key: String, material: Material, create: Callable) -> MeshInstance3D:
	if not meshes.has(key):
		var path: String = ROOT.path_join(key.sha256_text().left(24)+".res")
		meshes[key] = load(path) if use_baked and ResourceLoader.exists(path) else create.call()
	var node := MeshInstance3D.new()
	node.name = key.get_slice("|",0)
	node.mesh = meshes[key]
	node.material_override = material
	parent.add_child(node)
	return node

static func surface(columns: int, rows: int, sample: Callable, outward: Callable) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	for row: int in range(rows+1):
		for col: int in range(columns+1):
			var u: float = float(col)/columns
			var v: float = float(row)/rows
			var point: Vector3 = sample.call(u,v)
			var du: Vector3 = sample.call(minf(1,u+0.0001),v)-sample.call(maxf(0,u-0.0001),v)
			var dv: Vector3 = sample.call(u,minf(1,v+0.0001))-sample.call(u,maxf(0,v-0.0001))
			var expected: Vector3 = outward.call(u,v)
			var normal: Vector3 = du.cross(dv).normalized()
			if normal.length_squared() < 0.5: normal = expected.normalized()
			if normal.dot(expected) < 0: normal = -normal
			vertices.append(point)
			normals.append(normal)
			uv.append(Vector2(u,v))
	for row: int in range(rows):
		for col: int in range(columns):
			var a: int = row*(columns+1)+col
			for triangle: Array in [[a,a+1,a+columns+2],[a,a+columns+2,a+columns+1]]:
				var face: Vector3 = (vertices[triangle[1]]-vertices[triangle[0]]).cross(vertices[triangle[2]]-vertices[triangle[0]])
				if face.length_squared() < 1e-20: continue
				if face.dot(normals[triangle[0]]+normals[triangle[1]]+normals[triangle[2]]) > 0: triangle.reverse()
				for index: int in triangle: indices.append(index)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

static func patch(parent: Node3D, key: String, columns: int, rows: int, sample: Callable, outward: Callable, material: Material, simple: bool) -> MeshInstance3D:
	return attach(parent,key+("|simple" if simple else "|full"),material,func() -> ArrayMesh:
		return surface(maxi(4,columns/2) if simple else columns,maxi(2,rows/2) if simple else rows,sample,outward))

static func curve(points: Array, t: float) -> Variant:
	var at: float = clampf(t,0,1)*(points.size()-1)
	var i: int = mini(int(at),points.size()-2)
	return points[i].cubic_interpolate(points[i+1],points[maxi(0,i-1)],points[mini(points.size()-1,i+2)],at-i)

static func tube(parent: Node3D, label: String, points: Array[Vector3], radius: float, material: Material, simple: bool, segments: int = 32) -> void:
	var key: String = label+"|"+str(points)+"|"+str(radius)
	var radial := func(u: float,v: float) -> Vector3:
		var tangent: Vector3 = (curve(points,minf(1,v+0.0001))-curve(points,maxf(0,v-0.0001))).normalized()
		var axis: Vector3 = tangent.cross(Vector3.UP if absf(tangent.y)<0.95 else Vector3.RIGHT).normalized()
		return axis*cos(u*TAU)+tangent.cross(axis)*sin(u*TAU)
	patch(parent,key,8 if radius < 0.018 else 12,segments,func(u: float,v: float) -> Vector3:
		return curve(points,v)+radial.call(u,v)*radius,radial,material,simple)

static func ellipsoid(parent: Node3D, label: String, center: Vector3, radii: Vector3, material: Material, simple: bool) -> MeshInstance3D:
	var small: bool = radii.length() < 0.045
	var medium: bool = radii.length() < 0.13
	var node: MeshInstance3D = patch(parent,label+"|"+str(radii),12 if small else 20 if medium else 32,8 if small else 12 if medium else 20,func(u: float,v: float) -> Vector3:
		return Vector3(sin(v*PI)*sin(u*TAU),cos(v*PI),sin(v*PI)*cos(u*TAU))*radii,
		func(u: float,v: float) -> Vector3: return Vector3(sin(v*PI)*sin(u*TAU),cos(v*PI),sin(v*PI)*cos(u*TAU))/radii,material,simple)
	node.position = center
	return node

static func rounded(parent: Node3D, label: String, center: Vector3, size: Vector3, radius: float, material: Material, simple: bool) -> MeshInstance3D:
	var key: String = label+"|"+str(size)+"|"+str(radius)+( "|simple" if simple else "|full")
	var node: MeshInstance3D = attach(parent,key,material,func() -> ArrayMesh:
		var tool := SurfaceTool.new()
		for face: int in range(6):
			var normal: Vector3 = [Vector3.RIGHT,Vector3.LEFT,Vector3.UP,Vector3.DOWN,Vector3.BACK,Vector3.FORWARD][face]
			var right: Vector3 = normal.cross(Vector3.UP if absf(normal.y)<0.5 else Vector3.BACK)
			var up: Vector3 = normal.cross(right)
			var inner: Vector3 = size*0.5-Vector3.ONE*radius
			var sample := func(u: float,v: float) -> Vector3:
				var p: Vector3 = (normal+right*lerpf(-1,1,u)+up*lerpf(-1,1,v))*size*0.5
				var base: Vector3 = p.clamp(-inner,inner)
				return base+(p-base).normalized()*radius
			var resolution: int = 4 if size.length() < 0.11 else 6
			if simple: resolution = 3
			var mesh: ArrayMesh = surface(resolution,resolution,sample,func(_u: float,_v: float) -> Vector3: return normal)
			tool.append_from(mesh,0,Transform3D.IDENTITY)
		return tool.commit())
	node.position = center
	return node

static func loft(parent: Node3D, label: String, sections: Array[Vector4], material: Material, simple: bool, exponent: float = 0.65) -> void:
	# Monotone longitudinal stations and explicit end caps avoid folded tips.
	var key: String = label+"|"+str(sections)+str(exponent)+("|simple" if simple else "|full")
	attach(parent,key,material,func() -> ArrayMesh:
		var sample := func(u: float,v: float) -> Vector3:
			var p: Vector4 = loft_station(sections,v)
			return Vector3(signf(sin(u*TAU))*pow(absf(sin(u*TAU)),exponent)*p.y,p.z+signf(cos(u*TAU))*pow(absf(cos(u*TAU)),exponent)*p.w,p.x)
		var tool := SurfaceTool.new()
		tool.append_from(surface(24 if simple else 48,(sections.size()-1)*(2 if simple else 4),sample,func(u: float,_v: float) -> Vector3: return Vector3(sin(u*TAU),cos(u*TAU),0)),0,Transform3D.IDENTITY)
		for end: float in [0.0,1.0]:
			var station: Vector4 = loft_station(sections,end)
			var center := Vector3(0,station.z,station.x)
			var cap: ArrayMesh = surface(24 if simple else 48,1,func(u: float,v: float) -> Vector3:
				return center.lerp(sample.call(u,end),v),func(_u: float,_v: float) -> Vector3: return Vector3(0,0,-1 if end==0 else 1))
			tool.append_from(cap,0,Transform3D.IDENTITY)
		return tool.commit())

static func loft_station(profile: Array[Vector4], t: float) -> Vector4:
	var at: float = clampf(t,0,1)*(profile.size()-1)
	var i: int = mini(int(at),profile.size()-2)
	var a: Vector4 = profile[i]
	var b: Vector4 = profile[i+1]
	var p: Vector4 = profile[maxi(0,i-1)]
	var q: Vector4 = profile[mini(profile.size()-1,i+2)]
	var f: float = at-i
	var result: Vector4 = 0.5*((2*a)+(-p+b)*f+(2*p-5*a+4*b-q)*f*f+(-p+3*a-3*b+q)*f*f*f)
	result.x = lerpf(a.x,b.x,f)
	result.y = maxf(0.001,result.y)
	result.w = maxf(0.001,result.w)
	return result

static func loft_top(profile: Array[Vector4], x: float, t: float, exponent: float = 0.65) -> Vector3:
	var p: Vector4 = loft_station(profile,t)
	return Vector3(x,p.z+p.w*pow(maxf(0,1-pow(absf(x)/p.y,2/exponent)),exponent*0.5)+0.0015,p.x)

static func lathe(parent: Node3D, label: String, profile: Array[Vector2], material: Material, simple: bool) -> MeshInstance3D:
	var sample := func(u: float,v: float) -> Vector3:
		var at: float = v*(profile.size()-1)
		var row: int = mini(int(at),profile.size()-2)
		var p: Vector2 = profile[row].lerp(profile[row+1],at-row)
		return Vector3(p.x,sin(u*TAU)*p.y,cos(u*TAU)*p.y)
	var outward := func(u: float,v: float) -> Vector3:
		var at: float = v*(profile.size()-1)
		var row: int = mini(int(at),profile.size()-2)
		var d: Vector2 = profile[row+1]-profile[row]
		return Vector3(-d.y,d.x*sin(u*TAU),d.x*cos(u*TAU))
	return attach(parent,label+"|"+str(profile)+("|simple" if simple else "|full"),material,func() -> ArrayMesh:
		return surface(32 if simple else 64,profile.size()-1,sample,outward))
