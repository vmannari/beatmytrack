class_name PropStructures
extends RefCounted
## Original fictional service vehicles and track buildings; opaque shared meshes.
const METAL := Color("738482")
const DARK := Color("293b3c")
const WOOD := Color("8e7757")

static func append(tool: SurfaceTool, kit: Node, kind: String, center: Vector3, scale: float, turn: float) -> bool:
	if kind not in ["parked_car","van","car_wreck","shed","hut","grandstand"]: return false
	var local := SurfaceTool.new(); local.begin(Mesh.PRIMITIVE_TRIANGLES)
	if kind in ["parked_car","van","car_wreck"]: _vehicle(local,kind)
	elif kind == "grandstand": _grandstand(local)
	else: _building(local,kit,kind)
	PropGeometry.append_transformed(tool,local,center,scale,turn)
	return true

static func _vehicle(tool: SurfaceTool, kind: String) -> void:
	var wreck: bool = kind == "car_wreck"
	var van: bool = kind == "van"
	var paint := Color("8b9e91") if not van else Color("b4b5a1")
	if wreck: paint = Color("815842")
	var half: float = 2.50 if van else 2.10
	var axle: float = 1.60 if van else 1.30
	var belt: float = 0.88
	# Open wheel arches are cut into the side panels rather than wheels on a box.
	var samples: Array[float] = [-half,-axle-0.45,-axle-0.36,-axle-0.22,-axle,-axle+0.22,-axle+0.36,-axle+0.45,axle-0.45,axle-0.36,axle-0.22,axle,axle+0.22,axle+0.36,axle+0.45,half]
	for side: float in [-1.0,1.0]:
		for i: int in range(samples.size()-1):
			var a: float = samples[i]; var b: float = samples[i+1]
			var za: float = 0.84 if absf(a) < half-0.20 else 0.73
			var zb: float = 0.84 if absf(b) < half-0.20 else 0.73
			var ya: float = _arch(a,axle); var yb: float = _arch(b,axle)
			var top_a: float = belt-0.08 if absf(a) > half-0.25 else belt
			var top_b: float = belt-0.08 if absf(b) > half-0.25 else belt
			PropGeometry.face(tool,[Vector3(a,ya,side*za),Vector3(b,yb,side*zb),Vector3(b,top_b,side*zb),Vector3(a,top_a,side*za)],paint.darkened(0.05 if i%4 == 0 else 0))
			if ya > 0.30 or yb > 0.30:
				PropGeometry.beam(tool,Vector3(a,ya,side*(za+0.006)),Vector3(b,yb,side*(zb+0.006)),0.046,0.028,paint.lightened(0.11))
		PropGeometry.beam(tool,Vector3(-axle+0.48,0.28,side*0.80),Vector3(axle-0.48,0.28,side*0.80),0.10,0.10,DARK)
		for x: float in [-0.64,0.62]:
			PropGeometry.beam(tool,Vector3(x,0.43,side*0.847),Vector3(x,0.85,side*0.847),0.014,0.008,paint.darkened(0.32))
			PropGeometry.box(tool,Vector3(x-0.16,0.78,side*0.856),Vector3(0.16,0.038,0.026),METAL,0.009)
		PropGeometry.beam(tool,Vector3(-half+0.15,0.56,side*0.855),Vector3(half-0.15,0.56,side*0.855),0.027,0.015,DARK.lightened(0.16))
	PropGeometry.box(tool,Vector3(0,0.28,0),Vector3(half*2-0.12,0.20,1.25),DARK,0.055)
	for end: float in [-1.0,1.0]:
		PropGeometry.box(tool,Vector3(end*(half-0.07),0.54,0),Vector3(0.12,0.49,1.46),paint,0.065)
		PropGeometry.box(tool,Vector3(end*(half+0.015),0.38,0),Vector3(0.045,0.13,1.48),DARK.lightened(0.07),0.04)
		PropGeometry.box(tool,Vector3(end*(half+0.04),0.52,0),Vector3(0.012,0.11,0.34),Color("c8cbbb"),0.009)
		for z: float in [-0.56,0.56]:
			PropGeometry.box(tool,Vector3(end*(half+0.035),0.70,z),Vector3(0.025,0.145,0.29),Color("d6d4ac") if end > 0 else Color("9f4637"),0.025)
	for x: float in [half-0.035]:
		PropGeometry.box(tool,Vector3(x,0.65,0),Vector3(0.022,0.15,0.58),DARK,0.014)
		for z: float in [-0.21,0,0.21]: PropGeometry.beam(tool,Vector3(x+0.018,0.62,z),Vector3(x+0.018,0.70,z),0.026,0.012,METAL)
	var rear: float = -2.23 if van else -1.34
	var roof_rear: float = -2.18 if van else -0.90
	var roof_front: float = 0.58 if van else 0.32
	var front: float = 1.20 if van else 0.98
	var roof: float = 2.12 if van else 1.55
	if wreck: roof = 1.15; roof_front = 0.10
	var glass := Color("324e59")
	if wreck: glass = Color("273231")
	PropGeometry.face(tool,[Vector3(front,belt,-0.79),Vector3(half,belt-0.08,-0.73),Vector3(half,belt-0.08,0.73),Vector3(front,belt,0.79)],paint.lightened(0.08))
	PropGeometry.face(tool,[Vector3(-half,belt-0.08,-0.73),Vector3(rear,belt,-0.79),Vector3(rear,belt,0.79),Vector3(-half,belt-0.08,0.73)],paint.lightened(0.06))
	PropGeometry.face(tool,[Vector3(roof_rear,roof,-0.68),Vector3(roof_front,roof,-0.68),Vector3(roof_front,roof,0.68),Vector3(roof_rear,roof,0.68)],paint.lightened(0.16))
	PropGeometry.face(tool,[Vector3(front,belt,-0.79),Vector3(front,belt,0.79),Vector3(roof_front,roof,0.68),Vector3(roof_front,roof,-0.68)],paint)
	PropGeometry.face(tool,[Vector3(front-0.065,belt+0.07,-0.71),Vector3(front-0.065,belt+0.07,0.71),Vector3(roof_front+0.045,roof-0.09,0.62),Vector3(roof_front+0.045,roof-0.09,-0.62)],glass)
	PropGeometry.face(tool,[Vector3(rear,belt,0.79),Vector3(rear,belt,-0.79),Vector3(roof_rear,roof,-0.68),Vector3(roof_rear,roof,0.68)],paint)
	if not van:
		PropGeometry.face(tool,[Vector3(rear+0.06,belt+0.06,0.72),Vector3(rear+0.06,belt+0.06,-0.72),Vector3(roof_rear-0.03,roof-0.10,-0.61),Vector3(roof_rear-0.03,roof-0.10,0.61)],glass)
	for side: float in [-1.0,1.0]:
		PropGeometry.face(tool,[Vector3(rear,belt,side*0.79),Vector3(front,belt,side*0.79),Vector3(roof_front,roof,side*0.68),Vector3(roof_rear,roof,side*0.68)],paint)
		var window_rear: float = -0.20 if van else rear+0.14
		var upper_rear: float = -0.20 if van else roof_rear+0.06
		PropGeometry.face(tool,[Vector3(window_rear,belt+0.09,side*0.799),Vector3(front-0.15,belt+0.09,side*0.799),Vector3(roof_front-0.03,roof-0.10,side*0.701),Vector3(upper_rear,roof-0.10,side*0.701)],glass)
		PropGeometry.beam(tool,Vector3(-0.14,belt+0.07,side*0.805),Vector3(-0.14,roof-0.05,side*0.695),0.082,0.016,paint.darkened(0.05))
		PropGeometry.beam(tool,Vector3(front-0.17,belt+0.12,side*0.77),Vector3(front-0.12,belt+0.17,side*0.94),0.035,0.035,DARK)
		PropGeometry.box(tool,Vector3(front-0.10,belt+0.18,side*0.94),Vector3(0.23,0.13,0.105),paint.darkened(0.12),0.026)
		if van:
			PropGeometry.beam(tool,Vector3(-0.40,0.92,side*0.81),Vector3(-0.40,2.01,side*0.71),0.017,0.013,paint.darkened(0.30))
			PropGeometry.box(tool,Vector3(-1.21,1.47,side*0.77),Vector3(1.23,0.38,0.019),paint.darkened(0.08),0.022)
	for z: float in [-0.36,0.36]: PropGeometry.beam(tool,Vector3(front-0.08,0.98,z),Vector3(front-0.12,1.015,z-0.28),0.02,0.014,DARK)
	for x: float in [-axle,axle]:
		for side: float in [-1.0,1.0]:
			if wreck and x > 0 and side > 0:
				PropGeometry.tube(tool,Vector3(x,0.31,0.69),Vector3(x,0.31,0.86),0.10,0.10,Color("816951"),12)
				continue
			var p := Vector3(x,0.34,side*0.80)
			PropGeometry.ring(tool,p,Vector3.BACK,0.34,0.175,0.22,Color("303937"),24)
			PropGeometry.tube(tool,p+Vector3.BACK*side*0.117,p+Vector3.BACK*side*0.129,0.166,0.166,METAL.darkened(0.1),16)
			PropGeometry.tube(tool,p+Vector3.BACK*side*0.132,p+Vector3.BACK*side*0.14,0.055,0.055,DARK,10)
			for i: int in range(5):
				var a: float = TAU*i/5
				PropGeometry.beam(tool,p+Vector3(cos(a)*0.065,sin(a)*0.065,side*0.135),p+Vector3(cos(a)*0.14,sin(a)*0.14,side*0.135),0.040,0.012,Color("b4bbab"))
	if wreck:
		PropGeometry.box(tool,Vector3(1.36,0.91,0.02),Vector3(0.53,0.24,0.52),DARK,0.025)
		for z: float in [-0.19,0,0.19]: PropGeometry.beam(tool,Vector3(1.13,1.04,z),Vector3(1.56,1.04,z),0.055,0.055,Color("817b68"))
		PropGeometry.face(tool,[Vector3(1.05,0.91,-0.78),Vector3(1.97,0.95,-0.72),Vector3(1.97,1.19,-0.22),Vector3(1.05,1.14,-0.27)],paint.lightened(0.11))
		for side: float in [-1.0,1.0]:
			PropGeometry.face(tool,[Vector3(-0.73,0.58,side*0.848),Vector3(-0.26,0.52,side*0.849),Vector3(-0.05,0.74,side*0.849),Vector3(-0.61,0.79,side*0.849)],Color("a16e45"))
		PropGeometry.beam(tool,Vector3(-0.9,1.15,-0.68),Vector3(0.1,1.15,-0.68),0.045,0.045,Color("aa8970"))

