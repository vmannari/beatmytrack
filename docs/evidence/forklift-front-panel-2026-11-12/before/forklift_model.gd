extends RefCounted
## Original counterbalance forklift. Same finish, tire kit and material batching as Compact.
## All dimensions are model metres. Wheels remain independent steering/rolling frames.
static var meshes: Dictionary = {}
const TRANSPORT_LIFT: float = 0.60 # Raised carriage; model metres, before shared body scale.

static func build(car: CarVisual) -> void:
	var paint := CompactFinish.paint(Color("d5a62d"))
	var accent := CompactFinish.paint(Color("e0d5b5"))
	var steel := CompactFinish.alloy(Color("687576"))
	var bright := CompactFinish.alloy(Color("bac5c1"))
	var dark := CompactFinish.paint(Color("273439"))
	dark.roughness = 0.54
	var rubber := CompactFinish.rubber(Color("172024"))
	var seat := CompactFinish.rubber(Color("343d3e"))
	var amber := CompactFinish.paint(Color("c58025"))
	car.brake_material = CompactFinish.paint(Color("802d2b"))
	car.paint_materials = {"body":paint,"accent":accent}
	var detail: int = 1 if car.simple_model else 3
	var body: Node3D = car.body
	# Cast rear counterweight: rounded shoulders and an inset, removable engine lid.
	_box(body,Vector3(1.69,0.80,0.97),Vector3(0,1.02,1.07),0.17,paint,detail,"CastCounterweight")
	# Continuous formed sidework, with open wheel arches and functional entry steps.
	for side: float in [-1.0,1.0]:
		_side_skin(car,side,paint)
		_box(body,Vector3(0.28,0.09,0.68),Vector3(side*0.81,0.57,-0.13),0.035,dark,detail,"EntryStep")
		for ridge: int in range(8):
			_box(body,Vector3(0.25,0.009,0.018),Vector3(side*0.81,0.62,-0.41+ridge*0.079),0.004,steel,1,"StepGrip")
		_arch(car,side,-config_axle(),0.43,paint,rubber)
		_arch(car,side,config_axle(),0.30,paint,rubber)
	_box(body,Vector3(1.49,0.13,2.68),Vector3(0,0.37,0.17),0.055,rubber,detail,"Chassis")
	_box(body,Vector3(1.31,0.10,1.33),Vector3(0,0.81,-0.27),0.035,dark,detail,"OperatorFloor")
	for index: int in range(10):
		_box(body,Vector3(0.027,0.008,0.81),Vector3(-0.49+index*0.108,0.866,-0.32),0.004,rubber,1,"FloorGrip")
	_operator(car,seat,rubber,dark,steel,bright,detail)
	_guard(car,dark,steel,bright,rubber,accent,amber,detail)
	_mast(car,dark,steel,bright,rubber,detail)
	# Recessed rear light assemblies, perimeter bumper and safety bars.
	for side: float in [-1.0,1.0]:
		_box(body,Vector3(0.27,0.17,0.06),Vector3(side*0.55,1.10,1.548),0.032,rubber,detail,"TailLampRecess")
		_box(body,Vector3(0.22,0.11,0.045),Vector3(side*0.55,1.10,1.584),0.023,car.brake_material,detail,"TailLampLens")
		for line: int in range(4):
			_box(body,Vector3(0.18,0.005,0.005),Vector3(side*0.55,1.064+line*0.023,1.61),0.002,car.brake_material,1,"TailLensFlute")
		_box(body,Vector3(0.14,0.025,0.32),Vector3(side*0.53,0.677,1.54),0.009,amber,detail,"WarningMark")
	# Curved exhaust stack and its heat shield behind the operator, below the guard.
	_exhaust(body,dark,car.simple_model)
	_box(body,Vector3(0.12,0.43,0.11),Vector3(0.62,1.71,0.99),0.035,steel,detail,"ExhaustShield")
	for vent: int in range(6):
		_box(body,Vector3(0.07,0.008,0.004),Vector3(0.62,1.56+vent*0.058,1.049),0.002,dark,1,"ShieldVent")

static func config_axle() -> float:
	return 1.72/(2.0*HandlingConfig.BODY_SCALE)

