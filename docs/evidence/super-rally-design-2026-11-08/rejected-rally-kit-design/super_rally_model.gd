class_name SuperRallyModel
extends RefCounted
## Authored homologation exterior. All dimensions are unscaled visual metres.
## Factory parts use the ordinary replaceable frames, never simulation values.
const KEY: String = "super-rally-exterior-1/"

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

static func _apron_corner(root: Node3D, side: float, rear: bool, paint: Material) -> void:
	var section: Array[Vector2] = [Vector2(0.83,0.65),Vector2(0.97,0.665),Vector2(1.045,0.58),Vector2(1.045,0.31),Vector2(0.86,0.31),Vector2(0.82,0.45)]
	if rear: section = [Vector2(0.84,0.51),Vector2(0.98,0.51),Vector2(1.035,0.46),Vector2(1.035,0.29),Vector2(0.84,0.29)]
	CompactKitSurface.solid(root,KEY+"apron-corner"+str(side)+str(rear),func(u: float,v: float) -> Vector3:
		var q: Vector2 = CompactKitSurface.contour(section,v,0.025)
		var x: float = q.x-0.07*u
		var y: float = q.y+(0.025*u if not rear else 0.015*u)
		var z: float = lerpf(2.12,1.78,u) if rear else lerpf(-2.22,-1.74,u)
		return Vector3(side*x,y,z),paint,12,24)

static func roof(car: CarVisual) -> void:
	CompactKits.simple_parts = car.simple_model
	var root := Node3D.new()
	root.name = "SuperRoofIntake"
	car.body.add_child(root)
	var paint: Material = car.paint_materials.accent
	var dark: Material = CompactFinish.rubber(Color("101719"))
	# The low ram-air scoop is seated on the actual crowned roof. Its mouth
	# faces the nose and remains visible from the production overhead camera.
	var z0: float = -0.15
	var y0: float = CompactCoachwork.roof_point(0,0.17).y
	var section: Array[Vector2] = [Vector2(-0.19,y0-0.014),Vector2(0.19,y0-0.014),Vector2(0.17,y0+0.115),Vector2(-0.17,y0+0.115)]
	CompactKitSurface.solid(root,KEY+"roof-shell",func(u: float,v: float) -> Vector3:
		var q: Vector2 = CompactKitSurface.contour(section,v,0.035)
		var taper: float = 1.0-0.72*smoothstep(0.25,1,u)
		return Vector3(q.x*taper,lerpf(y0-0.012,q.y,taper),lerpf(z0,z0+0.60,u)),paint,12,16)
	_box(root,"roof-mouth",Vector3(0,y0+0.047,z0-0.006),Vector3(0.285,0.068,0.018),dark,0.012)
	for side: float in [-1.0,1.0]:
		_box(root,"roof-vane"+str(side),Vector3(side*0.065,y0+0.046,z0-0.017),Vector3(0.008,0.056,0.024),paint,0.003)

static func hood(root: Node3D, paint: Material, accent: Material) -> void:
	# A complete replacement panel with cut heat outlets. Reuse the established
	# closed recess/louvre construction, then add a taller central power blister.
	CompactHoodKits.build(root,"vented",paint,accent)
	var dark: Material = CompactFinish.rubber(Color("161d20"))
	CompactKitSurface.solid(root,KEY+"hood-blister",func(u: float,v: float) -> Vector3:
		var z: float = lerpf(-1.82,-1.07,u)
		var taper: float = smoothstep(0,0.18,u)*(1-smoothstep(0.80,1,u))
		var p: Vector3 = CompactCoachwork.hood_point(0,(z+1.84)/0.825)
		var section: Array[Vector2] = [Vector2(-0.22,-0.008),Vector2(0.22,-0.008),Vector2(0.18,0.104),Vector2(-0.18,0.104)]
		var q: Vector2 = CompactKitSurface.contour(section,v,0.035)
		return Vector3(q.x*taper,p.y+0.060+q.y*taper,z),accent,20,16)
	for side: float in [-1.0,1.0]:
		# Metallic quarter-turn catches read as hardware, not printed branding.
		var point: Vector3 = CompactCoachwork.hood_point(side*0.78,0.14)
		var catch: MeshInstance3D = CompactKits._cylinder(root,0.021,0.007,point+Vector3.UP*0.006,dark,8)
		catch.name = "SuperHoodCatch"

