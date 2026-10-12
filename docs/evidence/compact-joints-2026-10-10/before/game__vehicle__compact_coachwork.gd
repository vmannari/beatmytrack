class_name CompactCoachwork
extends RefCounted
## Original fictional compact surfaces. Model metres, independent of collision.
## Editable analytical patches with authored UV atlas regions and smooth normals.
static var meshes: Dictionary = {}
static var use_baked: bool = true
const ASSET_ROOT: String = "res://assets/vehicles/compact_coachwork_v1"

static func build_body(car: CarVisual, paint: Material) -> void:
	for side: float in [-1.0,1.0]:
		_patch(car,"CurvedBody",96,14,func(u: float,v: float) -> Vector3:
			var z: float = lerpf(-2.08,2.03,u)
			var end: float = smoothstep(1.79,2.09,absf(z))
			var lower: float = 0.33
			for axle: float in [-1.28,1.28]:
				var offset: float = absf(z-axle)
				if offset < 0.421: lower = maxf(lower,0.37+sqrt(0.421*0.421-offset*offset))
			var upper: float = 1.02-end*0.045
			if z < -1.03:
				upper = lerpf(0.976,1.048,clampf((z+2.045)/1.03,0,1))
			elif z < -0.95:
				upper = lerpf(1.048,1.02,smoothstep(-1.03,-0.95,z))
			var y: float = lerpf(lower,upper,v)
			var width: float = body_width(y,z)
			return Vector3(side*width,y,z),paint,Vector3(side,0.1,0),Rect2(0 if side < 0 else 0.25,0,0.25,1))
	# Sealed black underside remains visible only during rollover.
	VisualGeometry.box(car.body,Vector3(1.56,0.055,3.98),Vector3(0,0.34,0),car.underside_material)
	# Close the rear below the hatch; front fascia is authored by CompactDetail.
	_patch(car,"RearCoachwork",32,12,func(u: float,v: float) -> Vector3:
		var x: float = lerpf(-0.73,0.73,u)
		var y: float = lerpf(0.35,1.01,v)
		return Vector3(x,y,CompactDetail._rear_skin(x,y)),paint,Vector3.BACK,Rect2(0.5,0.85,0.25,0.15))

static func body_width(y: float, z: float) -> float:
	return 0.88+0.012*sin(clampf((y-0.33)/0.53,0,1)*PI)-0.12*smoothstep(0.85,1.02,y)-smoothstep(1.79,2.09,absf(z))*0.13

static func build_arch(car: CarVisual, side: float, axle: float, paint: Material, rubber: Material) -> void:
	var bulge: float = 0.070 if axle > 0 else 0.055
	_patch(car,"RolledWheelArchFront" if axle < 0 else "RolledWheelArchRear",56,10,func(u: float,v: float) -> Vector3:
		var angle: float = u*PI
		var radius: float = lerpf(0.405,0.55,v)
		var y: float = 0.37+sin(angle)*radius
		var z: float = axle+cos(angle)*radius
		var width: float = body_width(y,z)+bulge*pow(1.0-v,2)+0.009
		return Vector3(side*width,y,z),paint,Vector3(side,0.1,0),Rect2(0 if side < 0 else 0.25,0.4,0.25,0.2))
	_patch(car,"ArchRubberSealFront" if axle < 0 else "ArchRubberSealRear",56,2,func(u: float,v: float) -> Vector3:
		var angle: float = u*PI
		var radius: float = lerpf(0.392,0.405,v)
		var y: float = 0.37+sin(angle)*radius
		var z: float = axle+cos(angle)*radius
		return Vector3(side*(body_width(y,z)+bulge+0.011),y,z),rubber,Vector3(side,0.1,0),Rect2(0,0,1,1))

static func hood_point(u: float,v: float) -> Vector3:
	var x: float = u*lerpf(0.755,0.76,v)
	var z: float = lerpf(CompactDetail._nose_z(x),-1.015,v)
	var y: float = lerpf(0.976,1.048,v) + (1.0-u*u)*(0.010+0.018*sin(v*PI))
	return Vector3(x,y,z)