static func stock_engine_cover(car: CarVisual, parent: Node3D) -> void:
	var detail: int = 1 if car.simple_model else 3
	var rubber := CompactFinish.rubber(Color("172024"))
	var dark := CompactFinish.paint(Color("273439"))
	dark.roughness = 0.54
	_box(parent,Vector3(1.43,0.055,0.83),Vector3(0,1.441,1.04),0.024,rubber,detail,"EngineLidGasket")
	_box(parent,Vector3(1.39,0.065,0.79),Vector3(0,1.476,1.04),0.028,car.paint_materials.accent,detail,"EngineLid")
	_box(parent,Vector3(0.83,0.008,0.49),Vector3(0,1.511,1.06),0.012,rubber,1,"CoolingRecess")
	for index: int in range(10):
		_box(parent,Vector3(0.78,0.016,0.022),Vector3(0,1.519,0.848+index*0.047),0.007,dark,1,"CoolingLouvre")

static func stock_rear_guard(car: CarVisual, parent: Node3D) -> void:
	_box(parent,Vector3(1.52,0.19,0.15),Vector3(0,0.57,1.59),0.055,CompactFinish.rubber(Color("172024")),1 if car.simple_model else 3,"RearBumper")

static func _side_skin(car: CarVisual, side: float, paint: Material) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps: int = 36 if car.simple_model else 96
	for index: int in range(steps):
		var corners: Array[Vector3] = []
		for coordinate: Vector2 in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
			var z: float = lerpf(-1.27,1.48,(index+coordinate.x)/steps)
			var lower: float = 0.39
			for axle: float in [-config_axle(),config_axle()]:
				var radius: float = (0.43 if axle<0.0 else 0.30)+0.065
				var offset: float = absf(z-axle)
				if offset<radius: lower = maxf(lower,(0.43 if axle<0.0 else 0.30)+sqrt(radius*radius-offset*offset))
			var upper: float = 1.12-0.10*smoothstep(-0.75,-0.25,z)
			var y: float = lerpf(lower,upper,coordinate.y)
			var x: float = 0.82-0.045*pow((y-0.75)/0.55,2.0)-0.08*smoothstep(1.25,1.50,z)
			corners.append(Vector3(side*x,y,z))
		_solid_strip(tool,corners,Vector3(-side*0.065,0,0),Vector3(side,0,0),index==0,index==steps-1)
	_attach(car.body,tool.commit(),paint,"FormedSideSkinLeft" if side<0.0 else "FormedSideSkinRight")

static func _arch(car: CarVisual, side: float, z: float, tire: float, paint: Material, trim: Material) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps: int = 18 if car.simple_model else 40
	for index: int in range(steps):
		var a: float = lerpf(-0.12,PI+0.12,index/float(steps))
		var b: float = lerpf(-0.12,PI+0.12,(index+1)/float(steps))
		var corners: Array[Vector3] = []
		for pair: Vector2 in [Vector2(a,0),Vector2(b,0),Vector2(b,1),Vector2(a,1)]:
			var radius: float = tire+lerpf(0.048,0.086,pair.y)
			# The rolled rim sits outside the side skin instead of sharing its face.
			corners.append(Vector3(side*lerpf(0.857,0.833,pair.y),tire+sin(pair.x)*radius,z+cos(pair.x)*radius))
		_solid_strip(tool,corners,Vector3(-side*0.045,0,0),Vector3(side,0,0),index==0,index==steps-1)
	var shell: ArrayMesh = tool.commit()
	var arrays: Array = shell.surface_get_arrays(0)
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for vertex: int in range(positions.size()):
		var radial: Vector3 = Vector3(0,positions[vertex].y-tire,positions[vertex].z-z).normalized()
		var amount: float = normals[vertex].dot(radial)
		if absf(amount)>0.05:
			normals[vertex] = (Vector3(normals[vertex].x,0,0)+radial*signf(amount)*sqrt(maxf(0,1-normals[vertex].x*normals[vertex].x))).normalized()
	arrays[Mesh.ARRAY_NORMAL] = normals
	var smooth := ArrayMesh.new()
	smooth.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	_attach(car.body,smooth,paint,"RolledWheelArch%s%s" % ["Left" if side<0.0 else "Right","Front" if z<0.0 else "Rear"])
	# Thin inner lip separates paint from tire without filling the opening.
	var path: Array[Vector3] = []
	for index: int in range(steps+1):
		var angle: float = lerpf(-0.12,PI+0.12,index/float(steps))
		path.append(Vector3(side*0.861,tire+sin(angle)*(tire+0.041),z+cos(angle)*(tire+0.041)))
	_pipe(car.body,path,0.009,trim)

