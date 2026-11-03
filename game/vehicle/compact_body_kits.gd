class_name CompactBodyKits
extends RefCounted
## Nine purposeful packages: road mouldings, air dams, homologation arches,
## mounted rally flaps and a complete splitter / diffuser assembly.
const PROFILES: Dictionary = {
	"street":{"flare":0.035,"bottom":0.312,"depth":0.050},
	"rally":{"flare":0.035,"bottom":0.325,"depth":0.032,"arch":0.046,"flaps":true},
	"club":{"flare":0.070,"bottom":0.265,"depth":0.115,"arch":0.062,"tray":true},
	"heritage":{"flare":0.018,"bottom":0.335,"depth":0.022,"arch":0.024},
	"touring":{"flare":0.045,"bottom":0.285,"depth":0.067,"tray":true},
	"wide":{"flare":0.105,"bottom":0.292,"depth":0.100,"arch":0.105},
	"endurance":{"flare":0.080,"bottom":0.270,"depth":0.135,"arch":0.082,"tray":true},
	"gravel":{"flare":0.055,"bottom":0.345,"depth":0.045,"arch":0.070,"flaps":true},
	"urban":{"flare":0.055,"bottom":0.290,"depth":0.075,"tray":true}}

static func build(root: Node3D, kind: String, paint: Material, trim: Material, metal: Material) -> void:
	var profile: Dictionary = PROFILES[kind]
	var offroad: bool = profile.get("flaps",false)
	var outer: Material = trim if offroad else paint
	var key: String = "body6/"+kind+"/"
	var low: float = profile.bottom
	for side: float in [-1,1]:
		# The upper return is embedded in the original sill. Broad planar facets
		# replace round rails; the ends taper into the wheel-opening shoulders.
		var section: Array[Vector2] = [Vector2(-0.008,0.438),Vector2(0.012,0.438),Vector2(profile.flare,0.365),Vector2(profile.flare*0.87,low),Vector2(-0.010,low+0.018)]
		CompactKitSurface.solid(root,key+"sill"+str(side),func(u: float,v: float) -> Vector3:
			var z: float = lerpf(-0.82,0.82,u)
			var q: Vector2 = CompactKitSurface.contour(section,v,0.006)
			var taper: float = 0.40+0.60*smoothstep(0,0.14,u)*(1-smoothstep(0.86,1,u))
			# Distinct rocker profiles: kicked rear shoulders, straight classic trim,
			# and a wider competition sill all blend into the stock wheel openings.
			var shape: float = _sill_shape(kind,u)
			return Vector3(side*(CompactCoachwork.body_width(q.y,z)+q.x*taper*shape),q.y,z),outer,32,20)
		if profile.get("tray",false):
			var ledge: Array[Vector2] = [Vector2(-0.005,low+0.021),Vector2(profile.flare+0.022,low+0.014),Vector2(profile.flare+0.022,low+0.002),Vector2(-0.008,low+0.008)]
			CompactKitSurface.solid(root,key+"sillblade"+str(side),func(u: float,v: float) -> Vector3:
				var z: float = lerpf(-0.81,0.81,u)
				var q: Vector2 = CompactKitSurface.contour(ledge,v,0.003)
				return Vector3(side*(CompactCoachwork.body_width(q.y,z)+q.x*(0.5+0.5*sin(u*PI))),q.y,z),trim,24,16)
		if profile.has("arch"):
			for axle: float in [-1.28,1.28]: _arch(root,key,kind,side,axle,float(profile.arch),outer,metal)
		if offroad:
			for axle: float in [-1.28,1.28]: _flap(root,key,side,axle,kind=="gravel",trim,metal)
	for rear: bool in [false,true]:
		var depth: float = profile.depth*(0.72 if rear else 1.0)
		var top: float = 0.374 if rear else 0.466
		# The hidden return reaches the original bumper / sheet. Rear paint ends
		# below the plate pocket, while the front top overlaps its rounded bumper.
		var section: Array[Vector2] = [Vector2(-0.065,top),Vector2(0.010,top),Vector2(depth*0.52,lerpf(top,low,0.38)),Vector2(depth,low+0.017),Vector2(depth*0.82,low),Vector2(-0.095,low+0.021)]
		var apron_material: Material = trim if rear and kind in ["club","endurance"] else outer
		CompactKitSurface.solid(root,key+"valance"+str(rear),func(u: float,v: float) -> Vector3:
			var p: Vector2 = CompactCoachwork._bumper_path(rear,u)
			var tangent: Vector2 = (CompactCoachwork._bumper_path(rear,minf(1,u+0.0002))-CompactCoachwork._bumper_path(rear,maxf(0,u-0.0002))).normalized()
			var q: Vector2 = CompactKitSurface.contour(section,v,0.006)
			var outward: float = q.x
			if q.x > 0.0:
				outward *= _bumper_shape(kind,rear,u)
			p += Vector2(-tangent.y,tangent.x)*outward
			return Vector3(p.x,q.y,p.y),apron_material,64,24)
	if profile.get("tray",false): _aero_floor(root,key,kind,low,float(profile.depth),trim)

