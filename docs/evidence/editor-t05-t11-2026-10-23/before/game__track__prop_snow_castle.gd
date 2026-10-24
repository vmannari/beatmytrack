extends RefCounted
## A hand-packed snow fort. Cosmetic geometry only; original footprint/contact data.
const TAG: float = 0.60

static func append(tool: SurfaceTool) -> void:
	for x: float in [-2.65,2.65]:
		for z: float in [-2.10,2.10]: _tower(tool,Vector3(x,0,z))
	for side: int in range(4):
		var center := Vector3(0,0,-2.10) if side == 0 else Vector3(2.65,0,0) if side == 1 else Vector3(0,0,2.10) if side == 2 else Vector3(-2.65,0,0)
		var half: float = 2.25 if side%2 == 0 else 1.70
		var turn: float = PI*side*0.5
		if side == 0:
			_wall(tool,center,-half,-0.74,half,turn,true)
			_wall(tool,center,0.74,half,half,turn,true)
			_gate(tool)
		else: _wall(tool,center,-half,half,half,turn,false)
	_floor(tool,Vector2(4.72,3.65),Vector3.ZERO,18,14)
	_floor(tool,Vector2(1.46,0.92),Vector3(0,0,-2.16),8,5)

static func _warp(point: Vector3) -> Vector3:
	# Shared continuous deformation seats adjoining faces without random cracks.
	var soften: float = smoothstep(-0.05,0.24,point.y)
	point.x += 0.013*sin(point.y*4.3+point.z*3.1)*soften
	point.z += 0.013*sin(point.y*3.7+point.x*4.1)*soften
	point.y += 0.012*sin(point.x*3.3+point.z*2.7)*sin(point.z*4.8-point.x*2.1)*soften
	return point

static func _face(tool: SurfaceTool, source: Array, outward: Vector3, group: int = 0) -> void:
	var points: Array[Vector3] = []
	for point: Vector3 in source: points.append(_warp(point))
	tool.set_smooth_group(group)
	for i: int in range(1,points.size()-1):
		var normal: Vector3 = (points[i]-points[0]).cross(points[i+1]-points[0])
		if normal.length_squared() < 1e-16: continue
		var indices: Array = [0,i,i+1] if normal.dot(outward) < 0.0 else [0,i+1,i]
		for index: int in indices:
			var p: Vector3 = points[index]
			# Old, compacted lower snow is subdued; no blue masonry pigment.
			var tone: float = lerpf(0.91,1.0,smoothstep(0.06,0.65,p.y))
			tone -= 0.015*(0.5+0.5*sin(p.x*2.9+p.y*4.1+sin(p.z*3.7)))
			tool.set_color(Color(tone,tone,tone,TAG)); tool.add_vertex(p)

static func _tower_point(center: Vector3, angle: float, row: int) -> Vector3:
	var phase: float = center.x*1.7+center.z*2.3
	var crenel: float = smoothstep(-0.72,0.10,cos(angle*6.0+phase*0.14))
	var crest: float = 3.23+0.52*crenel+0.065*sin(angle*3.0+phase)+0.04*sin(phase)
	var wind: float = 0.5+0.5*cos(angle-0.7)
	var radii: Array[float] = [0.94+wind*0.07,0.95+wind*0.055,0.89,0.82,0.785,0.765,0.76,0.735,0.665,0.55,0.49,0.49,0.001]
	var heights: Array[float] = [-0.045,0.075,0.25,0.65,1.45,2.30,2.92,crest-0.14,crest-0.025,crest-0.035,crest-0.16,3.035,3.01]
	var r: float = radii[row]
	if row < 12: r += 0.011*sin(angle*5.0+phase)+0.008*sin(angle*9.0-phase)
	return center+Vector3(sin(angle)*r,heights[row],-cos(angle)*r)

static func _tower(tool: SurfaceTool, center: Vector3) -> void:
	const SEGMENTS: int = 48
	for row: int in range(12):
		for i: int in range(SEGMENTS):
			var a: float = TAU*i/SEGMENTS; var b: float = TAU*(i+1)/SEGMENTS
			var n := Vector3(sin((a+b)*0.5),0,-cos((a+b)*0.5))
			if row in [7,8,11]: n = Vector3.UP
			elif row in [9,10]: n = -n
			_face(tool,[_tower_point(center,a,row),_tower_point(center,b,row),_tower_point(center,b,row+1),_tower_point(center,a,row+1)],n)

