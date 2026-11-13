class_name SuperRallyModel
extends RefCounted
## Complete original 1970s C3-style coupe; -Z is the long nose.
## Presentation only: Rally-like canonical handling and wheel contacts stay unchanged.
const KEY: String = "super-rally-classic-c3-1/"
static var meshes: Dictionary = {}
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
	var stations: Array[Vector2] = [Vector2(-2.65,0.68),Vector2(-2.26,0.90),Vector2(-1.28,1.005),Vector2(-0.64,0.88),Vector2(0.12,0.815),Vector2(0.80,0.965),Vector2(1.30,1.025),Vector2(1.88,0.955),Vector2(2.20,0.835)]
	for index: int in range(stations.size()-1):
		if z <= stations[index+1].x: return lerpf(stations[index].y,stations[index+1].y,smoothstep(stations[index].x,stations[index+1].x,z))
	return stations.back().y

static func deck_y(z: float, across: float) -> float:
	var base: float = 0.675+0.125*smoothstep(-2.65,-0.74,z)
	var bulge: float = 0.24*exp(-pow((z+1.28)/0.62,2))+0.20*exp(-pow((z-1.30)/0.66,2))
	return base+bulge*exp(-pow((absf(across)-0.84)/0.27,2))-0.028*pow(absf(across),8)

static func _bottom(z: float) -> float:
	var y: float = 0.285
	for axle: float in [-1.28,1.28]:
		var delta: float = absf(z-axle)
		if delta < 0.414: y = maxf(y,0.37+sqrt(0.414*0.414-delta*delta))
	return y

static func _side(side: float, z: float, y: float) -> Vector3:
	var t: float = clampf((y-_bottom(z))/maxf(0.01,deck_y(z,1)-_bottom(z)),0,1)
	return Vector3(side*(width(z)-0.11*pow(1-t,2)),y,z)

static func hood_point(across: float, v: float, kind: String = "stock") -> Vector3:
	var front: float = -2.64+0.16*across*across
	var z: float = lerpf(front,-0.70,v)
	var power: float = 0.035 if kind == "stock" else 0.095 if kind in ["dome","vented","cowl"] else 0.055
	var rise: float = power*exp(-pow(across/0.32,4))*smoothstep(0.12,0.32,v)*(1-smoothstep(0.78,1,v))
	if kind == "ribs":
		for ridge: float in [-0.28,0.0,0.28]: rise += 0.018*exp(-pow((across-ridge)/0.035,4))*smoothstep(0.12,0.30,v)*(1-smoothstep(0.82,1,v))
	return Vector3(across*width(z),deck_y(z,across)+rise,z)

static func roof_point(across: float, v: float) -> Vector3:
	return Vector3(across*(0.535+0.020*sin(v*PI)),1.285+0.022*sin(v*PI)-0.045*across*across,lerpf(-0.25,0.69,v))

