extends RefCounted
## Low twin ducted propulsors for the original fictional sport hovercraft.
## Coordinates are model metres; -Z is the bow and +Z is the stern.
const Surface = preload("res://vehicle/hovercraft_sport_surface.gd")
const Hull = preload("res://vehicle/hovercraft_sport_hull.gd")
const FAN_X: float = 0.52
const FAN_Y: float = 1.03
const FAN_Z: float = 1.25
const DUCT_INNER: float = 0.293

static func build(parent: Node3D, paint: Material, accent: Material, seam: Material, metal: Material, dark_metal: Material, simple: bool) -> void:
	# The transform stays separate from the two independently rotating fan hubs.
	var rotor_group := Node3D.new()
	rotor_group.name = "FanRotor"
	parent.add_child(rotor_group)
	for side: float in [-1.0,1.0]:
		var center := Vector3(side*FAN_X,FAN_Y,FAN_Z)
		_fan_mounts(parent,center,side,metal,simple)
		_duct(parent,center,side,paint,seam,metal,dark_metal,simple)
		_rotor(rotor_group,center,side,metal,dark_metal,simple)
		_rudder(parent,center,side,paint,metal,simple)

static func _fan_mounts(parent: Node3D, center: Vector3, side: float, metal: Material, simple: bool) -> void:
	# Open braced mounts leave the forward intake, blades and guard visible.
	for edge: float in [-1.0,1.0]:
		var foot_x: float = center.x + edge*0.22
		var foot_z: float = 0.64
		var foot := Vector3(foot_x,Hull.deck_y(foot_x,foot_z)+0.015,foot_z)
		var attachment := center+Vector3(edge*0.23,-0.19,-0.23)
		Surface.tube(parent,"SportFanMount%d_%d"%[int(side),int(edge)],
			func(u: float) -> Vector3: return foot.lerp(attachment,u),
			0.017,3 if simple else 6,metal,simple)

static func _duct(parent: Node3D, center: Vector3, side: float, paint: Material, seam: Material, metal: Material, dark_metal: Material, simple: bool) -> void:
	# Rounded composite outer shell and rolled lips; the centerline sits low in the hull.
	var section: Array[Vector2] = [Vector2(0.318,-0.24),Vector2(0.345,-0.19),Vector2(0.352,-0.08),Vector2(0.35,0.10),Vector2(0.34,0.20),Vector2(0.316,0.235),Vector2(0.295,0.21),Vector2(0.293,-0.20),Vector2(0.305,-0.24)]
	Surface.surface(parent,"SportDuct%d"%int(side),32 if simple else 64,10 if simple else 20,
		func(u: float,v: float) -> Vector3:
			var p: Vector2 = Surface.profile(section,v,true)
			return center+Vector3(sin(u*TAU)*p.x,cos(u*TAU)*p.x,p.y),
		func(u: float,v: float) -> Vector3:
			var p: Vector2 = Surface.profile(section,v,true)
			return Vector3(sin(u*TAU)*(p.x-0.32),cos(u*TAU)*(p.x-0.32),p.y*0.2),paint,simple)
	# The inner wall is dark independently of the user-selected paint.
	Surface.surface(parent,"SportDuctLiner%d"%int(side),32 if simple else 64,3 if simple else 6,
		func(u: float,v: float) -> Vector3:
			var radius: float = 0.292-0.001*sin(PI*v)
			return center+Vector3(sin(u*TAU)*radius,cos(u*TAU)*radius,lerpf(-0.20,0.21,v)),
		func(u: float,_v: float) -> Vector3: return Vector3(-sin(u*TAU),-cos(u*TAU),0),dark_metal,simple)
	for end: float in [-1.0,1.0]:
		var z: float = -0.242 if end < 0.0 else 0.238
		Surface.ring(parent,"SportDuctRim%d_%d"%[int(side),int(end)],center+Vector3(0,0,z),0.312,0.006,metal,simple)
		# Radial guards sit well clear of the moving blades.
		var spokes: int = 8
		for spoke: int in range(spokes):
			var angle: float = TAU*(spoke+0.5)/spokes
			Surface.tube(parent,"SportGuard%d_%d_%d"%[int(side),int(end),spoke],
				func(u: float) -> Vector3: return center+Vector3(sin(angle),cos(angle),0)*lerpf(0.05,0.293,u)+Vector3(0,0,z),
				0.004,1,dark_metal,simple)
	for end_z: float in [-0.242,0.238]:
		Surface.ring(parent,"SportGuardRing%d_%d"%[int(side),roundi(end_z*1000)],center+Vector3(0,0,end_z),0.15,0.004,seam,simple)

