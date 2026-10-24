class_name ContainerVisual
extends RefCounted
## Original 20-foot-style freight container inside the existing 6 x 2.5 m footprint.
const HALF_LENGTH: float = 3.0
const HALF_WIDTH: float = 1.25
const HEIGHT: float = 2.6
const PANEL_HALF: float = 2.82
const RIBS: int = 18
const STEP: float = PANEL_HALF*2/(RIBS*4)
const RUST := Color("805035")
const RUST_EDGE := Color("a46b3f")
const STEEL := Color("87928b")
const GLYPHS: Dictionary = {
	"B":["11110","10001","10001","11110","10001","10001","11110"],
	"M":["10001","11011","10101","10101","10001","10001","10001"],
	"T":["11111","00100","00100","00100","00100","00100","00100"],
	"C":["01111","10000","10000","10000","10000","10000","01111"],
	"A":["01110","10001","10001","11111","10001","10001","10001"],
	"R":["11110","10001","10001","11110","10100","10010","10001"],
	"G":["01111","10000","10000","10111","10001","10001","01111"],
	"O":["01110","10001","10001","10001","10001","10001","01110"]
}

static func append(tool: SurfaceTool, paint: Color) -> void:
	# Recessed wall shell, structural corner posts and boxed top/bottom rails.
	PropGeometry.box(tool,Vector3(0,1.29,0),Vector3(5.64,2.18,2.28),paint.darkened(0.16),0.016)
	for side: float in [-1.0,1.0]:
		_wall(tool,paint,side)
		_wear(tool,side)
		for h: float in [0.13,2.49]:
			PropGeometry.box(tool,Vector3(0,h,side*1.19),Vector3(5.72,0.18,0.12),paint.darkened(0.16),0.024)
		for end: float in [-1.0,1.0]:
			PropGeometry.box(tool,Vector3(end*2.91,1.30,side*1.16),Vector3(0.16,2.26,0.17),paint.darkened(0.11),0.022)
			for h: float in [0.12,2.48]: _casting(tool,Vector3(end*2.90,h,side*1.145),paint)
		_logo(tool,paint,side)
	_roof(tool,paint)
	_end_wall(tool,paint)
	_doors(tool,paint)

static func side_z(x: float) -> float:
	# Rolled trapezoidal steel folds, with broad flats and angled webs.
	var cycle: float = fposmod((x+PANEL_HALF)/STEP,4.0)
	if cycle < 1: return lerpf(1.166,1.226,cycle)
	if cycle < 2: return 1.226
	if cycle < 3: return lerpf(1.226,1.166,cycle-2)
	return 1.166

static func _wall(tool: SurfaceTool, paint: Color, side: float) -> void:
	for col: int in range(RIBS*4):
		var x0: float = -PANEL_HALF+col*STEP; var x1: float = x0+STEP
		for row: int in range(12):
			var y0: float = 0.22+row*(2.16/12); var y1: float = 0.22+(row+1)*(2.16/12)
			var points: Array = [Vector3(x0,y0,side*side_z(x0)),Vector3(x1,y0,side*side_z(x1)),Vector3(x1,y1,side*side_z(x1)),Vector3(x0,y1,side*side_z(x0))]
			_painted_face(tool,points,paint,side,0.025 if col%4 == 3 else 0)

static func _painted_face(tool: SurfaceTool, points: Array, paint: Color, side: float, shade: float = 0.0) -> void:
	tool.set_smooth_group(-1)
	var flip: bool = (points[1]-points[0]).cross(points[2]-points[0]).dot(Vector3(0,0,side)) < 0
	for i: int in ([0,1,2,0,2,3] if flip else [0,2,1,0,3,2]):
		var p: Vector3 = points[i]
		tool.set_color(_pigment(Vector2(p.x,p.y),paint,side).darkened(shade))
		tool.add_vertex(p)

static func _pigment(p: Vector2, paint: Color, side: float) -> Color:
	var mask: float = 0.0
	for spot: Vector4 in [Vector4(-2.51,2.22,0.12,0.24),Vector4(-1.72,0.35,0.29,0.15),Vector4(-0.70,2.32,0.08,0.17),Vector4(0.82,2.20,0.13,0.27),Vector4(1.70,0.37,0.26,0.17),Vector4(2.52,0.68,0.12,0.36)]:
		var warped: float = 0.07*sin(p.y*28+side*2.7)+0.035*sin(p.x*39)
		var distance: float = Vector2((p.x-spot.x)/spot.z,(p.y-spot.y)/spot.w).length()+warped
		mask = maxf(mask,1.0-smoothstep(0.57,1.06,distance))
	# Thin roof-origin run-off tails, broken around the folded channels.
	for x: float in [-2.49,-0.70,0.84]:
		var width: float = 0.025+0.008*sin(p.y*19)
		var tail: float = (1.0-smoothstep(width,width*2.5,absf(p.x-x-0.025*sin(p.y*6))))*smoothstep(1.03,1.90,p.y)
		mask = maxf(mask,tail*0.63)
	var rust: Color = RUST.lerp(RUST_EDGE,0.5+0.5*sin(p.x*21+p.y*17))
	return paint.lightened(0.015*sin(p.x*3.1+p.y*2.7)).lerp(rust,mask*0.91)