static func _wall_top(x: float, half: float, gate: bool) -> float:
	var count: int = 5 if half > 2.0 else 4
	var crest: float = smoothstep(-0.58,0.12,cos((x+half)/(half*2.0)*TAU*count+0.12))
	return 2.30+0.38*crest+0.055*sin(x*3.9+half)+ (0.80*exp(-x*x/0.40) if gate else 0.0)

static func _wall_point(center: Vector3, x: float, row: int, half: float, turn: float, gate: bool) -> Vector3:
	var top: float = _wall_top(x,half,gate)
	var profile: Array[Vector2] = [Vector2(-0.50,-0.045),Vector2(-0.48,0.08),Vector2(-0.37,0.31),Vector2(-0.285,1.10),Vector2(-0.26,top-0.19),Vector2(-0.20,top-0.055),Vector2(0,top+0.015),Vector2(0.20,top-0.055),Vector2(0.26,top-0.19),Vector2(0.285,1.10),Vector2(0.37,0.31),Vector2(0.48,0.08),Vector2(0.50,-0.045)]
	var p: Vector2 = profile[row]
	# Slight surface bulges from hand packing, rather than rectangular blocks.
	if row in [2,3,4,8,9,10]: p.x *= 1.0+0.055*sin(x*4.7+p.y*3.2)
	return center+Vector3(x,p.y,p.x).rotated(Vector3.UP,turn)

static func _wall(tool: SurfaceTool, center: Vector3, lo: float, hi: float, half: float, turn: float, gate: bool) -> void:
	var segments: int = ceili((hi-lo)/0.15)
	for row: int in range(12):
		var n := Vector3(0,0,-1 if row < 6 else 1)
		if row in [4,5,6,7]: n = Vector3.UP
		n = n.rotated(Vector3.UP,turn)
		for i: int in range(segments):
			var a: float = lerpf(lo,hi,float(i)/segments); var b: float = lerpf(lo,hi,float(i+1)/segments)
			_face(tool,[_wall_point(center,a,row,half,turn,gate),_wall_point(center,b,row,half,turn,gate),_wall_point(center,b,row+1,half,turn,gate),_wall_point(center,a,row+1,half,turn,gate)],n)
	# Only gate jamb ends are exposed. Outer ends terminate inside the turrets.
	if gate:
		var end: float = hi if lo < 0.0 else lo
		var cap: Array[Vector3] = []
		for row: int in range(13): cap.append(_wall_point(center,end,row,half,turn,gate))
		_face(tool,cap,Vector3.RIGHT if lo < 0.0 else Vector3.LEFT,1)

static func _gate_point(x: float, row: int) -> Vector3:
	var bottom: float = 1.08+sqrt(maxf(0.0,0.74*0.74-x*x))
	var top: float = _wall_top(x,2.25,true)
	var profile: Array[Vector2] = [Vector2(-0.19,bottom),Vector2(-0.285,bottom+0.095),Vector2(-0.275,lerpf(bottom,top,0.45)),Vector2(-0.26,top-0.19),Vector2(-0.20,top-0.055),Vector2(0,top+0.015),Vector2(0.20,top-0.055),Vector2(0.26,top-0.19),Vector2(0.275,lerpf(bottom,top,0.45)),Vector2(0.285,bottom+0.095),Vector2(0.19,bottom),Vector2(0,bottom-0.015)]
	return Vector3(x,profile[row].y,-2.10+profile[row].x)

static func _gate(tool: SurfaceTool) -> void:
	for row: int in range(12):
		var next: int = (row+1)%12
		var n := Vector3(0,0,-1 if row < 5 else 1)
		if row in [3,4,5,6]: n = Vector3.UP
		elif row in [10,11]: n = Vector3.DOWN
		for i: int in range(16):
			var a: float = lerpf(-0.74,0.74,float(i)/16); var b: float = lerpf(-0.74,0.74,float(i+1)/16)
			_face(tool,[_gate_point(a,row),_gate_point(b,row),_gate_point(b,next),_gate_point(a,next)],n)

static func _floor(tool: SurfaceTool, size: Vector2, center: Vector3, columns: int, rows: int) -> void:
	for x: int in range(columns):
		for z: int in range(rows):
			var points: Array[Vector3] = []
			for offset: Vector2i in [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
				var p := Vector2((float(x+offset.x)/columns-0.5)*size.x,(float(z+offset.y)/rows-0.5)*size.y)
				var y: float = 0.025+0.009*sin(p.x*4.1+p.y*3.3)
				points.append(center+Vector3(p.x,y,p.y))
			_face(tool,points,Vector3.UP)
