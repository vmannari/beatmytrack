extends RefCounted
## Original fictional EV rebuilt as one restrained, production-oriented sportback.
const COACH = preload("res://vehicle/electric_coachwork.gd")
static var glass_shader: ShaderMaterial

static func build(car: CarVisual) -> void:
	car.body.name="ElectricSportback"
	var paint:=CompactFinish.paint(Color("638d86"))
	paint.roughness=0.34
	paint.metallic=0.16
	var accent:=CompactFinish.paint(Color("263c43"))
	var alloy:=CompactFinish.alloy(Color("9ba8ab"))
	var bright:=CompactFinish.alloy(Color("bac6c6"))
	var trim:=CompactFinish.rubber(Color("152025"))
	car.paint_materials={"body":paint,"accent":accent,"detail":alloy}
	if glass_shader==null:
		glass_shader=ShaderMaterial.new()
		glass_shader.shader=preload("res://vehicle/electric_glass.gdshader")
	COACH.body(car,paint,accent,trim)
	COACH.cabin(car,paint,accent,trim,glass_shader)
	COACH.front(car,paint,trim,bright)
	COACH.rear(car,paint,accent,trim,bright)
	for side: float in [-1.0,1.0]:
		COACH.doors(car,side,trim,alloy)
		COACH.mirror(car,side,accent,trim,glass_shader)
		for axle: float in [-COACH.AXLE,COACH.AXLE]:
			COACH.arch(car,side,axle,paint,trim)
			wheel(car,side,axle,trim,alloy,bright)

static func wheel(car: CarVisual,side: float,axle: float,trim: Material,alloy: Material,bright: Material) -> void:
	var pivot:=Node3D.new()
	pivot.name=("Front" if axle<0 else "Rear")+("Left" if side<0 else "Right")+"Wheel"
	pivot.position=Vector3(side*COACH.HALF_TRACK,0.37,axle)
	car.add_child(pivot)
	CompactDetail.tire(pivot,trim,car.simple_model)
	var dark:=CompactFinish.alloy(Color("34434b"))
	dark.roughness=0.46
	var fixed:=Node3D.new()
	fixed.name="BrakeAssembly"
	car.body.add_child(fixed)
	fixed.position=pivot.position
	var rotor:=VisualGeometry.cylinder(fixed,0.211,0.020,Vector3(side*0.056,0,0),dark,true)
	rotor.rotation.z=PI*0.5
	COACH.rounded(fixed,"Caliper",Vector3(0.05,0.16,0.075),Vector3(side*0.072,0.018,0.174),0.015,dark)
	COACH.patch(pivot,"AeroBarrel"+str(side),64,8,func(u: float,v: float)->Vector3:
		var a: float=u*TAU
		var r: float=lerpf(0.208,0.251,v)
		return Vector3(side*lerpf(-0.07,0.145,v),r*sin(a),r*cos(a)),dark,Vector3(side,0,0),car.simple_model)
	COACH.patch(pivot,"MachinedRim"+str(side),64,6,func(u: float,v: float)->Vector3:
		var a: float=u*TAU
		var r: float=lerpf(0.241,0.257,v)
		return Vector3(side*(0.146+0.004*sin(v*PI)),r*sin(a),r*cos(a)),bright,Vector3(side,0,0),car.simple_model)
	for spoke: int in range(5):
		var blade:=Node3D.new()
		blade.rotation.x=TAU*spoke/5.0
		pivot.add_child(blade)
		for front: bool in [true,false]:
			COACH.patch(blade,"AeroBlade"+str(side)+str(front),8,12,func(u: float,v: float)->Vector3:
				var r: float=lerpf(0.055,0.245,v)
				var theta: float=lerpf(-0.03,0.13,v)+lerpf(-1,1,u)*lerpf(0.19,0.13,v)
				return Vector3(side*(0.127+0.018*v+(0.006*sin(PI*u) if front else -0.019)),r*sin(theta),r*cos(theta)),alloy if front else dark,Vector3(side if front else -side,0,0),car.simple_model)
		for edge: float in [-1.0,1.0]:
			COACH.patch(blade,"BladeReturn"+str(side)+str(edge),12,2,func(u: float,v: float)->Vector3:
				var r: float=lerpf(0.055,0.245,u)
				var theta: float=lerpf(-0.03,0.13,u)+edge*lerpf(0.19,0.13,u)
				return Vector3(side*(0.127+0.018*u+lerpf(-0.019,0,v)),r*sin(theta),r*cos(theta)),dark,Vector3(0,edge,0),car.simple_model)
	var cap:=VisualGeometry.cylinder(pivot,0.065,0.012,Vector3(side*0.137,0,0),alloy,true)
	cap.rotation.z=PI*0.5
	for bolt: int in range(5):
		var a: float=TAU*bolt/5
		var lug:=VisualGeometry.cylinder(pivot,0.006,0.005,Vector3(side*0.146,0.043*sin(a),0.043*cos(a)),dark,true)
		lug.rotation.z=PI*0.5
	if axle<0: car.front_wheels.append(pivot)
	car.register_rolling_wheel(pivot,0.37)
	fixed.reparent(pivot,false)
	fixed.position=Vector3.ZERO
	if car.simple_model:
		for mesh: MeshInstance3D in fixed.find_children("*","MeshInstance3D",true,false): mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func night_lens(parent: Node3D,material: Material) -> void:
	COACH.patch(parent,"ElectricNightLightbar",96,4,func(u: float,v: float)->Vector3:return COACH.lightbar_point(u,v)+Vector3(0,0,-0.001),material,Vector3.FORWARD)