static func build(car: CarVisual) -> void:
	CompactKits.simple_parts = car.simple_model
	car.body = Node3D.new(); car.body.name = "ClassicStingrayCoupe"; car.add_child(car.body)
	var paint: Material = CompactFinish.paint(Color("b73528"))
	var accent: Material = CompactFinish.paint(Color("20272a"))
	var alloy: Material = CompactFinish.alloy(Color("a3aba9"))
	var dark: Material = CompactFinish.rubber(Color("182125"))
	var glass: StandardMaterial3D = VisualGeometry.material(Color("172d38")); glass.roughness = 0.19; glass.metallic = 0.18
	car.paint_materials = {"body":paint,"accent":accent,"detail":alloy}
	car.brake_material = VisualGeometry.material(Color("802d2b"))
	_patch(car.body,"C3Underbody",func(u: float,v: float) -> Vector3:
		var z: float = lerpf(-2.47,2.17,v)
		return Vector3((u*2-1)*(width(z)-0.11),0.285,z),car.underside_material,Vector3.DOWN,24,24)
	for side: float in [-1.0,1.0]:
		_patch(car.body,"C3SculptedSide"+str(side),func(u: float,v: float) -> Vector3:
			var z: float = lerpf(-2.48,2.20,u)
			return _side(side,z,lerpf(_bottom(z),deck_y(z,1),v)),paint,Vector3(side,0,0),112,14)
		for axle: float in [-1.28,1.28]:
			_curve(car.body,"C3ArchLip"+str(side)+str(axle),func(t: float) -> Vector3:
				var angle: float = lerpf(-0.11,PI+0.11,t)
				var z: float = axle+cos(angle)*0.414
				var p: Vector3 = _side(side,z,0.37+sin(angle)*0.414)
				return p+Vector3(side*0.008,0,0),0.009,dark,32)
		_curve(car.body,"C3Rocker"+str(side),func(t: float) -> Vector3:
			var z: float = lerpf(-0.80,0.81,t)
			return _side(side,z,0.34)+Vector3(side*0.012,0,0),0.014,alloy,24)
	_patch(car.body,"C3CowlUnderCabin",func(u: float,v: float) -> Vector3:
		var z: float = lerpf(-0.70,1.10,v); var x: float = u*2-1
		return Vector3(x*width(z),deck_y(z,x),z),paint,Vector3.UP,48,28)
	_patch(car.body,"C3RearDeck",func(u: float,v: float) -> Vector3:
		var z: float = lerpf(1.10,2.20,v); var x: float = u*2-1
		return Vector3(x*width(z),deck_y(z,x),z),paint,Vector3.UP,48,24)
	_patch(car.body,"C3SharkNose",func(u: float,v: float) -> Vector3:
		var x: float = u*2-1; var top: Vector3 = hood_point(x,0)
		return Vector3(top.x,lerpf(0.32,top.y,v),top.z+0.040*(1-v)),paint,Vector3.FORWARD,56,14)
	_patch(car.body,"C3TailPanel",func(u: float,v: float) -> Vector3:
		var x: float = (u*2-1)*0.835
		return Vector3(x,lerpf(0.33,deck_y(2.20,u*2-1),v),2.20-0.045*pow(absf(x)/0.835,4)),paint,Vector3.BACK,48,12)
	_patch(car.body,"C3LowerGrille",func(u: float,v: float) -> Vector3:
		var across: float = lerpf(-0.82,0.82,u); var p: Vector3 = hood_point(across,0)
		return Vector3(p.x,lerpf(0.372,0.490,v),p.z-0.007),dark,Vector3.FORWARD,32,4)
	for side: float in [-1.0,1.0]:
		_curve(car.body,"C3FrontChrome"+str(side),func(t: float) -> Vector3:
			var p: Vector3 = hood_point(side*lerpf(0.10,0.98,t),0)
			return Vector3(p.x,0.345,p.z-0.024),0.019,alloy,24)
		_curve(car.body,"C3RearChrome"+str(side),func(t: float) -> Vector3:
			var x: float = side*lerpf(0.26,0.82,t)
			return Vector3(x,0.365,2.22-0.045*pow(absf(x)/0.835,4)),0.022,alloy,20)
		for x: float in [0.465,0.715]:
			var rim := CompactKits._cylinder(car.body,0.111,0.033,Vector3(side*x,0.623,2.204),alloy,20); rim.rotation.x = PI*0.5
			var lens := CompactKits._cylinder(car.body,0.091,0.026,Vector3(side*x,0.623,2.228),car.brake_material,20); lens.rotation.x = PI*0.5; car.brake_lights.append(lens)
		_box(car.body,"C3SideVent"+str(side),Vector3(side*0.906,0.660,-0.73),Vector3(0.024,0.198,0.32),dark,0.006)
		for slat: int in range(4):
			_box(car.body,"C3SideVentBar"+str(side)+str(slat),Vector3(side*0.923,0.660,-0.845+slat*0.076),Vector3(0.021,0.17,0.010),alloy,0.003)
		var exhaust := CompactKits._cylinder(car.body,0.043,1.55,Vector3(side*0.885,0.30,0.03),alloy,12); exhaust.rotation.x = PI*0.5
	_box(car.body,"C3RearPlate",Vector3(0,0.575,2.236),Vector3(0.33,0.15,0.012),dark,0.005)
	_cabin(car,paint,accent,dark,glass,alloy)
	for side: float in [-1.0,1.0]:
		for axle: float in [-1.28,1.28]:
			var pivot := Node3D.new(); pivot.position = Vector3(side*0.83,0.37,axle); car.add_child(pivot)
			CompactDetail.tire(pivot,dark,car.simple_model)
			var frame: Node3D = car.new_kit_frame("rims",pivot) if car.editable_kits else pivot
			wheel(frame,side,str(car.customisation.rims))
			if axle < 0: car.front_wheels.append(pivot)
			car.register_rolling_wheel(pivot,0.37)
			CompactKits.build_caliper(pivot,side)
	for category: String in ["hood","aero","body"]: kit(car,category)

