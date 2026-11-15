class_name SuperRallyModel
extends RefCounted
## Simplified owner-supplied CC-BY Challenger; native immutable meshes, no rig/interior.
## Attribution: legal/challenger_hellcat_notices.txt; preprocessing: scripts/prepare_challenger.py.
## Presentation only: Rally-like canonical handling and wheel contacts stay unchanged.
const KEY: String = "super-rally-hellcat-6/"
const NOSE_INPUT: Array[float] = [1.72,1.80,1.88,1.96,2.04,2.1171]
const NOSE_OUTPUT: Array[float] = [1.72,1.90,2.080,2.145,2.205,2.2571]
const NOSE_TANGENT: Array[float] = [1.0,2.25,1.20,0.80,0.70,0.65]
static var meshes: Dictionary = {}
static var hood_profile: Dictionary = {}
const ROOT: String = "res://assets/vehicles/challenger_hellcat_v1/"
static var assets: Dictionary = {}
const AERO: Dictionary = {
	"lip":Vector4(0.70,0.845,2.17,0.065),"ducktail":Vector4(0.82,0.965,2.13,0.11),
	"wing":Vector4(0.90,1.28,1.92,0.19),"touring":Vector4(0.73,0.92,1.85,0.11),
	"pedestal":Vector4(0.86,1.08,2.10,0.15),"swan":Vector4(0.91,1.34,1.88,0.18),
	"biwing":Vector4(0.89,1.28,2.02,0.15),"rallywing":Vector4(0.95,1.18,2.10,0.17),
	"endurance":Vector4(0.99,1.13,2.30,0.23),"whale":Vector4(0.82,0.95,2.15,0.27),
	"drag":Vector4(0.78,0.86,2.32,0.30),"splitwing":Vector4(0.89,1.04,1.98,0.17)}

static func _patch(root: Node3D, name: String, sample: Callable, material: Material, hint: Vector3, columns: int = 48, rows: int = 16, holes: Array[Rect2] = [], normal_at: Callable = Callable()) -> void:
	var key: String = KEY+name+("/simple" if CompactKits.simple_parts else "/full")
	if not meshes.has(key):
		if CompactKits.simple_parts: columns = maxi(4,columns/2); rows = maxi(2,rows/2)
		var xs: Array[float] = []; var ys: Array[float] = []
		for index: int in range(columns+1): xs.append(index/float(columns))
		for index: int in range(rows+1): ys.append(index/float(rows))
		for hole: Rect2 in holes:
			for value: float in [hole.position.x,hole.end.x]:
				if value not in xs: xs.append(value)
			for value: float in [hole.position.y,hole.end.y]:
				if value not in ys: ys.append(value)
		xs.sort(); ys.sort()
		var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for row: int in range(ys.size()-1):
			for column: int in range(xs.size()-1):
				var middle := Vector2((xs[column]+xs[column+1])*0.5,(ys[row]+ys[row+1])*0.5)
				var omit: bool = false
				for hole: Rect2 in holes:
					if hole.has_point(middle): omit = true
				if omit: continue
				var uv: Array[Vector2] = [Vector2(xs[column],ys[row]),Vector2(xs[column+1],ys[row]),Vector2(xs[column+1],ys[row+1]),Vector2(xs[column],ys[row+1])]
				var points: Array[Vector3] = []
				for t: Vector2 in uv: points.append(sample.call(t.x,t.y))
				for triangle: Array in [[0,1,2],[0,2,3]]:
					var normal: Vector3 = (points[triangle[1]]-points[triangle[0]]).cross(points[triangle[2]]-points[triangle[0]])
					if normal.length_squared() < 1e-18: continue
					var order: Array = triangle.duplicate()
					var facing: Vector3 = normal_at.call(middle.x,middle.y) if normal_at.is_valid() else hint
					if normal.dot(facing) > 0: order.reverse()
					for index: int in order:
						var t: Vector2 = uv[index]
						var du: Vector3 = sample.call(minf(1,t.x+0.0002),t.y)-sample.call(maxf(0,t.x-0.0002),t.y)
						var dv: Vector3 = sample.call(t.x,minf(1,t.y+0.0002))-sample.call(t.x,maxf(0,t.y-0.0002))
						var n: Vector3 = normal_at.call(t.x,t.y) if normal_at.is_valid() else du.cross(dv).normalized()
						if not normal_at.is_valid() and n.dot(hint) < 0: n = -n
						if n.length_squared() < 0.5: n = facing.normalized()
						tool.set_normal(n); tool.set_uv(t); tool.add_vertex(points[index])
		tool.index(); tool.generate_tangents(); meshes[key] = tool.commit()
	var part := MeshInstance3D.new(); part.name = name; part.mesh = meshes[key]; part.material_override = material; root.add_child(part)

