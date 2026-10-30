extends RefCounted
## Original recreational sport hovercraft. Model metres; bow -Z, fan aft.
const Surface = preload("res://vehicle/hovercraft_surface.gd")
const FAN: Vector3 = Vector3(0,1.43,1.33)

static func build(car: CarVisual) -> void:
	var paint: StandardMaterial3D = CompactFinish.paint(Color("698d87"))
	paint.roughness = 0.46
	var accent: StandardMaterial3D = CompactFinish.paint(Color("d9d0b7"))
	accent.roughness = 0.48
	var detail: StandardMaterial3D = CompactFinish.alloy(Color("83918f"))
	var rubber: StandardMaterial3D = CompactFinish.rubber(Color("242b2e"))
	rubber.roughness = 0.93
	var seam: StandardMaterial3D = CompactFinish.rubber(Color("10181d"))
	var metal: StandardMaterial3D = CompactFinish.alloy(Color("68777b"))
	var dark_metal: StandardMaterial3D = CompactFinish.alloy(Color("252f35"))
	dark_metal.roughness = 0.52
	var glass := ShaderMaterial.new()
	glass.shader = preload("res://vehicle/electric_glass.gdshader")
	glass.set_shader_parameter("glass_tint_srgb",Vector3(0.045,0.079,0.090))
	car.paint_materials = {"body":paint,"accent":accent,"detail":detail}
	car.body.set_meta("hovercraft_revision",2)
	var simple: bool = car.simple_model
	_skirt(car.body,rubber,seam,simple)
	_hull(car.body,paint,seam,detail,simple)
	_cabin(car.body,paint,accent,glass,seam,metal,simple)
	_machinery(car.body,paint,accent,seam,metal,dark_metal,simple)
	_lights(car.body,car.brake_material,seam,detail,simple)

static func _outline(angle: float, scale: float = 1.0, height: float = 0.0) -> Vector3:
	var z: float = signf(cos(angle))*pow(absf(cos(angle)),0.74)*2.13*scale
	var taper: float = 0.95+0.05*tanh(z*1.6)
	return Vector3(signf(sin(angle))*pow(absf(sin(angle)),0.74)*1.16*taper*scale,height,z)

static func _outward(u: float, _v: float) -> Vector3:
	return _outline(u*TAU).normalized()

static func _deck_y(x: float,z: float) -> float:
	var width: float = 1.16*0.92*(0.95+0.05*tanh(z*1.6))
	var distance: float = pow(absf(x)/width,2.7027027)+pow(absf(z)/(2.13*0.92),2.7027027)
	var recess: float = 0.11*exp(-pow(x/0.44,4.0)-pow((z-1.30)/0.49,4.0))*smoothstep(0.0,0.25,1.0-distance)
	return 0.82+0.08*maxf(0.0,1.0-distance)-recess

static func _skirt(parent: Node3D,rubber: Material,seam: Material,simple: bool) -> void:
	var rings: Array[Vector2] = [Vector2(0.895,0.29),Vector2(0.975,0.33),Vector2(0.994,0.43),Vector2(0.970,0.54),Vector2(0.905,0.585)]
	Surface.surface(parent,"InflatedUpperBag",64 if simple else 128,8 if simple else 16,
		func(u: float,v: float) -> Vector3:
			var p: Vector2 = Surface.monotone_profile(rings,v)
			return _outline(u*TAU,p.x,p.y),_outward,rubber,simple)
	for index: int in range(52):
		var start: float = TAU*index/52.0
		Surface.surface(parent,"SkirtFinger%02d"%index,3 if simple else 6,4 if simple else 6,
			func(u: float,v: float) -> Vector3:
				var angle: float = start+(0.035+u*0.93)*TAU/52.0
				var bulge: float = pow(maxf(0.0,sin(PI*u)),0.55)
				var radius: float = 0.937+0.052*bulge*sin(v*PI*0.85)+0.009*v
				var y: float = lerpf(0.145-0.035*bulge,0.407,v)
				return _outline(angle,radius,y),
			func(u: float,_v: float) -> Vector3: return _outline(start+u*TAU/52.0).normalized(),rubber,simple)
	Surface.surface(parent,"Underside",48 if simple else 96,3,
		func(u: float,v: float) -> Vector3: return _outline(u*TAU,0.935*v,0.15+0.04*(1.0-v)),
		func(_u: float,_v: float) -> Vector3: return Vector3.DOWN,seam,simple)
	for height: float in [0.49,0.557]:
		Surface.tube(parent,"SkirtBinding%d"%roundi(height*1000),func(u: float) -> Vector3: return _outline(u*TAU,0.978 if height < 0.5 else 0.938,height),0.004,64 if simple else 128,seam,simple)

