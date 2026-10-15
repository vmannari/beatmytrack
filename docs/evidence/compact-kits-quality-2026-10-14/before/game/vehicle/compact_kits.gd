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
	if kind in CompactKitVariants.HOODS:
		CompactKitVariants.hood(car,kind,paint,accent)
		return
	var root: Node3D = _node(car.body,"KitHood_"+kind)
	var rubber: Material = CompactFinish.rubber(Color("171e21"))
	var holes: Array[Rect2] = []
	if kind == "louvres": holes = [Rect2(0.14,0.27,0.19,0.48),Rect2(0.67,0.27,0.19,0.48)]
	elif kind == "scoop": holes = [Rect2(0.37,0.30,0.26,0.47)]
	_patch(root,"hood/"+kind,func(u: float,v: float) -> Vector3: return hood_sample(kind,u,v),paint,Vector3.UP,88,32,false,holes)
	# Rolled opening flanges follow the actual sheet, with dark inner walls.
	for hole_index: int in range(holes.size()):
		var hole: Rect2 = holes[hole_index]
		for edge: int in range(4):
			var a: Vector2 = hole.position if edge==0 else Vector2(hole.end.x,hole.position.y) if edge==1 else hole.end if edge==2 else Vector2(hole.position.x,hole.end.y)
			var b: Vector2 = Vector2(hole.end.x,hole.position.y) if edge==0 else hole.end if edge==1 else Vector2(hole.position.x,hole.end.y) if edge==2 else hole.position
			var wall_center: Vector3 = hood_sample(kind,hole.get_center().x,hole.get_center().y)-hood_sample(kind,(a.x+b.x)*0.5,(a.y+b.y)*0.5)
			_patch(root,"hood/%s/%d/wall%d"%[kind,hole_index,edge],func(u: float,v: float) -> Vector3:
				var p: Vector2 = a.lerp(b,u)
				return hood_sample(kind,p.x,p.y)-Vector3.UP*v*0.030,rubber,Vector3(wall_center.x,0,wall_center.z),24,2)
		_patch(root,"hood/%s/%d/recess"%[kind,hole_index],func(u: float,v: float) -> Vector3:
			var p: Vector2 = hole.position+Vector2(u,v)*hole.size
			return hood_sample(kind,p.x,p.y)-Vector3.UP*0.031,rubber,Vector3.UP,12,8)
		if kind == "louvres":
			for blade: int in range(6):
				var leading: float = hole.position.y+0.018+blade*0.077
				_patch(root,"hood/louvre%d/blade%d"%[hole_index,blade],func(u: float,v: float) -> Vector3:
					var point: Vector3 = hood_sample(kind,lerpf(hole.position.x-0.012,hole.end.x+0.012,u),leading+v*0.052)
					point.y += 0.002+sin(v*PI*0.70)*0.022*sin(u*PI)
					return point,paint,Vector3.UP,18,8)
	if kind == "scoop":
		_patch(root,"hood/scoop/crown",func(u: float,v: float) -> Vector3:
			var along: float = lerpf(0.27,0.84,v)
			var p: Vector3 = hood_sample(kind,lerpf(0.35,0.65,u),along)
			p.y += 0.115*(1-smoothstep(0.10,1,v))+sin(u*PI)*0.010*(1-v)
			return p,paint,Vector3.UP,28,24)
		for side: float in [-1,1]:
			_patch(root,"hood/scoop/side"+str(side),func(u: float,v: float) -> Vector3:
				var p: Vector3 = hood_sample(kind,0.5+side*0.15,lerpf(0.27,0.84,u))
				p.y += 0.115*(1-smoothstep(0.10,1,u))*v
				return p,paint,Vector3(side,0,0),32,8)
		_patch(root,"hood/scoop/intake",func(u: float,v: float) -> Vector3:
			var p: Vector3 = hood_sample(kind,lerpf(0.359,0.641,u),0.283)
			p.y += lerpf(0.007,0.105,v)+sin(u*PI)*0.006
			return p,rubber,Vector3.FORWARD,24,8)
		for bar: int in range(7):
			var x: float = lerpf(0.39,0.61,bar/6.0)
			var p: Vector3 = hood_sample(kind,x,0.279)
			car._seam(root,p+Vector3.UP*0.015,p+Vector3.UP*0.093,0.006,rubber)
		_patch(root,"hood/scoop/rolledmouth",func(u: float,v: float) -> Vector3:
			var p: Vector3 = hood_sample(kind,lerpf(0.35,0.65,u),0.27)
			p.y += 0.115+sin(u*PI)*0.010
			return p+Vector3(0,cos(v*TAU)*0.0045,sin(v*TAU)*0.005),paint,Vector3.ZERO,28,12,true)
	# An inset pressed centre retains the owner's accent pigment on the dome.
	if kind == "dome":
		_patch(root,"hood/dome/accent",func(u: float,v: float) -> Vector3:
			return hood_sample(kind,lerpf(0.34,0.66,u),v)+Vector3.UP*0.0015,accent,Vector3.UP,32,32)
	for side: float in [-1,1]:
		for segment: int in range(24):
			var a: Vector3 = hood_sample(kind,0.5+side*0.494,segment/24.0)
			var b: Vector3 = hood_sample(kind,0.5+side*0.494,(segment+1)/24.0)
			car._seam(root,a+Vector3.UP*0.002,b+Vector3.UP*0.002,0.004,rubber)

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
		_patch(root,"aero/"+kind,func(u: float,v: float) -> Vector3:
			var x: float = lerpf(-0.64,0.64,u)
			var a: float = v*TAU
			var edge: float = pow(maxf(0,1-pow(absf(x)/0.65,12)),0.5)
			var base: Vector3 = CompactCoachwork.roof_point(x/0.63,0.94)
			return Vector3(x,base.y+0.025+0.018*edge*(0.5+0.5*cos(a))+sin(a)*0.012,base.z+0.095+cos(a)*0.115),paint,Vector3.ZERO,64,24,true)
		return
	# Roof-mounted GT wing: paired saddles clear the hatch glass and open edge.
	for side: float in [-1,1]:
		var mount: Vector3 = CompactCoachwork.roof_point(side*0.82,0.93)
		_rounded_box(root,"aero/wing/gasket"+str(side),mount+Vector3.UP*0.006,Vector3(0.16,0.014,0.19),0.006,trim)
		_rounded_box(root,"aero/wing/saddle"+str(side),mount+Vector3.UP*0.018,Vector3(0.13,0.026,0.16),0.009,metal)
		_patch(root,"aero/wing/pylon"+str(side),func(u: float,v: float) -> Vector3:
			var a: float = v*TAU
			return mount+Vector3(side*(0.010+u*0.012)+cos(a)*0.015,0.02+u*0.245,0.03+u*0.16+sin(a)*0.038),trim,Vector3.ZERO,20,16,true)
		for z: float in [-0.048,0.048]:
			_cylinder(root,0.012,0.006,mount+Vector3(0,0.035,z),metal)
	_patch(root,"aero/wing/airfoil",func(u: float,v: float) -> Vector3:
		var x: float = lerpf(-0.88,0.88,u)
		var a: float = v*TAU
		var chord: float = 0.20-0.035*pow(absf(x)/0.88,4)
		return Vector3(x,1.79+0.033*cos(a)+0.021*sin(a)-0.023*sin(a)*sin(a)+0.014*x*x,1.33+cos(a)*chord+0.07*x*x),paint,Vector3.ZERO,64,32,true)
	for side: float in [-1,1]:
		_rounded_box(root,"aero/wing/endplate"+str(side),Vector3(side*0.887,1.785,1.385),Vector3(0.025,0.16,0.41),0.012,trim)
		for z: float in [1.26,1.48]:
			var bolt := _cylinder(root,0.010,0.008,Vector3(side*0.902,1.792,z),metal)
			bolt.rotation.z = PI*0.5

