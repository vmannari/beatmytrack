extends RefCounted
## Original fictional electric sportback, using the Compact's automotive finishes.
const COACH = preload("res://vehicle/electric_coachwork.gd")
static var glass_shader: ShaderMaterial

static func build(car: CarVisual) -> void:
	car.body.name = "ElectricSportback"
	var paint := CompactFinish.paint(Color("638d86"))
	paint.roughness = 0.34
	paint.metallic = 0.16
	var accent := CompactFinish.paint(Color("263c43"))
	var alloy := CompactFinish.alloy(Color("9ba8ab"))
	var bright := CompactFinish.alloy(Color("bac6c6"))
	var trim := CompactFinish.rubber(Color("152025"))
	car.paint_materials = {"body":paint,"accent":accent,"detail":alloy}
	if glass_shader == null:
		glass_shader = ShaderMaterial.new()
		glass_shader.shader = preload("res://vehicle/electric_glass.gdshader")
	COACH.body(car,paint,accent,trim)
	COACH.cabin(car,paint,accent,trim,glass_shader)
	COACH.front(car,paint,trim,bright)
	COACH.rear(car,paint,accent,trim,bright)
	for side: float in [-1.0,1.0]:
		COACH.doors(car,side,trim,alloy)
		COACH.mirror(car,side,accent,trim,glass_shader)
		for axle: float in [-COACH.AXLE,COACH.AXLE]:
			COACH.arch(car,side,axle,paint,trim)
			_wheel(car,side,axle,trim,alloy,bright)
	COACH.rounded(car.body,"BatteryTray",Vector3(1.55,0.09,3.53),Vector3(0,0.30,0),0.035,trim)

static func _wheel(car: CarVisual, side: float, axle: float, trim: Material, alloy: Material, bright: Material) -> void:
	var pivot := Node3D.new()
	pivot.name = ("Front" if axle < 0 else "Rear")+("Left" if side < 0 else "Right")+"Wheel"
	pivot.position = Vector3(side*COACH.HALF_TRACK,0.37,axle)
	car.add_child(pivot)
	CompactDetail.tire(pivot,trim,car.simple_model)
	var inner := Node3D.new()
	inner.name = "BrakeAssembly"
	inner.position = pivot.position
	car.body.add_child(inner)
	var disc := CompactFinish.alloy(Color("59656a"))
	disc.roughness = 0.55
	var rotor := VisualGeometry.cylinder(inner,0.212,0.030,Vector3(side*0.055,0,0),disc,true)
	rotor.mesh = rotor.mesh.duplicate()
	(rotor.mesh as CylinderMesh).radial_segments = 64
	rotor.rotation.z = PI*0.5
	var bell := CompactFinish.alloy(Color("303a40"))
	bell.roughness = 0.58
	var rotor_bell := VisualGeometry.cylinder(inner,0.092,0.006,Vector3(side*0.073,0,0),bell,true)
	rotor_bell.rotation.z = PI*0.5
	for slot: int in range(12):
		var angle: float = slot*TAU/12
		COACH.patch(inner,"RotorSlot"+str(side)+str(slot),2,2,func(u: float,v: float) -> Vector3:
			var theta: float = angle+lerpf(-0.009,0.009,v)+0.11*u
			var radius: float = lerpf(0.145,0.198,u)
			return Vector3(side*0.0707,sin(theta)*radius,cos(theta)*radius),bell,Vector3(side,0,0),car.simple_model)
	var caliper := CompactFinish.paint(Color("404d52"))
	COACH.rounded(inner,"FixedCaliper",Vector3(0.050,0.19,0.082),Vector3(side*0.080,0.015,0.176),0.018,caliper)
	# Open barrel: the disc and fixed caliper sit behind the rolling spokes.
	COACH.patch(pivot,"EVForgedBarrel"+str(side),64,10,func(u: float,v: float) -> Vector3:
		var angle: float = u*TAU
		var radius: float = lerpf(0.198,0.252,v)
		return Vector3(side*lerpf(0.065,0.146,v),sin(angle)*radius,cos(angle)*radius),alloy,Vector3(side,0,0),car.simple_model)
	var ring := Node3D.new()
	ring.position.x = side*0.146
	ring.rotation.z = PI*0.5
	pivot.add_child(ring)
	VisualGeometry.ring(ring,Vector3.ZERO,0.254,0.009,bright)
	for spoke: int in range(5):
		var blade := Node3D.new()
		blade.rotation.x = TAU*spoke/5.0
		pivot.add_child(blade)
		for split: float in [-1.0,1.0]: _forged_spoke(blade,side,split,alloy,car.simple_model)
	var cap := VisualGeometry.cylinder(pivot,0.061,0.012,Vector3(side*0.133,0,0),alloy,true)
	cap.rotation.z = PI*0.5
	for lug: int in range(5):
		var angle: float = TAU*lug/5
		var bolt := VisualGeometry.cylinder(pivot,0.0065,0.006,Vector3(side*0.142,sin(angle)*0.043,cos(angle)*0.043),bright,true)
		bolt.rotation.z = PI*0.5
	if axle < 0: car.front_wheels.append(pivot)
	car.register_rolling_wheel(pivot,0.37)
	# Calipers steer with the upright and remain independent of the rolling rim.
	inner.reparent(pivot,false)
	inner.position = Vector3.ZERO
	if car.simple_model:
		# The five stock silhouette proxies own racing shadows. Fixed brakes
		# sit outside the rolling frame and must not add separate casters.
		for part: MeshInstance3D in inner.find_children("*","MeshInstance3D",true,false):
			part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func _spoke_point(side: float, split: float, t: float, across: float, depth: float) -> Vector3:
	var angle: float = 0.015*t+split*0.135*smoothstep(0.26,1,t)
	var radius: float = lerpf(0.065,0.247,t)
	var width: float = lerpf(0.011,0.017,t)*across
	# Taut forged branches with a shallow dish and narrow machined edge.
	return Vector3(side*(0.120+0.023*t+depth),sin(angle)*radius+cos(angle)*width,cos(angle)*radius-sin(angle)*width)

static func _forged_spoke(parent: Node3D, side: float, split: float, material: Material, simple: bool) -> void:
	var prefix: String = "ForgedSpoke"+str(side)+str(split)
	for front: bool in [true,false]:
		COACH.patch(parent,prefix+str(front),4,8,func(u: float,v: float) -> Vector3:
			var across: float = lerpf(-1,1,u)
			return _spoke_point(side,split,v,across,0.008+0.002*clampf((1-absf(across))*4,0,1) if front else -0.012),material,Vector3(side if front else -side,0,0),simple)
	for edge: float in [-1.0,1.0]:
		COACH.patch(parent,prefix+"Return"+str(edge),8,2,func(u: float,v: float) -> Vector3:
			return _spoke_point(side,split,u,edge,lerpf(-0.012,0.008,v)),material,Vector3(0,edge,0),simple)
	for end: float in [0.0,1.0]:
		COACH.patch(parent,prefix+"End"+str(end),4,2,func(u: float,v: float) -> Vector3:
			return _spoke_point(side,split,end,lerpf(-1,1,u),lerpf(-0.012,0.008+0.002*clampf((1-absf(lerpf(-1,1,u)))*4,0,1),v)),material,Vector3(0,0,-1 if end == 0 else 1),simple)

static func night_lens(parent: Node3D, material: Material) -> void:
	COACH.patch(parent,"ElectricNightLightbar",96,6,func(u: float,v: float) -> Vector3:
		return COACH.raw_lightbar_point(u,v)+Vector3(0,0,-0.001),material,Vector3.FORWARD)
