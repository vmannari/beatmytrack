class_name PropEquipment
extends RefCounted
## Original track furniture with construction details sized for overhead viewing.
const METAL := Color("7d8988")
const DARK := Color("354442")
const WOOD := Color("8b7453")

static func append(tool: SurfaceTool, kit: Node, kind: String, center: Vector3, scale: float, turn: float, length: float) -> bool:
	if kind not in ["barrier","fence","guardrail","wire_fence","cone","chevron","braking_board","banner","flag","light","gantry","crate","barrel","pallet","container"]: return false
	var local := SurfaceTool.new(); local.begin(Mesh.PRIMITIVE_TRIANGLES)
	var span: float = length/scale if length >= 0 else 6.0
	match kind:
		"barrier": _barrier(local,span)
		"fence", "guardrail", "wire_fence": _fence(local,kind,span,length >= 0)
		"cone":
			PropGeometry.box(local,Vector3(0,0.065,0),Vector3(0.7,0.13,0.7),Color("303a38"),0.055)
			CreatorPropVisual._lathe(local,kit,Vector3.ZERO,1,0,[Vector2(0.29,0.13),Vector2(0.28,0.20),Vector2(0.21,0.40),Vector2(0.18,0.51),Vector2(0.125,0.67),Vector2(0.08,0.80),Vector2(0.06,0.88),Vector2(0.027,0.88),Vector2(0.027,0.83)],
				[Color("ba5628"),Color("d77837"),Color("e4dfc9"),Color("e4dfc9"),Color("d77837"),Color("c5672b"),Color("e8a056"),Color("593d2f")])
			PropGeometry.ring(local,Vector3(0,0.20,0),Vector3.UP,0.282,0.258,0.045,Color("dc8441"))
		"chevron", "braking_board", "banner": _sign(local,kind)
		"flag": _flag(local)
		"light": _light(local)
		"gantry": _gantry(local)
		"crate": _crate(local)
		"barrel": _barrel(local,kit)
		"pallet": _pallet(local)
		"container": _container(local)
	PropGeometry.append_transformed(tool,local,center,scale,turn)
	return true

static func _barrier(tool: SurfaceTool, span: float) -> void:
	# Jersey profile keeps the original one-metre solid footprint and height.
	var profile: Array[Vector2] = [Vector2(-0.5,0),Vector2(-0.5,0.17),Vector2(-0.24,0.55),Vector2(-0.22,0.88),Vector2(-0.18,0.93),Vector2(0.18,0.93),Vector2(0.22,0.88),Vector2(0.24,0.55),Vector2(0.5,0.17),Vector2(0.5,0)]
	var lo: Array[Vector3] = []; var hi: Array[Vector3] = []
	for p: Vector2 in profile:
		lo.append(Vector3(-span*0.5,p.y,p.x)); hi.append(Vector3(span*0.5,p.y,p.x))
	for i: int in range(profile.size()):
		var j: int = (i+1)%profile.size()
		PropGeometry.face(tool,[lo[i],lo[j],hi[j],hi[i]],Color("a6aaa0").lightened(0.13 if i in [3,4,5] else 0).darkened(0.12 if i in [0,8] else 0))
	PropGeometry.face(tool,lo,Color("969d92")); hi.reverse(); PropGeometry.face(tool,hi,Color("969d92"))
	for x: float in [-span*0.33,0,span*0.33]:
		for side: float in [-1.0,1.0]:
			PropGeometry.face(tool,[Vector3(x-span*0.055,0.59,side*0.241),Vector3(x+span*0.09,0.59,side*0.241),Vector3(x+span*0.035,0.87,side*0.225),Vector3(x-span*0.11,0.87,side*0.225)],Color("ac4936"))
		PropGeometry.box(tool,Vector3(x,0.935,0),Vector3(span*0.12,0.009,0.34),Color("bf5940"),0.002)
	for x: float in [-span*0.22,span*0.22]:
		PropGeometry.box(tool,Vector3(x,0.939,0),Vector3(minf(0.14,span*0.07),0.008,0.08),DARK,0.015)
	for side: float in [-1.0,1.0]:
		PropGeometry.box(tool,Vector3(0,0.10,side*0.493),Vector3(maxf(0.02,span-0.08),0.06,0.017),Color("7a827a"),0.003)