static func _cabin(car: CarVisual, paint: Material, accent: Material, dark: Material, glass: Material, alloy: Material) -> void:
	_patch(car.body,"C3LowRoof",func(u: float,v: float) -> Vector3: return roof_point(u*2-1,v),paint,Vector3.UP,40,24)
	for side: float in [-1.0,1.0]:
		_patch(car.body,"C3Ttop"+str(side),func(u: float,v: float) -> Vector3:
			return roof_point(side*lerpf(0.085,0.955,u),lerpf(0.065,0.94,v))+Vector3.UP*0.004,accent,Vector3.UP,20,20)
	var windscreen: Callable = func(u: float,v: float) -> Vector3:
		var x: float = u*2-1; var bottom := Vector3(x*0.69,0.800+0.015*x*x,-0.70+0.09*x*x)
		return bottom.lerp(roof_point(x,0),v)+Vector3(0,0.006*sin(v*PI),-0.006)
	_patch(car.body,"C3CurvedWindscreen",windscreen,glass,Vector3(0,0.7,-0.7),40,20)
	for v: float in [0.0,1.0]: _curve(car.body,"C3ScreenEdge"+str(v),func(u: float) -> Vector3: return windscreen.call(u,v),0.012,dark,40)
	_patch(car.body,"C3RecessedRearWindow",func(u: float,v: float) -> Vector3:
		var x: float = (u*2-1)*lerpf(0.57,0.51,v)
		return Vector3(x,lerpf(0.84,1.23,v),lerpf(1.08,0.735,v)),glass,Vector3(0,0.5,0.8),32,14)
	for side: float in [-1.0,1.0]:
		var a := Vector3(side*0.70,0.82,-0.61); var b := Vector3(side*0.715,0.84,1.025)
		var c := Vector3(side*0.535,1.24,-0.235); var d := Vector3(side*0.555,1.245,0.67)
		_patch(car.body,"C3LongDoorGlass"+str(side),func(u: float,v: float) -> Vector3: return a.lerp(b,u).lerp(c.lerp(d,u),v),glass,Vector3(side,0.3,0),36,16)
		_curve(car.body,"C3Apillar"+str(side),func(t: float) -> Vector3: return a.lerp(c,t),0.026,paint,16)
		_curve(car.body,"C3WindowSill"+str(side),func(t: float) -> Vector3: return a.lerp(b,t),0.019,paint,24)
		_curve(car.body,"C3WindowHeader"+str(side),func(t: float) -> Vector3: return c.lerp(d,t),0.023,paint,24)
		var tip := Vector3(side*0.895,0.915,1.55)
		var sail: Callable = func(u: float,v: float) -> Vector3:
			return d.lerp(tip,u).lerp(b.lerp(tip,u),v)+Vector3(side*0.012*sin(u*PI)*sin(v*PI),0.015*sin(u*PI)*(1-v),0)
		_patch(car.body,"C3IntegralRearSail"+str(side),sail,paint,Vector3(side,0.2,0),28,14)
		_patch(car.body,"C3RearSailInner"+str(side),func(u: float,v: float) -> Vector3:
			return (sail.call(u,v) as Vector3)-Vector3(side*0.050,0,0),paint,Vector3(-side,0.2,0),28,14)
		_patch(car.body,"C3RearSailCrown"+str(side),func(u: float,v: float) -> Vector3:
			return (sail.call(u,0) as Vector3)-Vector3(side*0.050*v,0,0),paint,Vector3.UP,28,4)
		_curve(car.body,"C3Bpillar"+str(side),func(t: float) -> Vector3: return b.lerp(d,t),0.044,paint,18)
		_box(car.body,"C3MirrorStem"+str(side),Vector3(side*0.79,0.90,-0.49),Vector3(0.13,0.025,0.04),alloy,0.004)
		_box(car.body,"C3Mirror"+str(side),Vector3(side*0.865,0.93,-0.49),Vector3(0.09,0.09,0.17),paint,0.025)
		_box(car.body,"C3DoorHandle"+str(side),_side(side,0.66,0.755)+Vector3(side*0.015,0,0),Vector3(0.025,0.028,0.15),alloy,0.005)
		var outline: Array[Vector2] = [Vector2(-0.62,0.81),Vector2(0.98,0.84),Vector2(0.76,0.35),Vector2(-0.75,0.35),Vector2(-0.62,0.81)]
		for index: int in range(outline.size()-1):
			var p: Vector2 = outline[index]; var q: Vector2 = outline[index+1]
			_curve(car.body,"C3DoorGap"+str(side)+str(index),func(t: float) -> Vector3:
				var point: Vector2 = p.lerp(q,t); return _side(side,point.x,point.y)+Vector3(side*0.004,0,0),0.003,dark,16)