static func _arch(x: float, axle: float) -> float:
	var d: float = minf(absf(x-axle),absf(x+axle))
	return 0.34+sqrt(maxf(0.0,0.43*0.43-d*d)) if d < 0.43 else 0.27

static func _building(tool: SurfaceTool, kit: Node, kind: String) -> void:
	var shed: bool = kind == "shed"
	var width: float = 7.0 if shed else 2.5
	var depth: float = 5.0 if shed else 2.5
	var wall := Color("827c66") if shed else Color("8b7656")
	var roof := Color("566b68") if shed else Color("845b46")
	PropGeometry.box(tool,Vector3(0,1.5,0),Vector3(width,3,depth),wall,0.025)
	PropGeometry.box(tool,Vector3(0,0.14,0),Vector3(width+0.02,0.28,depth+0.02),Color("626e64"),0.025)
	CreatorPropVisual._roof(tool,kit,Vector3.ZERO,1,0,width,depth,roof)
	for side: float in [-1.0,1.0]:
		PropGeometry.face(tool,[Vector3(side*width*0.5,3,-depth*0.5),Vector3(side*width*0.5,3,depth*0.5),Vector3(side*width*0.5,4,0)],wall.darkened(0.16))
		PropGeometry.beam(tool,Vector3(-width*0.5-0.13,3.0,side*(depth*0.5+0.15)),Vector3(width*0.5+0.13,3.0,side*(depth*0.5+0.15)),0.14,0.13,roof.darkened(0.22))
		for x: float in [-width*0.47,width*0.47]:
			PropGeometry.box(tool,Vector3(x,1.55,side*(depth*0.5+0.021)),Vector3(0.14,2.90,0.075),wall.lightened(0.16),0.015)
		for h: int in range(11): PropGeometry.beam(tool,Vector3(-width*0.5,0.33+h*0.24,side*(depth*0.5+0.014)),Vector3(width*0.5,0.33+h*0.24,side*(depth*0.5+0.014)),0.014,0.009,wall.darkened(0.20))
		PropGeometry.tube(tool,Vector3(width*0.47,0.12,side*(depth*0.5+0.09)),Vector3(width*0.47,3,side*(depth*0.5+0.09)),0.042,0.042,roof.darkened(0.15),8)
	PropGeometry.beam(tool,Vector3(-width*0.5-0.15,4.025,0),Vector3(width*0.5+0.15,4.025,0),0.14,0.10,roof.lightened(0.14))
	for side: float in [-1.0,1.0]:
		for edge: float in [-width*0.5-0.16,width*0.5+0.16]: PropGeometry.beam(tool,Vector3(edge,3.01,side*(depth*0.5+0.15)),Vector3(edge,4.03,0),0.10,0.08,roof.lightened(0.12))
	if shed:
		var dw: float = width*0.51
		PropGeometry.box(tool,Vector3(0,1.27,-depth*0.5-0.022),Vector3(dw+0.24,2.57,0.055),DARK,0.025)
		PropGeometry.box(tool,Vector3(0,1.24,-depth*0.5-0.056),Vector3(dw,2.40,0.024),METAL.darkened(0.12),0.01)
		for i: int in range(11): PropGeometry.beam(tool,Vector3(-dw*0.5,0.16+i*0.21,-depth*0.5-0.073),Vector3(dw*0.5,0.16+i*0.21,-depth*0.5-0.073),0.025,0.012,METAL.lightened(0.13))
		for x: float in [-0.94,0,0.94]: _window(tool,Vector3(x,2.05,-depth*0.5-0.085),Vector2(0.67,0.28))
		PropGeometry.box(tool,Vector3(0,0.57,-depth*0.5-0.086),Vector3(0.34,0.038,0.036),DARK,0.01)
		for x: float in [-width*0.39,width*0.39]: _window(tool,Vector3(x,1.91,-depth*0.5-0.08),Vector2(0.70,0.82))
		# Rooflights sit on the actual pitch, with opaque inset glass.
		for x: float in [-1.70,1.70]:
			var corners: Array = [Vector3(x-0.44,3.49,-1.35),Vector3(x+0.44,3.49,-1.35),Vector3(x+0.44,3.82,-0.50),Vector3(x-0.44,3.82,-0.50)]
			PropGeometry.face(tool,corners,Color("8ca9a5"))
			for i: int in range(4): PropGeometry.beam(tool,corners[i],corners[(i+1)%4],0.045,0.04,DARK)
	else:
		PropGeometry.box(tool,Vector3(0,1.10,-depth*0.5-0.04),Vector3(0.79,2.20,0.08),DARK,0.022)
		PropGeometry.box(tool,Vector3(0,1.10,-depth*0.5-0.086),Vector3(0.63,2.03,0.023),Color("62766a"),0.012)
		_window(tool,Vector3(0,1.62,-depth*0.5-0.11),Vector2(0.49,0.67))
		PropGeometry.box(tool,Vector3(0.22,0.97,-depth*0.5-0.107),Vector3(0.038,0.11,0.032),Color("c1c5ad"),0.009)
		for x: float in [-0.87,0.87]: _window(tool,Vector3(x,1.91,-depth*0.5-0.055),Vector2(0.40,0.85))
		for side: float in [-1.0,1.0]:
			PropGeometry.box(tool,Vector3(side*(width*0.5+0.025),1.95,0),Vector3(0.04,0.98,1.52),Color("c0b596"),0.02)
			PropGeometry.box(tool,Vector3(side*(width*0.5+0.052),1.95,0),Vector3(0.02,0.78,1.32),Color("35565d"),0.01)
			PropGeometry.beam(tool,Vector3(side*(width*0.5+0.07),1.52,0),Vector3(side*(width*0.5+0.07),2.38,0),0.052,0.03,Color("b9b397"))
		PropGeometry.box(tool,Vector3(0,0.055,-depth*0.5-0.13),Vector3(1.02,0.11,0.23),Color("898e7c"),0.028)