static func _hull(parent: Node3D,paint: Material,seam: Material,detail: Material,simple: bool) -> void:
	var profile: Array[Vector2] = [Vector2(0.89,0.51),Vector2(0.965,0.57),Vector2(0.986,0.635),Vector2(0.984,0.70),Vector2(0.966,0.761),Vector2(0.932,0.8176),Vector2(0.92,0.82)]
	Surface.surface(parent,"FormedCompositeHull",64 if simple else 128,10 if simple else 18,
		func(u: float,v: float) -> Vector3:
			var p: Vector2 = Surface.monotone_profile(profile,v)
			return _outline(u*TAU,p.x,p.y),_outward,paint,simple)
	Surface.surface(parent,"CrownedDeck",64 if simple else 128,6 if simple else 10,
		func(u: float,v: float) -> Vector3:
			var p: Vector3 = _outline(u*TAU,0.92*v)
			p.y = _deck_y(p.x,p.z)
			return p,
		func(_u: float,_v: float) -> Vector3: return Vector3.UP,paint,simple)
	Surface.tube(parent,"HullRubbingStrake",func(u: float) -> Vector3: return _outline(u*TAU,0.978,0.729),0.012,64 if simple else 128,seam,simple)
	for layer: int in range(2):
		var rx: float = 0.64 if layer == 0 else 0.626
		var rz: float = 0.265 if layer == 0 else 0.251
		Surface.surface(parent,"BowHatch%d"%layer,40 if simple else 80,4 if simple else 8,
			func(u: float,v: float) -> Vector3:
				var x: float = sin(u*TAU)*rx*v
				var z: float = -1.54+cos(u*TAU)*rz*v
				return Vector3(x,_deck_y(x,z)+0.002+layer*0.003,z),
			func(_u: float,_v: float) -> Vector3: return Vector3.UP,seam if layer == 0 else paint,simple)
	for side: float in [-1.0,1.0]:
		Surface.rounded_box(parent,"HatchHinge%d"%int(side),Vector3(0.115,0.022,0.04),Vector3(side*0.38,_deck_y(side*0.38,-1.315)+0.014,-1.315),0.009,detail,simple)
		var x: float = side*0.91
		Surface.tube(parent,"DeckGrabRail%d"%int(side),func(u: float) -> Vector3:
			var z: float = lerpf(-0.75,0.22,u)
			return Vector3(x,_deck_y(x,z)+0.027+0.055*pow(maxf(0.0,sin(PI*u)),0.4),z),0.013,12 if simple else 24,detail,simple)
		for z: float in [-0.75,0.22]:
			Surface.rounded_box(parent,"RailFoot%d_%d"%[int(side),roundi(z*100)],Vector3(0.062,0.015,0.075),Vector3(x,_deck_y(x,z)+0.009,z),0.006,detail,simple)
	Surface.tube(parent,"BowTowingEye",func(u: float) -> Vector3: return Vector3(sin(u*TAU)*0.065,0.648+cos(u*TAU)*0.035,-1.928),0.012,24 if simple else 40,detail,simple)

static func _roof(s: float,t: float) -> Vector3:
	var z: float = t*2.0-1.0
	return Vector3(s*0.58,1.36+0.065*pow(maxf(0.0,1.0-pow(absf(s),5.0)-pow(absf(z),5.0)),2.0),lerpf(-0.68,0.30,t))

