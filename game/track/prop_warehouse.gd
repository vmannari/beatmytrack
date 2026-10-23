class_name PropWarehouse
extends RefCounted
## Original ruined industrial shell. No floor or roof surface across the road.
const STEEL:=Color(0.30,0.34,0.34,0)
const RUST:=Color(0.39,0.23,0.13,0)
const CONCRETE:=Color(0.43,0.44,0.41,0)
const SHEET:=Color(0.33,0.40,0.38,0)
const DARK:=Color(0.10,0.14,0.15,0)
const AMBER:=Color(1.0,0.58,0.20,0.6)

static func build(tool: SurfaceTool) -> void:
	for side: float in [-1.0,1.0]: _side(tool,side)
	for end: float in [-1.0,1.0]: _end(tool,end)
	for z: float in [-11.8,-6,0,6,11.8]: _frame(tool,z)
	_roof(tool)
	_details(tool)

static func _side(tool: SurfaceTool, side: float) -> void:
	var x: float=side*8.8
	# Buried footings bridge the road's raised datum down into the surrounding
	# ground, including the smallest supported object scale.
	PropGeometry.box(tool,Vector3(x,0.055,0),Vector3(0.40,0.61,24.0),CONCRETE.darkened(0.16),0.025)
	# Low masonry remains continuous beneath missing sheets and broken glazing.
	for bay: int in range(6):
		var z: float=-10+bay*4
		PropGeometry.box(tool,Vector3(x,0.87,z),Vector3(0.40,1.03,3.96),CONCRETE.darkened((bay%3)*0.045),0.025)
		for row: int in range(3):
			PropGeometry.beam(tool,Vector3(side*9.008,0.48+row*0.29,z-1.94),Vector3(side*9.008,0.48+row*0.29,z+1.94),0.012,0.012,CONCRETE.darkened(0.22))
		# Individual flutes give the metal wall real depth and a broken upper edge.
		for panel: int in range(8):
			if (bay==2 and panel in [2,3,4]) or (bay==4 and panel in [1,2]): continue
			var pz: float=z-1.76+panel*0.50
			var top: float=5.12-(0.35 if bay==2 and panel==5 else 0.0)
			var low: float=3.75 if bay in [1,3,5] else 1.42
			_sheet(tool,side,pz,low,top,0.48,SHEET.lerp(RUST,0.12+0.10*((panel+bay)%3)))
			if panel%4==0:
				# Rust tears stay seated on a raised flute, below its fastener.
				PropGeometry.face(tool,[Vector3(side*8.970,top-0.20,pz-0.035),Vector3(side*8.970,top-0.20,pz+0.035),Vector3(side*8.970,top-1.05,pz+0.009)],RUST.darkened(0.12),Vector3.RIGHT*side)
		if bay in [1,3,5]:
			# Open window bank: some cracked opaque panes remain in seated frames.
			for h: float in [1.43,3.73]: PropGeometry.beam(tool,Vector3(side*8.78,h,z-1.94),Vector3(side*8.78,h,z+1.94),0.09,0.09,STEEL)
			for pane: int in range(5):
				var pz: float=z-1.93+pane*0.965
				PropGeometry.beam(tool,Vector3(side*8.78,1.43,pz),Vector3(side*8.78,3.73,pz),0.055,0.055,STEEL.darkened(0.12))
				if pane in [0,3]:
					PropGeometry.face(tool,[Vector3(side*8.80,1.56,pz+0.08),Vector3(side*8.80,2.8,pz+0.08),Vector3(side*8.80,3.14,pz+0.34),Vector3(side*8.80,2.31,pz+0.77),Vector3(side*8.80,1.56,pz+0.77)],Color(0.22,0.31,0.32,0),Vector3.RIGHT*side)
	for z: float in [-11.8,-6,0,6,11.8]:
		PropGeometry.box(tool,Vector3(side*8.70,0.015,z),Vector3(0.56,0.53,0.66),CONCRETE,0.035)
		_ibeam(tool,Vector3(side*8.70,0.28,z),Vector3(side*8.70,5.25,z),0.28,0.32)
		for bolt_z: float in [-0.21,0.21]: PropGeometry.tube(tool,Vector3(side*8.70,0.285,z+bolt_z),Vector3(side*8.70,0.31,z+bolt_z),0.027,0.027,STEEL.lightened(0.15),4)
	# Long rails stiffen the intact side roof strips.
	for h: float in [1.38,5.20]: PropGeometry.beam(tool,Vector3(side*8.58,h,-12),Vector3(side*8.58,h,12),0.14,0.16,STEEL)