static func _curve(root: Node3D, name: String, path: Callable, radius: float, material: Material, columns: int = 32) -> void:
	_patch(root,name,func(u: float,v: float) -> Vector3:
		var p: Vector3 = path.call(u)
		var tangent: Vector3 = (path.call(minf(1,u+0.001)) as Vector3)-(path.call(maxf(0,u-0.001)) as Vector3)
		var normal: Vector3 = tangent.normalized().cross(Vector3.UP).normalized()
		if normal.length_squared() < 0.1: normal = Vector3.RIGHT
		var binormal: Vector3 = tangent.normalized().cross(normal).normalized()
		return p+radius*(normal*cos(v*TAU)+binormal*sin(v*TAU)),material,Vector3.UP,columns,8,[],func(u: float,v: float) -> Vector3:
		var tangent: Vector3 = ((path.call(minf(1,u+0.001)) as Vector3)-(path.call(maxf(0,u-0.001)) as Vector3)).normalized()
		var normal: Vector3 = tangent.cross(Vector3.UP).normalized()
		if normal.length_squared() < 0.1: normal = Vector3.RIGHT
		return normal*cos(v*TAU)+tangent.cross(normal).normalized()*sin(v*TAU))

static func width(z: float) -> float:
	return 0.95-0.11*smoothstep(1.75,2.22,absf(z))

static func hood_point(across: float, v: float, _kind: String = "stock") -> Vector3:
	var x: float = across*0.70
	var z: float = lerpf(-1.94,-1.04,v)
	var mapped_z: float = _nose_z(z,x)
	return Vector3(_nose_plan_x(x,mapped_z),_hood_height(x,z),mapped_z)

static func _nose_plan_x(x: float,z: float) -> float:
	var scale: float = 1.0
	for band: Array in [[1.53,1.73,0.040],[1.65,2.22,0.035]]:
		var t: float = clampf((-z-float(band[0]))/(float(band[1])-float(band[0])),0,1)
		scale-=float(band[2])*t*t*t*(10+t*(-15+6*t))
	return 0.005052088637516661+(x-0.005052088637516661)*scale

static func _nose_z(z: float,x: float=0.0) -> float:
	var d: float = -z
	if d<=NOSE_INPUT[0]:return z
	if d>=NOSE_INPUT[-1]:return -(NOSE_OUTPUT[-1]+(d-NOSE_INPUT[-1])*NOSE_TANGENT[-1])
	var i: int = 0
	while i<NOSE_INPUT.size()-2 and d>NOSE_INPUT[i+1]:i+=1
	var length: float = NOSE_INPUT[i+1]-NOSE_INPUT[i]
	var t: float = (d-NOSE_INPUT[i])/length
	var base: float = (2*t*t*t-3*t*t+1)*NOSE_OUTPUT[i]+(t*t*t-2*t*t+t)*length*NOSE_TANGENT[i]+(-2*t*t*t+3*t*t)*NOSE_OUTPUT[i+1]+(t*t*t-t*t)*length*NOSE_TANGENT[i+1]
	var u: float = clampf((absf(x)-0.35)/0.35,0,1)
	var amount: float = 0.55*u*u*u*(10+u*(-15+6*u))
	var span: float = NOSE_OUTPUT[-1]-NOSE_INPUT[0]
	var s: float = clampf((base-NOSE_INPUT[0])/span,0,1)
	return -(base+amount*span*s*(1-s))

static func _cubic_weights(t: float) -> Vector4:
	return Vector4(-0.5*t+t*t-0.5*t*t*t,1-2.5*t*t+1.5*t*t*t,0.5*t+2*t*t-1.5*t*t*t,-0.5*t*t+0.5*t*t*t)