# Profiles use continuous curves so the ends and returns stay attached.
static func _sill_shape(kind: String, u: float) -> float:
	match kind:
		"rally": return 0.75 + 0.40*u
		"club": return 0.85 + 0.35*sin(PI*u)
		"heritage": return 0.8
		"touring": return 0.8 + 0.25*u
		"wide": return 1.0 + 0.35*pow(sin(PI*u),2)
		"endurance": return 1.15 + 0.25*u
		"gravel": return 1.15 - 0.30*sin(PI*u)
		"urban": return 0.75 + 0.50*u
	return 1.0

static func _bumper_shape(kind: String, rear: bool, u: float) -> float:
	var center: float = pow(maxf(0.0,1.0-absf(2.0*u-1.0)),2.0)
	var shoulders: float = pow(sin(2.0*PI*u),2.0)
	match kind:
		"street": return 0.85 + 0.25*center
		"rally": return 0.8 + 0.45*shoulders
		"club": return 1.0 + 0.35*center
		"heritage": return 0.85
		"touring": return 0.9 + 0.25*center
		"wide": return 0.9 + 0.55*shoulders
		"endurance": return 1.0 + (0.35 if rear else 0.55)*center
		"gravel": return 0.9 + 0.45*center
		"urban": return 0.9 + 0.40*shoulders
	return 1.0

# Raise the outer shoulders towards a squared homologation flare while leaving
# the inner wheel opening untouched. The return follows this same radius.
static func _arch_radius(kind: String, angle: float, radius: float) -> float:
	var shoulder: float = pow(absf(sin(2.0*angle)),2.0)
	var amount: float = {"rally":0.034,"club":0.025,"wide":0.065,"endurance":0.045,"gravel":0.022}.get(kind,0.0)
	return radius + amount*shoulder*clampf((radius-0.460)/0.032,0.0,1.0)

static func _arch(root: Node3D, key: String, kind: String, side: float, axle: float, flare: float, material: Material, metal: Material) -> void:
	var outer: float = 0.461 if kind=="heritage" else 0.492
	var section: Array[Vector2] = [Vector2(0.423,0.018),Vector2(0.423,0.024),Vector2(0.441,flare),Vector2(outer,0.017),Vector2(outer,0.009),Vector2(0.440,flare-0.007)]
	CompactKitSurface.solid(root,key+"arch%s/%s"%[side,axle],func(u: float,v: float) -> Vector3:
		var angle: float = lerpf(-0.10,PI+0.10,u)
		var q: Vector2 = CompactKitSurface.contour(section,v,0.0018)
		var radius: float = _arch_radius(kind,angle,q.x)
		var y: float = 0.37+sin(angle)*radius
		var z: float = axle+cos(angle)*radius
		return Vector3(side*(CompactCoachwork.body_width(y,z)+CompactKits.arch_roll(radius,axle)+maxf(0.009,q.y)),y,z),material,40,24)
	# The inner clearance remains unchanged. A matching returned backing
	# fills the space behind the shaped outer flare.
	var embed: float = 0.020 if CompactKits.simple_parts else 0.015
	var mounting_section: Array[Vector2] = [Vector2(0.423,0),Vector2(outer,0),Vector2(outer,1),Vector2(0.440,1),Vector2(0.423,1)]
	CompactKitSurface.solid(root,key+"fendermount%s/%s"%[side,axle],func(u: float,v: float) -> Vector3:
		# The surface UVs are float32; quantise cap samples identically so their
		# endpoint vertices share exact positions with the swept section.
		var parameter := Vector2(u,v)
		var angle: float = lerpf(-0.10,PI+0.10,parameter.x)
		var q: Vector2 = CompactKitSurface.contour(mounting_section,parameter.y,0.0008)
		var radius: float = _arch_radius(kind,angle,q.x)
		var y: float = 0.37+sin(angle)*radius
		var z: float = axle+cos(angle)*radius
		var rear_offset: float = lerpf(0.018,flare-0.007,clampf((q.x-0.423)/0.017,0,1)) if q.x<0.440 else lerpf(flare-0.007,0.009,(q.x-0.440)/(outer-0.440))
		var offset: float = lerpf(-embed,rear_offset+0.005,q.y)
		return Vector3(side*(CompactCoachwork.body_width(y,z)+CompactKits.arch_roll(radius,axle)+offset),y,z),material,40 if CompactKits.simple_parts else 20,20)
	if kind in ["rally","gravel","wide"]:
		for index: int in range(7):
			var angle: float = lerpf(0.10,PI-0.10,index/6.0)
			var radius: float = 0.474
			var shaped_radius: float = _arch_radius(kind,angle,radius)
			var y: float = 0.37+sin(angle)*shaped_radius
			var z: float = axle+cos(angle)*shaped_radius
			var offset: float = lerpf(flare,0.017,(radius-0.441)/(outer-0.441))
			var bolt := CompactKits._cylinder(root,0.005,0.003,Vector3(side*(CompactCoachwork.body_width(y,z)+CompactKits.arch_roll(shaped_radius,axle)+offset+0.0015),y,z),metal,8)
			bolt.rotation.z = PI*0.5

