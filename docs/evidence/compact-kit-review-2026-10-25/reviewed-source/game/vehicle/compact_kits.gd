class_name CompactKits
extends RefCounted
## Original fitted kit geometry in unscaled compact model metres. No collisions.
## Cache keys describe a single immutable part, never a player's combination.
static var meshes: Dictionary = {}
static var hardware_meshes: Dictionary = {}
static var simple_parts: bool = false
static var use_baked: bool = true
const ASSET_ROOT: String = "res://assets/vehicles/compact_kits_v1"

static func _load_prepared(key: String) -> void:
	if meshes.has(key) or not use_baked: return
	var path: String = ASSET_ROOT.path_join("meshes/"+key.sha256_text()+".res")
	if ResourceLoader.exists(path): meshes[key] = load(path) as ArrayMesh

static func choice(car: CarVisual, category: String) -> String:
	return str(car.customisation.get(category,"stock"))

static func _node(parent: Node3D, label: String) -> Node3D:
	var result := Node3D.new()
	result.name = label
	parent.add_child(result)
	return result

static func _cylinder(parent: Node3D, radius: float, height: float, center: Vector3, surface: Material, segments: int = 12) -> MeshInstance3D:
	var key: String = "%s/%s/%d"%[radius,height,segments]
	if not hardware_meshes.has(key):
		var mesh := CylinderMesh.new()
		mesh.top_radius = radius
		mesh.bottom_radius = radius
		mesh.height = height
		mesh.radial_segments = segments
		mesh.rings = 1
		hardware_meshes[key] = mesh
	var node := MeshInstance3D.new()
	node.mesh = hardware_meshes[key]
	node.material_override = surface
	node.position = center
	parent.add_child(node)
	return node

static func _patch(parent: Node3D, key: String, sample: Callable, surface: Material, normal_hint: Vector3, columns: int = 48, rows: int = 16, closed: bool = false, holes: Array[Rect2] = []) -> MeshInstance3D:
	if simple_parts:
		key += "/simple"
		columns = maxi(8,columns/2)
		rows = maxi(4,rows/2)
	_load_prepared(key)
	if not meshes.has(key):
		var xs: Array[float] = []
		var ys: Array[float] = []
		for i: int in range(columns+1): xs.append(i/float(columns))
		for i: int in range(rows+1): ys.append(i/float(rows))
		for hole: Rect2 in holes:
			for x: float in [hole.position.x,hole.end.x]:
				if x not in xs: xs.append(x)
			for y: float in [hole.position.y,hole.end.y]:
				if y not in ys: ys.append(y)
		xs.sort()
		ys.sort()
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for row: int in range(ys.size()-1):
			for column: int in range(xs.size()-1):
				var midpoint := Vector2((xs[column]+xs[column+1])*0.5,(ys[row]+ys[row+1])*0.5)
				var omit: bool = false
				for hole: Rect2 in holes:
					if hole.has_point(midpoint): omit = true
				if omit: continue
				var uv: Array[Vector2] = [Vector2(xs[column],ys[row]),Vector2(xs[column+1],ys[row]),Vector2(xs[column+1],ys[row+1]),Vector2(xs[column],ys[row+1])]
				var points: Array[Vector3] = []
				for t: Vector2 in uv: points.append(sample.call(t.x,t.y))
				var hint: Vector3 = normal_hint
				if closed:
					var center: Vector3 = Vector3.ZERO
					for ring: float in [0.0,0.25,0.5,0.75]: center += (sample.call(midpoint.x,ring) as Vector3)*0.25
					hint = (sample.call(midpoint.x,midpoint.y) as Vector3)-center
				var order: Array[int] = []
				for triangle: Array in [[0,1,2],[0,2,3]]:
					var face: Vector3 = (points[triangle[1]]-points[triangle[0]]).cross(points[triangle[2]]-points[triangle[0]])
					if face.length_squared()<1e-20: continue
					order.append(triangle[0])
					order.append(triangle[2] if face.dot(hint)>0 else triangle[1])
					order.append(triangle[1] if face.dot(hint)>0 else triangle[2])
				for index: int in order:
					var t: Vector2 = uv[index]
					var du: Vector3 = sample.call(minf(1,t.x+0.0001),t.y)-sample.call(maxf(0,t.x-0.0001),t.y)
					var dv: Vector3 = sample.call(t.x,minf(1,t.y+0.0001))-sample.call(t.x,maxf(0,t.y-0.0001))
					var normal: Vector3 = du.cross(dv).normalized()
					var vertex_hint: Vector3 = normal_hint
					if closed:
						var vertex_center: Vector3 = Vector3.ZERO
						for ring: float in [0.0,0.25,0.5,0.75]: vertex_center += (sample.call(t.x,ring) as Vector3)*0.25
						vertex_hint = points[index]-vertex_center
					if normal.dot(vertex_hint)<0: normal = -normal
					if normal.length_squared()<0.1: normal = vertex_hint.normalized() if vertex_hint.length_squared()>1e-12 else Vector3.LEFT if t.x<0.5 else Vector3.RIGHT
					tool.set_normal(normal)
					tool.set_uv(t)
					tool.add_vertex(points[index])
		tool.index()
		tool.generate_tangents()
		meshes[key] = tool.commit()
	var part := MeshInstance3D.new()
	part.name = key.get_file().capitalize().replace(" ","")
	part.mesh = meshes[key]
	part.material_override = surface
	parent.add_child(part)
	return part