static func _hood_height(x: float,z: float) -> float:
	if hood_profile.is_empty(): hood_profile = (load(ROOT+"hood_profile.json") as JSON).data
	var xs: Array = hood_profile.x; var zs: Array = hood_profile.z
	var u: float = clampf((x-float(xs[0]))/(float(xs[1])-float(xs[0])),0,xs.size()-1)
	var v: float = clampf((z-float(zs[0]))/(float(zs[1])-float(zs[0])),0,zs.size()-1)
	var ix: int = floori(u); var iz: int = floori(v)
	var wx: Vector4 = _cubic_weights(u-ix); var wz: Vector4 = _cubic_weights(v-iz)
	var height: float = 0
	for a: int in range(4):
		for b: int in range(4): height += float(hood_profile.heights[clampi(ix+a-1,0,xs.size()-1)][clampi(iz+b-1,0,zs.size()-1)])*wx[a]*wz[b]
	return height

static func _paint(color: Color) -> StandardMaterial3D:
	var result: StandardMaterial3D = CompactFinish.paint(color)
	result.roughness = 0.40
	result.metallic = 0.06
	result.metallic_specular = 0.38
	result.clearcoat = 0.24
	result.clearcoat_roughness = 0.32
	return result

static func _materials(car: CarVisual) -> Dictionary:
	if car.has_meta("hellcat_materials"): return car.get_meta("hellcat_materials")
	var glass := CompactFinish.glass(Color("101b20"))
	var contour := VisualGeometry.material(Color("303b40"))
	contour.roughness = 0.85; contour.cull_mode = BaseMaterial3D.CULL_DISABLED
	var led := VisualGeometry.material(Color("a3b7bf"))
	led.roughness = 0.24; led.emission_enabled = true; led.emission = Color("73848c"); led.emission_energy_multiplier = 0.25
	var red_lens := VisualGeometry.material(Color("301213"))
	red_lens.roughness = 0.20; red_lens.metallic_specular = 0.55
	var vent_metal := CompactFinish.alloy(Color("30383a"))
	vent_metal.roughness = 0.55; vent_metal.metallic = 0.25
	var result: Dictionary = {"paint":car.paint_materials.body,"accent":car.paint_materials.accent,"detail":car.paint_materials.detail,
		"glass":glass,"contour":contour,"mirror":CompactFinish.alloy(Color("657578")),"dark":CompactFinish.rubber(Color("172125")),
		"chrome":CompactFinish.alloy(Color("8e999a")),"rubber":CompactFinish.rubber(Color("192125")),
		"red":car.brake_material,"white":VisualGeometry.material(Color("354956")),"reverse":VisualGeometry.material(Color("778789")),"amber":VisualGeometry.material(Color("b96820")),
		"led":led,"lens_red":red_lens,"vent_metal":vent_metal}
	car.set_meta("hellcat_materials",result)
	return result

static func _asset(car: CarVisual, parent: Node3D, group: String, roles: Array[String] = [], override: Material = null) -> void:
	var manifest: Dictionary = (load(ROOT+"manifest.json") as JSON).data
	for item: Dictionary in manifest.tiers["simple" if car.simple_model else "full"]:
		if item.group != group or (not roles.is_empty() and item.role not in roles): continue
		var path: String = ROOT+str(item.mesh)
		if not assets.has(path): assets[path] = load(path)
		var part := MeshInstance3D.new(); part.name = "Hellcat_"+group+"_"+str(item.role)
		part.mesh = assets[path]; part.material_override = override if override != null else _materials(car)[item.role]
		if item.role == "contour":
			part.mesh = preload("res://vehicle/challenger_panel_contours.gd").mesh(part.mesh,car.simple_model)
			part.material_override = preload("res://vehicle/panel_contour.gd").material(part.material_override)
		if item.role in ["contour","led","red","white","reverse","lens_red","vent_metal","glass"] or (group == "hood" and item.role == "dark"): part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(part)
		if group.begins_with("tail_"): car.brake_lights.append(part)

static func _wheel_group(position: Vector3) -> String:
	return "wheel_"+("Ft_" if position.z < 0.0 else "Bk_")+("L" if position.x < 0.0 else "R")