static func _solid_strip(tool: SurfaceTool, outer: Array[Vector3], inset: Vector3, outward: Vector3, first: bool, last: bool) -> void:
	# A closed formed-steel shell: outer/inner skins, rolled returns and end caps.
	var inner: Array[Vector3] = []
	for point: Vector3 in outer: inner.append(point+inset)
	_face(tool,outer,outward)
	_face(tool,inner,-outward)
	var lower: Vector3 = outer[0]+outer[1]-outer[2]-outer[3]
	var start: Vector3 = outer[0]+outer[3]-outer[1]-outer[2]
	_face(tool,[outer[0],outer[1],inner[1],inner[0]],lower)
	_face(tool,[outer[3],inner[3],inner[2],outer[2]],-lower)
	if first: _face(tool,[outer[0],inner[0],inner[3],outer[3]],start)
	if last: _face(tool,[outer[1],outer[2],inner[2],inner[1]],-start)

static func _face(tool: SurfaceTool, points: Array[Vector3], outward: Vector3) -> void:
	var normal: Vector3 = (points[1]-points[0]).cross(points[2]-points[0]).normalized()
	if normal.dot(outward)<0.0: normal = -normal
	# Godot's front faces wind clockwise; normals face out of the solid shell.
	_quad(tool,points,normal,(points[1]-points[0]).cross(points[2]-points[0]).dot(normal)>0.0)

static func _operator(car: CarVisual, seat: Material, rubber: Material, dark: Material, steel: Material, bright: Material, detail: int) -> void:
	var parent: Node3D = car.body
	_box(parent,Vector3(0.49,0.15,0.44),Vector3(0,1.02,0.25),0.035,steel,detail,"SeatSuspension")
	for side: float in [-1.0,1.0]:
		_box(parent,Vector3(0.04,0.06,0.59),Vector3(side*0.21,1.10,0.24),0.013,dark,detail,"SeatRail")
	_box(parent,Vector3(0.63,0.17,0.58),Vector3(0,1.20,0.22),0.077,seat,detail,"SeatCushion")
	_box(parent,Vector3(0.50,0.11,0.47),Vector3(0,1.273,0.19),0.045,rubber,detail,"SeatInset")
	var back: MeshInstance3D = _box(parent,Vector3(0.65,0.66,0.18),Vector3(0,1.54,0.50),0.082,seat,detail,"SeatBack")
	back.rotation.x = -0.12
	for side: float in [-1.0,1.0]:
		_box(parent,Vector3(0.10,0.31,0.13),Vector3(side*0.27,1.49,0.38),0.045,rubber,detail,"SeatBolster")
		_box(parent,Vector3(0.035,0.018,0.37),Vector3(side*0.30,1.306,0.22),0.008,dark,1,"SeatStitch")
	_box(parent,Vector3(0.045,0.075,0.07),Vector3(0.35,1.20,0.23),0.012,rubber,detail,"SeatBeltBuckle")
	_box(parent,Vector3(0.031,0.012,0.035),Vector3(0.35,1.24,0.23),0.006,car.brake_material,1,"BeltRelease")
	_box(parent,Vector3(0.87,0.24,0.29),Vector3(0,1.27,-0.66),0.065,dark,detail,"InstrumentConsole")
	var gauges := Node3D.new()
	parent.add_child(gauges)
	gauges.position = Vector3(-0.19,1.405,-0.63)
	gauges.rotation.x = 0.35
	for x: float in [-0.10,0.10]:
		var bezel := VisualGeometry.cylinder(gauges,0.067,0.012,Vector3(x,0,0),steel,true)
		VisualGeometry.cylinder(gauges,0.056,0.016,Vector3(x,0.004,0),rubber,true)
		_box(gauges,Vector3(0.006,0.003,0.036),Vector3(x+0.006,0.014,-0.006),0.002,bright,1,"GaugeNeedle")
		bezel.name = "InstrumentBezel"
	var column := Node3D.new()
	parent.add_child(column)
	column.position = Vector3(-0.16,1.61,-0.40)
	column.rotation.x = 0.40
	VisualGeometry.cylinder(column,0.040,0.41,Vector3(0,-0.21,0),dark,true)
	var rim := TorusMesh.new()
	rim.inner_radius = 0.183
	rim.outer_radius = 0.221
	rim.rings = 24 if car.simple_model else 48
	rim.ring_segments = 6 if car.simple_model else 10
	_attach(column,rim,rubber,"SteeringWheelRim")
	VisualGeometry.cylinder(column,0.055,0.038,Vector3.ZERO,dark,true)
	for spoke: int in range(3):
		var angle: float = spoke*TAU/3.0+0.35
		_beam(column,Vector3.ZERO,Vector3(cos(angle)*0.185,0,sin(angle)*0.185),0.023,dark,1)
	for index: int in range(3):
		var x: float = 0.36+index*0.105
		_box(parent,Vector3(0.08,0.045,0.14),Vector3(x,1.10,-0.10),0.018,rubber,detail,"LeverGaiter")
		_pipe(parent,[Vector3(x,1.11,-0.10),Vector3(x,1.30,-0.16),Vector3(x,1.45,-0.22)],0.012,steel)
		_box(parent,Vector3(0.058,0.076,0.058),Vector3(x,1.46,-0.22),0.027,rubber,detail,"LeverGrip")
	for x: float in [-0.27,0.22]:
		var pedal: MeshInstance3D = _box(parent,Vector3(0.14,0.028,0.18),Vector3(x,0.91,-0.64),0.015,rubber,detail,"Pedal")
		pedal.rotation.x = -0.30
		for rib: int in range(4):
			_box(parent,Vector3(0.12,0.007,0.012),Vector3(x,0.944-rib*0.012,-0.70+rib*0.035),0.003,steel,1,"PedalRib")