static func build_hood(car: CarVisual, paint: Material, accent: Material) -> void:
	_patch(car,"CrownedHood",40,24,func(u: float,v: float) -> Vector3:
		return hood_point(lerpf(-1,1,u),v),paint,Vector3.UP,Rect2(0.5,0,0.25,0.5))
	_patch(car,"HoodAccent",36,24,func(u: float,v: float) -> Vector3:
		return hood_point(lerpf(-0.82,0.82,u),v)+Vector3.UP*0.0015,accent,Vector3.UP,Rect2(0.5,0,0.25,0.5))
	var trim: Material = VisualGeometry.material(Color("263039"))
	for side: float in [-1,1]:
		for segment: int in range(24):
			var a: Vector3 = hood_point(side*0.83,segment/24.0)+Vector3.UP*0.003
			var b: Vector3 = hood_point(side*0.83,(segment+1)/24.0)+Vector3.UP*0.003
			car._seam(car.body,a,b,0.005,trim)

static func roof_point(u: float,v: float) -> Vector3:
	var x: float = u*0.63
	var z: float = lerpf(-0.4,1.18,v)
	var roll: float = pow(maxf(0,1.0-pow(absf(u),8)),0.7)
	var y: float = 1.48 + 0.033*roll*(0.75+0.25*sin(v*PI))
	return Vector3(x,y,z)

static func build_roof(car: CarVisual, accent: Material) -> void:
	_patch(car,"RolledRoof",40,32,func(u: float,v: float) -> Vector3:
		return roof_point(lerpf(-1,1,u),v),accent,Vector3.UP,Rect2(0.75,0,0.25,0.5))

static func _patch(car: CarVisual, label: String, columns: int, rows: int, sample: Callable, surface: Material, normal_hint: Vector3, uv_region: Rect2) -> void:
	var key: String = label.to_snake_case()+ ("_left" if normal_hint.x < 0 else "_right" if normal_hint.x > 0 else "")
	if not meshes.has(key) and use_baked and ResourceLoader.exists(ASSET_ROOT.path_join(key+".res")):
		meshes[key] = load(ASSET_ROOT.path_join(key+".res")) as ArrayMesh
	if meshes.has(key):
		_attach(car,label,meshes[key],surface)
		return
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row: int in range(rows):
		for column: int in range(columns):
			var uv: Array[Vector2] = [Vector2(float(column)/columns,float(row)/rows),Vector2(float(column+1)/columns,float(row)/rows),Vector2(float(column+1)/columns,float(row+1)/rows),Vector2(float(column)/columns,float(row+1)/rows)]
			var points: Array[Vector3] = []
			for t: Vector2 in uv: points.append(sample.call(t.x,t.y))
			var order: Array[int] = [0,1,2,0,2,3]
			if (points[1]-points[0]).cross(points[2]-points[0]).dot(normal_hint)>0: order=[0,2,1,0,3,2]
			for index: int in order:
				var t: Vector2 = uv[index]
				var du: Vector3 = sample.call(minf(1,t.x+0.001),t.y)-sample.call(maxf(0,t.x-0.001),t.y)
				var dv: Vector3 = sample.call(t.x,minf(1,t.y+0.001))-sample.call(t.x,maxf(0,t.y-0.001))
				var normal: Vector3 = du.cross(dv).normalized()
				if normal.dot(normal_hint)<0: normal=-normal
				tool.set_normal(normal)
				var mapped: Vector2 = uv_region.position+t*uv_region.size
				if normal_hint.x != 0.0:
					# The body and arch overlays share the same world-projected atlas.
					mapped = Vector2((0.0 if normal_hint.x < 0 else 0.25)+(points[index].z+2.08)/4.11*0.25,(points[index].y-0.33)/0.75)
				elif label in ["CrownedHood","HoodAccent"]:
					mapped.x = 0.5+(points[index].x/lerpf(0.755,0.76,t.y)+1.0)*0.125
				tool.set_uv(mapped)
				tool.add_vertex(points[index])
	tool.index()
	tool.generate_tangents()
	var resource: ArrayMesh = tool.commit()
	meshes[key] = resource
	_attach(car,label,resource,surface)

static func _attach(car: CarVisual, label: String, resource: ArrayMesh, surface: Material) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = resource
	mesh.material_override = surface
	car.body.add_child(mesh)
