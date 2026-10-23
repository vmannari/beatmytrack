class_name PropEgypt
extends RefCounted
## Original modular Egyptian-inspired stonework. All detail is static geometry.
const KINDS: Array[String] = ["egypt_pyramid","egypt_obelisk","egypt_column","egypt_column_broken","egypt_wall"]
const LIMESTONE := Color("c8ad7c")
const SANDSTONE := Color("bca077")
const GRANITE := Color("a57d68")
const CUT := Color("776448")
const BLUE := Color("617f81")
const RED := Color("985d49")

static func append(tool: SurfaceTool, kind: String, center: Vector3, scale: float, turn: float) -> bool:
	if kind not in KINDS: return false
	var local := SurfaceTool.new(); local.begin(Mesh.PRIMITIVE_TRIANGLES)
	match kind:
		"egypt_pyramid": _pyramid(local)
		"egypt_obelisk": _obelisk(local)
		"egypt_column": _column(local,false)
		"egypt_column_broken": _column(local,true)
		"egypt_wall": _wall(local)
	PropGeometry.append_transformed(tool,local,center,scale,turn)
	return true

static func material() -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = preload("res://track/egypt_stone.gdshader")
	return result

static func _tone(base: Color, seed_value: float) -> Color:
	return base.lightened(0.035*sin(seed_value*2.37)).darkened(0.025+0.025*sin(seed_value*5.13))

static func _turn(point: Vector3, side: int) -> Vector3:
	return point.rotated(Vector3.UP,side*PI*0.5)

static func _turned_face(tool: SurfaceTool, points: Array, color: Color, side: int, normal: Vector3) -> void:
	var transformed: Array[Vector3] = []
	for point: Vector3 in points: transformed.append(_turn(point,side))
	PropGeometry.face(tool,transformed,color,_turn(normal,side))

static func _frustum(tool: SurfaceTool, y0: float, y1: float, w0: float, w1: float, depth0: float, depth1: float, color: Color) -> void:
	for side: int in range(4):
		var a: float = w0 if side%2 == 0 else depth0
		var b: float = w1 if side%2 == 0 else depth1
		var c: float = depth0 if side%2 == 0 else w0
		var d: float = depth1 if side%2 == 0 else w1
		var points: Array = [Vector3(-a,y0,-c),Vector3(a,y0,-c),Vector3(b,y1,-d)]
		if b>0.0 or d>0.0: points.append(Vector3(-b,y1,-d))
		_turned_face(tool,points,color,side,Vector3(0,0,-1))
	if w1>0.0 and depth1>0.0: PropGeometry.face(tool,[Vector3(-w1,y1,-depth1),Vector3(w1,y1,-depth1),Vector3(w1,y1,depth1),Vector3(-w1,y1,depth1)],color,Vector3.UP)
	PropGeometry.face(tool,[Vector3(-w0,y0,-depth0),Vector3(w0,y0,-depth0),Vector3(w0,y0,depth0),Vector3(-w0,y0,depth0)],color.darkened(0.10),Vector3.DOWN)

static func _ashlar(tool: SurfaceTool, corners: Array, side: int, color: Color, seed_value: float) -> void:
	# A real sloped face with eight worn corners and bevel returns, seated in
	# a closed recessed core. Narrow joints retain depth at glancing angles.
	var outer: Array[Vector3] = []
	var inner: Array[Vector3] = []
	var centre := Vector3.ZERO
	for point: Vector3 in corners: centre += point*0.25
	for i: int in range(4):
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i+1)%4]
		var trim: float = 0.035+0.018*sin(seed_value+i*1.83)
		for t: float in [trim,1.0-trim]:
			var p: Vector3 = a.lerp(b,t)
			outer.append(p)
			inner.append(p.lerp(centre,0.025)+Vector3(0,0,-0.022-0.007*sin(seed_value+i)))
	for i: int in range(8):
		var j: int = (i+1)%8
		_turned_face(tool,[outer[i],outer[j],inner[j],inner[i]],color.darkened(0.035),side,Vector3(0,0,-1))
	_turned_face(tool,inner,color,side,Vector3(0,0,-1))