static func aero(root: Node3D, paint: Material, trim: Material, metal: Material) -> void:
	# A broad two-element competition wing carried by two substantial roof
	# pylons. Each leg lands on painted roof outside the rear window.
	for side: float in [-1.0,1.0]:
		var mount: Vector3 = CompactCoachwork.roof_point(side*0.86,0.93)
		_box(root,"wing-saddle"+str(side),mount+Vector3.UP*0.014,Vector3(0.14,0.036,0.20),trim)
		var target := Vector3(side*0.57,1.905,1.67)
		_beam(root,"wing-pylon"+str(side),mount+Vector3.UP*0.026,target,0.030,0.068,paint)
		_beam(root,"wing-brace"+str(side),mount+Vector3(0,0.024,-0.065),target+Vector3(0,-0.015,-0.12),0.012,0.020,trim)
	for layer: int in range(2):
		var y: float = 1.92 if layer == 0 else 1.735
		var z: float = 1.72 if layer == 0 else 1.64
		var chord: float = 0.255 if layer == 0 else 0.185
		CompactKitSurface.solid(root,KEY+"wing-element"+str(layer),func(u: float,v: float) -> Vector3:
			var x: float = lerpf(-1.02,1.02,u)
			var edge: float = pow(absf(x)/1.02,2)
			var a: float = v*TAU
			return Vector3(x,y+0.024*cos(a)+0.019*sin(a)+0.023*edge,z+chord*cos(a)*(1-0.18*edge)+0.06*edge),trim,28,12)
	for side: float in [-1.0,1.0]:
		var outline: Array[Vector2] = [Vector2(-0.28,-0.27),Vector2(0.055,-0.22),Vector2(0.075,0.20),Vector2(-0.22,0.29)]
		CompactAero._plate(root,KEY+"wing-endplate"+str(side),Vector3(side*1.026,1.92,1.78),outline,0.020,paint)
		for z: float in [-0.13,0.13]:
			var bolt := CompactKits._cylinder(root,0.009,0.006,Vector3(side*1.039,1.91,1.78+z),metal,8)
			bolt.rotation.z = PI*0.5