static func build(car: CarVisual) -> void:
	CompactKits.simple_parts = car.simple_model
	car.body = Node3D.new(); car.body.name = "SimplifiedHellcat"; car.add_child(car.body)
	car.paint_materials = {"body":_paint(Color("b73528")),"accent":_paint(Color("20272a")),"detail":CompactFinish.alloy(Color("a4abad"))}
	car.brake_material = VisualGeometry.material(Color("802d2b"))
	for group: String in ["body","window_seal","tail_left","tail_right","head_left","head_right"]: _asset(car,car.body,group)
	# A plain exterior underside replaces the source's cabin floor slabs.
	VisualGeometry.box(car.body,Vector3(1.48,0.018,3.50),Vector3(0,0.285,0),car.underside_material)
	_box(car.body,"GrilleBacking",Vector3(0,0.70,-1.87),Vector3(1.52,0.22,0.009),_materials(car).dark,0.005)
	for side: float in [-1.0,1.0]:
		for axle: float in [-1.28,1.28]:
			var pivot := Node3D.new(); pivot.position = Vector3(side*0.83,0.37,axle); car.add_child(pivot)
			var group: String = _wheel_group(pivot.position)
			# Round close-up silhouettes are worth the small local tessellation cost.
			CompactDetail.tire(pivot,_materials(car).rubber,false)
			var frame: Node3D = car.new_kit_frame("rims",pivot) if car.editable_kits else pivot
			wheel(frame,side,str(car.customisation.rims))
			if axle < 0.0: car.front_wheels.append(pivot)
			car.register_rolling_wheel(pivot,0.37)
			CompactKits.build_caliper(pivot,side)
	for category: String in ["hood","aero","body"]: kit(car,category)

static func kit(car: CarVisual, category: String) -> void:
	CompactKits.simple_parts = car.simple_model
	var kind: String = str(car.customisation.get(category,"stock"))
	if category == "rims":
		for rotor: Node3D in car.rolling_wheels:
			var frame: Node3D = car.new_kit_frame("rims",rotor) if car.editable_kits else rotor
			var pivot: Node3D = rotor.get_parent()
			wheel(frame,signf(pivot.position.x),kind)
		return
	var root: Node3D = car.new_kit_frame(category,car.body) if car.editable_kits else Node3D.new()
	if not car.editable_kits: root.name = "HellcatKit_"+category; car.body.add_child(root)
	if category == "hood":
		_asset(car,root,"hood")
		hood(root,car.paint_materials.body,car.paint_materials.accent,kind)
	elif category == "aero":
		if kind == "stock": _asset(car,root,"aero")
		else: aero(root,car.paint_materials.body,car.paint_materials.accent,kind)
	elif category == "body": body(root,car.paint_materials.body,car.paint_materials.accent,kind)

static func hood(root: Node3D, paint: Material, accent: Material, kind: String = "stock") -> void:
	if kind == "stock": return
	if kind in ["louvres","vented","extractor"]:
		var positions: Array[float] = []
		positions.assign([0.0] if kind == "extractor" else [-0.36,0.36])
		for x: float in positions:
			var at: Vector3 = hood_point(x,0.57)
			_box(root,"HeatOutlet"+kind+str(x),at+Vector3.UP*0.011,Vector3(0.25,0.018,0.33),accent,0.012)
			for slat: int in range(5): _box(root,"Vane"+kind+str(x)+str(slat),at+Vector3(0,0.027,-0.14+slat*0.07),Vector3(0.24,0.009,0.012),paint,0.003)
	elif kind in ["scoop","twin_scoop","reverse","cowl"]:
		var positions: Array[float] = []
		positions.assign([-0.22,0.22] if kind == "twin_scoop" else [0.0])
		for x: float in positions:
			var at: Vector3 = hood_point(x,0.70)
			var breadth: float = 0.22 if kind == "twin_scoop" else 0.40
			_box(root,"Induction"+kind+str(x),at+Vector3.UP*0.055,Vector3(breadth,0.10,0.41),paint,0.035)
			_box(root,"InductionMouth"+kind+str(x),at+Vector3(0,0.055,0.213 if kind in ["reverse","cowl"] else -0.213),Vector3(breadth*0.76,0.055,0.012),accent,0.006)
	else:
		_patch(root,"BonnetContour"+kind,func(u: float,v: float) -> Vector3:
			var x: float = (u*2-1)*0.45; var t: float = lerpf(0.35,0.91,v)
			var p: Vector3 = hood_point(x,t)
			p.y += 0.008+0.050*sin(u*PI)*sin(v*PI)
			if kind == "ribs": p.y += 0.012*sin(u*PI*6)*sin(v*PI)
			return p,paint,Vector3.UP,24,20)

