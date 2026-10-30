extends RefCounted
## Original seated driver and thin open bucket. Immutable presentation geometry.
const G = preload("res://vehicle/kart_geometry.gd")

static func seat_point(u: float, v: float) -> Vector3:
	# Centreline runs from the front lip, under the hips, then up the back.
	var stations: Array[Vector4] = [Vector4(0.253,-0.27,0.215,0.045),Vector4(0.248,-0.12,0.230,0.060),Vector4(0.260,0.06,0.231,0.060),Vector4(0.385,0.18,0.223,0.025),Vector4(0.535,0.356,0.220,0.005),Vector4(0.625,0.419,0.210,0.0)]
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

static func seat_stays(parent: Node3D, metal: Material, simple: bool) -> void:
	for side: float in [-1.0,1.0]:
		var u: float = side*0.78
		var v: float = 0.80
		var normal: Vector3 = -seat_normal(u,v)
		var across: Vector3 = (seat_point(u+0.001,v)-seat_point(u-0.001,v)).normalized()
		var mount: Vector3 = seat_point(u,v)+normal*0.019
		var pad: MeshInstance3D = G.rounded(parent,"SeatMountPad"+str(side),mount,Vector3(0.052,0.050,0.016),0.005,metal,simple)
		pad.basis = Basis(across,normal.cross(across).normalized(),normal)
		var bolt: MeshInstance3D = G.ellipsoid(parent,"SeatMountFastener"+str(side),mount+normal*0.011,Vector3(0.008,0.008,0.004),metal,simple)
		bolt.basis = pad.basis
		G.tube(parent,"SeatStay",[Vector3(side*0.40,0.18,0.51),Vector3(side*0.30,0.33,0.42),mount],0.014,metal,simple,12)

static func torso_point(angle: float, v: float) -> Vector3:
	# Hips, waist, ribcage, shoulders and neck form one tailored silhouette.
	var stations: Array[Vector4] = [Vector4(0.290,0.10,-0.04,0.065),Vector4(0.345,0.177,-0.025,0.115),Vector4(0.430,0.158,0.10,0.113),Vector4(0.540,0.171,0.22,0.125),Vector4(0.635,0.195,0.275,0.120),Vector4(0.680,0.166,0.263,0.105),Vector4(0.727,0.083,0.255,0.072)]
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

static func _joint_rect(arm: bool, side: float, simple: bool) -> Rect2i:
	var divide: int = 2 if simple else 1
	return Rect2i(Vector2i((4 if side > 0 else 20)/divide,20/divide),Vector2i(8/divide,4/divide)) if arm else Rect2i(Vector2i((2 if side > 0 else 24)/divide,2/divide),Vector2i(6/divide,6/divide))

static func _joint_parameter(rect: Rect2i, u: float, columns: int) -> Vector2:
	var at: float = wrapf(u,0,1)*2*(rect.size.x+rect.size.y)
	var p := Vector2(rect.position)
	if at <= rect.size.x: p += Vector2(at,0)
	elif at <= rect.size.x+rect.size.y: p += Vector2(rect.size.x,at-rect.size.x)
	elif at <= 2*rect.size.x+rect.size.y: p += Vector2(2*rect.size.x+rect.size.y-at,rect.size.y)
	else: p += Vector2(0,2*(rect.size.x+rect.size.y)-at)
	return p/columns

static func _torso_normal(parameter: Vector2) -> Vector3:
	var du: Vector3 = torso_point(minf(1,parameter.x+0.0001)*TAU,parameter.y)-torso_point(maxf(0,parameter.x-0.0001)*TAU,parameter.y)
	var dv: Vector3 = torso_point(parameter.x*TAU,minf(1,parameter.y+0.0001))-torso_point(parameter.x*TAU,maxf(0,parameter.y-0.0001))
	var normal: Vector3 = du.cross(dv).normalized()
	return normal if normal.dot(Vector3(sin(parameter.x*TAU),0,-cos(parameter.x*TAU))) > 0 else -normal

static func _cap(arrays: Array, columns: int, row: int, normal: Vector3) -> void:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var center := Vector3.ZERO
	for col: int in range(columns): center += vertices[row*(columns+1)+col]/columns
	var id: int = vertices.size()
	vertices.append(center)
	normals.append(normal)
	uv.append(Vector2(0.5,0.5))
	for col: int in range(columns):
		var triangle: Array[int] = [id,row*(columns+1)+col,row*(columns+1)+col+1]
		if (vertices[triangle[1]]-center).cross(vertices[triangle[2]]-center).dot(normal) > 0: triangle.reverse()
		indices.append_array(PackedInt32Array(triangle))
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	arrays[Mesh.ARRAY_TANGENT] = null