static func build_body(car: CarVisual) -> void:
	simple_parts = car.simple_model
	var kind: String = choice(car,"body")
	if kind == "stock":
		if car.editable_kits: car.new_kit_frame("body",car.body)
		return
	var root: Node3D = _node(car.body,"KitBody_"+kind)
	car.register_kit_frame("body",root)
	var paint: Material = car.paint_materials.body
	var rubber: Material = CompactFinish.rubber(Color("202729"))
	var bright: Material = CompactFinish.alloy(Color("899598"))
	var trim: Material = rubber
	if kind in CompactKitVariants.BODIES:
		CompactKitVariants.body(car,root,kind,paint,rubber,bright)
		return
	for side: float in [-1,1]:
		_patch(root,"body/%s/skirt%s"%[kind,side],func(u: float,v: float) -> Vector3:
			var z: float = lerpf(-0.84,0.84,u)
			var a: float = v*TAU
			var flare: float = (0.047 if kind=="street" else 0.033 if kind=="rally" else 0.078)*pow(sin(u*PI),0.4)
			return Vector3(side*(CompactCoachwork.body_width(0.39,z)+flare+cos(a)*0.022),0.375+sin(a)*0.062,z),paint if kind!="rally" else trim,Vector3.ZERO,32,16,true)
		if kind in ["rally","club"]:
			for axle: float in [-1.28,1.28]:
				_patch(root,"body/%s/arch%s/%s"%[kind,side,axle],func(u: float,v: float) -> Vector3:
					var a: float = lerpf(-0.14,PI+0.14,u)
					var radius: float = lerpf(0.423,0.482 if kind=="rally" else 0.495,v)
					var z: float = axle+cos(a)*radius
					var y: float = 0.37+sin(a)*radius
					var outer: float = 0.043 if kind=="rally" else 0.073
					return Vector3(side*(CompactCoachwork.body_width(y,z)+arch_roll(radius,axle)+0.008+sin(v*PI)*outer+0.015*(1-v)),y,z),trim if kind=="rally" else paint,Vector3(side,0,0),48,8)
				# Recessed mounting rivets follow the arch profile rather than floating.
				for fastener: int in range(7):
					var a: float = fastener*PI/6.0
					var y: float = 0.37+sin(a)*0.461
					var z: float = axle+cos(a)*0.461
					var t: float = (0.461-0.423)/((0.482 if kind=="rally" else 0.495)-0.423)
					var rise: float = arch_roll(0.461,axle)+0.008+sin(t*PI)*(0.043 if kind=="rally" else 0.073)+0.015*(1-t)+0.0025
					var bolt := _cylinder(root,0.008,0.005,Vector3(side*(CompactCoachwork.body_width(y,z)+rise),y,z),bright)
					bolt.rotation.z = PI*0.5
			if kind=="rally":
				for axle: float in [-1.28,1.28]:
					_rounded_box(root,"body/rally/flap%s/%s"%[side,axle],Vector3(side*0.83,0.265,axle+0.39),Vector3(0.24,0.24,0.024),0.011,trim)
	for rear: bool in [false,true]:
		_patch(root,"body/%s/valance%s"%[kind,rear],func(u: float,v: float) -> Vector3:
			var p: Vector2 = CompactCoachwork._bumper_path(rear,u)
			var tangent: Vector2 = (CompactCoachwork._bumper_path(rear,minf(1,u+0.0002))-CompactCoachwork._bumper_path(rear,maxf(0,u-0.0002))).normalized()
			var out := Vector2(-tangent.y,tangent.x)
			var a: float = v*TAU
			var depth: float = 0.04 if kind=="rally" else 0.085 if kind=="street" else 0.13
			p += out*(depth*(0.5+0.5*cos(a))-0.028)
			return Vector3(p.x,(0.34 if rear else 0.37)+sin(a)*0.039,p.y),paint if kind=="street" else trim,Vector3.ZERO,80,16,true)
	if kind=="club":
		for fin: int in range(5):
			_rounded_box(root,"body/club/diffuser"+str(fin),Vector3((fin-2)*0.25,0.32,2.00),Vector3(0.022,0.115,0.30),0.009,trim)
		for side: float in [-1,1]:
			_rounded_box(root,"body/club/splitterend"+str(side),Vector3(side*0.94,0.397,-1.89),Vector3(0.022,0.12,0.30),0.009,trim)