static func hood_sample(kind: String, u: float, v: float) -> Vector3:
	var point: Vector3 = CompactCoachwork.hood_point(lerpf(-1,1,u),v)
	if kind in CompactKitVariants.HOODS: return CompactKitVariants.hood_point(kind,u,v,point)
	if kind == "dome":
		var across: float = 1-smoothstep(0.20,0.47,absf(point.x))
		var along: float = smoothstep(0.12,0.34,v)*(1-smoothstep(0.65,0.94,v))
		point.y += 0.085*across*along
	return point

static func arch_roll(radius: float, axle: float) -> float:
	# Overlay extensions follow the original rolled fender, rather than cutting
	# through its raised inner edge and producing intersecting shaded triangles.
	var progress: float = clampf((radius-0.405)/0.075,0,1)
	return ((0.070 if axle>0 else 0.055)+0.009)*pow(1-progress,2)+0.0005*smoothstep(0,1,progress)

static func build_hood(car: CarVisual, paint: Material, accent: Material) -> void:
	simple_parts = car.simple_model
	var kind: String = choice(car,"hood")
	var root: Node3D = _node(car.body,"KitHood_"+kind)
	CompactHoodKits.build(root,kind,paint,accent)

static func _rounded_box(parent: Node3D, key: String, center: Vector3, size: Vector3, radius: float, surface: Material) -> void:
	# Bevelled superellipse sides with closed rounded caps, unlike sharp boxes.
	var half: Vector3 = size*0.5
	var sample: Callable = func(u: float,v: float) -> Vector3:
		var a: float = v*TAU
		var yz := Vector2(cos(a),sin(a))
		var raw := yz*Vector2(half.y,half.z)
		var core := Vector2(maxf(0,half.y-radius),maxf(0,half.z-radius))
		var nearest: Vector2 = raw.clamp(-core,core)
		var section: Vector2 = nearest+(raw-nearest).normalized()*radius
		var x: float = lerpf(-half.x,half.x,u)
		var cap: float = sqrt(maxf(0,1-pow(clampf((absf(x)-half.x+radius)/radius,0,1),2)))
		section = section*(1-radius/maxf(radius,minf(half.y,half.z))*(1-cap))
		return center+Vector3(x,section.x,section.y)
	_patch(parent,key,sample,surface,Vector3.ZERO,12,20,true)
	for endpoint: float in [0.0,1.0]:
		var cap_key: String = key+"/cap"+str(endpoint)+("/simple" if simple_parts else "")
		_load_prepared(cap_key)
		if not meshes.has(cap_key):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			var normal := Vector3(-1 if endpoint==0 else 1,0,0)
			var origin: Vector3 = center+Vector3(lerpf(-half.x,half.x,endpoint),0,0)
			var count: int = 10 if simple_parts else 20
			for segment: int in range(count):
				var a: Vector3 = sample.call(endpoint,segment/float(count))
				var b: Vector3 = sample.call(endpoint,(segment+1)/float(count))
				var points: Array[Vector3] = [origin,a,b]
				if (a-origin).cross(b-origin).dot(normal)>0: points.reverse()
				for point: Vector3 in points:
					tool.set_normal(normal)
					tool.set_uv(Vector2((point.y-center.y)/size.y+0.5,(point.z-center.z)/size.z+0.5))
					tool.add_vertex(point)
			tool.index()
			tool.generate_tangents()
			meshes[cap_key] = tool.commit()
		var cap := MeshInstance3D.new()
		cap.mesh = meshes[cap_key]
		cap.material_override = surface
		parent.add_child(cap)

