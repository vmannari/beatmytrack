extends RefCounted
## Stock Compact coachwork carved in ice, seated on one snow-covered plinth.
## Uses analytical model profiles only; no live car, cosmetics, lights or simulation.
const LIFT: float = 1.095
const ICE := Color(0.62,0.81,0.88,0.40)
const GLASS := Color(0.43,0.69,0.78,0.46)
const WHEEL := Color(0.49,0.72,0.81,0.43)
const FROST := Color(0.87,0.95,0.98,0.49)
const SNOW := Color(0.98,0.98,0.98,0.60)

static func append(tool: SurfaceTool) -> void:
	_pedestal(tool)
	for side: float in [-1.0,1.0]:
		_patch(tool,32,7,func(u: float,v: float) -> Vector3:
			var station: float = u*32.0
			var z: float = lerpf(-1.84,-1.015,station/8.0) if station <= 8 else lerpf(-1.015,1.75,(station-8)/24.0)
			var lower: float = 0.33
			for axle: float in [-1.28,1.28]:
				if absf(z-axle) < 0.421: lower = maxf(lower,0.37+sqrt(0.421*0.421-pow(z-axle,2)))
			var y: float = lerpf(lower,CompactCoachwork.body_upper(z),v)
			return Vector3(side*CompactCoachwork.body_width(y,z),y,z),ICE,Vector3(side,0,0))
		_patch(tool,4,7,func(u: float,v: float) -> Vector3: return CompactCoachwork.rear_shoulder_point(side,u,v),ICE,Vector3(side,0,0))
		_patch(tool,6,7,func(u: float,v: float) -> Vector3: return CompactCoachwork.rear_corner_point(side,u,v),ICE,Vector3(side,0,1))
		_patch(tool,6,7,func(u: float,v: float) -> Vector3: return CompactCoachwork.front_corner_point(side,u,v),ICE,Vector3(side,0,-1))
		_patch(tool,14,7,func(u: float,v: float) -> Vector3: return CompactCoachwork.cabin_side_point(side,u,v),ICE,Vector3(side,0,0))
		for front: bool in [true,false]:
			_patch(tool,6,7,func(u: float,v: float) -> Vector3: return CompactCoachwork.cabin_corner_point(side,u,v,front),ICE,Vector3(side,0,-1 if front else 1))
			_window(tool,side,front)
		for axle: float in [-1.28,1.28]:
			_arch(tool,side,axle)
			_wheel(tool,side,axle)
		# The original pressed door outline, gently engraved rather than painted.
		var door: Array[Vector2] = CompactCoachwork.door_outline()
		for i: int in range(door.size()):
			var a: Vector2 = door[i]; var b: Vector2 = door[(i+1)%door.size()]
			_stroke(tool,Vector3(side*(CompactCoachwork.body_width(a.y,a.x)+0.006),a.y,a.x),Vector3(side*(CompactCoachwork.body_width(b.y,b.x)+0.006),b.y,b.x),0.008,GLASS)
		_ellipsoid(tool,Vector3(side*0.932,1.065,-0.74),Vector3(0.103,0.0825,0.035),FROST,12,6)
	_patch(tool,14,7,func(u: float,v: float) -> Vector3: return CompactCoachwork.front_face_point(u,v),ICE,Vector3.FORWARD)
	_patch(tool,14,7,func(u: float,v: float) -> Vector3: return CompactCoachwork.rear_face_point(u,v),ICE,Vector3.BACK)
	_patch(tool,28,8,func(u: float,v: float) -> Vector3: return CompactCoachwork.hood_point(lerpf(-1,1,u),v),ICE,Vector3.UP)
	_patch(tool,18,8,func(u: float,v: float) -> Vector3: return CompactCoachwork.roof_point(lerpf(-1,1,u),v),FROST,Vector3.UP)
	_patch(tool,18,8,func(u: float,v: float) -> Vector3: return CompactCoachwork.cabin_front_point(lerpf(-1,1,u)*(CompactCoachwork.cabin_width(v)-0.06)/CompactCoachwork.cabin_width(v),v),GLASS,Vector3(0,0.8,-0.6))
	_patch(tool,18,8,func(u: float,v: float) -> Vector3: return CompactCoachwork.cabin_rear_point(lerpf(-1,1,u)*(CompactCoachwork.cabin_width(v)-lerpf(0.12,0.06,CompactCoachwork.cabin_depth_progress(v)))/CompactCoachwork.cabin_width(v),v),GLASS,Vector3(0,0.8,0.6))
	# Closed carved underside, with real wheels supporting the sculpture.
	_face(tool,[Vector3(-0.83,0.332,-1.83),Vector3(0.83,0.332,-1.83),Vector3(0.83,0.332,1.92),Vector3(-0.83,0.332,1.92)],ICE,Vector3.DOWN)
	_fittings(tool)