static func kit(car: CarVisual, category: String) -> void:
	CompactKits.simple_parts = car.simple_model
	var kind: String = str(car.customisation.get(category,"stock"))
	if category == "rims":
		for rotor: Node3D in car.rolling_wheels:
			var frame: Node3D = car.new_kit_frame("rims",rotor) if car.editable_kits else rotor
			wheel(frame,signf((rotor.get_parent() as Node3D).position.x),kind)
		return
	var root: Node3D = car.new_kit_frame(category,car.body) if car.editable_kits else Node3D.new()
	if not car.editable_kits: root.name = "ClassicKit_"+category; car.body.add_child(root)
	if category == "hood": hood(root,car.paint_materials.body,car.paint_materials.accent,kind)
	elif category == "aero": aero(root,car.paint_materials.body,car.paint_materials.accent,kind)
	elif category == "body": body(root,car.paint_materials.body,car.paint_materials.accent,kind)

static func hood(root: Node3D, paint: Material, accent: Material, kind: String = "stock") -> void:
	var dark: Material = CompactFinish.rubber(Color("152024"))
	var holes: Array[Rect2] = []
	if kind in ["louvres","vented"]: holes = [Rect2(0.16,0.44,0.15,0.25),Rect2(0.69,0.44,0.15,0.25)]
	if kind == "extractor": holes = [Rect2(0.33,0.44,0.34,0.28)]
	_patch(root,"C3LongBonnet_"+kind,func(u: float,v: float) -> Vector3: return hood_point(u*2-1,v,kind),paint,Vector3.UP,72,32,holes)
	for side: float in [-1.0,1.0]:
		var corners: Array[Vector2] = [Vector2(side*0.44,0.21),Vector2(side*0.78,0.21),Vector2(side*0.78,0.405),Vector2(side*0.44,0.405),Vector2(side*0.44,0.21)]
		for index: int in range(4):
			var a: Vector2 = corners[index]; var b: Vector2 = corners[index+1]
			_curve(root,"C3ClosedHeadlightGap"+str(side)+str(index),func(t: float) -> Vector3:
				var q: Vector2 = a.lerp(b,t); return hood_point(q.x,q.y,kind)+Vector3.UP*0.003,0.0025,dark,10)
	for index: int in range(holes.size()):
		var hole: Rect2 = holes[index]
		_patch(root,"C3HeatOutlet"+str(index)+kind,func(u: float,v: float) -> Vector3: return hood_point(lerpf(hole.position.x,hole.end.x,u)*2-1,lerpf(hole.position.y,hole.end.y,v),kind)-Vector3.UP*0.020,dark,Vector3.UP,10,6)
		for slat: int in range(5):
			var v: float = lerpf(hole.position.y,hole.end.y,slat/4.0)
			_curve(root,"C3HeatVane"+str(index)+str(slat)+kind,func(t: float) -> Vector3: return hood_point(lerpf(hole.position.x,hole.end.x,t)*2-1,v,kind)+Vector3.UP*0.005,0.006,paint,10)
	if kind in ["scoop","twin_scoop","reverse","cowl"]:
		var height: float = 0.055 if kind == "cowl" else 0.10
		var centers: Array[float] = []
		centers.assign([-0.22,0.22] if kind == "twin_scoop" else [0.0])
		for x: float in centers:
			var at: Vector3 = hood_point(x,0.80 if kind == "cowl" else 0.60,kind)+Vector3.UP*height*0.45
			var breadth: float = 0.22 if kind == "twin_scoop" else 0.38
			_box(root,"C3Induction_"+kind+str(x),at,Vector3(breadth,height,0.52),accent,0.025)
			_box(root,"C3InductionMouth_"+kind+str(x),at+Vector3(0,0.003,0.263 if kind in ["reverse","cowl"] else -0.263),Vector3(breadth*0.78,height*0.60,0.012),dark,0.006)