static func _guard(car: CarVisual, dark: Material, steel: Material, bright: Material, rubber: Material, accent: Material, amber: Material, detail: int) -> void:
	var parent: Node3D = car.body
	for side: float in [-1.0,1.0]:
		_box(parent,Vector3(0.25,0.17,0.16),Vector3(side*0.70,2.47,-0.81),0.045,rubber,detail,"WorkLampHousing")
		_box(parent,Vector3(0.21,0.12,0.025),Vector3(side*0.70,2.47,-0.902),0.025,bright,detail,"WorkLampReflector")
		_box(parent,Vector3(0.18,0.09,0.018),Vector3(side*0.70,2.47,-0.921),0.020,accent,detail,"WorkLampLens")
		for index: int in range(4):
			_box(parent,Vector3(0.026,0.058,0.006),Vector3(side*0.70-0.059+index*0.040,2.47,-0.932),0.007,bright,1,"LEDOptic")
		_pipe(parent,[Vector3(side*0.70,2.23,-0.69),Vector3(side*0.86,2.23,-0.62),Vector3(side*0.88,2.17,-0.58)],0.014,dark)
		_box(parent,Vector3(0.17,0.23,0.07),Vector3(side*0.88,2.13,-0.54),0.037,rubber,detail,"MirrorHousing")
		_box(parent,Vector3(0.13,0.18,0.008),Vector3(side*0.88,2.13,-0.50),0.025,bright,detail,"MirrorGlass")
	var beacon_base := VisualGeometry.cylinder(parent,0.115,0.044,Vector3(0.55,2.74,0.65),rubber,true)
	beacon_base.name = "BeaconBase"
	VisualGeometry.cylinder(parent,0.087,0.14,Vector3(0.55,2.83,0.65),amber,true)
	VisualGeometry.cylinder(parent,0.089,0.021,Vector3(0.55,2.908,0.65),amber,true)
	for index: int in range(3):
		VisualGeometry.ring(parent,Vector3(0.55,2.784+index*0.039,0.65),0.086,0.004,amber)

static func stock_cabin(car: CarVisual, parent: Node3D) -> void:
	# Original structure is replaceable; lamps, mirrors and beacon stay fixed.
	var dark := CompactFinish.paint(Color("273439"))
	dark.roughness = 0.54
	var steel := CompactFinish.alloy(Color("687576"))
	var bright := CompactFinish.alloy(Color("bac5c1"))
	var detail: int = 1 if car.simple_model else 3
	for side: float in [-1.0,1.0]:
		for z: float in [-0.77,0.74]:
			_beam(parent,Vector3(side*0.65,1.02,z),Vector3(side*0.71,2.61,z+0.06),0.078,dark,detail)
			_box(parent,Vector3(0.17,0.11,0.19),Vector3(side*0.65,1.05,z),0.021,steel,detail,"GuardFoot")
			_bolt(parent,Vector3(side*0.74,1.06,z),Vector3(side,0,0),0.021,bright)
		_box(parent,Vector3(0.13,0.12,1.85),Vector3(side*0.71,2.65,0.02),0.033,dark,detail,"GuardSideRail")
	for z: float in [-0.85,0.90]:
		_box(parent,Vector3(1.49,0.12,0.12),Vector3(0,2.65,z),0.031,dark,detail,"GuardCrossRail")
	for index: int in range(6):
		_box(parent,Vector3(1.34,0.052,0.061),Vector3(0,2.675,-0.65+index*0.27),0.017,dark,detail,"GuardSlat")