static func build_wheel(car: CarVisual, pivot: Node3D, side: float) -> void:
	simple_parts = car.simple_model
	var kind: String = choice(car,"rims")
	var root: Node3D = _node(pivot,"KitRims_"+kind)
	var pigment: String = {"five":"b8bfc1","split":"aa9165","turbine":"89979f","mesh":"b49c77","dish":"aeb9bd","rallydisc":"c7cdcd","six":"76848a","ten":"a3afb8","tri":"b1b9bd"}.get(kind,"b8bfc1")
	var alloy: Material = CompactFinish.alloy(Color(pigment))
	var polished: Material = CompactFinish.alloy(Color("c9d0d0"))
	var dark: Material = CompactFinish.rubber(Color("20272a"))
	var steel: Material = CompactFinish.alloy(Color("626b70"))
	# Lathed barrel and polished rolled bead match the original tire's 0.23m hole.
	_patch(root,"rim/%s/barrel%s"%[kind,side],func(u: float,v: float) -> Vector3:
		var a: float = v*TAU
		var depth: float = lerpf(0.025,0.148,u)
		var radius: float = 0.224+0.013*smoothstep(0.76,1,u)
		return Vector3(side*depth,sin(a)*radius,cos(a)*radius),alloy,Vector3.ZERO,12,64,true)
	_patch(root,"rim/bead"+str(side),func(u: float,v: float) -> Vector3:
		var a: float = u*TAU
		var b: float = v*TAU
		var radius: float = 0.235+cos(b)*0.009
		return Vector3(side*(0.147+sin(b)*0.008),sin(a)*radius,cos(a)*radius),polished,Vector3.ZERO,64,12,true)
	# Real open spoke spaces reveal a drilled rotor instead of a solid black disc.
	var disc := _cylinder(root,0.188,0.012,Vector3(side*0.043,0,0),steel,48)
	disc.rotation.z = PI*0.5
	for hole: int in range(20):
		var a: float = hole*TAU/20.0
		var dot := _cylinder(root,0.0065,0.0015,Vector3(side*0.050,sin(a)*0.157,cos(a)*0.157),dark,8)
		dot.rotation.z = PI*0.5
	if kind in CompactKitVariants.RIMS:
		CompactKitVariants.wheel_face(car,root,kind,side,alloy,polished,dark)
	var count: int = 0 if kind in CompactKitVariants.RIMS else 5 if kind=="five" else 6 if kind=="split" else 12
	for spoke: int in range(count):
		for fork: int in range(2 if kind=="split" else 1):
			_patch(root,"rim/%s/spoke%d/%d/%s"%[kind,spoke,fork,side],func(u: float,v: float) -> Vector3:
				var radius: float = lerpf(0.050,0.231,u)
				var a: float = spoke*TAU/count+(0.28*u if kind=="turbine" else (fork*2-1)*0.12*smoothstep(0.1,0.8,u) if kind=="split" else 0.06*u)
				var b: float = v*TAU
				var width: float = lerpf(0.035,0.022,u) if kind=="five" else lerpf(0.018,0.010,u) if kind=="split" else 0.014
				var tangent: float = cos(b)*width
				var x: float = 0.104+u*0.039+sin(b)*0.009
				return Vector3(side*x,sin(a)*radius+cos(a)*tangent,cos(a)*radius-sin(a)*tangent),alloy,Vector3.ZERO,16,12,true)
	var cap := _cylinder(root,0.050,0.018,Vector3(side*0.109,0,0),alloy,32)
	cap.rotation.z = PI*0.5
	var center := _cylinder(root,0.022,0.020,Vector3(side*0.111,0,0),dark,24)
	center.rotation.z = PI*0.5
	for lug: int in range(4):
		var a: float = lug*TAU/4.0
		var bolt := _cylinder(root,0.010,0.018,Vector3(side*0.118,sin(a)*0.036,cos(a)*0.036),polished)
		bolt.rotation.z = PI*0.5
	var valve := _cylinder(root,0.006,0.024,Vector3(side*0.149,0.190,0.083),dark)
	valve.rotation.z = PI*0.5

static func build_caliper(pivot: Node3D, side: float) -> void:
	var root: Node3D = _node(pivot,"KitBrakeCaliper")
	_rounded_box(root,"rim/caliper"+str(side),Vector3(side*0.059,0.070,0.13),Vector3(0.047,0.115,0.065),0.015,CompactFinish.alloy(Color("a17245")))