static func build_aero(car: CarVisual) -> void:
	simple_parts = car.simple_model
	var kind: String = choice(car,"aero")
	if kind == "stock":
		if car.editable_kits: car.new_kit_frame("aero",car.body)
		return
	var root: Node3D = _node(car.body,"KitAero_"+kind)
	car.register_kit_frame("aero",root)
	var paint: Material = car.paint_materials.body
	var trim: Material = CompactFinish.rubber(Color("20272a"))
	var metal: Material = CompactFinish.alloy(Color("8d979b"))
	if kind in CompactAero.PROFILES:
		CompactAero.build(root,kind,paint,trim,metal)
		return
	if kind == "lip":
		CompactKitSurface.solid(root,"aero6/"+kind,func(u: float,v: float) -> Vector3:
			var x: float = lerpf(-0.64,0.64,u)
			var a: float = v*TAU
			var edge: float = pow(maxf(0,1-pow(absf(x)/0.65,12)),0.5)
			var base: Vector3 = CompactCoachwork.roof_point(x/0.63,0.94)
			return Vector3(x,base.y+0.025+0.018*edge*(0.5+0.5*cos(a))+sin(a)*0.012,base.z+0.095+cos(a)*0.115),paint,64,24)
		return
static func build_body(car: CarVisual) -> void:
	simple_parts = car.simple_model
	var kind: String = choice(car,"body")
	if kind == "stock":
		if car.editable_kits: car.new_kit_frame("body",car.body)
		return
	var root: Node3D = _node(car.body,"KitBody_"+kind)
	car.register_kit_frame("body",root)
	CompactBodyKits.build(root,kind,car.paint_materials.body,CompactFinish.rubber(Color("202729")),CompactFinish.alloy(Color("899598")))

static func build_wheel(car: CarVisual, pivot: Node3D, side: float) -> void:
	simple_parts = car.simple_model
	var kind: String = choice(car,"rims")
	var root: Node3D = _node(pivot,"KitRims_"+kind)
	var pigment: String = {"five":"b8bfc1","split":"aa9165","turbine":"89979f","mesh":"b49c77","dish":"aeb9bd","rallydisc":"c7cdcd","six":"76848a","ten":"a3afb8","tri":"b1b9bd"}.get(kind,"b8bfc1")
	var alloy: Material = CompactFinish.alloy(Color(pigment))
	var polished: Material = CompactFinish.alloy(Color("c9d0d0"))
	var dark: Material = CompactFinish.rubber(Color("20272a"))
	var steel: Material = CompactFinish.alloy(Color("626b70"))
	CompactWheelKits.build(root,kind,side,alloy,polished,dark,steel)

static func build_caliper(pivot: Node3D, side: float) -> void:
	var root: Node3D = _node(pivot,"KitBrakeCaliper")
	_rounded_box(root,"rim/caliper"+str(side),Vector3(side*0.059,0.070,0.13),Vector3(0.047,0.115,0.065),0.015,CompactFinish.alloy(Color("a17245")))