static func _casting(tool: SurfaceTool, p: Vector3, paint: Color) -> void:
	PropGeometry.box(tool,p,Vector3(0.20,0.24,0.21),paint.darkened(0.23).lerp(RUST,0.28),0.034)
	var side: float = signf(p.z); var end: float = signf(p.x)
	PropGeometry.face(tool,[p+Vector3(-0.051,-0.027,side*0.106),p+Vector3(0.051,-0.027,side*0.106),p+Vector3(0.051,0.027,side*0.106),p+Vector3(-0.051,0.027,side*0.106)],Color("293839"),Vector3(0,0,side))
	PropGeometry.face(tool,[p+Vector3(end*0.101,-0.027,-0.055),p+Vector3(end*0.101,-0.027,0.055),p+Vector3(end*0.101,0.027,0.055),p+Vector3(end*0.101,0.027,-0.055)],Color("293839"),Vector3(end,0,0))
	if p.y > 2:
		PropGeometry.face(tool,[p+Vector3(-0.047,0.121,-0.037),p+Vector3(0.047,0.121,-0.037),p+Vector3(0.047,0.121,0.037),p+Vector3(-0.047,0.121,0.037)],Color("34403c"),Vector3.UP)

static func _roof(tool: SurfaceTool, paint: Color) -> void:
	# Raised trapezoidal folds across the roof, including broad high and low flats.
	for col: int in range(RIBS*4):
		var x0: float = -PANEL_HALF+col*STEP; var x1: float = x0+STEP
		for row: int in range(4):
			var z0: float = -1.13+row*0.565; var z1: float = z0+0.565
			var y0: float = 2.473+(0.040 if col%4 in [1,2] else 0); var y1: float = 2.473+(0.040 if (col+1)%4 in [1,2] else 0)
			var pigment: Color = paint.lightened(0.045).darkened(0.075 if col%4 in [0,3] else 0)
			PropGeometry.face(tool,[Vector3(x0,y0,z0),Vector3(x1,y1,z0),Vector3(x1,y1,z1),Vector3(x0,y0,z1)],pigment,Vector3.UP)

static func _wear(tool: SurfaceTool, side: float) -> void:
	# Small exposed corrosion cores inside the soft stains. Split at steel folds
	# so the irregular chipped edges follow the wall, without floating decals.
	for spot: Vector4 in [Vector4(-2.51,2.22,0.066,0.095),Vector4(-1.72,0.35,0.16,0.067),Vector4(0.82,2.20,0.079,0.093),Vector4(1.70,0.37,0.12,0.068),Vector4(2.52,0.68,0.062,0.16)]:
		var count: int = 8
		for i: int in range(count):
			var t0: float = -1.0+2.0*i/count; var t1: float = -1.0+2.0*(i+1)/count
			var a: float = sqrt(maxf(0,1-t0*t0))*spot.w*(0.84+0.16*sin(i*3.1+side))
			var b: float = sqrt(maxf(0,1-t1*t1))*spot.w*(0.84+0.16*sin((i+1)*3.1+side))
			var x0: float = spot.x+t0*spot.z; var x1: float = spot.x+t1*spot.z
			var cuts: Array[float] = [x0]
			for cut: int in range(floori((x0+PANEL_HALF)/STEP)+1,ceili((x1+PANEL_HALF)/STEP)): cuts.append(-PANEL_HALF+cut*STEP)
			cuts.append(x1)
			for j: int in range(cuts.size()-1):
				var lo: float = cuts[j]; var hi: float = cuts[j+1]
				var h0: float = lerpf(a,b,(lo-x0)/(x1-x0)); var h1: float = lerpf(a,b,(hi-x0)/(x1-x0))
				PropGeometry.face(tool,[Vector3(lo,spot.y-h0,side*(side_z(lo)+0.001)),Vector3(hi,spot.y-h1,side*(side_z(hi)+0.001)),Vector3(hi,spot.y+h1,side*(side_z(hi)+0.001)),Vector3(lo,spot.y+h0,side*(side_z(lo)+0.001))],RUST.darkened(0.06+0.05*(i%3)),Vector3(0,0,side))

static func _end_wall(tool: SurfaceTool, paint: Color) -> void:
	for col: int in range(24):
		var z0: float = -1.08+col*0.09; var z1: float = z0+0.09
		var x0: float = -2.87-(0.028 if col%4 in [1,2] else 0); var x1: float = -2.87-(0.028 if (col+1)%4 in [1,2] else 0)
		PropGeometry.face(tool,[Vector3(x0,0.23,z0),Vector3(x1,0.23,z1),Vector3(x1,2.36,z1),Vector3(x0,2.36,z0)],paint.darkened(0.025),Vector3.LEFT)
	for h: float in [0.16,2.44]: PropGeometry.box(tool,Vector3(-2.90,h,0),Vector3(0.15,0.15,2.20),paint.darkened(0.18),0.022)