static func _cabin_point(angle: float,v: float) -> Vector3:
	var x: float = signf(sin(angle))*pow(absf(sin(angle)),0.4)
	var z: float = -signf(cos(angle))*pow(absf(cos(angle)),0.4)
	var width: float = lerpf(0.73,0.58,v)+0.018*sin(PI*v)
	var front: float = lerpf(-1.22,-0.68,v)
	var back: float = lerpf(0.55,0.30,v)
	# Zero vertical derivative at the top turns the shell smoothly into the roof.
	var base_x: float = x*0.73
	var base_z: float = -0.335+z*0.885
	var base_y: float = _deck_y(base_x,base_z)-0.008
	var height: float = lerpf(base_y,1.36,v+sin(PI*v)/PI)
	return Vector3(x*width,height,(front+back)*0.5+z*(back-front)*0.5)

static func _windshield(s: float,v: float) -> Vector3:
	return _cabin_point(s*PI*0.25,v)

static func _side(side: float,t: float,v: float) -> Vector3:
	return _cabin_point(side*(PI*0.25+t*PI*0.5),v)

static func _rounded_uv(u: float,v: float,radius: float) -> Vector2:
	var p := Vector2(u,v)
	var inner: Vector2 = p.clamp(Vector2.ONE*radius,Vector2.ONE*(1.0-radius))
	var delta: Vector2 = p-inner
	return inner+delta.normalized()*minf(radius,delta.length())