static func _pyramid(tool: SurfaceTool) -> void:
	# Readable monument proportions; individually fitted sloping limestone
	# courses, staggered joints and a surviving quieter upper casing.
	_frustum(tool,-0.07,7.46,5.91,0.025,5.91,0.025,LIMESTONE.darkened(0.20))
	for row: int in range(12):
		var y0: float = row*0.59
		var y1: float = y0+0.571
		var r0: float = 5.96*(1.0-y0/7.5)
		var r1: float = 5.96*(1.0-y1/7.5)
		var count: int = maxi(1,ceili(r0*1.65))
		for side: int in range(4):
			for block: int in range(count):
				var u0: float = float(block)/count
				var u1: float = float(block+1)/count
				# Offset internal joints without disturbing the watertight corners.
				if block>0: u0 += sin(row*2.1+side)*0.15/count
				if block<count-1: u1 += sin(row*2.1+side)*0.15/count
				var a0: float = lerpf(-r0,r0,u0)+0.009
				var b0: float = lerpf(-r0,r0,u1)-0.009
				var a1: float = lerpf(-r1,r1,u0)+0.009
				var b1: float = lerpf(-r1,r1,u1)-0.009
				var seed_value: float = row*31+side*7+block*1.71
				_ashlar(tool,[Vector3(a0,y0,-r0),Vector3(b0,y0,-r0),Vector3(b1,y1,-r1),Vector3(a1,y1,-r1)],side,_tone(LIMESTONE,seed_value),seed_value)
	_frustum(tool,7.08,7.49,0.336,0.002,0.336,0.002,LIMESTONE.lightened(0.05))
	# A few displaced casing chips remain within the authored solid footprint.
	for i: int in range(9):
		var a: float = i*2.39
		var p := Vector3(cos(a)*5.50,0.07,sin(a)*5.50)
		PropGeometry.box(tool,p,Vector3(0.23+0.10*sin(i),0.20,0.32),_tone(LIMESTONE,i),0.048)

static func _obelisk(tool: SurfaceTool) -> void:
	PropGeometry.box(tool,Vector3(0,0.19,0),Vector3(2.7,0.5,2.7),SANDSTONE,0.065)
	PropGeometry.box(tool,Vector3(0,0.51,0),Vector3(2.24,0.18,2.24),GRANITE.darkened(0.07),0.035)
	PropGeometry.box(tool,Vector3(0,0.72,0),Vector3(1.86,0.30,1.86),GRANITE,0.035)
	# Monolithic tapered shaft. A shallow recessed inscription strip is
	# actually cut out of each side, including its four narrow reveal walls.
	var rings: Array = []
	for row: int in range(2):
		var ring: Array[Vector3] = []
		var radius: float = 0.73 if row==0 else 0.46
		var width: float = 0.23 if row==0 else 0.19
		var height: float = 0.86 if row==0 else 7.59
		for side: int in range(4):
			for q: Vector2 in [Vector2(-radius+0.035,-radius),Vector2(-width,-radius),Vector2(-width,-radius+0.022),Vector2(width,-radius+0.022),Vector2(width,-radius),Vector2(radius-0.035,-radius)]:
				ring.append(_turn(Vector3(q.x,height,q.y),-side))
		rings.append(ring)
	for i: int in range(rings[0].size()):
		var j: int = (i+1)%rings[0].size()
		var edge: Vector3 = rings[0][j]-rings[0][i]
		var normal:=Vector3(edge.z,0,-edge.x)
		PropGeometry.face(tool,[rings[0][i],rings[0][j],rings[1][j],rings[1][i]],GRANITE.darkened(0.09 if i%6==2 else 0.0),normal)
	for row: int in range(2):
		var cap:=Vector3(0,0.86 if row==0 else 7.59,0)
		for i: int in range(rings[row].size()):
			PropGeometry.face(tool,[rings[row][i],rings[row][(i+1)%rings[row].size()],cap],GRANITE,Vector3.DOWN if row==0 else Vector3.UP)
	for side: int in range(4):
		var y0: float = 0.86; var y1: float = 7.59
		var r0: float = 0.73; var r1: float = 0.46
		for row: int in range(10):
			var y: float = 1.19+row*0.58
			var z: float = -lerpf(r0,r1,(y-y0)/(y1-y0))+0.010
			_glyph(tool,Vector3(0,y,z),0.26,row+side,side,GRANITE.darkened(0.36))
	_frustum(tool,7.59,8.60,0.46,0.0,0.46,0.0,GRANITE.lightened(0.09))
	# Restrained mineral edge staining on the plinth, with seated fragments.
	for i: int in range(4):
		var p: Vector3 = _turn(Vector3(0.88,0.06,-1.12),i)
		PropGeometry.box(tool,p,Vector3(0.20,0.15,0.22),GRANITE.darkened(0.04),0.035)