static func _face(tool: SurfaceTool, points: Array, color: Color, outward: Vector3, lift: float = LIFT, group: int = 0) -> void:
	tool.set_color(color); tool.set_smooth_group(group)
	for i: int in range(1,points.size()-1):
		var normal: Vector3 = (points[i]-points[0]).cross(points[i+1]-points[0])
		if normal.length_squared() < 1e-16: continue
		for index: int in ([0,i,i+1] if normal.dot(outward) < 0 else [0,i+1,i]): tool.add_vertex(points[index]+Vector3.UP*lift)

static func _patch(tool: SurfaceTool, columns: int, rows: int, sample: Callable, color: Color, normal: Vector3) -> void:
	for x: int in range(columns):
		for y: int in range(rows):
			var a: float = float(x)/columns; var b: float = float(x+1)/columns
			var lo: float = float(y)/rows; var hi: float = float(y+1)/rows
			_face(tool,[sample.call(a,lo),sample.call(b,lo),sample.call(b,hi),sample.call(a,hi)],color,normal)

static func _window(tool: SurfaceTool, side: float, front: bool) -> void:
	_patch(tool,6,5,func(u: float,v: float) -> Vector3:
		var y: float = lerpf(CompactCoachwork.SIDE_WINDOW_BOTTOM,CompactCoachwork.SIDE_WINDOW_TOP,v)
		var height: float = (y-1.01)/0.47
		var a: Vector3 = CompactCoachwork.cabin_side_point(side,0,height)
		var b: Vector3 = CompactCoachwork.cabin_side_point(side,1,height)
		var leading: float = a.z+0.048 if front else CompactCoachwork.B_PILLAR_REAR
		var trailing: float = CompactCoachwork.B_PILLAR_FRONT if front else b.z-0.065
		return Vector3(a.x+side*0.006,y,lerpf(leading,trailing,u)),GLASS,Vector3(side,0.277,0))
	var corners: Array[Vector3] = CompactCoachwork.side_window_corners(side,front)
	for i: int in range(4):
		_stroke(tool,corners[i]+Vector3(side*0.003,0,0),corners[(i+1)%4]+Vector3(side*0.003,0,0),0.009,FROST)

static func _arch(tool: SurfaceTool, side: float, axle: float) -> void:
	_patch(tool,24,3,func(u: float,v: float) -> Vector3:
		var angle: float = PI*u; var radius: float = lerpf(0.402,0.48,v)
		var y: float = 0.37+sin(angle)*radius; var z: float = axle+cos(angle)*radius
		var bulge: float = 0.070 if axle > 0 else 0.055
		var width: float = CompactCoachwork.body_width(y,z)+(bulge+0.009)*pow(1.0-v,2)
		return Vector3(side*width,y,z),FROST,Vector3(side,0.1,0))