static func _mast(car: CarVisual, dark: Material, steel: Material, bright: Material, rubber: Material, detail: int) -> void:
	var parent: Node3D = car.body
	var carriage := Node3D.new()
	carriage.name = "RaisedForkCarriage"
	carriage.position.y = TRANSPORT_LIFT
	parent.add_child(carriage)
	for side: float in [-1.0,1.0]:
		var x: float = side*0.52
		# Open channel section and its polished sliding face.
		_box(parent,Vector3(0.045,2.47,0.24),Vector3(x+side*0.061,1.49,-1.23),0.009,dark,detail,"MastWeb")
		for z: float in [-1.345,-1.115]:
			_box(parent,Vector3(0.17,2.47,0.034),Vector3(x,1.49,z),0.009,dark,detail,"MastFlange")
		_box(parent,Vector3(0.035,2.30,0.022),Vector3(x-side*0.038,1.49,-1.355),0.006,steel,detail,"MastSlidingRail")
		VisualGeometry.cylinder(parent,0.078,0.99,Vector3(side*0.29,0.98,-1.19),dark,true)
		VisualGeometry.cylinder(parent,0.045,1.31,Vector3(side*0.29,1.89,-1.19),bright,true)
		VisualGeometry.cylinder(parent,0.090,0.065,Vector3(side*0.29,1.49,-1.19),steel,true)
		_pipe(parent,[Vector3(side*0.29,0.63,-1.11),Vector3(side*0.38,0.60,-1.01),Vector3(side*0.44,0.88,-1.01),Vector3(side*0.43,1.63,-1.07),Vector3(side*0.38,2.38,-1.18)],0.018,rubber)
		var pulley := VisualGeometry.cylinder(parent,0.11,0.105,Vector3(side*0.31,2.47,-1.23),steel,true)
		pulley.rotation.z = PI*0.5
		_bolt(parent,Vector3(side*0.37,2.47,-1.23),Vector3(side,0,0),0.025,bright)
		_lift_chain(parent,carriage,side,steel,dark,car.simple_model)
		_box(parent,Vector3(0.29,0.18,0.20),Vector3(x,0.44,-1.23),0.035,dark,detail,"MastPivotHousing")
		_bolt(parent,Vector3(x+side*0.17,0.44,-1.23),Vector3(side,0,0),0.055,steel)
		_fork(carriage,side*0.43,steel,car.simple_model)
	_box(parent,Vector3(1.20,0.15,0.25),Vector3(0,2.72,-1.23),0.032,dark,detail,"MastCrosshead")
	for y: float in [0.54,1.10]:
		_box(carriage,Vector3(1.31,0.12,0.13),Vector3(0,y,-1.42),0.018,steel,detail,"CarriageCrossmember")
	for side: float in [-1.0,1.0]:
		_box(carriage,Vector3(0.075,0.63,0.075),Vector3(side*0.62,0.83,-1.42),0.014,dark,detail,"BackrestFrame")
	for index: int in range(7):
		_box(carriage,Vector3(0.029,0.50,0.043),Vector3(-0.53+index*0.177,0.83,-1.42),0.008,dark,detail,"LoadBackrest")

static func _fork(parent: Node3D, x: float, steel: Material, simple: bool) -> void:
	# Extruded L profile: forged heel, sloping top and a thin tapered toe.
	var profile := PackedVector2Array([Vector2(-1.45,0.18),Vector2(-2.58,0.18),Vector2(-2.65,0.198),Vector2(-2.59,0.223),Vector2(-1.68,0.277),Vector2(-1.60,0.293),Vector2(-1.565,0.332),Vector2(-1.565,1.02),Vector2(-1.45,1.02)])
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var triangles: PackedInt32Array = Geometry2D.triangulate_polygon(profile)
	for side: float in [-1.0,1.0]:
		for index: int in range(0,triangles.size(),3):
			var order: Array = [2,1,0] if side<0.0 else [0,1,2]
			for vertex: int in order:
				var p: Vector2 = profile[triangles[index+vertex]]
				tool.set_normal(Vector3(side,0,0)); tool.set_uv(Vector2(p.x,p.y)); tool.add_vertex(Vector3(x+side*0.10,p.y,p.x))
	for index: int in range(profile.size()):
		var a: Vector2 = profile[index]
		var b: Vector2 = profile[(index+1)%profile.size()]
		var normal := Vector3(0,b.x-a.x,a.y-b.y).normalized()
		_quad(tool,[Vector3(x-0.10,a.y,a.x),Vector3(x+0.10,a.y,a.x),Vector3(x+0.10,b.y,b.x),Vector3(x-0.10,b.y,b.x)],normal)
	_attach(parent,tool.commit(),steel,"ForgedForkLeft" if x<0.0 else "ForgedForkRight")
	_box(parent,Vector3(0.11,0.08,0.16),Vector3(x,1.04,-1.43),0.016,steel,1 if simple else 3,"ForkLock")