static func _stroke(tool: SurfaceTool, a: Vector3, b: Vector3, width: float, side: int, color: Color) -> void:
	# Low carved relief is seated in the recessed field. Beveled sides catch
	# directional light; the geometry never uses emissive or floating decals.
	PropGeometry.beam(tool,_turn(a,side),_turn(b,side),width,0.013,color)

static func _glyph(tool: SurfaceTool, p: Vector3, size: float, index: int, side: int, color: Color) -> void:
	var shapes: Array = []
	match index%5:
		0: # sun disk and supporting horizon
			for i: int in range(12):
				var a: float = TAU*i/12; var b: float = TAU*(i+1)/12
				shapes.append([Vector2(cos(a)*0.35,sin(a)*0.35+0.17),Vector2(cos(b)*0.35,sin(b)*0.35+0.17)])
			shapes.append([Vector2(-0.48,-0.44),Vector2(0.48,-0.44)])
		1: # reed and two leaves
			shapes = [[Vector2(0,-0.58),Vector2(0,0.62)],[Vector2(0,0.14),Vector2(-0.4,0.48)],[Vector2(-0.4,0.48),Vector2(-0.19,-0.06)],[Vector2(0,0.14),Vector2(0.4,0.48)],[Vector2(0.4,0.48),Vector2(0.19,-0.06)]]
		2: # water lines
			for row: int in range(3):
				for i: int in range(4): shapes.append([Vector2(-0.5+i*0.25,-0.35+row*0.35+(0.09 if i%2==0 else 0.0)),Vector2(-0.25+i*0.25,-0.35+row*0.35+(0.09 if i%2!=0 else 0.0))])
		3: # folded cloth
			shapes = [[Vector2(-0.3,-0.6),Vector2(-0.3,0.55)],[Vector2(-0.3,0.55),Vector2(0.35,0.55)],[Vector2(0.35,0.55),Vector2(0.15,0.18)],[Vector2(0.15,0.18),Vector2(-0.3,0.18)]]
		4: # stylised bird profile, original ornament rather than copied text
			shapes = [[Vector2(-0.4,0.4),Vector2(-0.2,0.51)],[Vector2(-0.2,0.51),Vector2(-0.1,0.05)],[Vector2(-0.1,0.05),Vector2(0.40,-0.22)],[Vector2(0.40,-0.22),Vector2(-0.34,-0.22)],[Vector2(-0.34,-0.22),Vector2(-0.1,0.05)],[Vector2(-0.15,-0.22),Vector2(-0.25,-0.55)],[Vector2(0.13,-0.22),Vector2(0.22,-0.55)]]
	for line: Array in shapes:
		var a: Vector2 = line[0]; var b: Vector2 = line[1]
		_stroke(tool,p+Vector3(a.x,a.y,0)*size,p+Vector3(b.x,b.y,0)*size,size*0.070,side,color)

static func _lathe(tool: SurfaceTool, profile: Array, color: Color, lobes: float = 0.0, broken: bool = false) -> void:
	var segments: int = 48
	var rings: Array = []
	for row: int in range(profile.size()):
		var ring: Array[Vector3] = []
		var p: Vector2 = profile[row]
		for i: int in range(segments):
			var a: float = TAU*i/segments
			var radius: float = p.x+lobes*(0.5+0.5*cos(a*12))
			var height: float = p.y+(0.13*sin(a*3+0.8)+0.065*sin(a*7) if broken and row==profile.size()-1 else 0.0)
			ring.append(Vector3(cos(a)*radius,height,sin(a)*radius))
		rings.append(ring)
	for row: int in range(rings.size()-1):
		for i: int in range(segments):
			var j: int = (i+1)%segments
			var normal := Vector3(cos(TAU*(i+0.5)/segments),0,sin(TAU*(i+0.5)/segments))
			PropGeometry.face(tool,[rings[row][i],rings[row][j],rings[row+1][j],rings[row+1][i]],_tone(color,row*0.12+i*0.04),normal)
	# Connected triangle fan for the fracture; no flat disc over its broken edge.
	var cap := Vector3(0,profile[-1].y-0.025 if broken else profile[-1].y,0)
	for i: int in range(segments):
		PropGeometry.face(tool,[rings[-1][i],rings[-1][(i+1)%segments],cap],_tone(color.lightened(0.05),i),Vector3.UP)
	PropGeometry.face(tool,rings[0],color.darkened(0.12),Vector3.DOWN)