static func _fence(tool: SurfaceTool, kind: String, span: float, continuous: bool) -> void:
	var count: int = maxi(1,ceili(span/3.0))
	var reach: float = span*0.5 if continuous else span*0.5-0.1
	for i: int in range(count+1):
		var x: float = lerpf(-reach,reach,float(i)/count)
		if kind == "fence":
			PropGeometry.box(tool,Vector3(x,0.62,0),Vector3(0.20,1.24,0.20),WOOD.darkened(0.12),0.028)
			PropGeometry.box(tool,Vector3(x,1.25,0),Vector3(0.24,0.09,0.24),WOOD.lightened(0.12),0.035)
			for h: float in [0.42,1.02]:
				PropGeometry.tube(tool,Vector3(x,h,-0.113),Vector3(x,h,-0.126),0.027,0.027,DARK,8)
		elif kind == "guardrail":
			for z: float in [-0.072,0.025]:
				PropGeometry.beam(tool,Vector3(x,0,z),Vector3(x,1.25,z),0.15,0.035,METAL.darkened(0.20))
			PropGeometry.beam(tool,Vector3(x,0,-0.024),Vector3(x,1.25,-0.024),0.033,0.10,METAL.darkened(0.1))
			PropGeometry.box(tool,Vector3(x,0.80,0.035),Vector3(0.17,0.30,0.17),DARK,0.015)
			PropGeometry.tube(tool,Vector3(x,0.80,0.146),Vector3(x,0.80,0.169),0.040,0.040,Color("ccd1c6"),8)
			PropGeometry.box(tool,Vector3(x,1.20,0.06),Vector3(0.085,0.15,0.04),Color("bbab70"),0.012)
		else:
			PropGeometry.tube(tool,Vector3(x,0,0),Vector3(x,1.46,0),0.055,0.045,METAL,10)
			PropGeometry.box(tool,Vector3(x,0.07,0),Vector3(0.20,0.14,0.20),DARK,0.02)
	if kind == "fence":
		for h: float in [0.42,1.02]:
			PropGeometry.box(tool,Vector3(0,h,0.04),Vector3(span,0.18,0.15),WOOD,0.018)
			PropGeometry.beam(tool,Vector3(-span*0.5,h+0.04,-0.041),Vector3(span*0.5,h+0.04,-0.041),0.023,0.008,WOOD.lightened(0.24))
	elif kind == "guardrail":
		var section: Array[Vector2] = [Vector2(0.57,0.087),Vector2(0.62,0.11),Vector2(0.72,0.16),Vector2(0.80,0.11),Vector2(0.88,0.16),Vector2(0.98,0.11),Vector2(1.03,0.087)]
		for row: int in range(section.size()-1):
			var a: Vector2 = section[row]; var b: Vector2 = section[row+1]
			PropGeometry.face(tool,[Vector3(-span*0.5,a.x,a.y),Vector3(span*0.5,a.x,a.y),Vector3(span*0.5,b.x,b.y),Vector3(-span*0.5,b.x,b.y)],METAL.lightened(0.12 if row%2 == 0 else 0.02))
			PropGeometry.face(tool,[Vector3(span*0.5,a.x,a.y-0.015),Vector3(-span*0.5,a.x,a.y-0.015),Vector3(-span*0.5,b.x,b.y-0.015),Vector3(span*0.5,b.x,b.y-0.015)],METAL.darkened(0.15))
	else:
		for h: float in [0.18,1.38]: PropGeometry.tube(tool,Vector3(-span*0.5,h,0),Vector3(span*0.5,h,0),0.024,0.024,METAL,6)
		# Clipped diamond mesh, rather than a rectangular cage.
		var steps: int = ceili((span+1.2)/0.34)
		for i: int in range(steps):
			for slope: float in [-1.0,1.0]:
				var start: float = -span*0.5-1.2+i*0.34
				var xa: float = maxf(-span*0.5,start)
				var xb: float = minf(span*0.5,start+1.2)
				if xb <= xa: continue
				var ya: float = 0.18+(xa-start) if slope > 0 else 1.38-(xa-start)
				var yb: float = 0.18+(xb-start) if slope > 0 else 1.38-(xb-start)
				PropGeometry.beam(tool,Vector3(xa,ya,0),Vector3(xb,yb,0),0.011,0.011,METAL.darkened(0.05))