static func _suit_torso(parent: Node3D, suit: Material, simple: bool) -> void:
	G.attach(parent,"TailoredRaceSuitV3"+("|simple" if simple else "|full"),suit,func() -> ArrayMesh:
		var columns: int = 16 if simple else 32
		var mesh: ArrayMesh = G.surface(columns,columns,func(u: float,v: float) -> Vector3: return torso_point(u*TAU,v),func(u: float,_v: float) -> Vector3: return Vector3(sin(u*TAU),0,-cos(u*TAU)))
		var arrays: Array = mesh.surface_get_arrays(0)
		var original: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var indices := PackedInt32Array()
		for row: int in range(columns):
			for col: int in range(columns):
				var opening: bool = false
				for arm: bool in [false,true]:
					for side: float in [-1.0,1.0]: opening = opening or _joint_rect(arm,side,simple).has_point(Vector2i(col,row))
				if not opening: indices.append_array(original.slice((row*columns+col)*6,(row*columns+col+1)*6))
		arrays[Mesh.ARRAY_INDEX] = indices
		_cap(arrays,columns,0,Vector3.DOWN)
		_cap(arrays,columns,columns,Vector3.UP)
		var result := ArrayMesh.new()
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		return result)

static func _suit_limb(parent: Node3D, label: String, arm: bool, side: float, base: Callable, outward: Callable, suit: Material, simple: bool) -> void:
	G.attach(parent,label+"|joined-v3"+("|simple" if simple else "|full"),suit,func() -> ArrayMesh:
		var columns: int = 12 if simple else 24
		var body_columns: int = 16 if simple else 32
		var rows: int = (16 if simple else 32) if arm else (14 if simple else 28)
		var rect: Rect2i = _joint_rect(arm,side,simple)
		var trim: float = 0.18 if arm else 0.20
		var best := Vector2.ZERO
		var cost: float = INF
		# The torso hole and outgoing limb must traverse their common rim in
		# opposite directions; a mirrored nearest-point mapping folds the join.
		for orientation: float in [-1.0]:
			for phase: int in range(columns):
				var score: float = 0
				for col: int in range(columns):
					var u: float = float(col)/columns
					var p: Vector2 = _joint_parameter(rect,float(phase)/columns+orientation*u,body_columns)
					score += torso_point(p.x*TAU,p.y).distance_squared_to(base.call(u,trim))
				if score < cost:
					cost = score
					best = Vector2(float(phase)/columns,orientation)
		var sample := func(u: float,v: float) -> Vector3:
			if v >= trim: return base.call(u,v)
			var p: Vector2 = _joint_parameter(rect,best.x+best.y*u,body_columns)
			var center: Vector2 = (Vector2(rect.position)+Vector2(rect.size)*0.5)/body_columns
			var start: Vector3 = torso_point(p.x*TAU,p.y)
			var end: Vector3 = base.call(u,trim)
			var tangent: Vector3 = (torso_point(p.lerp(center,0.03).x*TAU,p.lerp(center,0.03).y)-start).normalized()*minf(0.055,start.distance_to(end)*0.6)
			var end_tangent: Vector3 = (Vector3(base.call(u,trim+0.0001))-Vector3(base.call(u,trim-0.0001)))*(trim/0.0002)
			var t: float = v/trim
			return start*(2*t*t*t-3*t*t+1)+tangent*(t*t*t-2*t*t+t)+end*(-2*t*t*t+3*t*t)+end_tangent*(t*t*t-t*t)
		var mesh: ArrayMesh = G.surface(columns,rows,sample,func(u: float,v: float) -> Vector3:
			var p: Vector2 = _joint_parameter(rect,best.x+best.y*u,body_columns)
			return _torso_normal(p).lerp(outward.call(u,v),smoothstep(0,trim,v)).normalized())
		var arrays: Array = mesh.surface_get_arrays(0)
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		# This is one oriented parametric tube, including the underarm return.
		# Its normals may turn through the torso's radial direction; keep the
		# common parameter winding instead of flipping individual triangles.
		for row: int in range(rows+1):
			for col: int in range(columns+1):
				var u: float = float(col)/columns
				var v: float = float(row)/rows
				var du: Vector3 = sample.call(minf(1,u+0.0001),v)-sample.call(maxf(0,u-0.0001),v)
				var dv: Vector3 = sample.call(u,minf(1,v+0.0001))-sample.call(u,maxf(0,v-0.0001))
				normals[row*(columns+1)+col] = du.cross(dv).normalized()
		for col: int in range(columns+1): normals[col] = _torso_normal(_joint_parameter(rect,best.x+best.y*float(col)/columns,body_columns))
		arrays[Mesh.ARRAY_NORMAL] = normals
		var indices := PackedInt32Array()
		for row: int in range(rows):
			for col: int in range(columns):
				var a: int = row*(columns+1)+col
				indices.append_array(PackedInt32Array([a,a+columns+2,a+1,a,a+columns+1,a+columns+2]))
		arrays[Mesh.ARRAY_INDEX] = indices
		var end: Vector3 = Vector3(base.call(0,1))+Vector3(base.call(0.5,1))
		var previous: Vector3 = Vector3(base.call(0,0.999))+Vector3(base.call(0.5,0.999))
		_cap(arrays,columns,rows,(end-previous).normalized())
		var result := ArrayMesh.new()
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		return result)

