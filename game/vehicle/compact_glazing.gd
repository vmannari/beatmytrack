extends RefCounted
## Rounded original glazing with a shared opaque dynamic sky reflection.
static var shared_glass: ShaderMaterial
static var sheets: Dictionary = {}
static var use_baked: bool = true

static func windshield_point(front: bool, u: float, v: float) -> Vector3:
	var height: float = lerpf(0.13,0.89,v)
	var lower_width: float = CompactCoachwork.cabin_width(0.13)*(0.90 if front else 0.83)
	var upper_width: float = CompactCoachwork.cabin_width(0.89)*(0.88 if front else 0.86)
	var across: float=u*lerpf(lower_width,upper_width,v)/CompactCoachwork.cabin_width(height)
	var point: Vector3 = CompactCoachwork.cabin_front_point(across,height) if front else CompactCoachwork.cabin_rear_point(across,height)
	var normal := Vector3(0,0.79,-0.61).normalized() if front else Vector3(0,0.84,0.54).normalized()
	# Only cross-car curvature: every vertical generator remains a straight line.
	return point+normal*(0.004+0.018*(1.0-u*u))

static func sheet(car: CarVisual, front: bool, trim: Material) -> void:
	if shared_glass == null:
		shared_glass = ShaderMaterial.new()
		shared_glass.shader = preload("res://vehicle/window_reflection.gdshader")
	var normal := Vector3(0,0.79,-0.61).normalized() if front else Vector3(0,0.84,0.54).normalized()
	for glass: bool in [false,true]:
		var key: String=("front" if front else "rear")+("_glass" if glass else "_seal")
		var path: String=CompactCoachwork.ASSET_ROOT.path_join(key+".res")
		if not sheets.has(key) and use_baked and ResourceLoader.exists(path):sheets[key]=load(path) as ArrayMesh
		if sheets.has(key):
			_attach_sheet(car,front,glass,sheets[key],trim)
			continue
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for row: int in range(20):
			for column: int in range(36):
				var uv: Array[Vector2] = [Vector2(column/36.0,row/20.0),Vector2((column+1)/36.0,row/20.0),Vector2((column+1)/36.0,(row+1)/20.0),Vector2(column/36.0,(row+1)/20.0)]
				var points: Array[Vector3] = []
				for t: Vector2 in uv: points.append(_sheet_point(front,t.x,t.y,glass))
				var order: Array[int]=[0,1,2,0,2,3]
				if (points[1]-points[0]).cross(points[2]-points[0]).dot(normal)>0: order=[0,2,1,0,3,2]
				for index: int in order:
					var t: Vector2=uv[index]
					var du: Vector3 = _sheet_point(front,minf(1,t.x+0.001),t.y,glass)-_sheet_point(front,maxf(0,t.x-0.001),t.y,glass)
					var dv: Vector3 = _sheet_point(front,t.x,minf(1,t.y+0.001),glass)-_sheet_point(front,t.x,maxf(0,t.y-0.001),glass)
					var n: Vector3=du.cross(dv).normalized()
					if n.dot(normal)<0:n=-n
					tool.set_normal(n)
					tool.set_uv(t)
					tool.add_vertex(points[index])
		tool.index()
		sheets[key]=tool.commit()
		_attach_sheet(car,front,glass,sheets[key],trim)

static func _attach_sheet(car: CarVisual,front: bool,glass: bool,resource: ArrayMesh,trim: Material) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name=("Front" if front else "Rear")+("GlassSheet" if glass else "GlazingSeal")
	mesh.mesh=resource
	mesh.material_override=shared_glass if glass else trim
	car.body.add_child(mesh)

static func _sheet_point(front: bool,u: float,v: float,glass: bool) -> Vector3:
	var edge: float = minf(v,1.0-v)
	var half_width: float=1.0
	if edge<0.07: half_width=0.93+0.07*sqrt(maxf(0,1.0-pow((edge-0.07)/0.07,2)))
	var across: float=lerpf(-half_width,half_width,u)
	var height: float=v
	if glass:
		across*=0.951 if front else 0.935
		height=lerpf(0.04,0.96,v) if front else lerpf(0.055,0.945,v)
	var point: Vector3=windshield_point(front,across,height)
	if glass: point+=Vector3(0,0.79,-0.61).normalized()*0.002 if front else Vector3(0,0.84,0.54).normalized()*0.002
	return point

static func window(car: CarVisual, corners: Array[Vector3], normal: Vector3, trim: Material, bow: float = 0.0, corner_radii: Array[float] = [], surround: Material = null, label: String = "Window") -> void:
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
	_surface(car,outline,center,normal,surround if surround != null else trim,0.0,false,label+"Seal")
	if surround != null:
		var seal: Array[Vector3] = []
		for point: Vector3 in outline:
			seal.append(center+(point-center)*0.977+normal.normalized()*0.003)
		_surface(car,seal,center+normal.normalized()*0.003,normal,trim,0.0,false,label+"InsetSeal")
	if shared_glass == null:
		shared_glass = ShaderMaterial.new()
		shared_glass.shader = preload("res://vehicle/window_reflection.gdshader")
	var inset: Array[Vector3] = []
	for point: Vector3 in outline:
		inset.append(center+(point-center)*0.947+normal.normalized()*0.006)
	_surface(car,inset,center+normal.normalized()*0.006,normal,shared_glass,bow,true,label+"Glass")

static func _surface(car: CarVisual, edge: Array[Vector3], center: Vector3, normal: Vector3, material: Material, bow: float, tinted: bool, label: String = "Window") -> void:
	normal = normal.normalized()
	if tinted and absf(normal.x) > 0.7:
		bow = maxf(bow,0.008)
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
	mesh.name=label
	mesh.mesh = tool.commit()
	mesh.material_override = material
	car.body.add_child(mesh)
