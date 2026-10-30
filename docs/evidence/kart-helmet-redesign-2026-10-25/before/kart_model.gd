extends RefCounted
## Original unbranded racing kart. Presentation only; canonical axle geometry.
const G = preload("res://vehicle/kart_geometry.gd")

static func build(car: CarVisual) -> void:
	car.body.name = "KartChassis"
	var paint := CompactFinish.paint(Color("b96d43"))
	paint.roughness = 0.44
	paint.clearcoat = 0.16
	var accent := CompactFinish.paint(Color("d9d0b7"))
	accent.roughness = 0.48
	var trim := CompactFinish.rubber(Color("171e22"))
	var metal := CompactFinish.alloy(Color("6e7778"))
	var bright := CompactFinish.alloy(Color("a8aea9"))
	var chassis := CompactFinish.paint(Color("3b3431"))
	chassis.roughness = 0.50
	car.paint_materials = {"body":paint,"accent":accent}
	_body(car,paint,accent,trim,chassis,metal,bright)
	_driver(car,trim,metal)
	_engine(car,trim,metal,bright)
	var config: HandlingConfig = VehicleCatalog.config("kart")
	for side: float in [-1.0,1.0]:
		for axle: float in [-1.0,1.0]:
			_wheel(car,Vector3(side*config.track_width/(2*HandlingConfig.BODY_SCALE),0.22,axle*config.wheelbase/(2*HandlingConfig.BODY_SCALE)),trim,metal,bright)

