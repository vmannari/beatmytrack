extends RefCounted
## Rounded original glazing with a shared opaque dynamic sky reflection.
static var shared_glass: ShaderMaterial

static func window(car: CarVisual, corners: Array[Vector3], normal: Vector3, trim: Material, bow: float = 0.0, corner_radii: Array[float] = [], surround: Material = null) -> void:
	var center := Vector3.ZERO
	for point: Vector3 in corners: center += point*0.25
	var outline: Array[Vector3] = []
	for i: int in range(4):
		var corner: Vector3 = corners[i]
		var radius: float = corner_radii[i] if corner_radii.size() == 4 else 0.065
		var start: Vector3 = corner.move_toward(corners[(i+3)%4],radius)
		var end: Vector3 = corner.move_toward(corners[(i+1)%4],radius)
		for step: int in range(6):
			var t: float = step/5.0
			outline.append(start.lerp(corner,t).lerp(corner.lerp(end,t),t))
	if bow > 0.0:
		# Sample the long edges too: bowing only the interior leaves a straight
		# silhouette from overhead. Curve both the seal and glass boundary.
		var curved: Array[Vector3] = []
		var half_width: float = maxf(absf(corners[0].x),absf(corners[1].x))
		var down_slope: Vector3 = (corners[0]-corners[3]).normalized()
		for i: int in range(outline.size()):
			var start: Vector3 = outline[i]
			var end: Vector3 = outline[(i+1)%outline.size()]
			var steps: int = maxi(1,int(ceil(start.distance_to(end)/0.10)))
			for step: int in range(steps):
				var point: Vector3 = start.lerp(end,float(step)/steps)
				var crown: float = maxf(0.0,1.0-pow(point.x/half_width,2.0))
				point += (normal.normalized()*0.35+down_slope*0.75)*bow*crown
				curved.append(point)
		outline = curved
		center += (normal.normalized()*0.35+down_slope*0.75)*bow
	_surface(car,outline,center,normal,surround if surround != null else trim,0.0,false)
	if surround != null:
		var seal: Array[Vector3] = []
		for point: Vector3 in outline:
			seal.append(center+(point-center)*0.977+normal.normalized()*0.003)
		_surface(car,seal,center+normal.normalized()*0.003,normal,trim,0.0,false)
	if shared_glass == null:
		shared_glass = ShaderMaterial.new()
		shared_glass.shader = preload("res://vehicle/window_reflection.gdshader")
	var inset: Array[Vector3] = []
	for point: Vector3 in outline:
		inset.append(center+(point-center)*0.947+normal.normalized()*0.006)
	_surface(car,inset,center+normal.normalized()*0.006,normal,shared_glass,bow,true)

static func _surface(car: CarVisual, edge: Array[Vector3], center: Vector3, normal: Vector3, material: Material, bow: float, tinted: bool) -> void:
	normal = normal.normalized()
	if tinted and absf(normal.x) > 0.7:
		bow = maxf(bow,0.055)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: int = 5 if bow > 0.0 else 1
	for ring: int in range(rings):
		var r0: float = float(ring)/rings
		var r1: float = float(ring+1)/rings
		for i: int in range(edge.size()):
			var j: int = (i+1)%edge.size()
			var points: Array[Vector3] = [center.lerp(edge[i],r0),center.lerp(edge[j],r0),center.lerp(edge[j],r1),center.lerp(edge[i],r1)]
			points[0] += normal*bow*(1.0-r0*r0)
			points[1] += normal*bow*(1.0-r0*r0)
			points[2] += normal*bow*(1.0-r1*r1)
			points[3] += normal*bow*(1.0-r1*r1)
			for triangle: Array in [[0,1,2],[0,2,3]]:
				if (points[triangle[1]]-points[triangle[0]]).cross(points[triangle[2]]-points[triangle[0]]).dot(normal) > 0:
					triangle.reverse()
				for index: int in triangle:
					var delta: Vector3 = points[index]-center
					tool.set_normal((normal+delta*bow*3.0).normalized())
					if tinted:
						var reflection: float = smoothstep(-0.13,0.12,delta.y+delta.x*0.28)
						tool.set_color(Color("1c3038").lerp(Color("415d69"),reflection*0.65))
					tool.add_vertex(points[index])
	var mesh := MeshInstance3D.new()
	mesh.mesh = tool.commit()
	mesh.material_override = material
	car.body.add_child(mesh)