static func aero_extent(kind: String) -> Vector2:
	var profile: Vector4 = AERO.get(kind,Vector4(0,0,0,0))
	return Vector2(profile.x+0.02,profile.y+0.22)

static func aero(root: Node3D, paint: Material, accent: Material, kind: String = "stock") -> void:
	if kind == "stock": return
	var profile: Vector4 = AERO[kind]
	var wing: bool = profile.y > 1.0
	var height: float = profile.y+0.13
	if wing:
		for side: float in [-1.0,1.0]: _beam(root,"HellcatDeckWingLeg"+str(side)+kind,Vector3(side*0.46,0.98,minf(2.13,profile.z)),Vector3(side*0.46,height-0.02,profile.z),0.018,0.035,paint)
	var spans: Array[Vector2] = [Vector2(-profile.x,profile.x)]
	if kind == "splitwing": spans = [Vector2(-profile.x,-0.065),Vector2(0.065,profile.x)]
	for span: Vector2 in spans:
		_patch(root,"HellcatRearAero"+kind+str(span.x),func(u: float,v: float) -> Vector3:
			var x: float = lerpf(span.x,span.y,u); var angle: float = v*TAU
			return Vector3(x,height+0.025*sin(angle)+0.023*pow(x/profile.x,2),profile.z+profile.w*cos(angle)),accent,Vector3.UP,32,12,[],func(_u: float,v: float) -> Vector3: return Vector3(0,sin(v*TAU)/0.025,cos(v*TAU)/profile.w).normalized())
	if kind == "biwing": _box(root,"HellcatLowerWing",Vector3(0,height-0.15,profile.z-0.04),Vector3(profile.x*1.85,0.035,0.22),paint)
	if wing:
		for side: float in [-1.0,1.0]: _box(root,"HellcatWingEnd"+kind+str(side),Vector3(side*profile.x,height+0.005,profile.z),Vector3(0.018,0.13,profile.w*1.95),paint,0.010)

static func body(root: Node3D, paint: Material, accent: Material, kind: String = "stock") -> void:
	if kind == "stock": return
	var ordinal: int = maxi(0,["street","rally","club","heritage","touring","wide","endurance","gravel","urban"].find(kind))
	var depth: float = 0.035+0.01*ordinal
	for side: float in [-1.0,1.0]:
		_box(root,"HellcatFittedSill"+kind+str(side),Vector3(side*(0.825+depth*0.3),0.29,0.03),Vector3(depth+0.055,0.065+0.004*ordinal,1.60),paint,0.015)
	_box(root,"HellcatFittedSplitter"+kind,Vector3(0,0.277,-2.28),Vector3(1.65+depth,0.030,0.24+depth),accent,0.012)
	if kind in ["wide","rally","gravel"]:
		for side: float in [-1.0,1.0]:
			for axle: float in [-1.28,1.28]:
				_curve(root,"HellcatFittedArch"+kind+str(side)+str(axle),func(t: float) -> Vector3:
					var a: float = t*PI; var z: float = axle+cos(a)*0.445
					return Vector3(side*(width(z)+0.018),0.37+sin(a)*0.445,z),0.025+depth*0.15,paint,36)
	if kind in ["rally","gravel"]:
		var rubber: Material = CompactFinish.rubber(Color("192125"))
		for side: float in [-1.0,1.0]:
			for axle: float in [-1.28,1.28]: _box(root,"HellcatMudflap"+kind+str(side)+str(axle),Vector3(side*0.86,0.335,axle+0.38),Vector3(0.23,0.43,0.024),rubber,0.006)