static func aero_extent(kind: String) -> Vector2:
	var profile: Vector4 = AERO.get(kind,Vector4(0,0,0,0))
	return Vector2(profile.x+0.02,profile.y+0.09)

static func aero(root: Node3D, paint: Material, accent: Material, kind: String = "stock") -> void:
	if kind == "stock": return
	var profile: Vector4 = AERO[kind]
	var wing: bool = profile.y > 1.0
	var height: float = profile.y
	if wing:
		for side: float in [-1.0,1.0]: _beam(root,"C3DeckWingLeg"+str(side)+kind,Vector3(side*0.46,0.82,minf(2.13,profile.z)),Vector3(side*0.46,height-0.02,profile.z),0.018,0.035,paint)
	var spans: Array[Vector2] = [Vector2(-profile.x,profile.x)]
	if kind == "splitwing": spans = [Vector2(-profile.x,-0.065),Vector2(0.065,profile.x)]
	for span: Vector2 in spans:
		_patch(root,"C3RearAero"+kind+str(span.x),func(u: float,v: float) -> Vector3:
			var x: float = lerpf(span.x,span.y,u); var angle: float = v*TAU
			return Vector3(x,height+0.025*sin(angle)+0.023*pow(x/profile.x,2),profile.z+profile.w*cos(angle)),accent,Vector3.UP,32,12,[],func(_u: float,v: float) -> Vector3: return Vector3(0,sin(v*TAU)/0.025,cos(v*TAU)/profile.w).normalized())
	if kind == "biwing": _box(root,"C3LowerWing",Vector3(0,height-0.15,profile.z-0.04),Vector3(profile.x*1.85,0.035,0.22),paint)
	if wing:
		for side: float in [-1.0,1.0]: _box(root,"C3WingEnd"+kind+str(side),Vector3(side*profile.x,height+0.005,profile.z),Vector3(0.018,0.13,profile.w*1.95),paint,0.010)

static func body(root: Node3D, paint: Material, accent: Material, kind: String = "stock") -> void:
	if kind == "stock": return
	var ordinal: int = maxi(0,["street","rally","club","heritage","touring","wide","endurance","gravel","urban"].find(kind))
	var depth: float = 0.035+0.01*ordinal
	for side: float in [-1.0,1.0]:
		_box(root,"C3FittedSill"+kind+str(side),Vector3(side*(0.825+depth*0.3),0.29,0.03),Vector3(depth+0.055,0.065+0.004*ordinal,1.60),paint,0.015)
	_box(root,"C3FittedSplitter"+kind,Vector3(0,0.277,-2.49),Vector3(1.65+depth,0.030,0.24+depth),accent,0.012)
	if kind in ["wide","rally","gravel"]:
		for side: float in [-1.0,1.0]:
			for axle: float in [-1.28,1.28]:
				_curve(root,"C3FittedArch"+kind+str(side)+str(axle),func(t: float) -> Vector3:
					var a: float = t*PI; var z: float = axle+cos(a)*0.445
					return Vector3(side*(width(z)+0.018),0.37+sin(a)*0.445,z),0.025+depth*0.15,paint,36)
	if kind in ["rally","gravel"]:
		var rubber: Material = CompactFinish.rubber(Color("192125"))
		for side: float in [-1.0,1.0]:
			for axle: float in [-1.28,1.28]: _box(root,"C3Mudflap"+kind+str(side)+str(axle),Vector3(side*0.86,0.335,axle+0.38),Vector3(0.23,0.43,0.024),rubber,0.006)