static func _sheet(tool: SurfaceTool, side: float, z: float, low: float, high: float, width: float, color: Color) -> void:
	var profile: Array[Vector2]=[Vector2(-width*0.5,0.0),Vector2(-width*0.27,0.0),Vector2(-width*0.17,0.065),Vector2(width*0.17,0.065),Vector2(width*0.27,0.0),Vector2(width*0.5,0.0)]
	for i: int in range(profile.size()-1):
		var a: Vector2=profile[i]; var b: Vector2=profile[i+1]
		PropGeometry.face(tool,[Vector3(side*(8.90+a.y),low,z+a.x),Vector3(side*(8.90+b.y),low,z+b.x),Vector3(side*(8.90+b.y),high,z+b.x),Vector3(side*(8.90+a.y),high,z+a.x)],color.darkened(0.06 if i%2==0 else 0.0),Vector3.RIGHT*side)
	for h: float in [low+0.10,high-0.10]:
		PropGeometry.tube(tool,Vector3(side*8.97,h,z),Vector3(side*8.985,h,z),0.020,0.020,STEEL,4)

static func _end(tool: SurfaceTool, end: float) -> void:
	var z: float=end*11.8
	for side: float in [-1.0,1.0]:
		PropGeometry.box(tool,Vector3(side*7.575,0.475,z),Vector3(2.85,1.45,0.4),CONCRETE,0.04)
		PropGeometry.box(tool,Vector3(side*7.575,3.13,z),Vector3(2.85,3.85,0.22),SHEET.darkened(0.05),0.02)
		for panel: int in range(6):
			PropGeometry.beam(tool,Vector3(side*(6.28+panel*0.47),1.28,z+end*0.12),Vector3(side*(6.28+panel*0.47),5.02,z+end*0.12),0.045,0.025,STEEL.lerp(RUST,0.40))
		_ibeam(tool,Vector3(side*6.28,0,z),Vector3(side*6.28,4.94,z),0.26,0.32)
		# Worn safety bands stay on the two real portal jambs.
		for row: int in range(5):
			var y: float=0.3+row*0.22
			PropGeometry.face(tool,[Vector3(side*6.28-0.124,y-0.064,z+end*0.167),Vector3(side*6.28+0.124,y-0.064,z+end*0.167),Vector3(side*6.28+0.124,y+0.064,z+end*0.167),Vector3(side*6.28-0.124,y+0.064,z+end*0.167)],Color(0.63,0.49,0.20,0) if row%2==0 else DARK,Vector3.BACK*end)
	# Door rolled clear of the12.3m opening; nothing spans it at car height.
	_ibeam(tool,Vector3(-6.4,4.94,z),Vector3(6.4,4.94,z),0.24,0.28)
	PropGeometry.tube(tool,Vector3(-6.17,5.24,z),Vector3(6.17,5.24,z),0.19,0.19,RUST.darkened(0.18),16)
	for x: float in [-5.7,0,5.7]: PropGeometry.ring(tool,Vector3(x,5.24,z),Vector3.RIGHT,0.199,0.187,0.035,STEEL.darkened(0.2),10)
	# The upper gable is perforated by the missing central roofing.
	for side: float in [-1.0,1.0]:
		PropGeometry.face(tool,[Vector3(side*9,5.25,z),Vector3(side*6.5,5.25,z),Vector3(side*6.5,5.67,z)],SHEET,Vector3.BACK*end)
		PropGeometry.beam(tool,Vector3(side*9.2,5.25,z),Vector3(0,6.75,z),0.17,0.18,STEEL.lerp(RUST,0.25))