static func wheel(car: CarVisual, center: Vector3, radius: float, width: float) -> void:
	var pivot := Node3D.new()
	pivot.position = center
	car.add_child(pivot)
	CompactDetail.tire(pivot,CompactFinish.rubber(Color("172024")),car.simple_model)
	var tire: MeshInstance3D = pivot.get_child(0)
	tire.scale = Vector3(width/0.28,radius/0.37,radius/0.37)
	if center.z>0.0: car.rear_wheels.append(pivot)
	car.register_rolling_wheel(pivot,radius)

static func stock_wheel(parent: Node3D, radius: float, width: float, side: float, closed_trim: bool = false) -> void:
	var rim := CompactFinish.paint(Color("b3b5a9"))
	rim.metallic = 0.48
	var dark := CompactFinish.rubber(Color("263034"))
	var bright := CompactFinish.alloy(Color("9ba7a5"))
	var scale_factor: float = radius/0.43
	var face: float = width*0.48
	# Recessed pressed-steel dish, rolled rim lip, raised hub and six lug nuts.
	var dish := VisualGeometry.cylinder(parent,radius*0.63,width*0.85,Vector3.ZERO,rim,true)
	dish.rotation.z = PI*0.5
	var well := VisualGeometry.cylinder(parent,radius*0.47,0.018,Vector3(side*(face+0.005),0,0),dark,true)
	well.rotation.z = PI*0.5
	var hub := VisualGeometry.cylinder(parent,radius*0.26,0.050,Vector3(side*(face+0.023),0,0),rim,true)
	hub.rotation.z = PI*0.5
	var lip := Node3D.new()
	parent.add_child(lip)
	lip.position.x = side*(face+0.008)
	lip.rotation.z = PI*0.5
	if not closed_trim:
		VisualGeometry.ring(lip,Vector3.ZERO,radius*0.59,0.018*scale_factor,bright)
		VisualGeometry.ring(lip,Vector3.ZERO,radius*0.48,0.009*scale_factor,rim)
	for index: int in range(6):
		var angle: float = index*TAU/6.0
		_bolt(parent,Vector3(side*(face+0.047),sin(angle)*radius*0.18,cos(angle)*radius*0.18),Vector3(side,0,0),0.016*scale_factor,bright)
		var hole := VisualGeometry.cylinder(parent,0.032*scale_factor,0.012,Vector3(side*(face+0.016),sin(angle)*radius*0.48,cos(angle)*radius*0.48),dark,true)
		hole.rotation.z = PI*0.5
	# A valve stem adds scale without additional moving frames.
	_beam(parent,Vector3(side*face,0,radius*0.52),Vector3(side*(face+0.032),0,radius*0.52),0.012,dark,1)
	if closed_trim:
		for node: MeshInstance3D in parent.find_children("*","MeshInstance3D",true,false):
			if node.mesh is CylinderMesh:
				var copy: CylinderMesh=node.mesh.duplicate()
				copy.rings=1
				node.mesh=copy

static func _bolt(parent: Node3D, point: Vector3, normal: Vector3, radius: float, material: Material) -> void:
	var bolt := VisualGeometry.cylinder(parent,radius,0.014,point,material,true)
	bolt.quaternion = Quaternion(Vector3.UP,normal)
	var mesh := bolt.mesh.duplicate() as CylinderMesh
	mesh.radial_segments = 6
	bolt.mesh = mesh

static func _beam(parent: Node3D, a: Vector3, b: Vector3, width: float, material: Material, detail: int) -> void:
	var mesh: MeshInstance3D = _box(parent,Vector3(width,width,a.distance_to(b)),(a+b)*0.5,width*0.20,material,detail,"WeldedBeam")
	mesh.quaternion = Quaternion(Vector3.BACK,(b-a).normalized())

