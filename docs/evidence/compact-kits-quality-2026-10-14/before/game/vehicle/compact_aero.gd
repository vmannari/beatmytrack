class_name CompactAero
extends RefCounted
## Original silhouette collection. Coordinates are the compact's unscaled metres.
## Rear mounts land on painted hatch metal below the glazing, not on its glass.
const PROFILES: Dictionary = {
	"ducktail":{"center":Vector3(0,1.055,2.020),"half":0.70,"chord":0.12,"rise":0.025,"sweep":0.005,"thickness":0.010,"rake":0.055,"taper":0.16,"mount":"integral"},
	"touring":{"center":Vector3(0,1.125,2.115),"half":0.73,"chord":0.145,"rise":0.065,"sweep":0.055,"thickness":0.019,"rake":0.028,"taper":0.36,"mount":"integral"},
	"pedestal":{"center":Vector3(0,1.255,2.215),"half":0.85,"chord":0.155,"rise":0.006,"sweep":0.010,"thickness":0.023,"rake":0.025,"taper":0.08,"mount":"rear","mount_x":0.46},
	"swan":{"center":Vector3(0,1.840,1.465),"half":0.88,"chord":0.190,"rise":0.032,"sweep":-0.045,"thickness":0.020,"rake":0.026,"taper":0.26,"mount":"roof"},
	"biwing":{"center":Vector3(0,1.510,2.240),"half":0.81,"chord":0.150,"rise":0.005,"sweep":0.020,"thickness":0.020,"rake":0.025,"taper":0.13,"mount":"rear","mount_x":0.52},
	"rallywing":{"center":Vector3(0,1.555,1.950),"half":0.82,"chord":0.170,"rise":0.175,"sweep":-0.050,"thickness":0.025,"rake":0.035,"taper":0.05,"mount":"roof"},
	"endurance":{"center":Vector3(0,1.390,2.345),"half":0.93,"chord":0.240,"rise":0.015,"sweep":0.045,"thickness":0.025,"rake":0.032,"taper":0.13,"mount":"rear","mount_x":0.55},
	"whale":{"center":Vector3(0,1.185,2.195),"half":0.79,"chord":0.260,"rise":0.085,"sweep":0.030,"thickness":0.033,"rake":0.055,"taper":-0.18,"mount":"integral"},
	"drag":{"center":Vector3(0,1.055,2.300),"half":0.77,"chord":0.285,"rise":0.0,"sweep":-0.025,"thickness":0.012,"rake":0.006,"taper":0.05,"mount":"rear","mount_x":0.47},
	"splitwing":{"center":Vector3(0,1.315,2.250),"half":0.85,"chord":0.185,"rise":-0.075,"sweep":0.080,"thickness":0.022,"rake":0.027,"taper":0.32,"mount":"rear","mount_x":0.45}}

static func roll_extent(kind: String) -> Vector2:
	var p: Dictionary = PROFILES[kind]
	var center: Vector3 = p.center
	return Vector2(float(p.half)+0.055,center.y+maxf(0,float(p.rise))+0.14)

static func mount_point(kind: String, side: float) -> Vector3:
	var p: Dictionary = PROFILES[kind]
	if p.mount=="roof": return CompactCoachwork.roof_point(side*0.87,0.94)
	var x: float = side*float(p.get("mount_x",0.50))
	return Vector3(x,0.976,CompactCoachwork.rear_skin(x,0.976))

static func blade_point(kind: String, x: float, ring: float, layer: int = 0) -> Vector3:
	var p: Dictionary = PROFILES[kind]
	var center: Vector3 = p.center
	var edge: float = pow(absf(x)/float(p.half),2)
	var angle: float = ring*TAU
	if kind=="biwing" and layer==1: center += Vector3(0,-0.185,-0.060)
	var y: float = center.y+float(p.rise)*edge+float(p.rake)*cos(angle)+float(p.thickness)*sin(angle)-0.010*sin(angle)*sin(angle)
	var z: float = center.z+float(p.sweep)*edge+cos(angle)*float(p.chord)*(1-float(p.taper)*edge)
	if kind=="ducktail": z += CompactCoachwork.rear_skin(x,0.985)-CompactCoachwork.rear_skin(0,0.985)
	if kind=="drag": y = center.y+float(p.thickness)*signf(sin(angle))*pow(absf(sin(angle)),0.25)
	return Vector3(x,y,z)