static func _ibeam(tool: SurfaceTool, a: Vector3, b: Vector3, width: float, depth: float) -> void:
	var axis: Vector3=(b-a).normalized()
	var across: Vector3=axis.cross(Vector3.UP).normalized()
	if across.length_squared()<0.1: across=Vector3.RIGHT
	var normal: Vector3=across.cross(axis).normalized()
	PropGeometry.beam(tool,a,b,width*0.18,depth,STEEL.darkened(0.13))
	for sign_value: float in [-1.0,1.0]:
		var offset: Vector3=normal*(depth*0.5-0.017)*sign_value
		PropGeometry.beam(tool,a+offset,b+offset,width,0.034,STEEL.lerp(RUST,0.20))

static func _frame(tool: SurfaceTool, z: float) -> void:
	# Thin exposed trusses cross overhead; the collapsed roof keeps the car in view.
	PropGeometry.beam(tool,Vector3(-8.7,5.20,z),Vector3(8.7,5.20,z),0.13,0.14,STEEL)
	for side: float in [-1.0,1.0]:
		PropGeometry.beam(tool,Vector3(side*8.7,5.25,z),Vector3(0,6.67,z),0.15,0.18,STEEL)
		for i: int in range(4):
			var x: float=side*(0.2+i*2.05)
			var next: float=side*(2.05+i*2.05)
			PropGeometry.beam(tool,Vector3(x,5.22,z),Vector3(next,6.67-absf(next)*1.42/8.7,z),0.065,0.065,STEEL.darkened(0.12))
	PropGeometry.beam(tool,Vector3(0,5.22,z),Vector3(0,6.67,z),0.075,0.075,STEEL)

static func _roof(tool: SurfaceTool) -> void:
	# Only attached outer roof panels survive. The whole central road is open
	# to the camera, without a new per-frame roof-fade system or camera change.
	for side: float in [-1.0,1.0]:
		for bay: int in range(6):
			if (side<0 and bay==2) or (side>0 and bay==4): continue
			var z: float=-10+bay*4
			var inner: float=6.65+(0.40 if bay%3==0 else 0.0)
			var low: Vector3=Vector3(side*9.35,5.15,z-1.97)
			var high: Vector3=Vector3(side*inner,6.67-inner*1.42/8.7,z-1.97)
			PropGeometry.face(tool,[low,low+Vector3.BACK*3.94,high+Vector3.BACK*3.94,high],SHEET.darkened(0.16+(bay%3)*0.04),Vector3.UP)
			for rib: int in range(6):
				var offset:=Vector3(0,0.018,rib*0.76)
				PropGeometry.beam(tool,low+offset,high+offset,0.03,0.024,STEEL.darkened(0.12))
		PropGeometry.tube(tool,Vector3(side*9.34,5.13,-12.1),Vector3(side*9.34,5.13,12.1),0.07,0.07,RUST.darkened(0.15),10)
		# Intact downpipe seated at the back corner.
		PropGeometry.tube(tool,Vector3(side*9.08,0.3,10.6),Vector3(side*9.08,5.1,10.6),0.055,0.055,RUST,10)

static func _details(tool: SurfaceTool) -> void:
	for side: float in [-1.0,1.0]:
		var p:=Vector3(side*7.35,4.05,side*7.5)
		PropGeometry.beam(tool,Vector3(side*8.55,4.38,side*7.5),p+Vector3.UP*0.14,0.065,0.065,STEEL)
		PropGeometry.box(tool,p,Vector3(0.8,0.12,0.38),DARK,0.04)
		PropGeometry.box(tool,p-Vector3.UP*0.075,Vector3(0.63,0.034,0.25),AMBER,0.015)
		for x: float in [-0.24,0,0.24]: PropGeometry.beam(tool,p+Vector3(x,-0.11,-0.15),p+Vector3(x,-0.11,0.15),0.022,0.022,STEEL)
		# Side-mounted disconnected cabinet and cable conduit, outside the passage.
		PropGeometry.box(tool,Vector3(side*8.47,1.9,-side*3),Vector3(0.16,0.95,0.65),STEEL.lerp(RUST,0.32),0.045)
		PropGeometry.tube(tool,Vector3(side*8.42,0.42,-side*3.37),Vector3(side*8.42,3.7,-side*3.37),0.025,0.025,DARK,7)
