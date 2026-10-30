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
		# Pedal spindle, forged pedal plate and anti-slip ribs are visible in the footwell.
		G.tube(p,"PedalLever",[Vector3(side*0.25,0.18,-0.84),Vector3(side*0.19,0.25,-0.92),Vector3(side*0.17,0.30,-0.93)],0.012,bright,s,8)
		var pedal: MeshInstance3D = G.rounded(p,"PedalPlate",Vector3(side*0.17,0.28,-0.94),Vector3(0.11,0.13,0.023),0.010,metal,s)
		pedal.rotation.x = -0.30
		for rib: int in range(4): G.rounded(p,"PedalRib",Vector3(side*0.17,0.24+rib*0.025,-0.958),Vector3(0.075,0.004,0.005),0.001,trim,s)
		for z: float in [-0.93,-0.60,-0.25,0.10,0.48]:
			G.ellipsoid(p,"TrayRivet",Vector3(side*0.39,0.165,z),Vector3(0.008,0.004,0.008),bright,s)
	preload("res://vehicle/kart_driver.gd").seat_stays(p,metal,s)
	G.tube(p,"FrontCrossmember",[Vector3(-0.49,0.19,-0.88),Vector3(0,0.19,-0.88),Vector3(0.49,0.19,-0.88)],0.026,chassis,s,12)
	G.tube(p,"RearProtection",[Vector3(-0.75,0.18,1.22),Vector3(-0.69,0.18,1.30),Vector3(-0.32,0.18,1.32),Vector3(0.32,0.18,1.32),Vector3(0.69,0.18,1.30),Vector3(0.75,0.18,1.22)],0.037,trim,s,40)
	for side: float in [-1.0,1.0]:
		G.tube(p,"RearBumperChassisMount",[Vector3(side*0.30,0.17,1.04),Vector3(side*0.35,0.18,1.17),Vector3(side*0.35,0.18,1.32)],0.022,metal,s,16)
		G.ellipsoid(p,"RearBumperEndCap",Vector3(side*0.75,0.18,1.22),Vector3.ONE*0.037,trim,s)
	G.tube(p,"LiveRearAxle",[Vector3(-0.72,0.22,0.88),Vector3(0.72,0.22,0.88)],0.026,metal,s,8)
	# Keep the entire broad nose ahead of the front tyres' full steering sweep.
	G.loft(p,"NoseLowerReturn",[Vector4(-1.40,0.52,0.185,0.020),Vector4(-1.35,0.715,0.182,0.035),Vector4(-1.25,0.735,0.19,0.035),Vector4(-1.195,0.60,0.19,0.025)],trim,s,0.65)
	var nose_profile: Array[Vector4] = [Vector4(-1.40,0.49,0.255,0.045),Vector4(-1.35,0.70,0.275,0.092),Vector4(-1.25,0.72,0.285,0.105),Vector4(-1.20,0.59,0.275,0.075)]
	G.loft(p,"SculptedFrontFairing",nose_profile,paint,s,0.75)
	_fitted_inlay(p,"NoseCenterInlay",p.get_child(-1),nose_profile,0.065,0.18,0.96,accent,s)
	var fairing := Node3D.new()
	p.add_child(fairing)
	var fairing_profile: Array[Vector4] = [Vector4(-1.235,0.13,0.37,0.032),Vector4(-0.87,0.155,0.425,0.035),Vector4(-0.64,0.19,0.515,0.045),Vector4(-0.41,0.175,0.565,0.037),Vector4(-0.35,0.145,0.55,0.027)]
	G.loft(fairing,"NassauFairing",fairing_profile,paint,s,0.70)
	_fitted_inlay(p,"FairingCenterInlay",fairing.get_child(-1),fairing_profile,0.064,0.06,0.94,accent,s)
	# Fitted little light housings retain the established night/brake presentation.
	for side: float in [-1.0,1.0]:
		G.rounded(p,"RearLampBezel",Vector3(side*0.55,0.225,1.31),Vector3(0.16,0.09,0.045),0.018,trim,s)
		G.rounded(p,"RearLampLens",Vector3(side*0.55,0.225,1.335),Vector3(0.125,0.055,0.015),0.007,car.brake_material,s)
		G.rounded(p,"FrontLampRecess",Vector3(side*0.33,0.25,-1.398),Vector3(0.12,0.048,0.025),0.012,trim,s)
		G.rounded(p,"FrontLampGlass",Vector3(side*0.33,0.25,-1.412),Vector3(0.092,0.024,0.010),0.004,CompactFinish.alloy(Color("a5b5af")),s)