static func _body(car: CarVisual, paint: Material, accent: Material, trim: Material, chassis: Material, metal: Material, bright: Material) -> void:
	var p: Node3D = car.body
	var s: bool = car.simple_model
	G.rounded(p,"FloorTray",Vector3(0,0.147,-0.20),Vector3(0.83,0.028,1.69),0.012,metal,s)
	for side: float in [-1.0,1.0]:
		G.tube(p,"BentMainRail",[Vector3(side*0.20,0.17,-1.10),Vector3(side*0.42,0.17,-0.95),Vector3(side*0.44,0.17,-0.30),Vector3(side*0.42,0.17,0.57),Vector3(side*0.30,0.17,1.08)],0.032,chassis,s,40)
		G.tube(p,"SideProtection",[Vector3(side*0.43,0.19,-0.59),Vector3(side*0.68,0.19,-0.46),Vector3(side*0.69,0.19,0.38),Vector3(side*0.43,0.19,0.54)],0.024,metal,s)
		var pod := Node3D.new()
		pod.position.x = side*0.535
		p.add_child(pod)
		var pod_profile: Array[Vector4] = [Vector4(-0.60,0.075,0.28,0.045),Vector4(-0.48,0.155,0.28,0.095),Vector4(-0.12,0.160,0.29,0.105),Vector4(0.34,0.147,0.275,0.09),Vector4(0.49,0.10,0.25,0.05)]
		G.loft(pod,"FormedSidePod",pod_profile,paint,s)
		G.patch(pod,"PodInsetStripe",32,8,func(u: float,v: float) -> Vector3:
			return G.loft_top(pod_profile,lerpf(-0.047,0.047,v),lerpf(0.17,0.84,u)),func(_u: float,_v: float) -> Vector3: return Vector3.UP,accent,s)
		G.tube(p,"SeatStay",[Vector3(side*0.40,0.18,0.51),Vector3(side*0.28,0.40,0.57),Vector3(side*0.25,0.54,0.55)],0.014,metal,s,12)
		# Pedal spindle, forged pedal plate and anti-slip ribs are visible in the footwell.
		G.tube(p,"PedalLever",[Vector3(side*0.25,0.18,-0.84),Vector3(side*0.19,0.25,-0.92),Vector3(side*0.17,0.30,-0.93)],0.012,bright,s,8)
		var pedal: MeshInstance3D = G.rounded(p,"PedalPlate",Vector3(side*0.17,0.28,-0.94),Vector3(0.11,0.13,0.023),0.010,metal,s)
		pedal.rotation.x = -0.30
		for rib: int in range(4): G.rounded(p,"PedalRib",Vector3(side*0.17,0.24+rib*0.025,-0.958),Vector3(0.075,0.004,0.005),0.001,trim,s)
		for z: float in [-0.93,-0.60,-0.25,0.10,0.48]:
			G.ellipsoid(p,"TrayRivet",Vector3(side*0.39,0.165,z),Vector3(0.008,0.004,0.008),bright,s)
	G.tube(p,"FrontCrossmember",[Vector3(-0.52,0.19,-0.88),Vector3(0,0.19,-0.88),Vector3(0.52,0.19,-0.88)],0.026,chassis,s,12)
	G.tube(p,"RearProtection",[Vector3(-0.75,0.18,1.22),Vector3(-0.69,0.18,1.30),Vector3(-0.32,0.18,1.32),Vector3(0.32,0.18,1.32),Vector3(0.69,0.18,1.30),Vector3(0.75,0.18,1.22)],0.037,trim,s,40)
	for side: float in [-1.0,1.0]:
		G.tube(p,"RearBumperChassisMount",[Vector3(side*0.30,0.17,1.04),Vector3(side*0.35,0.18,1.17),Vector3(side*0.35,0.18,1.32)],0.022,metal,s,16)
		G.ellipsoid(p,"RearBumperEndCap",Vector3(side*0.75,0.18,1.22),Vector3.ONE*0.037,trim,s)
	G.tube(p,"LiveRearAxle",[Vector3(-0.72,0.22,0.88),Vector3(0.72,0.22,0.88)],0.026,metal,s,8)
	# Wide swept front fairing with a separate rolled underside and center crown.
	G.loft(p,"NoseLowerReturn",[Vector4(-1.40,0.52,0.185,0.020),Vector4(-1.32,0.745,0.182,0.035),Vector4(-1.10,0.755,0.19,0.035),Vector4(-0.89,0.61,0.19,0.025)],trim,s,0.65)
	var nose_profile: Array[Vector4] = [Vector4(-1.40,0.49,0.255,0.045),Vector4(-1.31,0.738,0.275,0.092),Vector4(-1.10,0.753,0.285,0.105),Vector4(-0.90,0.59,0.275,0.075)]
	G.loft(p,"SculptedFrontFairing",nose_profile,paint,s,0.75)
	G.patch(p,"NoseCenterInlay",12,24,func(u: float,v: float) -> Vector3:
		return G.loft_top(nose_profile,lerpf(-0.065,0.065,u),lerpf(0.18,0.96,v),0.75),func(_u: float,_v: float) -> Vector3: return Vector3.UP,accent,s)
	var fairing := Node3D.new()
	p.add_child(fairing)
	var fairing_profile: Array[Vector4] = [Vector4(-1.04,0.13,0.38,0.032),Vector4(-0.87,0.155,0.425,0.035),Vector4(-0.64,0.19,0.515,0.045),Vector4(-0.41,0.175,0.565,0.037),Vector4(-0.35,0.145,0.55,0.027)]
	G.loft(fairing,"NassauFairing",fairing_profile,paint,s,0.70)
	G.patch(p,"FairingCenterInlay",12,32,func(u: float,v: float) -> Vector3:
		return G.loft_top(fairing_profile,lerpf(-0.064,0.064,u),lerpf(0.06,0.94,v),0.70),func(_u: float,_v: float) -> Vector3: return Vector3(0,1,-0.3),accent,s)
	# Fitted little light housings retain the established night/brake presentation.
	for side: float in [-1.0,1.0]:
		G.rounded(p,"RearLampBezel",Vector3(side*0.55,0.225,1.31),Vector3(0.16,0.09,0.045),0.018,trim,s)
		G.rounded(p,"RearLampLens",Vector3(side*0.55,0.225,1.335),Vector3(0.125,0.055,0.015),0.007,car.brake_material,s)
		G.rounded(p,"FrontLampRecess",Vector3(side*0.33,0.25,-1.398),Vector3(0.12,0.048,0.025),0.012,trim,s)
		G.rounded(p,"FrontLampGlass",Vector3(side*0.33,0.25,-1.412),Vector3(0.092,0.024,0.010),0.004,CompactFinish.alloy(Color("a5b5af")),s)

static func _limb(parent: Node3D, label: String, a: Vector3, b: Vector3, radius: Vector3, material: Material, simple: bool) -> void:
	var node: MeshInstance3D = G.ellipsoid(parent,label,(a+b)*0.5,Vector3(radius.x,a.distance_to(b)*0.5+radius.y,radius.z),material,simple)
	node.quaternion = Quaternion(Vector3.UP,(b-a).normalized())