static func night_lens(root: Node3D, lens: Material, _paint: Material) -> void:
	var car: Node = root
	while not car is CarVisual: car = car.get_parent()
	for group: String in ["head_left","head_right"]:
		var frame := Node3D.new(); frame.position.z = -0.003; root.add_child(frame)
		_asset(car,frame,group,[],lens)

static func _box(root: Node3D, name: String, center: Vector3, size: Vector3, material: Material, bevel: float = 0.012) -> void:
	# Broad fabricated faces need no densely sampled longitudinal rings.
	var key: String = KEY+name+("/low-simple-box" if CompactKits.simple_parts else "/low-full-box")
	if not CompactKits.meshes.has(key):
		var half: Vector3 = size*0.5
		var corners: Array[Vector2] = [Vector2(-half.y,-half.z),Vector2(half.y,-half.z),Vector2(half.y,half.z),Vector2(-half.y,half.z)]
		var outline: Array[Vector2] = []
		var count: int = 12 if CompactKits.simple_parts else 16
		for index: int in range(count): outline.append(CompactKitSurface.contour(corners,index/float(count),minf(bevel,minf(half.y,half.z)*0.65)))
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for index: int in range(count):
			var a: Vector2 = outline[index]
			var b: Vector2 = outline[(index+1)%count]
			var points: Array[Vector3] = [center+Vector3(-half.x,a.x,a.y),center+Vector3(-half.x,b.x,b.y),center+Vector3(half.x,b.x,b.y),center+Vector3(half.x,a.x,a.y)]
			var normal: Vector3 = (points[1]-points[0]).cross(points[2]-points[0]).normalized()
			if normal.dot(Vector3(0,a.x+b.x,a.y+b.y)) < 0: normal = -normal
			CompactAero._triangle(tool,points[0],points[1],points[2],normal)
			CompactAero._triangle(tool,points[0],points[2],points[3],normal)
		var cap: PackedInt32Array = Geometry2D.triangulate_polygon(PackedVector2Array(outline))
		for side: float in [-1.0,1.0]:
			for triangle: int in range(0,cap.size(),3):
				var a: Vector2 = outline[cap[triangle]]
				var b: Vector2 = outline[cap[triangle+1]]
				var c: Vector2 = outline[cap[triangle+2]]
				CompactAero._triangle(tool,center+Vector3(side*half.x,a.x,a.y),center+Vector3(side*half.x,b.x,b.y),center+Vector3(side*half.x,c.x,c.y),Vector3(side,0,0))
		tool.index()
		tool.generate_tangents()
		CompactKits.meshes[key] = tool.commit()
	CompactAero._attach(root,key,material)

static func _beam(root: Node3D, name: String, from: Vector3, to: Vector3, half_width: float, half_depth: float, material: Material) -> void:
	CompactAero._support(root,KEY+name,from,to,half_width,half_depth,material,0.0)


static func wheel(root: Node3D, side: float, kind: String = "stock") -> void:
	if kind == "stock":
		_factory_wheel(root,side)
		return
	var white: Material = CompactFinish.alloy(Color("e5e5db" if kind == "rallydisc" else "929a9c"))
	var dark: Material = CompactFinish.rubber(Color("192125"))
	var steel: Material = CompactFinish.alloy(Color("8c9698"))
	# Retain the existing purchased rim designs independently of the factory wheel.
	var rim: Array[Vector2] = [Vector2(0.095,0.230),Vector2(0.106,0.249),Vector2(0.151,0.249),Vector2(0.158,0.239),Vector2(0.149,0.224),Vector2(0.112,0.224)]
	CompactKitSurface.skin(root,KEY+"competition-rim"+str(side),func(u: float,v: float) -> Vector3:
		var a: float = u*TAU
		var q: Vector2 = CompactKitSurface.contour(rim,v,0.003)
		return Vector3(side*q.x,sin(a)*q.y,cos(a)*q.y),white,32,16)
	var hub := CompactKits._cylinder(root,0.077,0.067,Vector3(side*0.120,0,0),white,12)
	hub.rotation.z = PI*0.5
	var spokes: int = 5 if kind in ["five","dish"] else 3 if kind == "tri" else 10 if kind in ["ten","mesh"] else 6
	for index: int in range(spokes):
		var a: float = index*TAU/float(spokes)
		var spoke := VisualGeometry.box(root,Vector3(0.032,0.046,0.182),Vector3(side*0.131,sin(a)*0.156,cos(a)*0.156),white)
		spoke.rotation.x = -a
		var bolt := CompactKits._cylinder(root,0.009,0.006,Vector3(side*0.157,sin(a)*0.054,cos(a)*0.054),steel,8)
		bolt.rotation.z = PI*0.5
	var cap := CompactKits._cylinder(root,0.031,0.006,Vector3(side*0.158,0,0),dark,12)
	cap.rotation.z = PI*0.5

