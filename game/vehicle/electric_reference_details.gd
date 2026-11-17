extends RefCounted
## Wheels and fitted external details for the reference fastback.
const M = preload("res://vehicle/electric_reference_mesh.gd")
const BODY = preload("res://vehicle/electric_reference_body.gd")
const CABIN = preload("res://vehicle/electric_reference_cabin.gd")
const AXLE := 1.398
const HALF_TRACK := 0.841
const FRONT_HALF_TRACK := 0.791

static func build(car: CarVisual, paint: Material, trim: Material, bright: Material, glass: Material) -> void:
	var graphite := CompactFinish.alloy(Color("5c6265"))
	graphite.metallic = 0.72
	graphite.roughness = 0.30
	var inner := CompactFinish.alloy(Color("252a2d"))
	inner.roughness = 0.52
	for side: float in [-1.0, 1.0]:
		for axle: float in [-AXLE, AXLE]:
			wheel(car, side, axle, trim, graphite, inner, bright)
		mirror(car, side, paint, trim, glass)
		# Flush pulls sit near the trailing edge of each door, as in the
		# side reference. Negative Z is the front of the car.
		for z: float in [BODY.cabin_z(BODY.WINDOW_B_FOOT) - 0.16, 0.86]:
			handle(car, side, z, paint, trim)

static func wheel(car: CarVisual, side: float, axle: float, rubber: Material, graphite: Material, inner: Material, bright: Material) -> void:
	var pivot := Node3D.new()
	pivot.name = ("Front" if axle < 0 else "Rear") + ("Left" if side < 0 else "Right") + "Wheel"
	pivot.position = Vector3(side * (FRONT_HALF_TRACK if axle < 0 else HALF_TRACK), 0.37, axle)
	car.add_child(pivot)
	CompactDetail.tire(pivot, rubber, car.simple_model)
	# Swept, split-faced forged spokes replace the broad flat aero triangles.
	var rim_parent: Node3D = car.new_kit_frame("rims",pivot) if car.editable_kits else pivot
	if str(car.customisation.rims)=="stock":
		stock_rim(car,rim_parent,side,graphite,inner,bright)
	else:
		preload("res://vehicle/electric_kits.gd").rim(car,rim_parent,side)
	if axle < 0:
		car.front_wheels.append(pivot)
	car.register_rolling_wheel(pivot, 0.37)
	# Brake assembly follows steering but stays stationary while the wheel spins.
	var fixed := Node3D.new()
	fixed.name = "BrakeAssembly"
	pivot.add_child(fixed)
	var rotor_material := CompactFinish.alloy(Color("6f7779"))
	rotor_material.roughness = 0.52
	var rotor := VisualGeometry.cylinder(fixed, 0.226, 0.008, Vector3(side * 0.112, 0, 0), rotor_material, true)
	rotor.rotation.z = PI * 0.5
	var caliper_material := CompactFinish.alloy(Color("a78751"))
	M.rounded(fixed, "RefCaliper" + str(side), Vector3(0.024, 0.16, 0.068), Vector3(side * 0.137, 0.01, 0.175), 0.010, caliper_material)
	M.patch(fixed,"SportRotorGroove"+str(side),64,2,func(u: float,v: float)->Vector3:
		var angle: float=TAU*u
		var radius: float=lerpf(0.198,0.201,v)
		return Vector3(side*0.117,radius*sin(angle),radius*cos(angle)),inner,Vector3(side,0,0),car.simple_model)
	if car.simple_model:
		for mesh: MeshInstance3D in fixed.find_children("*", "MeshInstance3D", true, false):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func stock_rim(car: CarVisual, parent: Node3D, side: float, graphite: Material, inner: Material, bright: Material) -> void:
	M.patch(parent, "RefWheelBarrel" + str(side), 64, 6, func(u: float, v: float) -> Vector3:
		var angle: float = TAU * u
		var radius: float = lerpf(0.279, 0.305, v)
		return Vector3(side * 0.142, radius * sin(angle), radius * cos(angle)), inner, Vector3(side, 0, 0), car.simple_model)
	M.patch(parent, "RefWheelRim" + str(side), 64, 4, func(u: float, v: float) -> Vector3:
		var angle: float = TAU * u
		var radius: float = lerpf(0.296, 0.307, v)
		return Vector3(side * (0.145 + 0.003 * sin(PI * v)), radius * sin(angle), radius * cos(angle)), graphite, Vector3(side, 0, 0), car.simple_model)
	for spoke: int in range(5):
		var blade := Node3D.new()
		blade.name = "AeroBlade" + str(spoke)
		blade.rotation.x = TAU * spoke / 5.0
		parent.add_child(blade)
		M.patch(blade, "RefBladeFace" + str(side), 8, 12, func(u: float, v: float) -> Vector3:
			var radius: float = lerpf(0.061, 0.292, v)
			var theta: float = -0.28*v*v+lerpf(-1.0, 1.0, u)*lerpf(0.25,0.15,v)
			return Vector3(side * (0.151 + 0.009 * sin(PI * u)*sin(PI*v)), radius * sin(theta), radius * cos(theta)), graphite, Vector3(side, 0, 0), car.simple_model)
		M.patch(blade, "RefBladeBack" + str(side), 4, 8, func(u: float, v: float) -> Vector3:
			var radius: float = lerpf(0.061, 0.292, v)
			var theta: float = -0.28*v*v+lerpf(-1.0, 1.0, u)*lerpf(0.25,0.15,v)
			return Vector3(side * 0.125, radius * sin(theta), radius * cos(theta)), inner, Vector3(-side, 0, 0), car.simple_model)
		for edge: float in [-1.0, 1.0]:
			M.patch(blade, "RefBladeEdge" + str(side) + str(edge), 12, 2, func(u: float, v: float) -> Vector3:
				var radius: float = lerpf(0.061, 0.292, u)
				var theta: float = -0.28*u*u+edge*lerpf(0.25,0.15,u)
				return Vector3(side * lerpf(0.125, 0.151, v), radius * sin(theta), radius * cos(theta)), inner, Vector3(side, 0, 0), car.simple_model)
		M.patch(blade,"SportSpokeChannel"+str(side),2,12,func(u: float,v: float)->Vector3:
			var t: float=lerpf(0.27,1.0,v)
			var radius: float=lerpf(0.061,0.292,t)
			var theta: float=-0.28*t*t+(2.0*u-1.0)*0.025*smoothstep(0.27,0.5,t)
			return Vector3(side*(0.152+0.009*sin(PI*t)),radius*sin(theta),radius*cos(theta)),inner,Vector3(side,0,0),car.simple_model)
		M.patch(blade,"SportMachinedSpoke"+str(side),2,12,func(u: float,v: float)->Vector3:
			var radius: float=lerpf(0.075,0.292,v)
			var theta: float=-0.28*v*v-lerpf(0.25,0.15,v)+0.025*u
			return Vector3(side*0.153,radius*sin(theta),radius*cos(theta)),bright,Vector3(side,0,0),car.simple_model)
	var cap := VisualGeometry.cylinder(parent, 0.057, 0.013, Vector3(side * 0.151, 0, 0), graphite, true)
	cap.name = "WheelCentre"
	cap.rotation.z = PI * 0.5
	for bolt: int in range(5):
		var angle: float = TAU * bolt / 5.0
		var lug := VisualGeometry.cylinder(parent, 0.006, 0.004, Vector3(side * 0.159, 0.045 * sin(angle), 0.045 * cos(angle)), inner, true)
		lug.rotation.z = PI * 0.5