static func _doors(tool: SurfaceTool, paint: Color) -> void:
	for side: float in [-1.0,1.0]:
		var center: float = side*0.56
		PropGeometry.box(tool,Vector3(2.889,1.30,center),Vector3(0.038,2.16,1.07),Color("263739"),0.016)
		PropGeometry.box(tool,Vector3(2.912,1.30,center),Vector3(0.025,2.09,0.99),paint,0.018)
		for z: float in [side*0.055,side*1.065]:
			PropGeometry.box(tool,Vector3(2.933,1.30,z),Vector3(0.027,2.13,0.065),paint.darkened(0.08),0.012)
		for h: float in [0.265,2.335]: PropGeometry.box(tool,Vector3(2.933,h,center),Vector3(0.027,0.065,1.075),paint.darkened(0.09),0.012)
		for z: float in [side*0.27,side*0.80]:
			PropGeometry.tube(tool,Vector3(2.969,0.30,z),Vector3(2.969,2.31,z),0.018,0.018,STEEL,8)
			for h: float in [0.38,0.96,1.62,2.22]: PropGeometry.box(tool,Vector3(2.961,h,z),Vector3(0.030,0.105,0.065),STEEL.darkened(0.12),0.008)
			PropGeometry.beam(tool,Vector3(2.977,1.06,z),Vector3(2.977,1.06,z+side*0.19),0.032,0.022,STEEL.darkened(0.18))
		for h: float in [0.46,1.20,1.99]:
			PropGeometry.box(tool,Vector3(2.948,h,side*1.066),Vector3(0.057,0.115,0.17),STEEL.lerp(RUST,0.36),0.012)
	# Safety placard is original and decorative, not a claimed live cargo rating.
	PropGeometry.box(tool,Vector3(2.936,0.62,-0.55),Vector3(0.008,0.19,0.22),Color("baa767"),0.008)
	for i: int in range(3): PropGeometry.beam(tool,Vector3(2.942,0.55+i*0.045,-0.63),Vector3(2.942,0.55+i*0.045,-0.48),0.012,0.008,Color("384542"))

static func _surface_rect(tool: SurfaceTool, a: Vector2, b: Vector2, side: float, pigment: Color) -> void:
	# Opposite wall print orientation: readable from outside both long faces.
	if side < 0:
		var left: float = -b.x
		b.x = -a.x; a.x = left
	var cuts: Array[float] = [a.x]
	var start: int = floori((a.x+PANEL_HALF)/STEP)+1
	var end: int = ceili((b.x+PANEL_HALF)/STEP)
	for i: int in range(start,end): cuts.append(-PANEL_HALF+i*STEP)
	cuts.append(b.x)
	for i: int in range(cuts.size()-1):
		var x0: float = cuts[i]; var x1: float = cuts[i+1]
		PropGeometry.face(tool,[Vector3(x0,a.y,side*(side_z(x0)+0.0015)),Vector3(x1,a.y,side*(side_z(x1)+0.0015)),Vector3(x1,b.y,side*(side_z(x1)+0.0015)),Vector3(x0,b.y,side*(side_z(x0)+0.0015))],pigment,Vector3(0,0,side))

static func _word(tool: SurfaceTool, text: String, base: Vector2, pixel: float, side: float, pigment: Color) -> void:
	for letter: int in range(text.length()):
		var rows: Array = GLYPHS[text.substr(letter,1)]
		for y: int in range(7):
			var x: int = 0
			while x < 5:
				if rows[y].substr(x,1) != "1": x += 1; continue
				var start: int = x
				while x < 5 and rows[y].substr(x,1) == "1": x += 1
				var low: Vector2 = base+Vector2(letter*6+start,6-y)*pixel
				_surface_rect(tool,low,low+Vector2(x-start,1)*pixel,side,pigment)

static func _logo(tool: SurfaceTool, paint: Color, side: float) -> void:
	# Original fictional BMT CARGO mark, printed onto the corrugation itself.
	var value: float = paint.r*0.2126+paint.g*0.7152+paint.b*0.0722
	var ink := Color("e1dfc9") if value < 0.53 else Color("293e43")
	_word(tool,"BMT",Vector2(-0.30,1.10),0.082,side,ink)
	_word(tool,"CARGO",Vector2(-0.29,0.76),0.038,side,ink)
	for line: Array in [[Vector2(-1.48,1.21),Vector2(-0.80,1.27)],[Vector2(-1.41,1.34),Vector2(-0.73,1.40)],[Vector2(-1.33,1.47),Vector2(-0.66,1.53)]]:
		_surface_rect(tool,line[0],line[1],side,ink)