static func _cabin(parent: Node3D,paint: Material,accent: Material,glass: Material,seam: Material,metal: Material,simple: bool) -> void:
	Surface.surface(parent,"CurvedWindshieldFrame",16 if simple else 32,8 if simple else 18,
		func(u: float,v: float) -> Vector3: return _windshield(u*2.0-1.0,v),
		func(_u: float,_v: float) -> Vector3: return Vector3(0,0.5,-1),paint,simple)
	for layer: int in range(2):
		Surface.surface(parent,"Windshield%d"%layer,16 if simple else 32,8 if simple else 18,
			func(u: float,v: float) -> Vector3:
				var uv: Vector2 = _rounded_uv(u,v,0.065)
				return _windshield(lerpf(-0.933+layer*0.014,0.933-layer*0.014,uv.x),lerpf(0.085+layer*0.018,0.92-layer*0.018,uv.y))+Vector3(0,0.002+layer*0.001,-0.004-layer*0.001),
			func(_u: float,_v: float) -> Vector3: return Vector3(0,0.5,-1),seam if layer == 0 else glass,simple)
	Surface.surface(parent,"ArchedCanopy",64 if simple else 96,6 if simple else 12,
		func(u: float,v: float) -> Vector3:
			var p: Vector3 = _cabin_point(u*TAU,1.0)
			return Vector3(p.x*v,1.36+0.065*pow(1.0-pow(v,5.0),2.0),-0.19+(p.z+0.19)*v),
		func(_u: float,_v: float) -> Vector3: return Vector3.UP,accent,simple)
	for side: float in [-1.0,1.0]:
		Surface.surface(parent,"CabinSide%d"%int(side),16 if simple else 32,8 if simple else 16,
			func(u: float,v: float) -> Vector3: return _side(side,u,v),
			func(_u: float,_v: float) -> Vector3: return Vector3(side,0,0),paint,simple)
		for pane: int in range(2):
			for layer: int in range(2):
				Surface.surface(parent,"SideWindow%d_%d_%d"%[int(side),pane,layer],10 if simple else 20,6 if simple else 12,
					func(u: float,v: float) -> Vector3:
						var uv: Vector2 = _rounded_uv(u,v,0.085)
						var t: float = lerpf(0.075 if pane == 0 else 0.637,0.598 if pane == 0 else 0.934,lerpf(0.012*layer,1.0-0.012*layer,uv.x))
						return _side(side,t,lerpf(0.295+layer*0.02,0.92-layer*0.02,uv.y))+Vector3(side*(0.003+0.001*layer),0,0),
						func(_u: float,_v: float) -> Vector3: return Vector3(side,0.15,0),seam if layer == 0 else glass,simple)
		Surface.tube(parent,"DoorCut%d"%int(side),func(u: float) -> Vector3:
			var uv: Vector2 = _rounded_uv((sin(u*TAU)+1.0)*0.5,(cos(u*TAU)+1.0)*0.5,0.1)
			var t: float = lerpf(0.055,0.62,uv.x)
			var v: float = lerpf(0.07,0.965,uv.y)
			return _side(side,t,v)+Vector3(side*0.002,0,0),0.0025,32 if simple else 64,seam,simple)
		var handle: Vector3 = _side(side,0.51,0.22)+Vector3(side*0.007,0,0)
		Surface.rounded_box(parent,"DoorLatchRecess%d"%int(side),Vector3(0.016,0.048,0.15),handle,0.007,seam,simple)
		Surface.rounded_box(parent,"DoorLatch%d"%int(side),Vector3(0.022,0.015,0.098),handle+Vector3(side*0.008,0.004,0),0.006,metal,simple)
	Surface.surface(parent,"CabinRear",16 if simple else 32,8 if simple else 16,
		func(u: float,v: float) -> Vector3: return _cabin_point(PI*0.75+u*PI*0.5,v),
		func(_u: float,_v: float) -> Vector3: return Vector3(0,0.3,1),paint,simple)
	for layer: int in range(2):
		Surface.surface(parent,"RoofHatch%d"%layer,12 if simple else 24,10 if simple else 20,
			func(u: float,v: float) -> Vector3:
				var uv: Vector2 = _rounded_uv(u,v,0.14)
				return _roof(lerpf(-0.72+layer*0.015,0.72-layer*0.015,uv.x),lerpf(0.13+layer*0.012,0.84-layer*0.012,uv.y))+Vector3(0,0.002+layer*0.002,0),
			func(_u: float,_v: float) -> Vector3: return Vector3.UP,seam if layer == 0 else accent,simple)
	Surface.tube(parent,"WiperArm",func(u: float) -> Vector3: return _windshield(lerpf(0.45,-0.06,u),lerpf(0.12,0.60,u))+Vector3(0,0.007,-0.012),0.006,4 if simple else 8,metal,simple)
	Surface.tube(parent,"WiperBlade",func(u: float) -> Vector3: return _windshield(lerpf(-0.39,0.28,u),0.60)+Vector3(0,0.009,-0.017),0.008,8 if simple else 16,seam,simple)

