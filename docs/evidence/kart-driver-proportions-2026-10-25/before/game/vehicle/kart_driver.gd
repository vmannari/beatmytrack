extends RefCounted
## Original seated driver and thin open bucket. Immutable presentation geometry.
const G = preload("res://vehicle/kart_geometry.gd")

static func seat_point(u: float, v: float) -> Vector3:
	# Centreline runs from the front lip, under the hips, then up the back.
	var stations: Array[Vector4] = [Vector4(0.253,-0.065,0.215,0.045),Vector4(0.248,0.11,0.230,0.060),Vector4(0.260,0.30,0.231,0.060),Vector4(0.385,0.385,0.223,0.025),Vector4(0.535,0.416,0.220,0.005),Vector4(0.625,0.419,0.210,0.0)]
	var p: Vector4 = G.curve(stations,v)
	var side: float = pow(absf(u),3)
	return Vector3(u*p.z,p.x+p.w*side,p.y-0.105*side*smoothstep(0.3,0.7,v))

static func seat_normal(u: float, v: float) -> Vector3:
	var across: Vector3 = seat_point(minf(1,u+0.001),v)-seat_point(maxf(-1,u-0.001),v)
	var along: Vector3 = seat_point(u,minf(1,v+0.001))-seat_point(u,maxf(0,v-0.001))
	return along.cross(across).normalized()

static func _seat(parent: Node3D, trim: Material, padding: Material, simple: bool) -> void:
	G.attach(parent,"MouldedSeatBucketOpenV2"+("|simple" if simple else "|full"),trim,func() -> ArrayMesh:
		var tool := SurfaceTool.new()
		var columns: int = 12 if simple else 24
		var rows: int = 16 if simple else 32
		for inner: bool in [true,false]:
			tool.append_from(G.surface(columns,rows,func(u: float,v: float) -> Vector3:
				var x: float = lerpf(-1,1,u)
				return seat_point(x,v)-seat_normal(x,v)*(0 if inner else 0.012),func(u: float,v: float) -> Vector3:
				return seat_normal(lerpf(-1,1,u),v)*(1 if inner else -1)),0,Transform3D.IDENTITY)
		# Rolled returns close the material thickness around the entire open rim.
		for edge: int in range(4):
			tool.append_from(G.surface(columns if edge < 2 else rows,1,func(u: float,v: float) -> Vector3:
				var x: float = lerpf(-1,1,u) if edge < 2 else (-1.0 if edge == 2 else 1.0)
				var t: float = float(edge) if edge < 2 else u
				return seat_point(x,t)-seat_normal(x,t)*v*0.012,func(u: float,_v: float) -> Vector3:
				if edge >= 2: return Vector3.LEFT if edge == 2 else Vector3.RIGHT
				return Vector3.FORWARD if edge == 0 else Vector3.UP),0,Transform3D.IDENTITY)
		return tool.commit())
	G.patch(parent,"SeatPanPaddingV2",20,16,func(u: float,v: float) -> Vector3:
		var x: float = lerpf(-0.87,0.87,u)
		var t: float = lerpf(0.04,0.37,v)
		return seat_point(x,t)+seat_normal(x,t)*0.003,func(u: float,v: float) -> Vector3: return seat_normal(lerpf(-0.87,0.87,u),lerpf(0.04,0.37,v)),padding,simple)
	G.patch(parent,"SeatBackPaddingV2",20,20,func(u: float,v: float) -> Vector3:
		var x: float = lerpf(-0.87,0.87,u)
		var t: float = lerpf(0.60,0.96,v)
		return seat_point(x,t)+seat_normal(x,t)*0.003,func(u: float,v: float) -> Vector3: return seat_normal(lerpf(-0.87,0.87,u),lerpf(0.60,0.96,v)),padding,simple)

static func torso_point(angle: float, v: float) -> Vector3:
	# Hips, waist, ribcage, shoulders and neck form one tailored silhouette.
	var stations: Array[Vector4] = [Vector4(0.290,0.10,0.215,0.065),Vector4(0.345,0.177,0.225,0.115),Vector4(0.430,0.158,0.263,0.113),Vector4(0.540,0.171,0.272,0.125),Vector4(0.635,0.195,0.275,0.120),Vector4(0.680,0.166,0.263,0.105),Vector4(0.727,0.083,0.255,0.072)]
	var p: Vector4 = G.curve(stations,v)
	var x: float = signf(sin(angle))*pow(absf(sin(angle)),0.88)*p.y
	var z: float = signf(cos(angle))*pow(absf(cos(angle)),0.88)*p.w
	return Vector3(x,p.x,p.z-z)

static func arm_path(side: float) -> Array[Vector3]:
	return [Vector3(side*0.172,0.645,0.265),Vector3(side*0.238,0.565,0.135),Vector3(side*0.264,0.487,-0.012),Vector3(side*0.216,0.509,-0.16),Vector3(side*0.153,0.551,-0.306)]