static func handle(car: CarVisual, side: float, z: float, _paint: Material, trim: Material) -> void:
	# A small, flush body-colour pull inside a fine perimeter seam.
	M.fitted_line(car.body, "RefHandleOutline" + str(side) + str(z), car.body.find_child("ReferenceSide"+str(side).replace(".","_"),false,false), func(t: float) -> Vector3:
		var angle: float = TAU * t
		var c: float = cos(angle)
		var s: float = sin(angle)
		var zz: float = z + 0.080 * signf(c) * pow(absf(c), 0.35)
		var yy: float = BODY.shoulder(z) - 0.082 + 0.016 * signf(s) * pow(absf(s), 0.35)
		return BODY.side_point(side, zz, yy), 40 if car.simple_model else 96, 0.0022, trim, Vector3(side,0,0), car.simple_model)
	M.fitted_line(car.body, "RefHandlePull" + str(side) + str(z), car.body.find_child("ReferenceSide"+str(side).replace(".","_"),false,false), func(t: float) -> Vector3:
		var zz: float = z + lerpf(-0.045, 0.045, t)
		var yy: float = BODY.shoulder(z) - 0.089 - 0.002 * sin(PI * t)
		return BODY.side_point(side, zz, yy), 12 if car.simple_model else 16, 0.0016, trim, Vector3(side,0,0), car.simple_model)

static func mirror(car: CarVisual, side: float, paint: Material, trim: Material, glass: Material) -> void:
	# A low stalk carries a body-coloured aerodynamic shell with a dark lower rim.
	var root: Vector3 = CABIN.side_point(side, 0.19, 0.16)
	var center: Vector3 = root + Vector3(side * 0.145, 0.040, 0.020)
	M.patch(car.body, "RefMirrorStalk" + str(side), 8, 4, func(u: float, v: float) -> Vector3:
		var p: Vector3 = root.lerp(center + Vector3(0, -0.035, 0), u)
		return p + Vector3(0, 0.018 * sin(PI * v), (v - 0.5) * 0.09), trim, Vector3(side, 1, 0), car.simple_model)
	for top: bool in [true, false]:
		var latitude_start: float = 0.0 if top else 0.5
		var latitude_end: float = 0.5 if top else 1.0
		var sample: Callable = func(u: float, v: float) -> Vector3:
			var a: float = TAU * u
			var b: float = PI * lerpf(latitude_start, latitude_end, v)
			return center + Vector3(side * 0.115 * cos(a) * sin(b), 0.047 * cos(b), 0.102 * sin(a) * sin(b))
		var normal: Callable = func(u: float, v: float) -> Vector3:
			var p: Vector3 = sample.call(u, v) - center
			return Vector3(p.x / (0.115 * 0.115), p.y / (0.047 * 0.047), p.z / (0.102 * 0.102)).normalized()
		M.patch(car.body, "RefMirrorShell" + str(side) + str(top), 40, 12, sample, paint if top else trim, Vector3.UP, car.simple_model, Callable(), normal)
	# Glass occupies the rear-facing end of the housing.
	M.patch(car.body, "RefMirrorGlass" + str(side), 16, 8, func(u: float, v: float) -> Vector3:
		var xx: float = (2.0 * u - 1.0) * 0.082
		var yy: float = (2.0 * v - 1.0) * 0.027 * sqrt(maxf(0.0, 1.0 - pow(xx / 0.085, 2)))
		var zz: float = 0.103 * sqrt(maxf(0.0, 1.0 - pow(xx / 0.115, 2) - pow(yy / 0.047, 2))) + 0.001
		return center + Vector3(side * xx, yy, zz), glass, Vector3.BACK, car.simple_model)