static func _sign(tool: SurfaceTool, kind: String) -> void:
	var width: float = 4.0 if kind == "banner" else 1.5
	for x: float in [-width*0.4,width*0.4]:
		PropGeometry.beam(tool,Vector3(x,0,0),Vector3(x,1.46,0),0.08,0.09,METAL.darkened(0.15))
		PropGeometry.box(tool,Vector3(x,0.05,0),Vector3(0.21,0.10,0.24),DARK,0.018)
	PropGeometry.box(tool,Vector3(0,1.15,0),Vector3(width,0.80,0.12),DARK,0.035)
	for side: float in [-1.0,1.0]:
		PropGeometry.box(tool,Vector3(0,1.15,side*0.066),Vector3(width-0.08,0.70,0.025),Color("d6d8c7"),0.022)
		if kind == "chevron":
			for x: float in [-0.43,0.18]:
				PropGeometry.face(tool,[Vector3(x-0.14,0.85,side*0.083),Vector3(x+0.06,0.85,side*0.083),Vector3(x+0.32,1.15,side*0.083),Vector3(x+0.06,1.45,side*0.083),Vector3(x-0.14,1.45,side*0.083),Vector3(x+0.13,1.15,side*0.083)],DARK)
		elif kind == "braking_board":
			# Actual brake-distance identifier, authored as simple segment geometry.
			for i: int in range(3): _digit(tool,1 if i == 0 else 0,Vector3(-0.39+i*0.34,1.15,side*0.084),0.44)
		else:
			for col: int in range(4):
				for row: int in range(2):
					if (col+row)%2 == 0: PropGeometry.box(tool,Vector3(-1.53+col*0.20,1.06+row*0.20,side*0.084),Vector3(0.19,0.19,0.008),DARK,0.002)
			PropGeometry.beam(tool,Vector3(-0.5,1.04,side*0.085),Vector3(1.45,1.04,side*0.085),0.11,0.007,Color("697d72"))
			PropGeometry.beam(tool,Vector3(-0.5,1.27,side*0.085),Vector3(1.1,1.27,side*0.085),0.045,0.007,DARK)
		for x: float in [-width*0.44,width*0.44]:
			PropGeometry.tube(tool,Vector3(x,1.15,side*0.077),Vector3(x,1.15,side*0.09),0.023,0.023,METAL,8)

static func _digit(tool: SurfaceTool, value: int, center: Vector3, height: float) -> void:
	var segments: Array = [1,2] if value == 1 else [0,1,2,3,4,5]
	var ends: Array = [[Vector2(-0.20,0.5),Vector2(0.20,0.5)],[Vector2(0.23,0.43),Vector2(0.23,0.07)],[Vector2(0.23,-0.07),Vector2(0.23,-0.43)],[Vector2(-0.20,-0.5),Vector2(0.20,-0.5)],[Vector2(-0.23,-0.43),Vector2(-0.23,-0.07)],[Vector2(-0.23,0.07),Vector2(-0.23,0.43)]]
	for i: int in segments:
		var a: Vector2 = ends[i][0]*height; var b: Vector2 = ends[i][1]*height
		PropGeometry.beam(tool,center+Vector3(a.x,a.y,0),center+Vector3(b.x,b.y,0),height*0.105,0.007,DARK)

static func _flag(tool: SurfaceTool) -> void:
	PropGeometry.box(tool,Vector3(0,0.07,0),Vector3(0.27,0.14,0.27),DARK,0.03)
	PropGeometry.tube(tool,Vector3.ZERO,Vector3(0,3,0),0.045,0.025,METAL,12)
	PropGeometry.tube(tool,Vector3(0,3,0),Vector3(0,3.07,0),0.05,0.005,Color("d0c6a5"),10)
	for col: int in range(5):
		for row: int in range(3):
			var xa: float = 0.03+col*0.184; var xb: float = xa+0.184
			var ya: float = 2.44+row*0.16; var yb: float = ya+0.16
			PropGeometry.face(tool,[Vector3(xa,ya-0.06*xa,sin(xa*6.0)*0.08),Vector3(xb,ya-0.06*xb,sin(xb*6.0)*0.08),Vector3(xb,yb-0.06*xb,sin(xb*6.0)*0.08),Vector3(xa,yb-0.06*xa,sin(xa*6.0)*0.08)],Color("dad9c7") if (row+col)%2 == 0 else DARK)