static func _driver(car: CarVisual, trim: Material, metal: Material) -> void:
	var p: Node3D = car.body
	var s: bool = car.simple_model
	var suit := CompactFinish.rubber(Color("283d4b"))
	suit.roughness = 0.92
	var seams := CompactFinish.rubber(Color("b8b3a0"))
	var helmet := CompactFinish.paint(Color("d9d3bc"))
	helmet.roughness = 0.42
	var dark := CompactFinish.rubber(Color("10191d"))
	var visor := CompactFinish.alloy(Color("253d49"))
	visor.metallic = 0.35
	visor.roughness = 0.22
	# Continuous seat bucket: flared hip bolsters rise to a shaped shoulder shell.
	G.loft(p,"MouldedSeatBucket",[Vector4(-0.02,0.18,0.26,0.075),Vector4(0.18,0.27,0.28,0.11),Vector4(0.47,0.245,0.39,0.21),Vector4(0.62,0.225,0.44,0.20)],trim,s)
	G.ellipsoid(p,"SeatCushion",Vector3(0,0.29,0.27),Vector3(0.205,0.09,0.24),dark,s)
	G.ellipsoid(p,"DriverPelvis",Vector3(0,0.35,0.23),Vector3(0.19,0.12,0.17),suit,s)
	var torso: MeshInstance3D = G.ellipsoid(p,"TailoredRaceSuit",Vector3(0,0.535,0.29),Vector3(0.195,0.215,0.135),suit,s)
	torso.rotation.x = -0.18
	G.ellipsoid(p,"Collar",Vector3(0,0.722,0.26),Vector3(0.105,0.035,0.085),dark,s)
	G.tube(p,"SuitZipper",[Vector3(0,0.39,0.155),Vector3(0,0.55,0.151),Vector3(0,0.68,0.187)],0.0035,seams,s,16)
	for side: float in [-1.0,1.0]:
		# One continuous tailored trouser leg bends through the knee. No separate
		# floating kneecap or intersecting thigh/shin ellipsoids.
		var leg: Array[Vector3] = [Vector3(side*0.115,0.345,0.19),Vector3(side*0.145,0.37,-0.08),Vector3(side*0.155,0.355,-0.29),Vector3(side*0.145,0.285,-0.52),Vector3(side*0.14,0.225,-0.75)]
		var radial := func(u: float,v: float) -> Vector3:
			var tangent: Vector3 = (G.curve(leg,minf(1,v+0.0001))-G.curve(leg,maxf(0,v-0.0001))).normalized()
			var across: Vector3 = tangent.cross(Vector3.UP).normalized()
			return across*cos(u*TAU)+tangent.cross(across)*sin(u*TAU)
		G.patch(p,"ContinuousTrouserLeg"+str(side),24,28,func(u: float,v: float) -> Vector3:
			var radius: float = lerpf(0.082,0.050,smoothstep(0.30,1,v))
			return G.curve(leg,v)+radial.call(u,v)*radius,radial,suit,s)
		var boot: MeshInstance3D = G.rounded(p,"RaceBoot",Vector3(side*0.14,0.23,-0.79),Vector3(0.125,0.12,0.25),0.044,dark,s)
		boot.rotation.x = -0.17
		G.rounded(p,"BootSole",Vector3(side*0.14,0.178,-0.79),Vector3(0.129,0.018,0.25),0.008,trim,s)
		_limb(p,"UpperSleeve",Vector3(side*0.17,0.65,0.28),Vector3(side*0.27,0.48,-0.015),Vector3(0.069,0.025,0.067),suit,s)
		_limb(p,"LowerSleeve",Vector3(side*0.27,0.48,-0.015),Vector3(side*0.151,0.55,-0.31),Vector3(0.055,0.024,0.05),suit,s)
		G.ellipsoid(p,"RacingGlove",Vector3(side*0.153,0.553,-0.315),Vector3(0.051,0.052,0.05),seams,s)
		G.ellipsoid(p,"GloveGrip",Vector3(side*0.147,0.54,-0.339),Vector3(0.04,0.032,0.031),dark,s)
		G.tube(p,"SleevePiping",[Vector3(side*0.207,0.662,0.27),Vector3(side*0.299,0.49,0.01),Vector3(side*0.183,0.574,-0.27)],0.004,seams,s,24)
	G.patch(p,"FullFaceHelmet",48,32,func(u: float,v: float) -> Vector3:
		var latitude: float = v*PI
		var angle: float = u*TAU
		var y: float = 0.90+0.213*cos(latitude)
		var chin: float = 0.044*exp(-pow((y-0.795)/0.060,2))*maxf(0,-cos(angle))
		return Vector3(0.198*sin(latitude)*sin(angle),y,0.25+0.205*sin(latitude)*cos(angle)-chin),func(u: float,v: float) -> Vector3: return Vector3(sin(v*PI)*sin(u*TAU),cos(v*PI),sin(v*PI)*cos(u*TAU)),helmet,s)
	for gasket: bool in [true,false]:
		G.patch(p,"VisorGasket" if gasket else "WraparoundVisor",48,12,func(u: float,v: float) -> Vector3:
			var angle: float = lerpf(-1.24,1.24,u)
			var y: float = lerpf(0.885 if gasket else 0.892,0.981 if gasket else 0.973,v)
			var radius: float = sqrt(maxf(0.0,1-pow((y-0.90)/0.213,2)))
			var offset: float = 0.004 if gasket else 0.007
			var chin: float = 0.044*exp(-pow((y-0.795)/0.060,2))*maxf(0,cos(angle))
			return Vector3(sin(angle)*(0.198*radius+offset),y,0.25-cos(angle)*(0.205*radius+offset+0.003)-chin),func(u: float,_v: float) -> Vector3: return Vector3(sin(lerpf(-1.24,1.24,u)),0,-cos(lerpf(-1.24,1.24,u))),dark if gasket else visor,s)
	for side: float in [-1.0,1.0]:
		G.ellipsoid(p,"VisorPivot",Vector3(side*0.189,0.927,0.181),Vector3(0.007,0.014,0.014),metal,s)
		for vent: int in range(3):
			G.ellipsoid(p,"ChinVent",Vector3(side*(0.035+vent*0.025),0.801,0.021+vent*0.008),Vector3(0.008,0.004,0.004),dark,s)
	G.patch(p,"HelmetCrownStripe",8,32,func(u: float,v: float) -> Vector3:
		var angle: float = lerpf(0.17,2.67,v)
		var x: float = lerpf(-0.024,0.024,u)
		var r: float = sqrt(1-pow(x/0.199,2))
		return Vector3(x,0.90+cos(angle)*0.214*r,0.25+sin(angle)*0.206*r),func(_u: float,v: float) -> Vector3: return Vector3(0,cos(lerpf(0.17,2.67,v)),sin(lerpf(0.17,2.67,v))),suit,s)
	# Anatomically aligned hands reach the thick D-shaped steering rim.
	var wheel := Node3D.new()
	wheel.name = "SteeringAssembly"
	wheel.position = Vector3(0,0.54,-0.31)
	wheel.rotation.x = 1.15
	p.add_child(wheel)
	var rim: Array[Vector3] = []
	for step: int in range(33):
		var a: float = TAU*step/32.0
		rim.append(Vector3(sin(a)*0.168,0,maxf(-0.12,cos(a)*0.168)))
	G.tube(wheel,"SteeringRim",rim,0.015,dark,s,64)
	for a: float in [0.0,2.15,-2.15]:
		G.tube(wheel,"SteeringSpoke",[Vector3.ZERO,Vector3(sin(a)*0.15,0,cos(a)*0.14)],0.010,metal,s,8)
	G.rounded(wheel,"WheelHub",Vector3.ZERO,Vector3(0.075,0.025,0.065),0.010,dark,s)
	G.rounded(wheel,"DashDisplay",Vector3(0,0.021,-0.095),Vector3(0.10,0.025,0.048),0.009,metal,s)
	G.rounded(wheel,"DashGlass",Vector3(0,0.035,-0.095),Vector3(0.075,0.004,0.031),0.001,visor,s)
	G.tube(p,"SteeringColumn",[Vector3(0,0.32,-0.85),Vector3(0,0.54,-0.31)],0.017,metal,s,8)
	G.tube(p,"ColumnSupport",[Vector3(-0.20,0.17,-0.85),Vector3(0,0.32,-0.85),Vector3(0.20,0.17,-0.85)],0.014,metal,s,12)