static func _window(tool: SurfaceTool, p: Vector3, size: Vector2) -> void:
	PropGeometry.box(tool,p,Vector3(size.x,size.y,0.04),Color("bcb99e"),0.018)
	PropGeometry.box(tool,p+Vector3(0,0,-0.026),Vector3(size.x-0.12,size.y-0.12,0.018),Color("35545b"),0.012)
	PropGeometry.beam(tool,p+Vector3(0,-size.y*0.43,-0.039),p+Vector3(0,size.y*0.43,-0.039),0.035,0.014,Color("afb298"))
	PropGeometry.box(tool,p+Vector3(0,-size.y*0.5,-0.036),Vector3(size.x+0.08,0.07,0.09),Color("b5b198"),0.018)

static func _grandstand(tool: SurfaceTool) -> void:
	for row: int in range(4):
		var h: float = 0.25+row*0.40
		var z: float = -1.50+row
		PropGeometry.box(tool,Vector3(0,h,z),Vector3(8,0.18,0.85),METAL.darkened(0.16),0.025)
		for x: float in [-3.65,3.65]:
			PropGeometry.beam(tool,Vector3(x,0,z),Vector3(x,h,z),0.15,0.15,DARK)
		for seat: int in range(10):
			var x: float = -3.45+seat*0.77
			if absf(x) < 0.65: continue
			PropGeometry.box(tool,Vector3(x,h+0.16,z+0.13),Vector3(0.56,0.09,0.38),Color("687f77"),0.05)
			PropGeometry.box(tool,Vector3(x,h+0.36,z+0.33),Vector3(0.55,0.37,0.07),Color("778d80"),0.04)
		# Clear central aisle, two half-rise stair treads per tier.
		for step: int in range(2): PropGeometry.box(tool,Vector3(0,h-0.10+step*0.20,z-0.21+step*0.42),Vector3(1.03,0.07,0.40),METAL.lightened(0.10),0.012)
	for x: float in [-3.9,3.9]:
		PropGeometry.beam(tool,Vector3(x,0.06,-1.85),Vector3(x,1.68,1.90),0.12,0.12,DARK)
		PropGeometry.beam(tool,Vector3(x,1.10,-1.85),Vector3(x,2.70,1.90),0.075,0.075,METAL)
		for row: int in range(5): PropGeometry.beam(tool,Vector3(x,0.15+row*0.40,-1.65+row*0.86),Vector3(x,1.15+row*0.40,-1.65+row*0.86),0.055,0.055,METAL)
		PropGeometry.beam(tool,Vector3(x,0.15,-1.2),Vector3(x,1.38,1.35),0.08,0.08,DARK)
	for x: float in [-3.9,-1.3,1.3,3.9]: PropGeometry.beam(tool,Vector3(x,1.48,1.86),Vector3(x,2.60,1.86),0.06,0.06,METAL)
	for h: float in [1.84,2.59]: PropGeometry.beam(tool,Vector3(-3.9,h,1.86),Vector3(3.9,h,1.86),0.065,0.065,METAL)