static func build(root: Node3D, kind: String, paint: Material, trim: Material, metal: Material) -> void:
	var p: Dictionary = PROFILES[kind]
	var center: Vector3 = p.center
	var prefix: String = "aero4/"+kind+"/"
	var half: float = p.half
	if p.mount=="integral": _foundation(root,kind,prefix,paint)
	elif p.mount=="rear":
		for side: float in [-1,1]:
			var mount: Vector3 = mount_point(kind,side)
			_rear_saddle(root,prefix+str(side)+"/",mount,trim,metal)
			var target: Vector3 = Vector3(mount.x,center.y-0.021,center.z-0.012)
			if kind=="splitwing": target.y -= 0.026
			_support(root,prefix+str(side)+"/upright",mount+Vector3(0,0,0.023),target,0.015,0.030,metal,0.0)
			if kind in ["endurance","biwing"]:
				_support(root,prefix+str(side)+"/brace",mount+Vector3(0,-0.045,0.030),target-Vector3(0,0.015,0.105),0.009,0.014,trim,-0.035)
	else:
		for side: float in [-1,1]:
			var mount: Vector3 = mount_point(kind,side)
			CompactKits._rounded_box(root,prefix+str(side)+"/seal",mount+Vector3.UP*0.005,Vector3(0.15,0.012,0.18),0.005,trim)
			CompactKits._rounded_box(root,prefix+str(side)+"/saddle",mount+Vector3.UP*0.017,Vector3(0.12,0.024,0.15),0.009,metal)
			var target: Vector3 = Vector3(mount.x,center.y+float(p.rise)*pow(absf(mount.x)/half,2),center.z)
			if kind=="swan":
				target.y += 0.060
				_support(root,prefix+str(side)+"/neck",mount+Vector3.UP*0.029,target,0.013,0.029,trim,-0.145)
				CompactKits._rounded_box(root,prefix+str(side)+"/upperclamp",target-Vector3.UP*0.026,Vector3(0.052,0.073,0.115),0.014,metal)
			else:
				target.x = side*0.76
				target.y = center.y+float(p.rise)*pow(0.76/half,2)-0.020
				_support(root,prefix+str(side)+"/hoopleg",mount+Vector3.UP*0.029,target,0.024,0.054,paint,0.035)
			for z: float in [-0.045,0.045]: CompactKits._cylinder(root,0.008,0.004,mount+Vector3(0,0.032,z),metal,10)
	if kind=="splitwing":
		_blade(root,prefix+"left",kind,-half,-0.14,paint)
		_blade(root,prefix+"right",kind,0.14,half,paint)
	else:
		_blade(root,prefix+"blade",kind,-half,half,paint)
	if kind=="biwing": _blade(root,prefix+"lower",kind,-half*0.94,half*0.94,paint,1)
	if kind in ["pedestal","endurance","biwing","swan"]:
		for side: float in [-1,1]:
			var tip: Vector3 = blade_point(kind,side*half,0.25)
			var height: float = 0.285 if kind=="biwing" else 0.17 if kind=="endurance" else 0.135
			var plate_center := Vector3(side*(half+0.011),tip.y-(0.085 if kind=="biwing" else 0.006),center.z+float(p.sweep))
			var outline: Array[Vector2] = [Vector2(-height*0.5,-float(p.chord)),Vector2(height*0.5,-float(p.chord)*0.72),Vector2(height*0.40,float(p.chord)*0.95),Vector2(-height*0.5,float(p.chord)*(1.08 if kind=="endurance" else 1.15))]
			_plate(root,prefix+"end"+str(side),plate_center,outline,0.019,trim)
			for z: float in [-0.062,0.068]:
				var bolt := CompactKits._cylinder(root,0.0065,0.004,Vector3(side*(half+0.023),tip.y-0.006,plate_center.z+z),metal,8)
				bolt.rotation.z = PI*0.5
	if kind in ["drag","endurance"]:
		var lip_center := Vector3(0,center.y+0.025,center.z+float(p.chord)*0.98)
		CompactKits._rounded_box(root,prefix+"gurney",lip_center,Vector3(half*1.87,0.040,0.012),0.005,trim)

static func _support(root: Node3D, key: String, start: Vector3, finish: Vector3, width: float, depth: float, material: Material, bend: float) -> void:
	CompactKits._patch(root,key,func(u: float,v: float) -> Vector3:
		var p: Vector3 = start.lerp(finish,u)
		p.z += sin(u*PI)*bend
		var tangent: Vector3 = (finish-start+Vector3(0,0,cos(u*PI)*PI*bend)).normalized()
		var normal: Vector3 = Vector3.RIGHT.cross(tangent).normalized()
		return p+Vector3.RIGHT*cos(v*TAU)*width+normal*sin(v*TAU)*depth,material,Vector3.ZERO,20,12,true)