static func _factory_wheel(root: Node3D, side: float) -> void:
	var alloy := CompactFinish.alloy(Color("9aa4a7"))
	alloy.roughness = 0.25
	var barrel := CompactFinish.alloy(Color("3b4549"))
	barrel.roughness = 0.40
	var rotor := CompactFinish.alloy(Color("4c5659"))
	rotor.roughness = 0.49
	var dark := CompactFinish.rubber(Color("172025"))
	var rim: Array[Vector2] = [Vector2(0.065,0.226),Vector2(0.069,0.248),Vector2(0.143,0.248),Vector2(0.157,0.242),Vector2(0.159,0.232),Vector2(0.150,0.224)]
	CompactKitSurface.skin(root,KEY+"forged-barrel"+str(side),func(u: float,v: float) -> Vector3:
		var q: Vector2 = CompactKitSurface.contour(rim,v,0.002)
		return Vector3(side*q.x,sin(u*TAU)*q.y,cos(u*TAU)*q.y),barrel,64,8)
	var lip: Array[Vector2] = [Vector2(0.146,0.242),Vector2(0.154,0.246),Vector2(0.160,0.240),Vector2(0.158,0.234),Vector2(0.151,0.233)]
	CompactKitSurface.skin(root,KEY+"turned-rim-lip"+str(side),func(u: float,v: float) -> Vector3:
		var q: Vector2 = CompactKitSurface.contour(lip,v,0.0015)
		return Vector3(side*q.x,sin(u*TAU)*q.y,cos(u*TAU)*q.y),alloy,64,8)
	_patch(root,"ventilated-brake-disc"+str(side),func(u: float,v: float) -> Vector3:
		var r: float = lerpf(0.076,0.185,v)
		return Vector3(side*0.092,sin(u*TAU)*r,cos(u*TAU)*r),rotor,Vector3(side,0,0),64,4)
	for spoke: int in range(5):
		for fork: float in [-1.0,1.0]:
			var base: float = spoke*TAU/5.0
			CompactKitSurface.solid(root,KEY+"forged-spoke"+str(side)+str(spoke)+str(fork),func(u: float,v: float) -> Vector3:
				var r: float = lerpf(0.061,0.236,u)
				var angle: float = base+fork*(0.055+0.095*smoothstep(0.1,1.0,u))+0.055*sin(u*PI)
				var breadth: float = lerpf(0.012,0.009,u)
				var x: float = lerpf(0.119,0.153,pow(u,0.72))
				var section: Array[Vector2] = [Vector2(-breadth,-0.008),Vector2(breadth,-0.008),Vector2(breadth,0.006),Vector2(-breadth,0.006)]
				var q: Vector2 = CompactKitSurface.contour(section,v,0.002)
				return Vector3(side*(x+q.y),sin(angle)*r+cos(angle)*q.x,cos(angle)*r-sin(angle)*q.x),alloy,16,8)
	var hub := CompactKits._cylinder(root,0.072,0.025,Vector3(side*0.126,0,0),alloy,32)
	hub.rotation.z = PI*0.5
	for bolt: int in range(5):
		var a: float = bolt*TAU/5.0
		var lug := CompactKits._cylinder(root,0.008,0.008,Vector3(side*0.145,sin(a)*0.050,cos(a)*0.050),barrel,8)
		lug.rotation.z = PI*0.5
	var cap := CompactKits._cylinder(root,0.027,0.005,Vector3(side*0.143,0,0),dark,24)
	cap.rotation.z = PI*0.5