static func _flap(root: Node3D, key: String, side: float, axle: float, gravel: bool, trim: Material, metal: Material) -> void:
	var z: float = axle+0.415
	var width: float = 0.255 if gravel else 0.230
	var sections: Array = [
		["flap",[Vector2(0.150,-0.0065),Vector2(0.370,-0.0065),Vector2(0.370,0.0065),Vector2(0.150,0.0065)],trim],
		["flapbracket",[Vector2(0.3525,0.0015),Vector2(0.3735,0.0015),Vector2(0.3735,0.0145),Vector2(0.3525,0.0145)],metal]]
	for section: Array in sections:
		var polygon: Array[Vector2] = []
		polygon.assign(section[1])
		CompactKitSurface.solid(root,key+str(section[0])+"%s/%s"%[side,axle],func(u: float,v: float) -> Vector3:
			var q: Vector2 = CompactKitSurface.contour(polygon,v,0.002)
			return Vector3(side*0.842+(u-0.5)*width,q.x,z+q.y),section[2],8,16)
	for offset: float in [-0.080,0.080]:
		var bolt := CompactKits._cylinder(root,0.005,0.004,Vector3(side*0.842+offset,0.363,z+0.017),metal,8)
		bolt.rotation.x = PI*0.5

static func _aero_floor(root: Node3D, key: String, kind: String, low: float, depth: float, trim: Material) -> void:
	# A complete nose deck attaches behind the valance and follows its bowed path.
	var section: Array[Vector2] = [Vector2(-0.075,low+0.010),Vector2(depth+0.015,low+0.010),Vector2(depth+0.015,low-0.005),Vector2(-0.075,low-0.005)]
	CompactKitSurface.solid(root,key+"splitterdeck",func(u: float,v: float) -> Vector3:
		var p: Vector2 = CompactCoachwork._bumper_path(false,u)
		var tangent: Vector2 = (CompactCoachwork._bumper_path(false,minf(1,u+0.0002))-CompactCoachwork._bumper_path(false,maxf(0,u-0.0002))).normalized()
		var q: Vector2 = CompactKitSurface.contour(section,v,0.003)
		p += Vector2(-tangent.y,tangent.x)*q.x
		return Vector3(p.x,q.y,p.y),trim,64,16)
	# Rising diffuser is a real undertray. Strakes intersect it throughout their run.
	var tray_section: Array[Vector2] = [Vector2(low-0.002,1.74),Vector2(low+0.058,2.16),Vector2(low+0.067,2.16),Vector2(low+0.007,1.74)]
	CompactKitSurface.solid(root,key+"diffusertray",func(u: float,v: float) -> Vector3:
		var q: Vector2 = CompactKitSurface.contour(tray_section,v,0.0015)
		return Vector3(lerpf(-0.71,0.71,u),q.x,q.y),trim,24,16)
	var count: int = 5 if kind=="endurance" else 3
	for fin: int in range(count):
		var x: float = (fin-(count-1)*0.5)*(0.24 if count==5 else 0.38)
		var outline: Array[Vector2] = [Vector2(low+0.009,1.78),Vector2(low+0.077,2.16),Vector2(low-0.044,2.16),Vector2(low-0.025,1.78)]
		CompactAero._plate(root,key+"strake"+str(fin),Vector3(x,0,0),outline,0.009,trim)
	if kind in ["club","endurance"]:
		for side: float in [-1,1]:
			var p: Vector2 = CompactCoachwork._bumper_path(false,0.17 if side>0 else 0.83)
			var outline: Array[Vector2] = [Vector2(low+0.004,p.y+0.050),Vector2(low+0.055,p.y),Vector2(low+0.042,p.y-depth*0.6),Vector2(low+0.004,p.y-depth*0.6)]
			CompactAero._plate(root,key+"splitterfence"+str(side),Vector3(p.x,0,0),outline,0.008,trim)