static func _rear_saddle(root: Node3D, key: String, mount: Vector3, trim: Material, metal: Material) -> void:
	# Both curved faces follow the actual rear metal, well below the hatch glass.
	for surface: Array in [["seal",0.007,trim,0.096,0.091],["plate",0.016,metal,0.078,0.075]]:
		_pad(root,key+str(surface[0]),mount,float(surface[3]),float(surface[4]),0.001 if surface[0]=="seal" else 0.007,float(surface[1]),surface[2])
	for y: float in [-0.025,0.025]:
		var at := Vector3(mount.x,mount.y+y,CompactCoachwork.rear_skin(mount.x,mount.y+y)+0.021)
		var bolt := CompactKits._cylinder(root,0.0075,0.005,at,metal,10)
		bolt.rotation.x = PI*0.5

static func _pad(root: Node3D, key: String, mount: Vector3, width: float, height: float, back: float, front: float, material: Material) -> void:
	if CompactKits.simple_parts: key += "/simple"
	CompactKits._load_prepared(key)
	if not CompactKits.meshes.has(key):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var point: Callable = func(u: float,v: float,depth: float,inset: float = 0.0) -> Vector3:
			var x: float = mount.x+(u-0.5)*(width-inset*2)
			var y: float = mount.y+(v-0.5)*(height-inset*2)
			return Vector3(x,y,CompactCoachwork.rear_skin(x,y)+depth)
		var count: int = 3 if CompactKits.simple_parts else 6
		for face: int in [0,1]:
			for row: int in range(count):
				for column: int in range(count):
					var u: float = column/float(count)
					var v: float = row/float(count)
					var step: float = 1.0/count
					var depth: float = back if face==0 else front
					var inset: float = 0.0 if face==0 else 0.002
					var a: Vector3 = point.call(u,v,depth,inset)
					var b: Vector3 = point.call(u+step,v,depth,inset)
					var c: Vector3 = point.call(u+step,v+step,depth,inset)
					var d: Vector3 = point.call(u,v+step,depth,inset)
					var normal: Vector3 = (b-a).cross(d-a).normalized()*(1 if face==1 else -1)
					_triangle(tool,a,b,c,normal)
					_triangle(tool,a,c,d,normal)
		var corners: Array[Vector2] = [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]
		for edge: int in range(4):
			for segment: int in range(count):
				var a: Vector2 = corners[edge].lerp(corners[(edge+1)%4],segment/float(count))
				var b: Vector2 = corners[edge].lerp(corners[(edge+1)%4],(segment+1)/float(count))
				for bevel: int in [0,1]:
					var low: float = back if bevel==0 else front-0.002
					var high: float = front-0.002 if bevel==0 else front
					var p: Vector3 = point.call(a.x,a.y,low)
					var q: Vector3 = point.call(b.x,b.y,low)
					var r: Vector3 = point.call(b.x,b.y,high,0.0 if bevel==0 else 0.002)
					var s: Vector3 = point.call(a.x,a.y,high,0.0 if bevel==0 else 0.002)
					var normal: Vector3 = (q-p).cross(s-p).normalized()
					_triangle(tool,p,q,r,normal)
					_triangle(tool,p,r,s,normal)
		tool.index()
		tool.generate_tangents()
		CompactKits.meshes[key] = tool.commit()
	_attach(root,key,material)

static func _foundation(root: Node3D, kind: String, key: String, paint: Material) -> void:
	var p: Dictionary = PROFILES[kind]
	var half: float = float(p.half)*(0.92 if kind=="whale" else 0.86)
	CompactKits._patch(root,key+"pressedroot",func(u: float,v: float) -> Vector3:
		var x: float = lerpf(-half,half,u)
		var start := Vector3(x,0.988,CompactCoachwork.rear_skin(x,0.988)+0.002)
		var finish: Vector3 = blade_point(kind,x,0.76)
		return start.lerp(finish,v),paint,Vector3.BACK,40,8)
	CompactKits._patch(root,key+"rootunder",func(u: float,v: float) -> Vector3:
		var x: float = lerpf(-half,half,u)
		var start := Vector3(x,0.968,CompactCoachwork.rear_skin(x,0.968)+0.002)
		var finish: Vector3 = blade_point(kind,x,0.76)-Vector3.UP*0.008
		return start.lerp(finish,v),paint,Vector3.DOWN,40,8)
	for side: float in [-1,1]:
		CompactKits._patch(root,key+"rootcheek"+str(side),func(u: float,v: float) -> Vector3:
			var x: float = side*half
			var y: float = lerpf(0.968,0.988,v)
			var start := Vector3(x,y,CompactCoachwork.rear_skin(x,y)+0.002)
			var finish: Vector3 = blade_point(kind,x,0.76)-Vector3.UP*(1-v)*0.008
			return start.lerp(finish,u),paint,Vector3(side,0,0),8,4)