static func sleeve_point(side: float, angle: float, v: float) -> Vector3:
	var path: Array[Vector3] = arm_path(side)
	var center: Vector3 = G.curve(path,v)
	var tangent: Vector3 = (G.curve(path,minf(1,v+0.0001))-G.curve(path,maxf(0,v-0.0001))).normalized()
	var across: Vector3 = tangent.cross(Vector3.UP).normalized()
	var radial: Vector3 = across*cos(angle)+tangent.cross(across)*sin(angle)
	var radius: float = lerpf(0.066,0.043,v)+0.004*exp(-pow((v-0.52)/0.13,2))
	return center+radial*radius

static func build(parent: Node3D, trim: Material, simple: bool) -> void:
	var suit := CompactFinish.rubber(Color("283d4b"))
	suit.roughness = 0.92
	var seams := CompactFinish.rubber(Color("b8b3a0"))
	var dark := CompactFinish.rubber(Color("10191d"))
	var padding := CompactFinish.rubber(Color("30383b"))
	_seat(parent,trim,padding,simple)
	G.patch(parent,"TailoredRaceSuitV2",32,32,func(u: float,v: float) -> Vector3: return torso_point(u*TAU,v),func(u: float,_v: float) -> Vector3: return Vector3(sin(u*TAU),0,-cos(u*TAU)),suit,simple)
	G.ellipsoid(parent,"Collar",Vector3(0,0.737,0.255),Vector3(0.088,0.026,0.073),dark,simple)
	G.ellipsoid(parent,"BalaclavaNeck",Vector3(0,0.787,0.255),Vector3(0.077,0.082,0.068),dark,simple)
	G.patch(parent,"SuitZipperV2",2,32,func(u: float,v: float) -> Vector3:
		return torso_point(lerpf(-0.012,0.012,u),lerpf(0.28,0.92,v))+Vector3.FORWARD*0.0015,func(_u: float,_v: float) -> Vector3: return Vector3.FORWARD,seams,simple)
	for side: float in [-1.0,1.0]:
		var leg: Array[Vector3] = [Vector3(side*0.108,0.345,0.195),Vector3(side*0.138,0.368,-0.06),Vector3(side*0.151,0.349,-0.29),Vector3(side*0.145,0.282,-0.52),Vector3(side*0.14,0.225,-0.75)]
		var radial := func(u: float,v: float) -> Vector3:
			var tangent: Vector3 = (G.curve(leg,minf(1,v+0.0001))-G.curve(leg,maxf(0,v-0.0001))).normalized()
			var across: Vector3 = tangent.cross(Vector3.UP).normalized()
			return across*cos(u*TAU)+tangent.cross(across)*sin(u*TAU)
		G.patch(parent,"ContinuousTrouserLegV2"+str(side),24,28,func(u: float,v: float) -> Vector3:
			var radius: float = lerpf(0.080,0.046,smoothstep(0.2,1,v))
			return G.curve(leg,v)+radial.call(u,v)*radius,radial,suit,simple)
		var boot: MeshInstance3D = G.rounded(parent,"RaceBoot",Vector3(side*0.14,0.23,-0.79),Vector3(0.125,0.12,0.25),0.044,dark,simple)
		boot.rotation.x = -0.17
		G.rounded(parent,"BootSole",Vector3(side*0.14,0.178,-0.79),Vector3(0.129,0.018,0.25),0.008,trim,simple)
		G.patch(parent,"UpperSleeveContinuousV2"+str(side),24,32,func(u: float,v: float) -> Vector3: return sleeve_point(side,u*TAU,v),func(u: float,v: float) -> Vector3:
			return (sleeve_point(side,u*TAU,v)-G.curve(arm_path(side),v)).normalized(),suit,simple)
		# Trim samples the same continuous cloth surface, including the elbow bend.
		G.patch(parent,"SleevePipingV2"+str(side),4,48,func(u: float,v: float) -> Vector3:
			var t: float = lerpf(0.06,0.94,v)
			var angle: float = (0.0 if side > 0 else PI)+lerpf(-0.040,0.040,u)*smoothstep(0,0.06,v)*smoothstep(0,0.06,1-v)
			var surface: Vector3 = sleeve_point(side,angle,t)
			return surface+(surface-Vector3(G.curve(arm_path(side),t))).normalized()*0.0015,func(_u: float,_v: float) -> Vector3: return Vector3(side,0.35,-0.15).normalized(),seams,simple)
		G.ellipsoid(parent,"RacingGlove",Vector3(side*0.153,0.553,-0.315),Vector3(0.044,0.045,0.046),seams,simple)
		G.ellipsoid(parent,"GloveGrip",Vector3(side*0.147,0.54,-0.339),Vector3(0.034,0.029,0.031),dark,simple)
	preload("res://vehicle/kart_helmet.gd").build(parent,simple)
