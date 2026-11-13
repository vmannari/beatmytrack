extends RefCounted
## Low, single-seat racing hull. Model metres, nose -Z.
const Surface = preload("res://vehicle/hovercraft_sport_surface.gd")
const LENGTH: float = 2.10
const HALF_BEAM: float = 1.10

static func outline(angle: float,scale: float = 1.0,height: float = 0.0) -> Vector3:
	var s: float = sin(angle)
	var c: float = cos(angle)
	var z: float = signf(c)*pow(absf(c),0.82)*LENGTH
	var taper: float = 0.83+0.17*tanh(z*0.95)
	return Vector3(signf(s)*pow(absf(s),0.72)*HALF_BEAM*taper*scale,height,z*scale)

static func half_width(z: float,scale: float = 0.91) -> float:
	var nz: float = clampf(absf(z)/(LENGTH*scale),0.0,1.0)
	var c: float = pow(nz,1.0/0.82)
	return HALF_BEAM*scale*pow(sqrt(maxf(0.0,1.0-c*c)),0.72)*(0.83+0.17*tanh(z/scale*0.95))

static func deck_y(x: float,z: float) -> float:
	var scale: float = 0.91
	var beam: float = HALF_BEAM*scale*(0.83+0.17*tanh(z/scale*0.95))
	var radial: float = pow(absf(x)/beam,2.0/0.72)+pow(absf(z)/(LENGTH*scale),2.0/0.82)
	var inside: float = maxf(0.0,1.0-radial)
	var recess: float = 0.0
	for center: float in [-0.52,0.52]:
		recess += 0.10*exp(-pow((x-center)/0.38,4.0)-pow((z-1.25)/0.42,4.0))
	return 0.75+0.08*inside-recess*smoothstep(0.0,0.25,inside)

static func outward(u: float,_v: float) -> Vector3:
	return outline(u*TAU).normalized()

static func build(parent: Node3D,paint: Material,accent: Material,detail: Material,rubber: Material,seam: Material,glass: Material,brake: Material,simple: bool) -> void:
	_skirt(parent,rubber,seam,simple)
	_body(parent,paint,accent,seam,simple)
	_cockpit(parent,paint,accent,seam,glass,simple)
	_fittings(parent,paint,detail,seam,brake,simple)

static func _skirt(parent: Node3D,rubber: Material,seam: Material,simple: bool) -> void:
	# Inflated pressure bag with molded transverse finger divisions.
	var profile: Array[Vector2] = [Vector2(0.86,0.13),Vector2(0.95,0.15),Vector2(0.99,0.22),Vector2(1.0,0.32),Vector2(0.98,0.41),Vector2(0.91,0.47)]
	Surface.surface(parent,"SportPressureSkirt",192 if simple else 384,10 if simple else 20,
		func(u: float,v: float) -> Vector3:
			var p: Vector2 = Surface.monotone_profile(profile,v)
			var groove: float = pow(0.5+0.5*cos(u*TAU*48.0),8.0)
			var depth: float = 0.012*groove*pow(maxf(0.0,sin(PI*v)),0.5)
			return outline(u*TAU,p.x-depth,p.y),outward,rubber,simple)
	Surface.surface(parent,"SportUnderside",48 if simple else 96,3,
		func(u: float,v: float) -> Vector3: return outline(u*TAU,0.86*v,0.13+0.015*(1.0-v)),
		func(_u: float,_v: float) -> Vector3: return Vector3.DOWN,seam,simple)
	# Narrow stitched divisions are integrated into the bag, not dangling pads.
	for index: int in range(48):
		var angle: float = TAU*index/48.0
		Surface.tube(parent,"SportSkirtSeam%02d"%index,
			func(u: float) -> Vector3:
				var p: Vector2 = Surface.monotone_profile(profile,lerpf(0.18,0.84,u))
				return outline(angle,p.x-0.008,p.y),0.002,4 if simple else 8,seam,simple)