static func night_lens(root: Node3D, lens: Material, paint: Material) -> void:
	var dark: Material = CompactFinish.rubber(Color("132025"))
	for side: float in [-1.0,1.0]:
		var at: Vector3 = hood_point(side*0.62,0.325)
		_box(root,"C3RaisedPopUp"+str(side),Vector3(at.x,at.y+0.115,at.z),Vector3(0.35,0.21,0.28),paint,0.028)
		_box(root,"C3HeadlampPanel"+str(side),Vector3(at.x,at.y+0.12,at.z-0.15),Vector3(0.31,0.16,0.018),dark,0.010)
		for delta: float in [-0.080,0.080]:
			var bulb := CompactKits._cylinder(root,0.063,0.018,Vector3(at.x+delta,at.y+0.12,at.z-0.166),lens,16); bulb.rotation.x = PI*0.5; bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

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
	var white: Material = CompactFinish.alloy(Color("b9bbb4" if kind == "stock" else "e5e5db" if kind == "rallydisc" else "929a9c"))
	var dark: Material = CompactFinish.rubber(Color("192125"))
	var steel: Material = CompactFinish.alloy(Color("8c9698"))
	# A compact closed annular rim plus six open spokes; no high-density forged
	# accessory mesh is needed for the factory competition wheel.
	var rim: Array[Vector2] = [Vector2(0.095,0.230),Vector2(0.106,0.249),Vector2(0.151,0.249),Vector2(0.158,0.239),Vector2(0.149,0.224),Vector2(0.112,0.224)]
	CompactKitSurface.skin(root,KEY+"competition-rim"+str(side),func(u: float,v: float) -> Vector3:
		var a: float = u*TAU
		var q: Vector2 = CompactKitSurface.contour(rim,v,0.003)
		return Vector3(side*q.x,sin(a)*q.y,cos(a)*q.y),white,32,16)
	if kind == "stock":
		var slots: Array[Rect2] = []
		for slot: int in range(5): slots.append(Rect2(slot/5.0+0.035,0.53,0.125,0.37))
		_patch(root,"C3FiveSlotRallyWheel"+str(side),func(u: float,v: float) -> Vector3:
			var angle: float = u*TAU; var radius: float = lerpf(0.070,0.232,v)
			return Vector3(side*(0.121+0.030*v*v),sin(angle)*radius,cos(angle)*radius),white,Vector3(side,0,0),60,12,slots)
	var hub := CompactKits._cylinder(root,0.077,0.067,Vector3(side*0.120,0,0),white,12)
	hub.rotation.z = PI*0.5
	var spokes: int = 0 if kind == "stock" else 5 if kind in ["five","dish"] else 3 if kind == "tri" else 10 if kind in ["ten","mesh"] else 6
	for index: int in range(spokes):
		var a: float = index*TAU/float(spokes)
		var spoke := VisualGeometry.box(root,Vector3(0.032,0.046,0.182),Vector3(side*0.131,sin(a)*0.156,cos(a)*0.156),white)
		spoke.rotation.x = -a
		var bolt := CompactKits._cylinder(root,0.009,0.006,Vector3(side*0.157,sin(a)*0.054,cos(a)*0.054),steel,8)
		bolt.rotation.z = PI*0.5
	if kind == "stock":
		var hubcap := CompactKits._cylinder(root,0.092,0.018,Vector3(side*0.158,0,0),steel,20); hubcap.rotation.z = PI*0.5
	var cap := CompactKits._cylinder(root,0.024 if kind == "stock" else 0.031,0.006,Vector3(side*0.170 if kind == "stock" else side*0.158,0,0),dark,12)
	cap.rotation.z = PI*0.5