static func _light(tool: SurfaceTool) -> void:
	PropGeometry.box(tool,Vector3(0,0.11,0),Vector3(0.36,0.22,0.36),Color("747e76"),0.04)
	PropGeometry.tube(tool,Vector3(0,0.2,0),Vector3(0,4.72,0),0.10,0.063,METAL,12)
	PropGeometry.box(tool,Vector3(0,0.52,-0.095),Vector3(0.16,0.24,0.035),DARK,0.012)
	PropGeometry.beam(tool,Vector3(0,4.58,0),Vector3(0.43,4.82,0),0.11,0.11,METAL)
	PropGeometry.box(tool,Vector3(0.4,4.79,0),Vector3(1,0.23,0.40),DARK,0.07)
	PropGeometry.box(tool,Vector3(0.4,4.666,0),Vector3(0.80,0.027,0.30),Color("d3d1b1"),0.035)
	for x: float in [0.08,0.24,0.40,0.56,0.72]: PropGeometry.beam(tool,Vector3(x,4.92,-0.12),Vector3(x,4.92,0.12),0.025,0.018,METAL.darkened(0.3))

static func _gantry(tool: SurfaceTool) -> void:
	for x: float in [-5.7,5.7]:
		PropGeometry.box(tool,Vector3(x,0.15,0),Vector3(0.60,0.30,1),Color("8c968a"),0.045)
		for z: float in [-0.34,0.34]: PropGeometry.beam(tool,Vector3(x,0.3,z),Vector3(x,4.8,z),0.18,0.18,METAL)
		for i: int in range(4): PropGeometry.beam(tool,Vector3(x,0.5+i,z_sign(i)*0.34),Vector3(x,1.5+i,-z_sign(i)*0.34),0.075,0.075,DARK)
	for z: float in [-0.3,0.3]:
		for h: float in [4.45,5.18]: PropGeometry.beam(tool,Vector3(-5.7,h,z),Vector3(5.7,h,z),0.12,0.12,METAL)
		for i: int in range(12): PropGeometry.beam(tool,Vector3(-5.7+i*0.95,4.45,z),Vector3(-4.75+i*0.95,5.18,z),0.065,0.065,DARK)
	PropGeometry.box(tool,Vector3(0,4.79,-0.37),Vector3(10.8,0.54,0.10),DARK,0.03)
	for i: int in range(20):
		for row: int in range(2):
			if (i+row)%2 == 0: PropGeometry.box(tool,Vector3(-5.13+i*0.54,4.65+row*0.27,-0.426),Vector3(0.53,0.26,0.012),Color("d2d4c3"),0.002)
	for x: float in [-0.68,0,0.68]:
		PropGeometry.box(tool,Vector3(x,4.07,-0.15),Vector3(0.42,0.41,0.29),Color("263332"),0.045)
		PropGeometry.tube(tool,Vector3(x,4.07,-0.31),Vector3(x,4.07,-0.34),0.13,0.13,Color("7b4435"),16)

static func z_sign(i: int) -> float: return -1.0 if i%2 == 0 else 1.0

static func _crate(tool: SurfaceTool) -> void:
	PropGeometry.box(tool,Vector3(0,0.5,0),Vector3(1.02,0.96,1.02),WOOD.darkened(0.25),0.025)
	for side: float in [-1.0,1.0]:
		for i: int in range(5):
			PropGeometry.box(tool,Vector3(-0.43+i*0.215,0.50,side*0.522),Vector3(0.197,0.94,0.04),WOOD.lightened((i%3)*0.035),0.008)
			PropGeometry.box(tool,Vector3(side*0.522,0.50,-0.43+i*0.215),Vector3(0.04,0.94,0.197),WOOD.lightened((i%3)*0.025),0.008)
		for h: float in [0.12,0.88]:
			PropGeometry.box(tool,Vector3(0,h,side*0.56),Vector3(1.10,0.13,0.07),WOOD.lightened(0.12),0.012)
			PropGeometry.box(tool,Vector3(side*0.56,h,0),Vector3(0.07,0.13,1.10),WOOD.lightened(0.12),0.012)
		PropGeometry.beam(tool,Vector3(-0.41,0.23,side*0.555),Vector3(0.41,0.77,side*0.555),0.12,0.065,WOOD.lightened(0.08))
		for x: float in [-0.42,0.42]:
			for h: float in [0.12,0.88]: PropGeometry.tube(tool,Vector3(x,h,side*0.60),Vector3(x,h,side*0.605),0.019,0.019,DARK,6)
	for i: int in range(5): PropGeometry.box(tool,Vector3(-0.43+i*0.215,0.99,0),Vector3(0.197,0.055,1.05),WOOD.lightened(0.06),0.008)