static func _clip_inlay(polygon: Array[Dictionary], normal: Vector3, offset: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if polygon.is_empty(): return result
	var previous: Dictionary = polygon[-1]
	var previous_distance: float = normal.dot(previous.point)-offset
	for current: Dictionary in polygon:
		var distance: float = normal.dot(current.point)-offset
		if (distance >= 0) != (previous_distance >= 0):
			var t: float = previous_distance/(previous_distance-distance)
			result.append({"point":previous.point.lerp(current.point,t),"normal":previous.normal.lerp(current.normal,t).normalized()})
		if distance >= 0: result.append(current)
		previous = current
		previous_distance = distance
	return result

static func _fitted_inlay(parent: Node3D, label: String, shell: MeshInstance3D, profile: Array[Vector4], half_width: float, start: float, end: float, material: Material, simple: bool) -> void:
	# Clip the actual shell triangles, so the racing LOD cannot swallow the stripe
	# between independently sampled analytic surfaces. Runs only during mesh bake.
	G.attach(parent,label+"|fitted-v1"+("|simple" if simple else "|full"),material,func() -> ArrayMesh:
		var front: float = G.loft_station(profile,start).x
		var rear: float = G.loft_station(profile,end).x
		var arrays: Array = shell.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for face: int in range(indices.size()/3):
			var polygon: Array[Dictionary] = []
			var upward: float = 0
			for corner: int in range(3):
				var index: int = indices[face*3+corner]
				polygon.append({"point":vertices[index],"normal":normals[index]})
				upward += normals[index].y
			if upward <= 0.1: continue
			for plane: Vector4 in [Vector4(1,0,0,-half_width),Vector4(-1,0,0,-half_width),Vector4(0,0,1,front),Vector4(0,0,-1,-rear)]:
				polygon = _clip_inlay(polygon,Vector3(plane.x,plane.y,plane.z),plane.w)
			for triangle: int in range(1,polygon.size()-1):
				for corner: int in [0,triangle,triangle+1]:
					var point: Vector3 = polygon[corner].point
					tool.set_normal(polygon[corner].normal)
					tool.set_uv(Vector2(inverse_lerp(-half_width,half_width,point.x),inverse_lerp(front,rear,point.z)))
					tool.add_vertex(point+Vector3.UP*0.0015)
		tool.index()
		return tool.commit())

static func _driver(car: CarVisual, trim: Material, metal: Material) -> void:
	var p: Node3D = car.body
	var s: bool = car.simple_model
	var dark := CompactFinish.rubber(Color("10191d"))
	var visor := CompactFinish.alloy(Color("253d49"))
	visor.metallic = 0.35
	visor.roughness = 0.22
	preload("res://vehicle/kart_driver.gd").build(p,trim,s)
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
	G.rounded(p,"EngineMount",Vector3(0.395,0.205,0.70),Vector3(0.30,0.055,0.38),0.020,metal,s)
	G.rounded(p,"CastCrankcase",Vector3(0.395,0.30,0.75),Vector3(0.31,0.22,0.33),0.073,cast,s)
	G.rounded(p,"CylinderBlock",Vector3(0.405,0.435,0.70),Vector3(0.21,0.20,0.23),0.033,cast,s)
	for fin: int in range(8):
		G.rounded(p,"CoolingFin",Vector3(0.405,0.36+fin*0.023,0.70),Vector3(0.29,0.010,0.30),0.004,metal,s)
	G.rounded(p,"CylinderHead",Vector3(0.405,0.55,0.70),Vector3(0.26,0.035,0.27),0.014,cast,s)
	for x: float in [0.315,0.495]:
		for z: float in [0.61,0.79]: G.ellipsoid(p,"HeadFastener",Vector3(x,0.574,z),Vector3(0.014,0.008,0.014),bright,s)
	G.tube(p,"SparkPlugBoot",[Vector3(0.405,0.59,0.69),Vector3(0.435,0.62,0.76),Vector3(0.545,0.55,0.84)],0.011,trim,s,20)
	G.rounded(p,"Airbox",Vector3(0.56,0.45,0.39),Vector3(0.22,0.22,0.28),0.075,trim,s)
	G.tube(p,"IntakeManifold",[Vector3(0.405,0.43,0.66),Vector3(0.48,0.41,0.50),Vector3(0.56,0.43,0.45)],0.035,trim,s,16)
	G.tube(p,"ExhaustHeader",[Vector3(0.40,0.43,0.82),Vector3(0.38,0.40,0.90),Vector3(0.25,0.38,0.98),Vector3(0.20,0.38,1.02)],0.027,bronze,s,24)
	var exhaust := Node3D.new()
	exhaust.name = "ExhaustAssembly"
	exhaust.position = Vector3(0.20,0.38,1.02)
	exhaust.rotation.y = -PI*0.5
	p.add_child(exhaust)
	var chamber_profile: Array[Vector4] = [Vector4(0,0.027,0,0.027),Vector4(0.12,0.060,0,0.060),Vector4(0.30,0.075,0,0.075),Vector4(0.49,0.034,0,0.034),Vector4(0.55,0.024,0,0.024)]
	G.loft(exhaust,"ExpansionChamber",chamber_profile,bronze,s,1)
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
		var radius: float = _chamber_radius(chamber_profile,0.20-x)+0.004
		G.tube(p,"ExhaustChassisStay",[Vector3(signf(x)*0.30,0.17,1.06),Vector3(x,0.38-radius,1.02)],0.010,metal,s,8)
		var strap: Array[Vector3] = []
		for step: int in range(17):
			var a: float = TAU*step/16
			strap.append(Vector3(x,0.38+sin(a)*radius,1.02+cos(a)*radius))
		G.tube(p,"ExhaustStrap",strap,0.005,metal,s,48)
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

static func _chamber_radius(profile: Array[Vector4], longitudinal: float) -> float:
	for station: int in range(profile.size()-1):
		if longitudinal <= profile[station+1].x:
			var fraction: float = inverse_lerp(profile[station].x,profile[station+1].x,longitudinal)
			return G.loft_station(profile,(station+fraction)/(profile.size()-1)).y
	return profile[-1].y

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