static func _body(parent: Node3D,paint: Material,accent: Material,seam: Material,simple: bool) -> void:
	var profile: Array[Vector2] = [Vector2(0.90,0.405),Vector2(0.98,0.44),Vector2(0.995,0.50),Vector2(0.99,0.59),Vector2(0.97,0.66),Vector2(0.93,0.745),Vector2(0.91,0.75)]
	Surface.surface(parent,"SportFormedHull",64 if simple else 128,9 if simple else 18,
		func(u: float,v: float) -> Vector3:
			var p: Vector2 = Surface.monotone_profile(profile,v)
			return outline(u*TAU,p.x,p.y),outward,paint,simple)
	Surface.surface(parent,"SportCrownedDeck",64 if simple else 128,6 if simple else 12,
		func(u: float,v: float) -> Vector3:
			var p: Vector3 = outline(u*TAU,0.91*v)
			p.y = deck_y(p.x,p.z)
			return p,
		func(_u: float,_v: float) -> Vector3: return Vector3.UP,paint,simple)
	Surface.tube(parent,"SportRubRail",func(u: float) -> Vector3: return outline(u*TAU,0.983,0.615),0.008,64 if simple else 128,seam,simple)
	for side: float in [-1.0,1.0]:
		# Sculpted swept shoulders add a racing plan view and blend into the deck.
		Surface.surface(parent,"SportShoulder%d"%int(side),8 if simple else 14,24 if simple else 48,
			func(u: float,v: float) -> Vector3: return _shoulder(side,u,v),
			func(_u: float,_v: float) -> Vector3: return Vector3.UP,paint,simple)
		Surface.surface(parent,"SportShoulderAccent%d"%int(side),2 if simple else 4,24 if simple else 48,
			func(u: float,v: float) -> Vector3: return _shoulder(side,lerpf(0.50,0.64,u),lerpf(0.08,0.91,v))+Vector3(0,0.002,0),
			func(_u: float,_v: float) -> Vector3: return Vector3.UP,accent,simple)
		# Slim intake slots read as a purposeful engine detail at showroom scale.
		for slot: int in range(3):
			var z: float = -0.88+slot*0.12
			var x: float = side*half_width(z)*0.66
			Surface.rounded_box(parent,"SportVent%d_%d"%[int(side),slot],Vector3(0.12,0.01,0.035),Vector3(x,deck_y(x,z)+0.012,z),0.004,seam,simple)

static func _shoulder(side: float,u: float,v: float) -> Vector3:
	var z: float = lerpf(-1.73,1.69,v)
	var x: float = side*half_width(z)*lerpf(0.68,0.97,u)
	var lift: float = 0.08*pow(maxf(0.0,sin(PI*u)),2.0)*pow(maxf(0.0,sin(PI*v)),0.7)
	return Vector3(x,deck_y(x,z)+lift+0.001,z)

static func canopy_point(t: float,across: float) -> Vector3:
	var v: float = clampf(t,0.0,1.0)
	var z: float = lerpf(-1.18,0.76,v)
	var volume: float = pow(maxf(0.0,sin(PI*v)),0.72)
	var width: float = 0.50*volume*(1.10-0.25*v)
	var angle: float = across*PI*0.5
	var x: float = width*sin(angle)
	var height: float = 0.40*pow(volume,0.85)*maxf(0.0,cos(angle))
	return Vector3(x,deck_y(x,z)+height,z)