static func _machinery(parent: Node3D,paint: Material,accent: Material,seam: Material,metal: Material,dark_metal: Material,simple: bool) -> void:
	Surface.rounded_box(parent,"EngineCoverSeal",Vector3(0.85,0.22,0.61),Vector3(0,0.965,0.80),0.07,seam,simple)
	Surface.rounded_box(parent,"EngineCover",Vector3(0.82,0.23,0.59),Vector3(0,0.98,0.79),0.075,paint,simple)
	for side: float in [-1.0,1.0]:
		for vent: int in range(5):
			Surface.rounded_box(parent,"CoolingSlot%d_%d"%[int(side),vent],Vector3(0.015,0.068,0.018),Vector3(side*0.410,0.977,0.63+vent*0.07),0.006,seam,simple)
		Surface.tube(parent,"FanSupport%d"%int(side),func(u: float) -> Vector3: return Vector3(side*lerpf(0.70,0.49,u),lerpf(0.84,1.16,u),lerpf(1.05,1.32,u)),0.033,3 if simple else 6,dark_metal,simple)
		Surface.rounded_box(parent,"FanSupportFoot%d"%int(side),Vector3(0.14,0.025,0.19),Vector3(side*0.70,0.84,1.05),0.01,metal,simple)
	var duct: Array[Vector2] = [Vector2(0.615,-0.21),Vector2(0.645,-0.12),Vector2(0.650,0.12),Vector2(0.615,0.21),Vector2(0.585,0.23),Vector2(0.558,0.18),Vector2(0.553,-0.18),Vector2(0.585,-0.23)]
	Surface.surface(parent,"RolledFanDuct",64 if simple else 128,16 if simple else 32,
		func(u: float,v: float) -> Vector3:
			var p: Vector2 = Surface.profile(duct,v,true)
			return FAN+Vector3(sin(u*TAU)*p.x,cos(u*TAU)*p.x,p.y),
		func(u: float,v: float) -> Vector3:
			var p: Vector2 = Surface.profile(duct,v,true)
			return Vector3(sin(u*TAU)*(p.x-0.595),cos(u*TAU)*(p.x-0.595),p.y*0.3),accent,simple)
	for end: float in [-1.0,1.0]:
		Surface.ring(parent,"DuctLip%d"%int(end),FAN+Vector3(0,0,end*0.217),0.592,0.008,metal,simple)
		for radius: float in [0.22,0.40,0.55]:
			Surface.ring(parent,"GuardRing%d_%d"%[int(end),roundi(radius*100)],FAN+Vector3(0,0,end*0.239),radius,0.0045,dark_metal,simple)
		for spoke: int in range(12):
			var angle: float = spoke*TAU/12.0
			Surface.tube(parent,"GuardSpoke%d_%d"%[int(end),spoke],func(u: float) -> Vector3: return FAN+Vector3(sin(angle),cos(angle),0)*lerpf(0.07,0.565,u)+Vector3(0,0,end*0.239),0.0045,1,dark_metal,simple)
	var fan := Node3D.new()
	fan.name = "FanRotor"
	fan.position = FAN
	parent.add_child(fan)
	for blade: int in range(6):
		var angle: float = blade*TAU/6.0
		var blade_point: Callable = func(u: float,v: float,face: float) -> Vector3:
			var radius: float = lerpf(0.09,0.521,u)
			var width: float = 0.12*(0.64+0.36*sin(PI*u))*pow(maxf(0.0,1.0-u*u),0.22)
			var sweep: float = 0.12*u*u
			var chord: float = (v-0.5)*width
			var twist: float = lerpf(0.82,0.23,u)
			return Vector3(chord*cos(twist)+sweep,radius,chord*sin(twist)+face*0.009*sin(PI*v)*sqrt(maxf(0.0,1.0-u*u))).rotated(Vector3.BACK,angle)
		for face: float in [-1.0,1.0]:
			Surface.surface(fan,"Airfoil%d_%d"%[blade,int(face)],10 if simple else 20,4 if simple else 8,
				func(u: float,v: float) -> Vector3: return blade_point.call(u,v,face),
				func(_u: float,_v: float) -> Vector3: return Vector3(0,0,face),dark_metal,simple)
	var spinner: Array[Vector2] = [Vector2(0.0,-0.155),Vector2(0.055,-0.145),Vector2(0.103,-0.095),Vector2(0.115,0.01),Vector2(0.10,0.08),Vector2(0.0,0.08)]
	Surface.surface(fan,"PropellerSpinner",32 if simple else 64,12 if simple else 24,
		func(u: float,v: float) -> Vector3:
			var p: Vector2 = Surface.profile(spinner,v)
			return Vector3(sin(u*TAU)*p.x,cos(u*TAU)*p.x,p.y),
		func(u: float,v: float) -> Vector3:
			var tangent: Vector2 = Surface.profile(spinner,v+0.0001)-Surface.profile(spinner,v-0.0001)
			return Vector3(sin(u*TAU)*tangent.y,cos(u*TAU)*tangent.y,-tangent.x),metal,simple)
	for side: float in [-1.0,1.0]:
		var rudder := Node3D.new()
		rudder.name = "RudderLeft" if side < 0.0 else "RudderRight"
		rudder.position = FAN+Vector3(side*0.30,0,0.337)
		parent.add_child(rudder)
		Surface.surface(rudder,"SteeringFoil%d"%int(side),16 if simple else 32,8 if simple else 16,
			func(u: float,v: float) -> Vector3:
				var z: float = (0.5+0.5*cos(u*TAU))*0.29-0.075
				var end: float = absf(v*2.0-1.0)
				var cap: float = sqrt(maxf(0.0,1.0-pow(maxf(0.0,(end-0.875)/0.125),2.0)))
				return Vector3(sin(u*TAU)*0.025*pow(maxf(0.001,1.0-(z+0.075)/0.29),0.35)*cap,lerpf(-0.46,0.46,v),(z-0.07)*cap+0.07),
			func(u: float,v: float) -> Vector3: return Vector3(sin(u*TAU),(v*2.0-1.0)*0.3,cos(u*TAU)),paint,simple)
		for y: float in [-0.44,0.44]:
			Surface.rounded_box(rudder,"VaneHinge%d_%d"%[int(side),roundi(y*100)],Vector3(0.07,0.045,0.095),Vector3(0,y,-0.044),0.012,metal,simple)
		Surface.tube(parent,"SteeringLink%d"%int(side),func(u: float) -> Vector3: return FAN+Vector3(side*lerpf(0.30,0.56,u),-0.34,0.315),0.008,1,dark_metal,simple)