static func _wheel(tool: SurfaceTool, side: float, axle: float) -> void:
	# Rounded tyre and a deeply carved circular hub, all made of the same ice.
	# Closed blue ice in the carved wheel well avoids a hollow black car shell.
	for i: int in range(24):
		var a: float = TAU*i/24; var b: float = TAU*(i+1)/24
		_face(tool,[Vector3(side*0.76,0.37,axle),Vector3(side*0.76,0.37+cos(a)*0.422,axle+sin(a)*0.422),Vector3(side*0.76,0.37+cos(b)*0.422,axle+sin(b)*0.422)],ICE.darkened(0.12),Vector3(side,0,0),LIFT,3)
	var profile: Array[Vector2] = [Vector2(-0.095,0.27),Vector2(-0.095,0.33),Vector2(-0.06,0.365),Vector2(0.06,0.37),Vector2(0.105,0.33),Vector2(0.105,0.235),Vector2(0.088,0.21)]
	for row: int in range(profile.size()-1):
		for i: int in range(20):
			var points: Array[Vector3] = []
			for q: Vector2i in [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
				var angle: float = TAU*(i+q.x)/20; var p: Vector2 = profile[row+q.y]
				points.append(Vector3(side*(0.845+p.x),0.37+cos(angle)*p.y,axle+sin(angle)*p.y))
			var middle: Vector3 = (points[0]+points[2])*0.5-Vector3(side*0.845,0.37,axle)
			_face(tool,points,WHEEL if row < 4 else ICE,middle,LIFT,2)
	for i: int in range(20):
		var a: float = TAU*i/20; var b: float = TAU*(i+1)/20
		_face(tool,[Vector3(side*0.933,0.37,axle),Vector3(side*0.933,0.37+cos(a)*0.21,axle+sin(a)*0.21),Vector3(side*0.933,0.37+cos(b)*0.21,axle+sin(b)*0.21)],GLASS,Vector3(side,0,0),LIFT,3)
	for i: int in range(5):
		var angle: float = TAU*i/5
		_stroke(tool,Vector3(side*0.94,0.37,axle),Vector3(side*0.94,0.37+cos(angle)*0.18,axle+sin(angle)*0.18),0.018,FROST)

static func _stroke(tool: SurfaceTool, a: Vector3, b: Vector3, radius: float, color: Color) -> void:
	PropGeometry.tube(tool,a+Vector3.UP*LIFT,b+Vector3.UP*LIFT,radius,radius,color,6)

static func _ellipsoid(tool: SurfaceTool, center: Vector3, radius: Vector3, color: Color, segments: int = 16, rows: int = 8) -> void:
	for row: int in range(rows):
		for i: int in range(segments):
			var points: Array[Vector3] = []
			for q: Vector2i in [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
				var a: float = TAU*(i+q.x)/segments; var e: float = -PI*0.5+PI*(row+q.y)/rows
				points.append(center+Vector3(cos(a)*cos(e),sin(e),sin(a)*cos(e))*radius)
			_face(tool,points,color,(points[0]+points[2])*0.5-center)

static func _fittings(tool: SurfaceTool) -> void:
	for side: float in [-1.0,1.0]:
		for x: float in [0.46,0.62]:
			var at := Vector3(side*x,0.765,CompactCoachwork.front_skin(side*x,0.765)-0.012)
			_ellipsoid(tool,at,Vector3(0.075,0.075,0.021),FROST,12,6)
		var rear := Vector3(side*0.61,0.79,CompactCoachwork.rear_skin(side*0.61,0.79)+0.01)
		_ellipsoid(tool,rear,Vector3(0.10,0.095,0.021),GLASS,12,6)
	for y: float in [0.64,0.69,0.74]:
		_stroke(tool,Vector3(-0.32,y,CompactCoachwork.front_skin(-0.32,y)-0.015),Vector3(0.32,y,CompactCoachwork.front_skin(0.32,y)-0.015),0.010,GLASS)
	for rear: bool in [false,true]:
		var z: float = 2.035 if rear else -2.12
		_stroke(tool,Vector3(-0.70,0.54,z),Vector3(0.70,0.54,z),0.045,FROST)

static func _pedestal_point(profile: Vector3, index: int) -> Vector3:
	var corner: int = index/4
	var angle: float = corner*PI*0.5+float(index%4)/3*PI*0.5
	var radius: float = 0.20
	var center := Vector2((profile.x-radius)*(1.0 if corner in [0,3] else -1.0),(profile.z-radius)*(1.0 if corner in [0,1] else -1.0))
	return Vector3(center.x+cos(angle)*radius,profile.y,center.y+sin(angle)*radius)

static func _pedestal(tool: SurfaceTool) -> void:
	var profile: Array[Vector3] = [Vector3(1.61,-0.035,2.75),Vector3(1.64,0.10,2.78),Vector3(1.56,0.22,2.68),Vector3(1.28,0.30,2.40),Vector3(1.25,0.88,2.36),Vector3(1.39,0.98,2.52),Vector3(1.38,1.05,2.50),Vector3(1.30,1.10,2.42)]
	for row: int in range(profile.size()-1):
		for i: int in range(16):
			var j: int = (i+1)%16
			var points: Array = [_pedestal_point(profile[row],i),_pedestal_point(profile[row],j),_pedestal_point(profile[row+1],j),_pedestal_point(profile[row+1],i)]
			var n: Vector3 = (points[0]+points[2])*0.5-Vector3(0,(profile[row].y+profile[row+1].y)*0.5,0)
			_face(tool,points,ICE if row == 5 else SNOW,n,0.0,4)
	var top: Array[Vector3] = []
	for i: int in range(16): top.append(_pedestal_point(profile[-1],i))
	_face(tool,top,SNOW,Vector3.UP,0.0,5)