static func body(root: Node3D, paint: Material, accent: Material) -> void:
	var dark: Material = CompactFinish.rubber(Color("161e21"))
	var alloy: Material = CompactFinish.alloy(Color("8d989b"))
	for side: float in [-1.0,1.0]:
		for axle: float in [-1.28,1.28]:
			# A closed, swept blister follows the original wheel opening, with a
			# broad flat shoulder instead of a second floating arch outline.
			var section: Array[Vector2] = [Vector2(-0.012,0.418),Vector2(0.12,0.425),Vector2(0.145,0.485),Vector2(0.065,0.555),Vector2(-0.018,0.525)]
			CompactKitSurface.solid(root,KEY+"wide-arch"+str(side)+str(axle),func(u: float,v: float) -> Vector3:
				var angle: float = lerpf(-0.065,PI+0.065,u)
				var q: Vector2 = CompactKitSurface.contour(section,v,0.010)
				var y: float = 0.37+sin(angle)*q.y
				var z: float = axle+cos(angle)*q.y
				var x: float = CompactCoachwork.body_width(y,z)+q.x
				return Vector3(side*x,y,z),paint,28,20)
		var sill: Array[Vector2] = [Vector2(0.86,0.39),Vector2(1.015,0.35),Vector2(1.05,0.245),Vector2(0.87,0.255)]
		CompactKitSurface.solid(root,KEY+"competition-sill"+str(side),func(u: float,v: float) -> Vector3:
			var q: Vector2 = CompactKitSurface.contour(sill,v,0.015)
			return Vector3(side*q.x,q.y,lerpf(-0.85,0.85,u)),paint,10,16)
		_box(root,"sill-blade"+str(side),Vector3(side*1.012,0.245,0),Vector3(0.11,0.035,1.74),dark,0.008)
		# Broad rear-quarter cooling outlet, below the glass and ahead of the
		# rear arch. The housing is a solid part with an inset dark mouth.
		_box(root,"quarter-intake-frame"+str(side),Vector3(side*0.897,0.805,0.66),Vector3(0.06,0.225,0.43),paint,0.022)
		_box(root,"quarter-intake"+str(side),Vector3(side*0.932,0.805,0.66),Vector3(0.018,0.157,0.31),dark,0.008)
		for slat: int in range(3):
			_box(root,"quarter-vane"+str(side)+str(slat),Vector3(side*0.944,0.753+slat*0.052,0.66),Vector3(0.025,0.012,0.29),accent,0.004)
	# A much deeper full-width air dam. The intake is recessed behind its
	# painted frame; no coincident stock/front surfaces can flicker.
	_box(root,"front-radiator",Vector3(0,0.495,-2.155),Vector3(1.69,0.278,0.055),dark,0.018)
	_box(root,"front-crossbar",Vector3(0,0.656,-2.17),Vector3(1.96,0.075,0.12),paint,0.025)
	for side: float in [-1.0,1.0]:
		_apron_corner(root,side,false,paint)
		_box(root,"front-duct"+str(side),Vector3(side*0.72,0.485,-2.192),Vector3(0.20,0.20,0.023),dark,0.016)
		_box(root,"front-duct-divider"+str(side),Vector3(side*0.57,0.49,-2.201),Vector3(0.045,0.26,0.035),paint,0.009)
	for vane: int in range(9):
		_box(root,"radiator-vane"+str(vane),Vector3(lerpf(-0.49,0.49,vane/8.0),0.488,-2.188),Vector3(0.012,0.232,0.014),alloy,0.003)
	_box(root,"front-splitter",Vector3(0,0.292,-2.10),Vector3(2.15,0.046,0.34),dark,0.022)
	# Rear valance and diffuser grow below the retained lamps/registration area.
	_box(root,"rear-diffuser",Vector3(0,0.31,2.085),Vector3(1.85,0.14,0.33),dark,0.015)
	for x: float in [-0.67,-0.34,0,0.34,0.67]:
		_box(root,"diffuser-strake"+str(x),Vector3(x,0.268,2.14),Vector3(0.022,0.13,0.32),dark,0.006)
	for side: float in [-1.0,1.0]:
		_apron_corner(root,side,true,paint)
		var exhaust := CompactKits._cylinder(root,0.050,0.20,Vector3(side*0.57,0.385,2.20),alloy,12)
		exhaust.rotation.x = PI*0.5
		var bore := CompactKits._cylinder(root,0.039,0.006,Vector3(side*0.57,0.385,2.305),dark,12)
		bore.rotation.x = PI*0.5

static func wheel(root: Node3D, side: float) -> void:
	var white: Material = CompactFinish.paint(Color("e5e5db"))
	var dark: Material = CompactFinish.rubber(Color("192125"))
	var steel: Material = CompactFinish.alloy(Color("8c9698"))
	# A compact closed annular rim plus six open spokes; no high-density forged
	# accessory mesh is needed for the factory competition wheel.
	var rim: Array[Vector2] = [Vector2(0.095,0.230),Vector2(0.106,0.249),Vector2(0.151,0.249),Vector2(0.158,0.239),Vector2(0.149,0.224),Vector2(0.112,0.224)]
	CompactKitSurface.skin(root,KEY+"competition-rim"+str(side),func(u: float,v: float) -> Vector3:
		var a: float = u*TAU
		var q: Vector2 = CompactKitSurface.contour(rim,v,0.003)
		return Vector3(side*q.x,sin(a)*q.y,cos(a)*q.y),white,32,16)
	var hub := CompactKits._cylinder(root,0.077,0.067,Vector3(side*0.120,0,0),white,12)
	hub.rotation.z = PI*0.5
	for index: int in range(6):
		var a: float = index*TAU/6.0
		var spoke := VisualGeometry.box(root,Vector3(0.032,0.046,0.182),Vector3(side*0.131,sin(a)*0.156,cos(a)*0.156),white)
		spoke.rotation.x = -a
		var bolt := CompactKits._cylinder(root,0.009,0.006,Vector3(side*0.157,sin(a)*0.054,cos(a)*0.054),steel,8)
		bolt.rotation.z = PI*0.5
	var cap := CompactKits._cylinder(root,0.031,0.006,Vector3(side*0.158,0,0),dark,12)
	cap.rotation.z = PI*0.5