static func _cockpit(parent: Node3D,paint: Material,accent: Material,seam: Material,glass: Material,simple: bool) -> void:
	var frame := CompactFinish.alloy(Color("414f54"))
	frame.roughness = 0.56
	frame.metallic = 0.38
	# Painted base and fitted dark gasket wrap a single low, raked canopy.
	Surface.surface(parent,"SportCockpitBase",16 if simple else 32,20 if simple else 40,
		func(u: float,v: float) -> Vector3: return canopy_point(v,u*2.0-1.0),
		func(u: float,_v: float) -> Vector3: return Vector3(u*2.0-1.0,0.8,0),paint,simple)
	for layer: int in range(2):
		Surface.surface(parent,"SportCanopy%d"%layer,16 if simple else 32,20 if simple else 40,
			func(u: float,v: float) -> Vector3:
				var across: float = lerpf(-0.93+layer*0.018,0.93-layer*0.018,u)
				return canopy_point(v,across)+Vector3(0,0.003+layer*0.002,0),
			func(u: float,_v: float) -> Vector3: return Vector3(u*2.0-1.0,0.8,0),seam if layer == 0 else glass,simple)
	# A restrained painted spine gives roof stickers a physical, top-facing panel.
	Surface.surface(parent,"SportCanopySpine",8 if simple else 16,12 if simple else 24,
		func(u: float,v: float) -> Vector3:
			var width: float = 0.28*pow(maxf(0.0,sin(PI*v)),0.65)
			return canopy_point(lerpf(0.46,0.93,v),lerpf(-width,width,u))+Vector3(0,0.008,0),
		func(_u: float,_v: float) -> Vector3: return Vector3.UP,accent,simple)
	Surface.tube(parent,"SportCanopyFrame",func(u: float) -> Vector3:
		return canopy_point(lerpf(0.04,0.96,u),-0.94)+Vector3(0,0.006,0),0.005,20 if simple else 40,frame,simple)
	Surface.tube(parent,"SportCanopyFrameRight",func(u: float) -> Vector3:
		return canopy_point(lerpf(0.04,0.96,u),0.94)+Vector3(0,0.006,0),0.005,20 if simple else 40,frame,simple)

static func _headlamp_curve(side: float,u: float) -> Vector3:
	var z: float = lerpf(-1.92,-1.41,u)
	return Vector3(side*(half_width(z,0.97)-0.012),0.675+0.035*u,z)

static func _headlamps(parent: Node3D,material: Material,simple: bool,bezel: bool,night: bool = false) -> void:
	for side: float in [-1.0,1.0]:
		var lamp: MeshInstance3D = Surface.tube(parent,("SportLampRecess" if bezel else "SportLampLens")+str(int(side)),
			func(u: float) -> Vector3:
				var p: Vector3 = _headlamp_curve(side,u)
				if not bezel: p += Vector3(p.x,0,p.z).normalized()*0.018
				return p,0.020 if bezel else 0.010,12 if simple else 24,material,simple)
		if not bezel: lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if night:
			var center: Vector3 = _headlamp_curve(side,0.5)
			lamp.position = Vector3(center.x,0,center.z).normalized()*0.003

static func night_lens(parent: Node3D,material: Material) -> void:
	_headlamps(parent,material,false,false,true)

static func _fittings(parent: Node3D,paint: Material,detail: Material,seam: Material,brake: Material,simple: bool) -> void:
	var white: StandardMaterial3D = CompactFinish.rubber(Color("cbd9d6"))
	white.emission_enabled = true
	white.emission = Color("b6cac7")
	white.emission_energy_multiplier = 0.3
	_headlamps(parent,seam,simple,true)
	_headlamps(parent,white,simple,false)
	# A single rear light signature follows the trailing rim.
	var tail: Callable = func(u: float) -> Vector3: return outline(lerpf(-0.70,0.70,u),0.978,0.655)
	Surface.tube(parent,"SportTailRecess",tail,0.019,24 if simple else 48,seam,simple)
	Surface.tube(parent,"SportTailLight",func(u: float) -> Vector3:
		var p: Vector3 = tail.call(u)
		return p+Vector3(p.x,0,p.z).normalized()*0.017,0.010,24 if simple else 48,brake,simple)
	for side: float in [-1.0,1.0]:
		var z: float = -1.28
		var x: float = side*half_width(z)*0.55
		Surface.rounded_box(parent,"SportTowMount%d"%int(side),Vector3(0.09,0.012,0.04),Vector3(x,deck_y(x,z)+0.007,z),0.005,detail,simple)