static func _rotor(parent: Node3D, center: Vector3, side: float, metal: Material, dark_metal: Material, simple: bool) -> void:
	var rotor := Node3D.new()
	rotor.name = "FanRotorLeft" if side < 0.0 else "FanRotorRight"
	rotor.position = center
	parent.add_child(rotor)
	# Opposite sweep and pitch allow visually plausible counter-rotation.
	for blade: int in range(5):
		var angle: float = blade*TAU/5.0
		var point: Callable = func(u: float,v: float,face: float) -> Vector3:
			var radius: float = lerpf(0.062,0.275,u)
			var width: float = 0.084*(0.64+0.36*sin(PI*u))*pow(maxf(0.0,1.0-u*u),0.28)
			var sweep: float = side*0.04*u*u
			var chord: float = (v-0.5)*width
			var twist: float = side*lerpf(0.72,0.22,u)
			var thickness: float = face*0.006*sin(PI*v)*sqrt(maxf(0.0,1.0-u*u))
			return Vector3(chord*cos(twist)+sweep,radius,chord*sin(twist)+thickness).rotated(Vector3.BACK,angle)
		for face: float in [-1.0,1.0]:
			Surface.surface(rotor,"SportBlade%d_%d_%d"%[int(side),blade,int(face)],8 if simple else 14,3 if simple else 5,
				func(u: float,v: float) -> Vector3: return point.call(u,v,face),
				func(_u: float,_v: float) -> Vector3: return Vector3(0,0,face),dark_metal,simple)
	var spinner: Array[Vector2] = [Vector2(0.0,-0.09),Vector2(0.045,-0.085),Vector2(0.071,-0.045),Vector2(0.078,0.025),Vector2(0.063,0.065),Vector2(0.0,0.07)]
	Surface.surface(rotor,"SportSpinner%d"%int(side),24 if simple else 48,6 if simple else 12,
		func(u: float,v: float) -> Vector3:
			var p: Vector2 = Surface.profile(spinner,v)
			return Vector3(sin(u*TAU)*p.x,cos(u*TAU)*p.x,p.y),
		func(u: float,v: float) -> Vector3:
			var tangent: Vector2 = Surface.profile(spinner,v+0.0001)-Surface.profile(spinner,v-0.0001)
			return Vector3(sin(u*TAU)*tangent.y,cos(u*TAU)*tangent.y,-tangent.x),metal,simple)

static func _rudder(parent: Node3D, center: Vector3, side: float, paint: Material, metal: Material, simple: bool) -> void:
	var rudder := Node3D.new()
	rudder.name = "RudderLeft" if side < 0.0 else "RudderRight"
	rudder.position = center+Vector3(0,0,0.42)
	parent.add_child(rudder)
	Surface.surface(rudder,"SportSteeringVane%d"%int(side),12 if simple else 24,6 if simple else 12,
		func(u: float,v: float) -> Vector3:
			var z: float = (0.5+0.5*cos(u*TAU))*0.17-0.06
			var end: float = absf(v*2.0-1.0)
			var cap: float = sqrt(maxf(0.0,1.0-pow(maxf(0.0,(end-0.84)/0.16),2.0)))
			var x: float = sin(u*TAU)*0.017*pow(maxf(0.001,1.0-(z+0.06)/0.17),0.35)
			return Vector3(x*cap,lerpf(-0.20,0.20,v),(z-0.025)*cap+0.025),
		func(u: float,v: float) -> Vector3: return Vector3(sin(u*TAU),(v*2.0-1.0)*0.25,cos(u*TAU)),paint,simple)
	for y: float in [-0.18,0.18]:
		Surface.rounded_box(rudder,"SportVaneHinge%d_%d"%[int(side),roundi(y*100)],Vector3(0.05,0.027,0.06),Vector3(0,y,-0.045),0.008,metal,simple)
		var hinge_y: float = y
		Surface.tube(parent,"SportRudderSupport%d_%d"%[int(side),roundi(y*100)],
			func(u: float) -> Vector3:
				return center+Vector3(side*lerpf(sqrt(0.293*0.293-hinge_y*hinge_y),0.0,u),hinge_y,lerpf(0.238,0.375,u)),
			0.010,2 if simple else 4,metal,simple)