static func _pipe(parent: Node3D, points: Array[Vector3], radius: float, material: Material) -> void:
	for index: int in range(points.size()-1):
		var a: Vector3 = points[index]
		var b: Vector3 = points[index+1]
		var pipe := VisualGeometry.cylinder(parent,radius,a.distance_to(b),(a+b)*0.5,material,true)
		pipe.quaternion = Quaternion(Vector3.UP,(b-a).normalized())

static func _lift_chain(parent: Node3D, carriage: Node3D, side: float, steel: Material, dark: Material, simple: bool) -> void:
	# A leaf chain has paired continuous side plates and transverse pins. The
	# fixed return rises behind the sheave and wraps to the raised carriage.
	var suffix: String = "Left" if side<0.0 else "Right"
	var mechanism := Node3D.new()
	mechanism.name = "LiftMechanism"+suffix
	parent.add_child(mechanism)
	var x: float = side*0.31
	var path: Array[Vector3] = [Vector3(x,0.47,-1.11),Vector3(x,2.47,-1.11)]
	var arc_steps: int = 8 if simple else 16
	for index: int in range(1,arc_steps+1):
		var angle: float = index*PI/arc_steps
		path.append(Vector3(x,2.47+sin(angle)*0.12,-1.23+cos(angle)*0.12))
	path.append(Vector3(x,1.10+TRANSPORT_LIFT,-1.35))
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for plate: float in [-1.0,1.0]:
		for index: int in range(path.size()-1):
			var corners: Array[Vector3] = []
			for pair: Vector2i in [Vector2i(index,1),Vector2i(index+1,1),Vector2i(index+1,-1),Vector2i(index,-1)]:
				var point: Vector3 = path[pair.x]
				var tangent: Vector3 = (path[mini(pair.x+1,path.size()-1)]-path[maxi(pair.x-1,0)]).normalized()
				var normal := Vector3(0,-tangent.z,tangent.y)
				corners.append(point+Vector3(plate*0.029,0,0)+normal*pair.y*0.010)
			_solid_strip(tool,corners,Vector3(-plate*0.014,0,0),Vector3(plate,0,0),index==0,index==path.size()-2)
	_attach(mechanism,tool.commit(),steel,"LiftChain"+suffix)
	# Pins share the route at a bounded pitch, including the bend. Racing keeps
	# the full chain silhouette while reducing only the small transverse detail.
	var length: float = 0.0
	for index: int in range(path.size()-1): length += path[index].distance_to(path[index+1])
	var count: int = ceili(length/(0.13 if simple else 0.065))
	var segment: int = 0
	var traversed: float = 0.0
	for index: int in range(count+1):
		var distance: float = length*index/count
		while segment<path.size()-2 and traversed+path[segment].distance_to(path[segment+1])<distance:
			traversed += path[segment].distance_to(path[segment+1])
			segment += 1
		var point: Vector3 = path[segment].lerp(path[segment+1],(distance-traversed)/path[segment].distance_to(path[segment+1]))
		var pin := VisualGeometry.cylinder(mechanism,0.009,0.066,point,dark,true)
		pin.name = "ChainPin"
		pin.rotation.z = PI*0.5
		var mesh: CylinderMesh = pin.mesh.duplicate() as CylinderMesh
		mesh.radial_segments = 6
		pin.mesh = mesh
	_box(mechanism,Vector3(0.10,0.12,0.16),Vector3(x,0.47,-1.15),0.012,dark,1,"FixedChainAnchor"+suffix)
	_box(carriage,Vector3(0.10,0.13,0.13),Vector3(x,1.10,-1.37),0.014,steel,1,"CarriageChainAnchor"+suffix)