static func _cornice(tool: SurfaceTool) -> void:
	# Closed extruded cavetto blocks: a concave face, a solid cap and real
	# returns at both ends. Every curved strip is supported by stone behind it.
	var profile: Array[Vector2] = [Vector2(0.57,3.18),Vector2(0.58,3.28),Vector2(0.605,3.42),Vector2(0.66,3.58),Vector2(0.75,3.73),Vector2(0.84,3.83)]
	for block: int in range(3):
		var x0: float = -3.55+block*1.17
		var x1: float = x0+1.154
		var color: Color = _tone(SANDSTONE,block*0.8)
		for sign_value: float in [-1.0,1.0]:
			for row: int in range(profile.size()-1):
				var a: Vector2=profile[row]; var b: Vector2=profile[row+1]
				PropGeometry.face(tool,[Vector3(x0,a.y,sign_value*a.x),Vector3(x1,a.y,sign_value*a.x),Vector3(x1,b.y,sign_value*b.x),Vector3(x0,b.y,sign_value*b.x)],color,Vector3(0,0,sign_value))
		PropGeometry.face(tool,[Vector3(x0,3.83,-0.84),Vector3(x1,3.83,-0.84),Vector3(x1,3.83,0.84),Vector3(x0,3.83,0.84)],color,Vector3.UP)
		PropGeometry.face(tool,[Vector3(x0,3.18,-0.57),Vector3(x1,3.18,-0.57),Vector3(x1,3.18,0.57),Vector3(x0,3.18,0.57)],color.darkened(0.1),Vector3.DOWN)
		for x: float in [x0,x1]:
			var loop: Array[Vector3] = []
			for p: Vector2 in profile: loop.append(Vector3(x,p.y,-p.x))
			for i: int in range(profile.size()-1,-1,-1): loop.append(Vector3(x,profile[i].y,profile[i].x))
			# These concave end sections need a centre inside the solid volume.
			var centre:=Vector3(x,3.50,0)
			for i: int in range(loop.size()): PropGeometry.face(tool,[loop[i],loop[(i+1)%loop.size()],centre],color,Vector3(-1 if x==x0 else 1,0,0))