static func _engine(car: CarVisual, trim: Material, metal: Material, bright: Material) -> void:
	var p: Node3D = car.body
	var s: bool = car.simple_model
	var cast := CompactFinish.alloy(Color("535b5b"))
	cast.roughness = 0.62
	var bronze := CompactFinish.alloy(Color("77705c"))
	bronze.roughness = 0.57
	G.rounded(p,"EngineMount",Vector3(0.40,0.205,0.70),Vector3(0.39,0.055,0.38),0.020,metal,s)
	G.rounded(p,"CastCrankcase",Vector3(0.42,0.30,0.75),Vector3(0.31,0.22,0.33),0.073,cast,s)
	G.rounded(p,"CylinderBlock",Vector3(0.43,0.435,0.70),Vector3(0.21,0.20,0.23),0.033,cast,s)
	for fin: int in range(8):
		G.rounded(p,"CoolingFin",Vector3(0.43,0.36+fin*0.023,0.70),Vector3(0.29,0.010,0.30),0.004,metal,s)
	G.rounded(p,"CylinderHead",Vector3(0.43,0.55,0.70),Vector3(0.26,0.035,0.27),0.014,cast,s)
	for x: float in [0.34,0.52]:
		for z: float in [0.61,0.79]: G.ellipsoid(p,"HeadFastener",Vector3(x,0.574,z),Vector3(0.014,0.008,0.014),bright,s)
	G.tube(p,"SparkPlugBoot",[Vector3(0.43,0.59,0.69),Vector3(0.46,0.62,0.76),Vector3(0.57,0.55,0.84)],0.011,trim,s,20)
	G.rounded(p,"Airbox",Vector3(0.56,0.45,0.39),Vector3(0.22,0.22,0.28),0.075,trim,s)
	G.tube(p,"IntakeManifold",[Vector3(0.43,0.43,0.66),Vector3(0.48,0.41,0.50),Vector3(0.56,0.43,0.45)],0.035,trim,s,16)
	G.tube(p,"ExhaustHeader",[Vector3(0.40,0.43,0.82),Vector3(0.38,0.40,0.90),Vector3(0.25,0.38,0.98),Vector3(0.20,0.38,1.02)],0.027,bronze,s,24)
	var exhaust := Node3D.new()
	exhaust.name = "ExhaustAssembly"
	exhaust.position = Vector3(0.20,0.38,1.02)
	exhaust.rotation.y = -PI*0.5
	p.add_child(exhaust)
	G.loft(exhaust,"ExpansionChamber",[Vector4(0,0.027,0,0.027),Vector4(0.12,0.060,0,0.060),Vector4(0.30,0.075,0,0.075),Vector4(0.49,0.034,0,0.034),Vector4(0.55,0.024,0,0.024)],bronze,s,1)
	G.tube(p,"ExhaustStinger",[Vector3(-0.35,0.38,1.02),Vector3(-0.42,0.35,1.03),Vector3(-0.44,0.35,1.07)],0.013,bronze,s,12)
	var silencer := Node3D.new()
	silencer.name = "ExhaustSilencer"
	silencer.position = Vector3(-0.44,0.35,1.06)
	p.add_child(silencer)
	G.loft(silencer,"SilencerCan",[Vector4(0,0.016,0,0.016),Vector4(0.015,0.034,0,0.034),Vector4(0.105,0.034,0,0.034),Vector4(0.12,0.016,0,0.016)],metal,s,1)
	var outlet: MeshInstance3D = G.lathe(silencer,"HollowExhaustOutlet",[Vector2(0,0.010),Vector2(0,0.015),Vector2(0.06,0.015),Vector2(0.06,0.010),Vector2(0,0.010)],bronze,s)
	outlet.position.z = 0.11
	outlet.rotation.y = -PI*0.5
	for x: float in [0.08,-0.15]:
		G.tube(p,"ExhaustChassisStay",[Vector3(signf(x)*0.30,0.17,1.06),Vector3(x,0.30,1.02)],0.010,metal,s,8)
		var strap: Array[Vector3] = []
		for step: int in range(17):
			var a: float = TAU*step/16
			strap.append(Vector3(x,0.38+sin(a)*0.078,1.02+cos(a)*0.078))
		G.tube(p,"ExhaustStrap",strap,0.005,metal,s,24)
	G.tube(p,"RearBrakeLine",[Vector3(-0.26,0.19,-0.75),Vector3(-0.35,0.20,0.1),Vector3(-0.33,0.30,0.87)],0.006,trim,s,32)
	# Turned live-axle disc and guarded chain run sit inboard of the rear tyres.
	var brake := Node3D.new()
	brake.position = Vector3(-0.34,0.22,0.88)
	p.add_child(brake)
	G.lathe(brake,"RearBrakeRotor",[Vector2(-0.008,0.045),Vector2(-0.008,0.125),Vector2(0.008,0.125),Vector2(0.008,0.045),Vector2(-0.008,0.045)],metal,s)
	G.rounded(p,"RearCaliper",Vector3(-0.34,0.315,0.87),Vector3(0.07,0.07,0.13),0.023,cast,s)
	G.rounded(p,"ChainGuard",Vector3(0.22,0.33,0.80),Vector3(0.026,0.055,0.46),0.012,trim,s)
	G.tube(p,"ChainUpperRun",[Vector3(0.225,0.30,0.61),Vector3(0.225,0.295,0.96)],0.010,cast,s,10)
	G.tube(p,"ChainLowerRun",[Vector3(0.225,0.19,0.61),Vector3(0.225,0.13,0.96)],0.010,cast,s,10)
	var tank := CompactFinish.rubber(Color("b8afa0"))
	G.rounded(p,"FuelTank",Vector3(0,0.24,-0.28),Vector3(0.18,0.17,0.31),0.045,tank,s)
	G.ellipsoid(p,"FuelCap",Vector3(0,0.334,-0.26),Vector3(0.04,0.015,0.04),trim,s)
	G.tube(p,"FuelLine",[Vector3(0.05,0.29,-0.17),Vector3(0.30,0.22,0.12),Vector3(0.38,0.35,0.53)],0.005,trim,s,24)

