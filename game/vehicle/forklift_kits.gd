extends RefCounted
## Industrial cosmetic assemblies: formed panels, rolled edges and bolted hardpoints.
const Model = preload("res://vehicle/forklift_model.gd")
const Surface = preload("res://vehicle/forklift_kit_surface.gd")

static func _finish(color: String, metal: float = 0.18) -> StandardMaterial3D:
	var result := CompactFinish.paint(Color(color))
	result.roughness = 0.66
	result.metallic = metal
	result.metallic_specular = 0.24
	result.clearcoat_enabled = false
	return result

static func _box(parent: Node3D, label: String, size: Vector3, at: Vector3, material: Material, simple: bool, bevel: float = 0.006) -> MeshInstance3D:
	return Model._box(parent,size,at,bevel,material,1 if simple else 2,label)

static func _bolt(parent: Node3D, at: Vector3, normal: Vector3, radius: float, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius=radius; mesh.bottom_radius=radius; mesh.height=0.012
	mesh.radial_segments=6; mesh.rings=1
	var node := MeshInstance3D.new()
	node.name="FlushHexFastener"
	node.mesh=mesh; node.material_override=material
	node.position=at; node.quaternion=Quaternion(Vector3.UP,normal)
	parent.add_child(node)

static func _beam(parent: Node3D, label: String, a: Vector3, b: Vector3, size: Vector2, material: Material, simple: bool) -> void:
	Surface.tube(parent,label,[a,b],size,0.007,material,simple)

static func build(car: CarVisual, category: String) -> void:
	var kind: String = str(car.customisation[category])
	if category == "rims":
		_wheels(car,kind)
		return
	var frame: Node3D = car.new_kit_frame(category,car.body)
	if kind == "stock":
		match category:
			"hood": Model.stock_engine_cover(car,frame)
			"aero": Model.stock_rear_guard(car,frame)
			"body": Model.stock_cabin(car,frame)
		return
	match category:
		"hood": _hood(car,frame,kind)
		"aero": _rear(car,frame,kind)
		"body": _cabin(car,frame,kind)

static func _cover_louvres(frame: Node3D, pocket: Rect2, base: float, material: Material, simple: bool, longitudinal: bool = false) -> void:
	var count: int = maxi(2,int((pocket.size.x if longitudinal else pocket.size.y)/0.062))
	for i: int in range(count):
		var f: float=(i+0.5)/count
		var center: Vector2=pocket.position+pocket.size*Vector2(f if longitudinal else 0.5,0.5 if longitudinal else f)
		var size:=Vector3(0.031 if longitudinal else pocket.size.x-0.028,0.018,pocket.size.y-0.028 if longitudinal else 0.037)
		var vane:=_box(frame,"InsetCoolingVane",size,Vector3(center.x,base-0.002,center.y),material,simple,0.004)
		if longitudinal: vane.rotation.z=0.20
		else: vane.rotation.x=-0.22

static func _hood(car: CarVisual, frame: Node3D, kind: String) -> void:
	var simple: bool=car.simple_model
	var graphite: Material=_finish("344247")
	var rubber: Material=CompactFinish.rubber(Color("172024"))
	var alloy: Material=_finish("87918e",0.48)
	var dark_alloy: Material=_finish("596a6b",0.36)
	var paint: Material=car.paint_materials.body
	var accent: Material=car.paint_materials.accent
	var bounds:=Rect2(-0.695,0.645,1.39,0.79)
	var base: float=1.489
	var crown: float=0.025
	var profile: String="crown"
	var skin: Material=paint
	var pockets: Array[Rect2]=[]
	match kind:
		"fork_vent": pockets=[Rect2(-0.575,0.78,1.15,0.51)]; profile="hip"; crown=0.035
		"fork_rib": skin=alloy; crown=0.014; profile="hip"
		"fork_twin": crown=0.028; profile="barrel"
		"fork_scoop": pockets=[Rect2(-0.50,1.14,1.0,0.16)]; profile="wedge"; crown=0.057
		"fork_louvre": skin=accent; pockets=[Rect2(-0.55,0.79,0.46,0.47),Rect2(0.09,0.79,0.46,0.47)]; profile="ridge"; crown=0.038
		"fork_split": crown=0.022; profile="hip"
		"fork_dome": crown=0.058; profile="barrel"; pockets=[Rect2(-0.61,0.79,0.12,0.48),Rect2(0.49,0.79,0.12,0.48)]
		"fork_fan": crown=0.008
		"fork_cross": crown=0.025; profile="hip"; pockets=[Rect2(-0.46,0.81,0.92,0.44)]
		"fork_flush": skin=accent; crown=0.006; pockets=[Rect2(-0.55,1.30,1.10,0.06)]
		"fork_armour": crown=0.036; profile="hip"; pockets=[Rect2(-0.38,0.87,0.76,0.34)]
		"fork_channel": skin=dark_alloy; crown=0.045; profile="flutes"; pockets=[Rect2(-0.53,1.31,1.06,0.06)]
		"fork_race": crown=0.052; profile="ridge"; pockets=[Rect2(-0.57,0.86,0.27,0.40),Rect2(0.30,0.86,0.27,0.40)]
	_box(frame,"EngineLidGasket",Vector3(1.43,0.045,0.83),Vector3(0,1.441,1.04),rubber,simple,0.018)
	if kind=="fork_twin":
		# Two full shells form butterfly service doors, with an actual central joint.
		for side: float in [-1.0,1.0]:
			var panel:=Rect2(-0.695 if side<0 else 0.015,0.645,0.68,0.79)
			var vent:=Rect2(-0.53 if side<0 else 0.18,0.83,0.35,0.39)
			Surface.deck(frame,"ButterflyServiceDoor",panel,base,crown,[vent],paint,graphite,simple,"barrel")
			_cover_louvres(frame,vent,base,dark_alloy,simple,true)
			_box(frame,"ButterflyLatch",Vector3(0.07,0.012,0.055),Vector3(side*0.085,1.512,1.30),graphite,simple,0.004)
		_box(frame,"ButterflyCentreSpine",Vector3(0.024,0.025,0.72),Vector3(0,1.482,1.04),graphite,simple)
	elif kind=="fork_split":
		# Independent front hinge shell and rear lift-out maintenance panel.
		Surface.deck(frame,"FrontHingedServiceShell",Rect2(-0.695,0.645,1.39,0.367),base,0.026,[],paint,graphite,simple,"hip")
		Surface.deck(frame,"RearLiftOutServicePanel",Rect2(-0.695,1.026,1.39,0.409),base,0.008,[],graphite,graphite,simple)
		for x: float in [-0.58,0,0.58]:
			for z: float in [1.08,1.37]: _bolt(frame,Vector3(x,1.507,z),Vector3.UP,0.009,alloy)
	else:
		Surface.deck(frame,"FormedEngineCover",bounds,base,crown,pockets,skin,graphite,simple,profile)
		if kind=="fork_louvre":
			# Clip every diagonal vane to the real recessed bank.
			for side: float in [-1.0,1.0]:
				for i: int in range(12):
					var intercept: float=-0.18+i*0.06
					var a: float=maxf(0.02,(0.02-intercept)/0.5)
					var b: float=minf(0.44,(0.45-intercept)/0.5)
					if b-a<0.045: continue
					_beam(frame,"HerringboneCoolingVane",Vector3(side*(0.09+a),base-0.001,0.79+intercept+0.5*a),Vector3(side*(0.09+b),base-0.001,0.79+intercept+0.5*b),Vector2(0.025,0.020),dark_alloy,simple)
		elif kind not in ["fork_cross","fork_flush","fork_channel"]:
			for pocket: Rect2 in pockets: _cover_louvres(frame,pocket,base,dark_alloy,simple,kind in ["fork_dome","fork_race"])
	if kind=="fork_rib":
		for i: int in range(9):
			var x: float=lerpf(-0.54,0.54,i/8.0)
			var path: Array[Vector3]=[]
			for j: int in range(11):
				var z: float=lerpf(0.755,1.325,j/10.0)
				var y: float=Surface._lid_height(Vector2(x,z),bounds,base,crown,profile)+0.014
				path.append(Vector3(x,y,z))
			Surface.tube(frame,"CastCoolingFin",path,Vector2(0.045,0.035),0.007,alloy,simple)
	if kind=="fork_fan":
		# Circular filter cassette: rolled rim, recessed screen and six captive screws.
		var cassette:=Surface.lathe(frame,"FilterCassette",PackedVector2Array([Vector2(0,-0.018),Vector2(0.294,-0.018),Vector2(0.306,-0.005),Vector2(0.306,0.004),Vector2(0.277,0.012),Vector2(0,0.012)]),graphite,simple)
		cassette.position=Vector3(0,1.513,1.04)
		var rim:=Surface.lathe(frame,"RolledFilterRim",PackedVector2Array([Vector2(0.273,-0.006),Vector2(0.297,-0.006),Vector2(0.309,0.002),Vector2(0.309,0.012),Vector2(0.296,0.018),Vector2(0.273,0.018)]),alloy,simple)
		rim.position=Vector3(0,1.513,1.04)
		for i: int in range(11):
			var x: float=lerpf(-0.245,0.245,i/10.0)
			var half: float=sqrt(0.263*0.263-x*x)
			_beam(frame,"FilterScreenBar",Vector3(x,1.529,1.04-half),Vector3(x,1.529,1.04+half),Vector2(0.018,0.015),dark_alloy,simple)
		for i: int in range(6):
			var angle: float=i*TAU/6
			_bolt(frame,Vector3(cos(angle)*0.29,1.536,1.04+sin(angle)*0.29),Vector3.UP,0.009,graphite)
	if kind=="fork_cross":
		var panel:=Surface.plate(frame,"CaptiveServiceHatch",Surface.outline(Vector2(0.95,0.47),0.055,Vector2(0,1.03)),0.024,dark_alloy,0.005)
		panel.position.y=1.494
		for x: float in [-0.415,0,0.415]:
			for z: float in [0.835,1.225]: _bolt(frame,Vector3(x,1.516,z),Vector3.UP,0.010,alloy)
		_box(frame,"HatchRecessedHandle",Vector3(0.17,0.013,0.045),Vector3(0,1.508,1.14),graphite,simple,0.005)
	if kind=="fork_armour":
		for side: float in [-1.0,1.0]:
			var path: Array[Vector3]=[]
			for j: int in range(9):
				var z: float=lerpf(0.77,1.31,j/8.0)
				path.append(Vector3(side*0.56,Surface._lid_height(Vector2(side*0.56,z),bounds,base,crown,profile)+0.010,z))
			Surface.tube(frame,"BoltedShoulderWearPlate",path,Vector2(0.14,0.026),0.008,dark_alloy,simple)
			for j: int in [1,7]: _bolt(frame,path[j]+Vector3.UP*0.020,Vector3.UP,0.010,alloy)
	# Hardware is seated on each shell's actual surface, not on a shared assumed height.
	for x: float in [-0.48,0.48]:
		var y: float=Surface._lid_height(Vector2(x,0.69),bounds,base,crown,profile)
		if kind=="fork_twin": y=base+crown*(1-pow((absf(x)-0.355)/0.34,2))
		if kind=="fork_split": y=1.494
		_box(frame,"LidHinge",Vector3(0.095,0.016,0.060),Vector3(x,y+0.003,0.69),alloy,simple,0.003)
		_bolt(frame,Vector3(x,y+0.016,0.69),Vector3.UP,0.008,graphite)
	var latch_y: float=Surface._lid_height(Vector2(0,1.389),bounds,base,crown,profile)
	if kind=="fork_twin": latch_y=1.483
	if kind=="fork_split": latch_y=1.494
	_box(frame,"FlushLatch",Vector3(0.10,0.012,0.035),Vector3(0,latch_y+0.003,1.389),graphite,simple,0.004)


static func _guard_face(frame: Node3D, label: String, points: PackedVector2Array, depth: float, z: float, material: Material) -> MeshInstance3D:
	var panel:=Surface.plate(frame,label,points,depth,material,0.006)
	panel.basis=Basis(Vector3.RIGHT,Vector3.FORWARD,Vector3.UP)
	panel.position.z=z
	return panel

static func _rear(car: CarVisual, frame: Node3D, kind: String) -> void:
	var simple: bool=car.simple_model
	var steel: Material=_finish("4c5e61",0.32)
	var rubber: Material=CompactFinish.rubber(Color("20292b"))
	var hardware: Material=_finish("929c96",0.48)
	var paint: Material=car.paint_materials.body
	# Substantial shoes and horizontal stays join every assembly to the chassis.
	for side: float in [-1.0,1.0]:
		_box(frame,"GuardChassisShoe",Vector3(0.16,0.16,0.20),Vector3(side*0.54,0.55,1.48),steel,simple,0.012)
		_beam(frame,"GuardMountStay",Vector3(side*0.54,0.56,1.49),Vector3(side*0.54,0.56,1.68),Vector2(0.11,0.11),steel,simple)
		_bolt(frame,Vector3(side*0.629,0.55,1.49),Vector3(side,0,0),0.016,hardware)
	match kind:
		"fork_bar":
			# Stamped face with folded end cheeks and a rolled lower return.
			_guard_face(frame,"PressedImpactBeam",PackedVector2Array([Vector2(-0.78,0.53),Vector2(-0.72,0.49),Vector2(0.72,0.49),Vector2(0.78,0.53),Vector2(0.74,0.68),Vector2(0.64,0.71),Vector2(-0.64,0.71),Vector2(-0.74,0.68)]),0.085,1.67,steel)
			_beam(frame,"FoldedLowerReturn",Vector3(-0.67,0.515,1.71),Vector3(0.67,0.515,1.71),Vector2(0.055,0.04),hardware,simple)
			for side: float in [-1.0,1.0]:
				_box(frame,"BeamEndCheek",Vector3(0.09,0.13,0.19),Vector3(side*0.69,0.59,1.59),steel,simple)
				_bolt(frame,Vector3(side*0.63,0.61,1.722),Vector3.BACK,0.013,hardware)
		"fork_wrap":
			var outline:=PackedVector2Array([Vector2(-0.78,1.42),Vector2(-0.82,1.57),Vector2(-0.72,1.755),Vector2(0.72,1.755),Vector2(0.82,1.57),Vector2(0.78,1.42),Vector2(0.65,1.44),Vector2(0.68,1.57),Vector2(0.62,1.63),Vector2(-0.62,1.63),Vector2(-0.68,1.57),Vector2(-0.65,1.44)])
			var wrap:=Surface.plate(frame,"ContinuousWraparoundGuard",outline,0.18,paint,0.009)
			wrap.position.y=0.59
			for side: float in [-1.0,1.0]:
				_box(frame,"ReplaceableCornerBuffer",Vector3(0.16,0.14,0.09),Vector3(side*0.66,0.59,1.74),rubber,simple,0.018)
		"fork_twin":
			for y: float in [0.515,0.705]:
				Surface.tube(frame,"RoundImpactRail",[Vector3(-0.72,y,1.69),Vector3(0.72,y,1.69)],Vector2(0.085,0.085),0.041,steel,simple)
			for x: float in [-0.59,0,0.59]:
				_box(frame,"TwinRailWeb",Vector3(0.07,0.235,0.075),Vector3(x,0.61,1.63),paint,simple,0.010)
				_bolt(frame,Vector3(x,0.61,1.677),Vector3.BACK,0.012,hardware)
		"fork_low":
			var pad:=Surface.plate(frame,"LowRubberImpactShoe",Surface.outline(Vector2(1.52,0.20),0.055,Vector2(0,1.66)),0.105,rubber,0.015)
			pad.position.y=0.505
			_box(frame,"LowGuardBacking",Vector3(1.32,0.065,0.07),Vector3(0,0.555,1.565),steel,simple,0.008)
			for side: float in [-1.0,1.0]: _bolt(frame,Vector3(side*0.57,0.505,1.77),Vector3.BACK,0.011,hardware)
		"fork_bow":
			var path: Array[Vector3]=[]
			for i: int in range(25):
				var x: float=lerpf(-0.74,0.74,i/24.0)
				var bow: float=1-pow(x/0.74,2)
				path.append(Vector3(x,0.55+0.105*bow,1.57+0.125*bow))
			Surface.tube(frame,"SweptWingImpactBeam",path,Vector2(0.14,0.13),0.022,paint,simple)
			for side: float in [-1.0,1.0]:
				_box(frame,"SweptBeamEndPad",Vector3(0.13,0.105,0.11),Vector3(side*0.67,0.571,1.625),rubber,simple,0.018)
		"fork_step":
			for side: float in [-1.0,1.0]:
				var wing:=Surface.plate(frame,"RaisedStepWing",Surface.outline(Vector2(0.38,0.27),0.05,Vector2(side*0.59,1.62)),0.20,paint,0.010)
				wing.position.y=0.62
				_box(frame,"StepWingBuffer",Vector3(0.23,0.13,0.055),Vector3(side*0.60,0.61,1.75),rubber,simple,0.012)
			var step:=Surface.plate(frame,"RecessedCentralStep",Surface.outline(Vector2(0.82,0.30),0.035,Vector2(0,1.60)),0.04,steel,0.008)
			step.position.y=0.53
			_box(frame,"StepTreadBacking",Vector3(0.70,0.016,0.22),Vector3(0,0.555,1.615),rubber,simple,0.004)
			for i: int in range(9): _box(frame,"CastStepGrip",Vector3(0.024,0.012,0.18),Vector3(-0.30+i*0.075,0.565,1.615),hardware,simple,0.004)
		"fork_mesh":
			for y: float in [0.50,0.73]: _beam(frame,"ServiceGuardHeader",Vector3(-0.70,y,1.69),Vector3(0.70,y,1.69),Vector2(0.09,0.05),steel,simple)
			for x: float in [-0.70,0.70]: _beam(frame,"ServiceGuardEnd",Vector3(x,0.50,1.69),Vector3(x,0.73,1.69),Vector2(0.06,0.09),steel,simple)
			for i: int in range(9):
				var x: float=lerpf(-0.59,0.59,i/8.0)
				_beam(frame,"OpenServiceGrilleVane",Vector3(x,0.51,1.69),Vector3(x,0.72,1.69),Vector2(0.036,0.065),hardware,simple)
		"fork_roller":
			_box(frame,"RollerGuardCrossmember",Vector3(1.22,0.11,0.09),Vector3(0,0.56,1.57),steel,simple)
			for side: float in [-1.0,1.0]:
				_box(frame,"RollerBackplate",Vector3(0.25,0.26,0.045),Vector3(side*0.58,0.61,1.55),steel,simple)
				for y: float in [0.485,0.735]:
					var ear:=Surface.plate(frame,"RollerAxleBracket",Surface.outline(Vector2(0.265,0.225),0.045,Vector2(side*0.58,1.635)),0.025,steel,0.005)
					ear.position.y=y
				var drum:=Surface.lathe(frame,"VerticalRubberDockRoller",PackedVector2Array([Vector2(0,-0.105),Vector2(0.089,-0.105),Vector2(0.108,-0.085),Vector2(0.108,0.085),Vector2(0.089,0.105),Vector2(0,0.105)]),rubber,simple)
				drum.position=Vector3(side*0.58,0.61,1.65)
				var axle:=VisualGeometry.cylinder(frame,0.022,0.285,Vector3(side*0.58,0.61,1.65),hardware,true)
				axle.name="CaptiveRollerAxle"
				_bolt(frame,Vector3(side*0.58,0.76,1.65),Vector3.UP,0.027,hardware)
		"fork_plate":
			_guard_face(frame,"FacetedCounterweightShield",PackedVector2Array([Vector2(-0.80,0.58),Vector2(-0.71,0.475),Vector2(0.71,0.475),Vector2(0.80,0.58),Vector2(0.74,0.75),Vector2(-0.74,0.75)]),0.065,1.69,paint)
			_box(frame,"ShieldLowerRubberFacing",Vector3(1.24,0.065,0.04),Vector3(0,0.54,1.735),rubber,simple,0.010)
			for side: float in [-1.0,1.0]:
				for y: float in [0.59,0.70]: _bolt(frame,Vector3(side*0.65,y,1.734),Vector3.BACK,0.014,hardware)
		"fork_cage":
			for y: float in [0.495,0.72]: _beam(frame,"BoxGuardChord",Vector3(-0.68,y,1.68),Vector3(0.68,y,1.68),Vector2(0.12,0.075),steel,simple)
			for x: float in [-0.68,0,0.68]:
				_beam(frame,"BoxGuardUpright",Vector3(x,0.495,1.68),Vector3(x,0.72,1.68),Vector2(0.08,0.12),steel,simple)
			for side: float in [-1.0,1.0]:
				_beam(frame,"BoxGuardDiagonal",Vector3(side*0.68,0.51,1.67),Vector3(side*0.43,0.70,1.67),Vector2(0.055,0.06),hardware,simple)
				_box(frame,"BoxGuardCornerPad",Vector3(0.15,0.22,0.06),Vector3(side*0.67,0.61,1.755),rubber,simple,0.015)
		"fork_arc":
			var path: Array[Vector3]=[]
			for i: int in range(25):
				var x: float=lerpf(-0.73,0.73,i/24.0)
				path.append(Vector3(x,0.57,1.57+0.12*sqrt(maxf(0,1-pow(x/0.83,2)))))
			Surface.tube(frame,"ContinuousRolledSteelBumper",path,Vector2(0.15,0.15),0.074,hardware,simple)
			for side: float in [-1.0,1.0]: _box(frame,"TubeClampSaddle",Vector3(0.13,0.13,0.11),Vector3(side*0.54,0.57,1.60),steel,simple,0.020)
		"fork_rib":
			_box(frame,"BufferCarrierRail",Vector3(1.37,0.11,0.11),Vector3(0,0.56,1.59),steel,simple,0.008)
			for x: float in [-0.53,0,0.53]:
				_box(frame,"MouldedDockBuffer",Vector3(0.275,0.28,0.13),Vector3(x,0.615,1.68),rubber,simple,0.028)
				for i: int in range(5): _box(frame,"MouldedBufferRib",Vector3(0.235,0.017,0.025),Vector3(x,0.525+i*0.045,1.746),rubber,simple,0.006)
		"fork_tow":
			for side: float in [-1.0,1.0]:
				_box(frame,"TowGuardWing",Vector3(0.47,0.15,0.17),Vector3(side*0.53,0.57,1.62),steel,simple,0.018)
				_box(frame,"TowWingBuffer",Vector3(0.27,0.10,0.04),Vector3(side*0.55,0.57,1.725),rubber,simple,0.012)
			_box(frame,"ClevisChassisBracket",Vector3(0.24,0.25,0.15),Vector3(0,0.605,1.525),paint,simple,0.012)
			for y: float in [0.505,0.715]:
				_box(frame,"ClevisEarStay",Vector3(0.16,0.028,0.12),Vector3(0,y,1.57),steel,simple,0.006)
				var ear:=Surface.lathe(frame,"BoredClevisEar",PackedVector2Array([Vector2(0.025,-0.014),Vector2(0.076,-0.014),Vector2(0.085,-0.007),Vector2(0.085,0.007),Vector2(0.076,0.014),Vector2(0.025,0.014)]),steel,simple)
				ear.position=Vector3(0,y,1.68)
			var pin:=VisualGeometry.cylinder(frame,0.018,0.27,Vector3(0,0.61,1.68),hardware,true)
			pin.name="CaptiveTowingPin"
			_bolt(frame,Vector3(0,0.752,1.68),Vector3.UP,0.030,hardware)


static func _curve(a: Vector3, corner: Vector3, b: Vector3, steps: int = 8) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for i: int in range(steps+1):
		var t: float = i/float(steps)
		points.append(a.lerp(corner,t).lerp(corner.lerp(b,t),t))
	return points

static func _cabin_side(side: float, front: Vector3, rear: Vector3, radius: float) -> Array[Vector3]:
	# Local anchors stay fixed; the actual roof and pillar silhouettes belong to each design.
	var f: Vector3 = Vector3(side*front.x,front.y,front.z)
	var r: Vector3 = Vector3(side*rear.x,rear.y,rear.z)
	var foot_f := Vector3(side*0.65,1.06,-0.77)
	var foot_r := Vector3(side*0.65,1.06,0.74)
	var path: Array[Vector3] = [foot_f]
	path.append_array(_curve(f.move_toward(foot_f,radius),f,f.move_toward(r,radius)))
	path.append_array(_curve(r.move_toward(f,radius),r,r.move_toward(foot_r,radius)))
	path.append(foot_r)
	return path

static func _cabin(car: CarVisual, frame: Node3D, kind: String) -> void:
	var simple: bool = car.simple_model
	var steel: Material = _finish("2c383c")
	var edge: Material = _finish("71807f",0.35)
	var rubber: Material = CompactFinish.rubber(Color("172024"))
	var paint: Material = car.paint_materials.body
	var front := Vector3(0.70,2.65,-0.79)
	var rear := Vector3(0.70,2.65,0.80)
	var section := Vector2(0.09,0.095)
	var bend: float = 0.12
	var round_section: float = 0.014
	match kind:
		"fork_rail": section=Vector2(0.095,0.095); round_section=0.047
		"fork_plate": section=Vector2(0.075,0.13); front.y=2.59; rear.y=2.67
		"fork_twin": section=Vector2(0.14,0.22); front.y=2.56; rear.y=2.64
		"fork_canted": front=Vector3(0.72,2.61,-0.47); rear=Vector3(0.72,2.67,0.91); bend=0.16
		"fork_round": front.y=2.47; rear.y=2.47; section=Vector2(0.09,0.09); round_section=0.04
		"fork_cross": front.y=2.57; rear.y=2.57; section=Vector2(0.085,0.085)
		"fork_canopy": front.y=2.60; rear.y=2.60; section=Vector2(0.085,0.10)
		"fork_lattice": front.y=2.58; rear.y=2.58; section=Vector2(0.07,0.07)
		"fork_arch": front.y=2.48; rear.y=2.48; section=Vector2(0.075,0.09)
		"fork_sport": front=Vector3(0.73,2.48,-0.64); rear=Vector3(0.60,2.67,0.61); section=Vector2(0.085,0.10)
		"fork_mesh": front.y=2.57; rear.y=2.57; section=Vector2(0.075,0.075)
		"fork_heavy": front.y=2.60; rear.y=2.60; section=Vector2(0.14,0.17); bend=0.22
		"fork_safari": front.y=2.55; rear.y=2.55; section=Vector2(0.085,0.085); round_section=0.04
	var structural: Material = edge if kind=="fork_mesh" else steel
	# Every attachment is seated on the original chassis hardpoints.
	for side: float in [-1.0,1.0]:
		for z: float in [-0.77,0.74]:
			if kind=="fork_twin" and z<0: continue
			_box(frame,"CabinFootIsolator",Vector3(0.18,0.022,0.20),Vector3(side*0.65,1.035,z),rubber,simple)
			_box(frame,"CabinMountPlate",Vector3(0.17,0.035,0.19),Vector3(side*0.65,1.061,z),structural,simple)
			for dz: float in [-0.057,0.057]: _bolt(frame,Vector3(side*0.65,1.083,z+dz),Vector3.UP,0.011,edge)
		var f := Vector3(side*front.x,front.y,front.z)
		var r := Vector3(side*rear.x,rear.y,rear.z)
		if kind=="fork_twin":
			# Rear-mounted goosenecks leave the entry and front corners completely open.
			var path: Array[Vector3] = [Vector3(side*0.65,1.06,0.74)]
			path.append_array(_curve(Vector3(side*0.70,2.36,0.83),r,Vector3(side*0.70,2.63,0.54)))
			path.append(f)
			Surface.tube(frame,"RearCantileverColumn",path,section,0.024,paint,simple)
		elif kind=="fork_rail":
			# Two transverse roll hoops, rather than the side portals used by the factory.
			for z: float in [-0.77,0.74]:
				if side>0: continue
				var path: Array[Vector3] = [Vector3(-0.65,1.06,z)]
				path.append_array(_curve(Vector3(-0.70,2.40,z),Vector3(-0.70,2.65,z),Vector3(-0.45,2.65,z)))
				path.append_array(_curve(Vector3(0.45,2.65,z),Vector3(0.70,2.65,z),Vector3(0.70,2.40,z)))
				path.append(Vector3(0.65,1.06,z))
				Surface.tube(frame,"TransverseRoundHoop",path,section,round_section,steel,simple)
			_beam(frame,"HoopSideTie",f,r,Vector2(0.055,0.055),edge,simple)
		elif kind=="fork_round":
			var path: Array[Vector3] = [Vector3(side*0.65,1.06,-0.77),f]
			for i: int in range(1,17):
				var t: float=i/16.0
				path.append(Vector3(side*0.70,2.47+0.23*sin(t*PI),lerpf(front.z,rear.z,t)))
			path.append(Vector3(side*0.65,1.06,0.74))
			Surface.tube(frame,"BarrelRoofSideArch",path,section,round_section,steel,simple)
		else:
			Surface.tube(frame,"ShapedCabinPortal",_cabin_side(side,front,rear,bend),section,round_section,structural,simple)
		# Accessories connect to the real pillar or hang from the cantilever, without floating.
		var lamp_from: Vector3 = f.lerp(r,0.03)
		if kind not in ["fork_twin","fork_round"]:
			lamp_from=Vector3(side*lerpf(0.65,front.x,0.90),2.47,lerpf(-0.77,front.z,0.90))
		_beam(frame,"WorkLampBracket",lamp_from,Vector3(side*0.70,2.51,-0.81),Vector2(0.055,0.045),structural,simple)
		var mirror_from := Vector3(side*lerpf(0.65,front.x,0.76),2.23,lerpf(-0.77,front.z,0.76))
		if kind=="fork_twin": mirror_from=f
		_beam(frame,"MirrorMountStay",mirror_from,Vector3(side*0.70,2.23,-0.69),Vector2(0.035,0.035),structural,simple)
		# Broad tapered pillar skins and substantial haunches change the side elevation.
		if kind in ["fork_plate","fork_heavy"]:
			var panel: PackedVector2Array
			if kind=="fork_plate":
				panel=PackedVector2Array([Vector2(0.67,1.10),Vector2(0.83,1.10),Vector2(0.89,2.64),Vector2(0.49,2.64),Vector2(0.69,2.28)])
			else:
				panel=PackedVector2Array([Vector2(0.64,1.10),Vector2(0.85,1.10),Vector2(0.90,2.59),Vector2(0.30,2.59),Vector2(0.63,2.15)])
			var skin: MeshInstance3D=Surface.plate(frame,"TaperedRearPillar",panel,0.042,paint,0.006)
			skin.basis=Basis(Vector3.BACK,Vector3.RIGHT,Vector3.UP)
			skin.position.x=side*0.705
			for y: float in [1.22,2.32]: _bolt(frame,Vector3(side*0.735,y,0.76),Vector3(side,0,0),0.014,edge)
		if kind=="fork_cross":
			var gusset:=Surface.plate(frame,"UpperCornerHaunch",PackedVector2Array([Vector2(0.36,2.55),Vector2(0.82,2.55),Vector2(0.75,2.16)]),0.028,paint,0.004)
			gusset.basis=Basis(Vector3.BACK,Vector3.RIGHT,Vector3.UP); gusset.position.x=side*0.70
	# Headers follow the design's height and width. The vault gets full curved transverse ribs.
	if kind not in ["fork_rail","fork_arch"]:
		for p: Vector3 in [front,rear]: _beam(frame,"RoofEndHeader",Vector3(-p.x,p.y,p.z),p,Vector2(0.09,0.09),structural,simple)
	if kind=="fork_arch":
		for i: int in range(6):
			var path: Array[Vector3]=[]
			var z: float=lerpf(front.z,rear.z,i/5.0)
			for j: int in range(17):
				var x: float=lerpf(-0.70,0.70,j/16.0)
				path.append(Vector3(x,2.48+0.23*(1-pow(x/0.70,2)),z))
			Surface.tube(frame,"VaultedRoofRib",path,Vector2(0.055,0.045),0.012,steel,simple)
		for x: float in [-0.35,0.35]: _beam(frame,"VaultPurlin",Vector3(x,2.6525,front.z),Vector3(x,2.6525,rear.z),Vector2(0.03,0.03),edge,simple)
	elif kind=="fork_round":
		for i: int in range(7):
			var t: float=(i+0.5)/7.0
			_beam(frame,"BarrelRoofSlat",Vector3(-0.70,2.47+0.23*sin(t*PI),lerpf(front.z,rear.z,t)),Vector3(0.70,2.47+0.23*sin(t*PI),lerpf(front.z,rear.z,t)),Vector2(0.055,0.035),steel,simple)
	elif kind in ["fork_canopy","fork_safari"]:
		var roof_material: Material = _finish("a6aa9b") if kind=="fork_safari" else paint
		var bounds := Rect2(-0.77,-0.93,1.54,1.88)
		if kind=="fork_safari": bounds=Rect2(-0.765,-0.97,1.53,0.64)
		Surface.deck(frame,"PressedWeatherRoof",bounds,2.65 if kind=="fork_canopy" else 2.60,0.018,[],roof_material,steel,simple)
		for side: float in [-1.0,1.0]:
			_beam(frame,"RoofDripEdge",Vector3(side*0.75,2.63 if kind=="fork_canopy" else 2.58,bounds.position.y+0.03),Vector3(side*0.75,2.63 if kind=="fork_canopy" else 2.58,bounds.end.y-0.03),Vector2(0.02,0.055),steel,simple)
			_beam(frame,"WeatherRoofSpacer",Vector3(side*0.70,front.y,front.z),Vector3(side*0.70,2.65 if kind=="fork_canopy" else 2.60,front.z),Vector2(0.055,0.055),steel,simple)
			if kind=="fork_canopy": _beam(frame,"RearRoofSpacer",Vector3(side*0.70,rear.y,rear.z),Vector3(side*0.70,2.65,rear.z),Vector2(0.055,0.055),steel,simple)
		if kind=="fork_safari":
			for z: float in [-0.20,0.10,0.40,0.70]: _beam(frame,"OpenRearRoofSlat",Vector3(-0.70,2.55,z),Vector3(0.70,2.55,z),Vector2(0.06,0.04),steel,simple)
	elif kind in ["fork_cross","fork_lattice"]:
		var count: int=1 if kind=="fork_cross" else 4
		for i: int in range(count):
			var z0: float=lerpf(front.z,rear.z,i/float(count))
			var z1: float=lerpf(front.z,rear.z,(i+1)/float(count))
			for direction: float in [-1.0,1.0]:
				_beam(frame,"RoofDiagonal",Vector3(-0.69*direction,front.y+0.015,z0),Vector3(0.69*direction,front.y+0.015,z1),Vector2(0.08 if kind=="fork_cross" else 0.035,0.035),steel,simple)
	elif kind=="fork_mesh":
		for axis: int in range(2):
			for i: int in range(11):
				var f: float=(i+0.5)/11.0
				var a:=Vector3(lerpf(-0.68,0.68,f) if axis==0 else -0.70,2.60,front.z if axis==0 else lerpf(front.z,rear.z,f))
				var b:=Vector3(a.x if axis==0 else 0.70,2.60,rear.z if axis==0 else a.z)
				_beam(frame,"FineRoofScreen",a,b,Vector2(0.018,0.018),edge,simple)
	else:
		var longitudinal: bool=kind in ["fork_canted","fork_sport","fork_twin"]
		var count: int=3 if kind=="fork_sport" else 4 if kind in ["fork_canted","fork_heavy"] else 5
		for i: int in range(count):
			var f: float=(i+0.5)/count
			var a: Vector3
			var b: Vector3
			if longitudinal:
				a=Vector3(lerpf(-front.x+0.08,front.x-0.08,f),front.y+0.01,front.z)
				b=Vector3(lerpf(-rear.x+0.08,rear.x-0.08,f),rear.y+0.01,rear.z)
			else:
				var p: Vector3=front.lerp(rear,f)
				a=Vector3(-p.x,p.y+0.015,p.z); b=Vector3(p.x,p.y+0.015,p.z)
			_beam(frame,"RoofProtectionSlat",a,b,Vector2(0.15 if kind in ["fork_heavy","fork_sport"] else 0.055,0.045),steel,simple)
	if kind in ["fork_plate","fork_heavy"]:
		for side: float in [-1.0,1.0]:
			_beam(frame,"DeepRoofSideRail",Vector3(side*front.x,front.y-0.025,front.z),Vector3(side*rear.x,rear.y-0.025,rear.z),Vector2(0.10,0.15 if kind=="fork_heavy" else 0.115),paint,simple)
	# Retained beacon is served by a shoe and two stays meeting actual roof members.
	_box(frame,"BeaconMountingShoe",Vector3(0.23,0.026,0.19),Vector3(0.55,2.705,0.65),steel,simple)
	var beacon_roof_y: float=front.lerp(rear,clampf((0.65-front.z)/(rear.z-front.z),0,1)).y
	if kind=="fork_round": beacon_roof_y=2.47+0.23*sin((0.65-front.z)/(rear.z-front.z)*PI)
	if kind=="fork_arch": beacon_roof_y=2.48+0.23*(1-pow(0.55/0.70,2))
	if kind=="fork_canopy": beacon_roof_y=2.66
	var width: float=front.lerp(rear,clampf((0.65-front.z)/(rear.z-front.z),0,1)).x
	_beam(frame,"BeaconMountStay",Vector3(0.55,beacon_roof_y,0.65),Vector3(width,beacon_roof_y,0.65),Vector2(0.055,0.035),steel,simple)
	_beam(frame,"BeaconRiser",Vector3(0.55,beacon_roof_y,0.65),Vector3(0.55,2.705,0.65),Vector2(0.06,0.06),steel,simple)

static func _wheels(car: CarVisual, kind: String) -> void:
	var steel: Material = _finish("9b9f94",0.35)
	var graphite: Material = _finish("485557",0.27)
	var hardware: Material = _finish("838e88",0.48)
	var dark: Material = CompactFinish.rubber(Color("20292b"))
	var settings: Dictionary = {
		"fork_disc":[0,0.42,0.40,0.07,0.012],"fork_ring":[0,0.42,0.40,0.07,0.012],
		"fork_spoke":[6,0.48,0.42,0.080,0.016],"fork_three":[3,0.47,0.39,0.098,0.024],
		"fork_four":[4,0.48,0.40,0.094,0.025],"fork_five":[5,0.46,0.41,0.088,0.022],
		"fork_eight":[8,0.43,0.43,0.065,0.010],"fork_turbine":[10,0.46,0.43,0.070,0.018],
		"fork_mesh":[12,0.40,0.44,0.041,0.010],"fork_dish":[0,0.4,0.40,0.07,-0.012],
		"fork_bolt":[0,0.4,0.40,0.07,0.008],"fork_slots":[8,0.64,0.40,0.085,0.014],
		"fork_star":[5,0.38,0.42,0.072,0.026]}
	for index: int in range(car.rolling_wheels.size()):
		var rotor: Node3D = car.rolling_wheels[index]
		var frame: Node3D = car.new_kit_frame("rims",rotor)
		var radius: float = car.wheel_radii[index]/HandlingConfig.BODY_SCALE
		var pivot: Node3D = rotor.get_parent()
		var side: float = signf(pivot.position.x)
		var width: float = 0.32 if pivot.position.z<0 else 0.25
		var face: float = width*0.48
		if kind in ["stock","fork_ring"]:
			Model.stock_wheel(frame,radius,width,side,kind=="fork_ring")
			if car.simple_model: RacingCarModels._reduce_primitives(frame)
			if kind=="stock": continue
		var wheel := Node3D.new()
		wheel.name="IndustrialWheelCover"
		frame.add_child(wheel)
		wheel.position.x=side*(face+(0.006 if kind=="fork_ring" else -0.010))
		wheel.rotation.z=-side*PI*0.5
		var profile := PackedVector2Array([Vector2(radius*0.535,-0.008),Vector2(radius*0.605,-0.008),Vector2(radius*0.623,0.001),Vector2(radius*0.623,0.012),Vector2(radius*0.609,0.022),Vector2(radius*0.571,0.022),Vector2(radius*0.548,0.012),Vector2(radius*0.535,0.007)])
		Surface.lathe(wheel,"RolledWheelFlange",profile,hardware if kind=="fork_ring" else steel,car.simple_model)
		if kind=="fork_ring": continue
		Surface.lathe(wheel,"WheelBarrel",PackedVector2Array([Vector2(radius*0.53,-width*0.85),Vector2(radius*0.595,-width*0.85),Vector2(radius*0.595,-0.008),Vector2(radius*0.53,-0.008)]),graphite,car.simple_model)
		var p: Array = settings[kind]
		Surface.wheel_face(wheel,radius,p[0],p[1],Vector2(p[2],p[3]),p[4],graphite if kind in ["fork_three","fork_four","fork_five","fork_star"] else steel,car.simple_model)
		Surface.lathe(wheel,"HubCover",PackedVector2Array([Vector2(0,-0.012),Vector2(radius*0.125,-0.012),Vector2(radius*0.14,0.016),Vector2(radius*0.14,0.031),Vector2(radius*0.10,0.045),Vector2(0,0.045)]),hardware,car.simple_model)
		var count: int = 8 if kind=="fork_bolt" else 6
		for i: int in range(count):
			var angle: float = i*TAU/count
			_bolt(wheel,Vector3(cos(angle)*radius*0.21,0.018+float(p[4])*0.65,sin(angle)*radius*0.21),Vector3.UP,radius*0.025,hardware)
		if kind=="fork_bolt":
			Surface.lathe(wheel,"SplitRimSeam",PackedVector2Array([Vector2(radius*0.49,0.014),Vector2(radius*0.50,0.014),Vector2(radius*0.50,0.017),Vector2(radius*0.49,0.017)]),dark,car.simple_model)
			for i: int in range(12):
				var angle: float = i*TAU/12
				_bolt(wheel,Vector3(cos(angle)*radius*0.515,0.020,sin(angle)*radius*0.515),Vector3.UP,radius*0.017,hardware)