static func _blade(root: Node3D, key: String, kind: String, left: float, right: float, paint: Material, layer: int = 0) -> void:
	var sample: Callable = func(u: float,v: float) -> Vector3: return blade_point(kind,lerpf(left,right,u),v,layer)
	CompactKits._patch(root,key,sample,paint,Vector3.ZERO,48 if kind!="splitwing" else 24,20,true)
	for end: float in [0.0,1.0]:
		var cap_key: String = key+"/cap"+str(end)+("/simple" if CompactKits.simple_parts else "")
		CompactKits._load_prepared(cap_key)
		if not CompactKits.meshes.has(cap_key):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			var normal := Vector3(-1 if end==0 else 1,0,0)
			var center := Vector3.ZERO
			for t: float in [0.0,0.25,0.5,0.75]: center += (sample.call(end,t) as Vector3)*0.25
			for index: int in range(20):
				_triangle(tool,center,sample.call(end,index/20.0),sample.call(end,(index+1)/20.0),normal)
			tool.index()
			tool.generate_tangents()
			CompactKits.meshes[cap_key] = tool.commit()
		_attach(root,cap_key,paint)

static func _triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	var points: Array = [a,b,c] if (b-a).cross(c-a).dot(normal)<0 else [a,c,b]
	for point: Vector3 in points:
		tool.set_normal(normal)
		tool.set_uv(Vector2(point.z,point.y))
		tool.add_vertex(point)

static func _attach(root: Node3D, key: String, material: Material) -> void:
	var part := MeshInstance3D.new()
	part.name = key.get_file().replace(".","_")
	part.mesh = CompactKits.meshes[key]
	part.material_override = material
	root.add_child(part)

static func _plate(root: Node3D, key: String, center: Vector3, polygon: Array[Vector2], thickness: float, material: Material) -> void:
	if CompactKits.simple_parts: key += "/simple"
	CompactKits._load_prepared(key)
	if not CompactKits.meshes.has(key):
		var contour: Array[Vector2] = []
		var steps: int = 3 if CompactKits.simple_parts else 5
		for index: int in range(polygon.size()):
			var p: Vector2 = polygon[index]
			var a: Vector2 = p+(polygon[posmod(index-1,polygon.size())]-p).normalized()*0.012
			var b: Vector2 = p+(polygon[(index+1)%polygon.size()]-p).normalized()*0.012
			for step: int in range(steps):
				var t: float = step/float(steps)
				contour.append(a.lerp(p,t).lerp(p.lerp(b,t),t))
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for side: float in [-1,1]:
			var origin: Vector3 = center+Vector3(side*thickness*0.5,0,0)
			for index: int in range(contour.size()):
				var a: Vector2 = contour[index]
				var b: Vector2 = contour[(index+1)%contour.size()]
				_triangle(tool,origin,origin+Vector3(0,a.x,a.y),origin+Vector3(0,b.x,b.y),Vector3(side,0,0))
		for index: int in range(contour.size()):
			var a: Vector2 = contour[index]
			var b: Vector2 = contour[(index+1)%contour.size()]
			var points: Array[Vector3] = [center+Vector3(-thickness*0.5,a.x,a.y),center+Vector3(thickness*0.5,a.x,a.y),center+Vector3(thickness*0.5,b.x,b.y),center+Vector3(-thickness*0.5,b.x,b.y)]
			var midpoint: Vector2 = (a+b)*0.5
			var delta: Vector2 = b-a
			var normal: Vector3 = Vector3(0,delta.y,-delta.x).normalized()
			if normal.dot(Vector3(0,midpoint.x,midpoint.y))<0: normal = -normal
			_triangle(tool,points[0],points[1],points[2],normal)
			_triangle(tool,points[0],points[2],points[3],normal)
		tool.index()
		tool.generate_tangents()
		CompactKits.meshes[key] = tool.commit()
	_attach(root,key,material)