static func _barrel(tool: SurfaceTool, kit: Node) -> void:
	var paint := Color("6e7f70")
	CreatorPropVisual._lathe(tool,kit,Vector3.ZERO,1,0,[Vector2(0.47,0.02),Vector2(0.51,0.08),Vector2(0.51,0.15),Vector2(0.48,0.18),Vector2(0.48,0.31),Vector2(0.51,0.34),Vector2(0.51,0.39),Vector2(0.48,0.42),Vector2(0.48,0.72),Vector2(0.51,0.75),Vector2(0.51,0.80),Vector2(0.48,0.83),Vector2(0.48,0.99),Vector2(0.51,1.03),Vector2(0.51,1.08),Vector2(0.46,1.08),Vector2(0.46,1.055),Vector2(0,1.055)],
		[paint.darkened(0.2),METAL,paint,paint,paint.lightened(0.05),METAL,paint,paint,paint.lightened(0.05),METAL,paint,paint,paint,METAL,METAL,paint.darkened(0.15),paint.lightened(0.09)])
	PropGeometry.tube(tool,Vector3(0.22,1.06,0.15),Vector3(0.22,1.075,0.15),0.074,0.074,DARK,12)
	PropGeometry.tube(tool,Vector3(-0.22,1.06,-0.15),Vector3(-0.22,1.075,-0.15),0.037,0.037,METAL,10)
	PropGeometry.box(tool,Vector3(0,0.57,-0.484),Vector3(0.30,0.18,0.015),Color("c5bd96"),0.012)

static func _pallet(tool: SurfaceTool) -> void:
	for x: float in [-0.72,0,0.72]:
		for z: float in [-0.52,0,0.52]: PropGeometry.box(tool,Vector3(x,0.14,z),Vector3(0.22,0.22,0.22),WOOD.darkened(0.22),0.008)
	for z: float in [-0.52,0,0.52]: PropGeometry.box(tool,Vector3(0,0.035,z),Vector3(1.94,0.07,0.17),WOOD.darkened(0.10),0.009)
	for i: int in range(7):
		var x: float = -0.85+i*0.283
		PropGeometry.box(tool,Vector3(x,0.285,0),Vector3(0.23,0.08,1.40),WOOD.lightened((i%3)*0.04),0.012)
		for z: float in [-0.52,0.52]: PropGeometry.tube(tool,Vector3(x,0.327,z),Vector3(x,0.330,z),0.016,0.016,DARK,6)

static func _container(tool: SurfaceTool) -> void:
	var paint := Color("657c70")
	PropGeometry.box(tool,Vector3(0,1.3,0),Vector3(5.88,2.5,2.4),paint.darkened(0.08),0.035)
	for side: float in [-1.0,1.0]:
		for i: int in range(16):
			PropGeometry.box(tool,Vector3(-2.81+i*0.375,1.3,side*1.226),Vector3(0.095,2.36,0.048),paint.lightened(0.12),0.02)
		for h: float in [0.10,2.50]: PropGeometry.box(tool,Vector3(0,h,side*1.22),Vector3(6,0.20,0.06),paint.darkened(0.24),0.022)
		for x: float in [-2.91,2.91]:
			for h: float in [0.11,2.49]:
				PropGeometry.box(tool,Vector3(x,h,side*1.22),Vector3(0.18,0.22,0.06),Color("b2b7a1"),0.018)
	for z: float in [-0.60,0.60]:
		PropGeometry.box(tool,Vector3(2.975,1.3,z),Vector3(0.035,2.32,1.15),paint.lightened(0.025),0.01)
		PropGeometry.tube(tool,Vector3(3.005,0.26,z),Vector3(3.005,2.34,z),0.03,0.03,METAL,8)
		PropGeometry.beam(tool,Vector3(3.035,1.12,z),Vector3(3.035,1.12,z+0.26),0.04,0.04,DARK)
		for h: float in [0.37,1.30,2.21]: PropGeometry.box(tool,Vector3(3.004,h,z+0.42),Vector3(0.055,0.10,0.19),METAL,0.009)
	for i: int in range(16): PropGeometry.box(tool,Vector3(-2.81+i*0.375,2.577,0),Vector3(0.095,0.045,2.35),paint.lightened(0.15),0.018)