static func _wheel(car: CarVisual, center: Vector3, trim: Material, metal: Material, bright: Material) -> void:
	var s: bool = car.simple_model
	var side: float = signf(center.x)
	var pivot := Node3D.new()
	pivot.name = "KartWheelUpright"
	pivot.position = center
	car.add_child(pivot)
	var rubber := ShaderMaterial.new()
	rubber.shader = preload("res://vehicle/kart_slick.gdshader")
	G.lathe(pivot,"SlickTyre",[Vector2(-0.135,0.12),Vector2(-0.137,0.175),Vector2(-0.129,0.202),Vector2(-0.105,0.217),Vector2(-0.076,0.22),Vector2(0.076,0.22),Vector2(0.105,0.217),Vector2(0.129,0.202),Vector2(0.137,0.175),Vector2(0.135,0.12)],rubber,s)
	var magnesium := CompactFinish.alloy(Color("807b68"))
	magnesium.roughness = 0.43
	G.lathe(pivot,"DishedMagnesiumRim",[Vector2(-0.138,0.115),Vector2(-0.138,0.135),Vector2(-0.120,0.145),Vector2(-0.101,0.127),Vector2(0.101,0.127),Vector2(0.120,0.145),Vector2(0.138,0.135),Vector2(0.138,0.115),Vector2(0.103,0.111),Vector2(-0.103,0.111),Vector2(-0.138,0.115)],magnesium,s)
	# Open recesses between six formed spokes, independent of the steering pivot.
	for spoke: int in range(6):
		var a: float = TAU*spoke/6
		G.tube(pivot,"MagnesiumSpoke",[Vector3(side*0.09,sin(a)*0.035,cos(a)*0.035),Vector3(side*0.115,sin(a+0.08)*0.082,cos(a+0.08)*0.082),Vector3(side*0.125,sin(a+0.12)*0.128,cos(a+0.12)*0.128)],0.012,magnesium,s,10)
	var cap := VisualGeometry.cylinder(pivot,0.042,0.20,Vector3.ZERO,metal,true)
	cap.rotation.z = PI*0.5
	for bolt: int in range(3):
		var a: float = TAU*bolt/3
		G.ellipsoid(pivot,"WheelNut",Vector3(side*0.111,sin(a)*0.052,cos(a)*0.052),Vector3(0.009,0.008,0.008),bright,s)
	G.tube(pivot,"ValveStem",[Vector3(side*0.13,0.095,-0.066),Vector3(side*0.15,0.10,-0.069)],0.004,trim,s,4)
	var bearing := VisualGeometry.cylinder(pivot,0.029,0.30,Vector3.ZERO,metal,true)
	bearing.rotation.z = PI*0.5
	if center.z < 0: car.front_wheels.append(pivot)
	car.register_rolling_wheel(pivot,0.22)