static func _column(tool: SurfaceTool, broken: bool) -> void:
	PropGeometry.box(tool,Vector3(0,0.11,0),Vector3(2.66,0.34,2.66),SANDSTONE.darkened(0.05),0.07)
	_lathe(tool,[Vector2(1.12,0.23),Vector2(1.16,0.29),Vector2(1.15,0.43),Vector2(0.99,0.53),Vector2(0.80,0.60)],SANDSTONE)
	var shaft: Array = [Vector2(0.77,0.53),Vector2(0.76,0.83),Vector2(0.73,1.43),Vector2(0.71,2.1)] if broken else [Vector2(0.77,0.53),Vector2(0.76,0.83),Vector2(0.73,1.43),Vector2(0.69,2.44),Vector2(0.65,3.48),Vector2(0.64,4.0)]
	_lathe(tool,shaft,SANDSTONE,0.022,broken)
	# Fine drum joints remain narrow and structural; no stacked-disc silhouette.
	for joint: Vector2 in ([Vector2(0.733,1.42)] if broken else [Vector2(0.733,1.42),Vector2(0.693,2.43),Vector2(0.653,3.47)]):
		_lathe(tool,[Vector2(joint.x,joint.y-0.008),Vector2(joint.x,joint.y+0.008)],SANDSTONE.darkened(0.15),0.022)
	if broken:
		for i: int in range(3):
			PropGeometry.box(tool,Vector3(-0.91+i*0.48,0.055,-0.94),Vector3(0.24,0.16,0.28),_tone(SANDSTONE,i),0.05)
		return
	# Bound neck, swelling lotus bud, attached pointed petals and abacus.
	_lathe(tool,[Vector2(0.67,3.91),Vector2(0.71,3.95),Vector2(0.71,4.03),Vector2(0.67,4.08),Vector2(0.72,4.17),Vector2(0.91,4.43),Vector2(1.04,4.77),Vector2(0.99,5.08),Vector2(0.80,5.36),Vector2(0.60,5.54)],SANDSTONE)
	_lathe(tool,[Vector2(0.713,3.97),Vector2(0.713,4.01)],SANDSTONE.lerp(BLUE,0.25))
	var petals: Array[Vector3] = [Vector3(0.692,4.12,0.018),Vector3(0.815,4.30,0.080),Vector3(0.937,4.50,0.145),Vector3(1.04,4.77,0.195),Vector3(0.99,5.08,0.165),Vector3(0.80,5.36,0.085),Vector3(0.622,5.52,0.003)]
	for i: int in range(12):
		var a: float = TAU*i/12
		var rings: Array = []
		for petal: Vector3 in petals:
			var ring: Array[Vector3] = []
			for k: int in range(5):
				var u: float = float(k)*0.5-1.0
				var angle: float = a+petal.z*u
				var r: float = petal.x+0.007+0.024*(1.0-u*u)
				ring.append(Vector3(sin(angle)*r,petal.y,-cos(angle)*r))
			rings.append(ring)
		for row: int in range(rings.size()-1):
			for k: int in range(4):
				PropGeometry.face(tool,[rings[row][k],rings[row][k+1],rings[row+1][k+1],rings[row+1][k]],SANDSTONE.lerp(BLUE,0.16 if i%3==0 else 0.035),Vector3(sin(a),0,-cos(a)))
	PropGeometry.box(tool,Vector3(0,5.65,0),Vector3(1.64,0.25,1.64),SANDSTONE,0.045)
	# Surviving muted mineral pigment at the lower carved stem register.
	for side: int in range(4):
		_glyph(tool,Vector3(0,1.0,-0.775),0.25,side+1,side,SANDSTONE.lerp(RED,0.32))

static func _wall(tool: SurfaceTool) -> void:
	# Closed battered temple remnant, intentionally no decorative doorway
	# through a solid footprint. Crown loss is confined to the top courses.
	_frustum(tool,-0.05,3.26,3.72,3.48,0.80,0.56,SANDSTONE.darkened(0.22))
	for row: int in range(6):
		var y0: float = row*0.53
		var y1: float = y0+0.51
		var z0: float = 0.81-row*0.04
		var z1: float = z0-0.04
		for side: int in [0,2]:
			for block: int in range(6):
				var x0: float = -3.64+block*1.21
				var x1: float = x0+1.19
				_ashlar(tool,[Vector3(x0,y0,-z0),Vector3(x1,y0,-z0),Vector3(x1,y1,-z1),Vector3(x0,y1,-z1)],side,_tone(SANDSTONE,row*11+block+side),row*11+block)
	# Concave cavetto cornice on a retained left bay.
	_cornice(tool)
	for side: int in [0,2]:
		# Relief register: sun disk, paired wings and alternating reed motifs.
		_glyph(tool,Vector3(-1.73,2.72,-0.630),0.49,0,side,SANDSTONE.darkened(0.27))
		for sign_value: float in [-1.0,1.0]:
			for i: int in range(5):
				_stroke(tool,Vector3(-1.73+sign_value*(0.32+i*0.18),2.77,-0.635),Vector3(-1.73+sign_value*(0.52+i*0.17),2.70-i*0.07,-0.641),0.032,side,SANDSTONE.darkened(0.19))
		for i: int in range(10):
			_glyph(tool,Vector3(-3.19+i*0.67,1.02,-0.742),0.32,i+1,side,SANDSTONE.darkened(0.24))
	for i: int in range(4):
		var x: float = 0.49+i*0.76
		PropGeometry.box(tool,Vector3(x,3.32+sin(i*2.1)*0.08,0),Vector3(0.71,0.27,1.06),_tone(SANDSTONE,i),0.07)