static func _exhaust(parent: Node3D, surface: Material, simple: bool) -> void:
	# Continuous outer wall, dark inner bore and annular ends. There is no disk
	# across the outlet, and cylinder caps cannot protrude through the bends.
	var stack := Node3D.new()
	stack.name = "HollowExhaustStack"
	parent.add_child(stack)
	var points: Array[Vector3] = [Vector3(0.58,1.24,0.94),Vector3(0.62,1.50,0.98),Vector3(0.62,2.03,0.98),Vector3(0.59,2.12,1.02)]
	var segments: int = 12 if simple else 24
	var rings: Array[Array] = []
	var normals: Array[Array] = []
	var tangents: Array[Vector3] = []
	for index: int in range(points.size()):
		var tangent: Vector3 = (points[mini(index+1,points.size()-1)]-points[maxi(index-1,0)]).normalized()
		tangents.append(tangent)
		var u: Vector3 = Vector3.RIGHT.slide(tangent).normalized()
		var v: Vector3 = tangent.cross(u).normalized()
		var radial: Array[Vector3] = []
		for step: int in range(segments): radial.append(u*cos(step*TAU/segments)+v*sin(step*TAU/segments))
		normals.append(radial)
		var ring: Array[Vector3] = []
		for radius: float in [0.032,0.024]:
			for normal: Vector3 in radial: ring.append(points[index]+normal*radius)
		rings.append(ring)
	var outer := SurfaceTool.new()
	var inner := SurfaceTool.new()
	outer.begin(Mesh.PRIMITIVE_TRIANGLES)
	inner.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in range(points.size()-1):
		for step: int in range(segments):
			var next: int = (step+1)%segments
			for wall: int in range(2):
				var offset: int = wall*segments
				var sign_normal: float = 1.0 if wall==0 else -1.0
				_smooth_quad(outer if wall==0 else inner,[rings[index][offset+step],rings[index][offset+next],rings[index+1][offset+next],rings[index+1][offset+step]],[normals[index][step]*sign_normal,normals[index][next]*sign_normal,normals[index+1][next]*sign_normal,normals[index+1][step]*sign_normal])
	for end: int in [0,points.size()-1]:
		for step: int in range(segments):
			var next: int = (step+1)%segments
			_face(outer,[rings[end][step],rings[end][next],rings[end][segments+next],rings[end][segments+step]],tangents[end]*(-1.0 if end==0 else 1.0))
	_attach(stack,outer.commit(),surface,"ExhaustOuterWall")
	_attach(stack,inner.commit(),CompactFinish.rubber(Color("080d0f")),"ExhaustBore")

static func _smooth_quad(tool: SurfaceTool, points: Array[Vector3], normals: Array[Vector3]) -> void:
	var reverse: bool = (points[1]-points[0]).cross(points[2]-points[0]).dot(normals[0]+normals[1]+normals[2]+normals[3])>0.0
	for index: int in ([0,2,1,0,3,2] if reverse else [0,1,2,0,2,3]):
		tool.set_normal(normals[index])
		tool.set_uv(Vector2(points[index].x+points[index].z,points[index].y))
		tool.add_vertex(points[index])

static func _box(parent: Node3D, size: Vector3, center: Vector3, radius: float, material: Material, detail: int, label: String) -> MeshInstance3D:
	var key: String = str([size,radius,detail])
	if not meshes.has(key):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var half: Vector3 = size*0.5
		var r: float = minf(radius,minf(half.x,minf(half.y,half.z))*0.95)
		var inner: Vector3 = half-Vector3.ONE*r
		for face: int in range(3):
			var u: int = (face+1)%3
			var v: int = (face+2)%3
			var us: Array[float] = _samples(half[u],r,detail)
			var vs: Array[float] = _samples(half[v],r,detail)
			for side: float in [-1.0,1.0]:
				for row: int in range(us.size()-1):
					for col: int in range(vs.size()-1):
						for index: int in ([0,1,2,0,2,3] if side<0.0 else [2,1,0,3,2,0]):
							var q := Vector3.ZERO
							q[face] = side*half[face]
							q[u] = us[row+(1 if index in [1,2] else 0)]
							q[v] = vs[col+(1 if index in [2,3] else 0)]
							var clipped: Vector3 = q.clamp(-inner,inner)
							var normal: Vector3 = (q-clipped).normalized()
							tool.set_normal(normal)
							tool.set_uv(Vector2(q[u]/size[u]+0.5,q[v]/size[v]+0.5))
							tool.add_vertex(clipped+normal*r)
		tool.index()
		meshes[key] = tool.commit()
	var result: MeshInstance3D = _attach(parent,meshes[key],material,label)
	result.position = center
	return result

static func _samples(half: float, radius: float, detail: int) -> Array[float]:
	var result: Array[float] = []
	for index: int in range(detail+1): result.append(lerpf(-half,-half+radius,index/float(detail)))
	for index: int in range(detail+1): result.append(lerpf(half-radius,half,index/float(detail)))
	return result

static func _attach(parent: Node3D, resource: Mesh, material: Material, label: String) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	result.name = label
	result.mesh = resource
	result.material_override = material
	parent.add_child(result)
	return result

static func _quad(tool: SurfaceTool, points: Array[Vector3], normal: Vector3, reverse: bool = false) -> void:
	for index: int in ([0,2,1,0,3,2] if reverse else [0,1,2,0,2,3]):
		tool.set_normal(normal)
		tool.set_uv(Vector2(points[index].x+points[index].z,points[index].y))
		tool.add_vertex(points[index])