static func _lamp(parent: Node3D,side: float,material: Material,simple: bool,frame: bool) -> void:
	var position := Vector3(side*0.59,0.79,_rim_z(0.59,0.95,true)+0.013)
	var yaw: float = -side*0.47
	var lens_offset: Vector3 = Vector3(0,0,-0.038).rotated(Vector3.UP,yaw)
	var node: MeshInstance3D = Surface.rounded_box(parent,("HeadlampBezel" if frame else "HeadlampLens")+str(int(side)),Vector3(0.285,0.092,0.075) if frame else Vector3(0.226,0.042,0.016),position if frame else position+lens_offset,0.025 if frame else 0.007,material,simple)
	node.rotation.y = yaw

static func _rim_z(x: float,scale: float,front: bool) -> float:
	var a: float = 0.0
	var b: float = PI*0.5
	for iteration: int in range(24):
		var angle: float = (a+b)*0.5
		var p: Vector3 = _outline(PI-angle if front else angle,scale)
		if p.x < x: a = angle
		else: b = angle
	return _outline(PI-(a+b)*0.5 if front else (a+b)*0.5,scale).z

static func _lights(parent: Node3D,brake: Material,seam: Material,detail: Material,simple: bool) -> void:
	var white: StandardMaterial3D = CompactFinish.rubber(Color("d5dfd7"))
	white.emission_enabled = true
	white.emission = Color("a9c1bf")
	white.emission_energy_multiplier = 0.2
	for side: float in [-1.0,1.0]:
		_lamp(parent,side,seam,simple,true)
		_lamp(parent,side,white,simple,false)
		var tail := Vector3(side*0.69,0.75,_rim_z(0.69,0.968,false)-0.010)
		var bezel: MeshInstance3D = Surface.rounded_box(parent,"TailLampBezel%d"%int(side),Vector3(0.24,0.080,0.065),tail,0.022,seam,simple)
		bezel.rotation.y = side*0.44
		var lens: MeshInstance3D = Surface.rounded_box(parent,"TailLampLens%d"%int(side),Vector3(0.18,0.039,0.018),tail+Vector3(0,0,0.034).rotated(Vector3.UP,side*0.44),0.007,brake,simple)
		lens.rotation.y = side*0.44
		Surface.rounded_box(parent,"AftTieDown%d"%int(side),Vector3(0.09,0.023,0.075),Vector3(side*0.81,0.81,1.40),0.009,detail,simple)

static func night_lens(parent: Node3D,material: Material) -> void:
	for side: float in [-1.0,1.0]: _lamp(parent,side,material,false,false)