static func build(parent: Node3D, trim: Material, simple: bool) -> void:
	var suit := CompactFinish.rubber(Color("283d4b"))
	suit.roughness = 0.92
	var seams := CompactFinish.rubber(Color("b8b3a0"))
	var dark := CompactFinish.rubber(Color("10191d"))
	var padding := CompactFinish.rubber(Color("30383b"))
	_seat(parent,trim,padding,simple)
	_suit_torso(parent,suit,simple)
	G.ellipsoid(parent,"Collar",Vector3(0,0.737,0.255),Vector3(0.088,0.026,0.073),dark,simple)
	G.ellipsoid(parent,"BalaclavaNeck",Vector3(0,0.751,0.255),Vector3(0.077,0.046,0.068),dark,simple)
	G.patch(parent,"SuitZipperV2",2,32,func(u: float,v: float) -> Vector3:
		return torso_point(lerpf(-0.012,0.012,u),lerpf(0.28,0.92,v))+Vector3.FORWARD*0.0015,func(_u: float,_v: float) -> Vector3: return Vector3.FORWARD,seams,simple)
	for side: float in [-1.0,1.0]:
		# A forward, reclined pelvis gives the torso its proper seated length;
		# balanced thighs/shins bend below the wheel without moving the pedals.
		var leg: Array[Vector3] = [Vector3(side*0.108,0.345,-0.055),Vector3(side*0.138,0.375,-0.21),Vector3(side*0.151,0.370,-0.39),Vector3(side*0.145,0.300,-0.57),Vector3(side*0.14,0.225,-0.75)]
		var radial := func(u: float,v: float) -> Vector3:
			var tangent: Vector3 = (G.curve(leg,minf(1,v+0.0001))-G.curve(leg,maxf(0,v-0.0001))).normalized()
			var across: Vector3 = tangent.cross(Vector3.UP).normalized()
			return across*cos(u*TAU)+tangent.cross(across)*sin(u*TAU)
		_suit_limb(parent,"ContinuousTrouserLegV3"+str(side),false,side,func(u: float,v: float) -> Vector3:
			var radius: float = lerpf(0.080,0.046,smoothstep(0.2,1,v))
			return G.curve(leg,v)+radial.call(u,v)*radius,radial,suit,simple)
		var boot: MeshInstance3D = G.rounded(parent,"RaceBoot",Vector3(side*0.14,0.23,-0.79),Vector3(0.125,0.12,0.25),0.044,dark,simple)
		boot.rotation.x = -0.17
		G.rounded(parent,"BootSole",Vector3(side*0.14,0.178,-0.79),Vector3(0.129,0.018,0.25),0.008,trim,simple)
		_suit_limb(parent,"UpperSleeveContinuousV3"+str(side),true,side,func(u: float,v: float) -> Vector3: return sleeve_point(side,u*TAU,v),func(u: float,v: float) -> Vector3:
			return (sleeve_point(side,u*TAU,v)-G.curve(arm_path(side),v)).normalized(),suit,simple)
		# Trim samples the same continuous cloth surface, including the elbow bend.
		G.patch(parent,"SleevePipingV2"+str(side),4,48,func(u: float,v: float) -> Vector3:
			var t: float = lerpf(0.20,0.94,v)
			var angle: float = (0.0 if side > 0 else PI)+lerpf(-0.040,0.040,u)*smoothstep(0,0.06,v)*smoothstep(0,0.06,1-v)
			var surface: Vector3 = sleeve_point(side,angle,t)
			return surface+(surface-Vector3(G.curve(arm_path(side),t))).normalized()*0.0015,func(_u: float,_v: float) -> Vector3: return Vector3(side,0.35,-0.15).normalized(),seams,simple)
		G.ellipsoid(parent,"RacingGlove",Vector3(side*0.153,0.553,-0.315),Vector3(0.044,0.045,0.046),seams,simple)
		G.ellipsoid(parent,"GloveGrip",Vector3(side*0.147,0.54,-0.339),Vector3(0.034,0.029,0.031),dark,simple)
	var head := Node3D.new()
	head.name = "HelmetMount"
	head.position.y = -0.065
	parent.add_child(head)
	preload("res://vehicle/kart_helmet.gd").build(head,simple)
