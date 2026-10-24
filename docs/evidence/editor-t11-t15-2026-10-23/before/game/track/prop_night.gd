class_name PropNight
extends RefCounted
## Original Night furniture. Vertex alpha selects opaque finish/emissive glass.
const KINDS: Array[String] = ["firefly_bush","burning_barrel","lantern_post","neon_arrow","burning_car","abandoned_warehouse"]
const STEEL := Color(0.24,0.29,0.32,0.0)
const SOOT := Color(0.065,0.075,0.085,0.0)
const RUST := Color(0.30,0.15,0.08,0.0)
const WARM := Color(1.0,0.43,0.10,0.6)
const NEON := Color(0.16,0.85,0.80,0.9)
static var surface: ShaderMaterial

static func material() -> ShaderMaterial:
	if surface == null:
		surface=ShaderMaterial.new(); surface.shader=preload("res://track/night_prop_surface.gdshader")
	return surface

static func append(tool: SurfaceTool, kit: Node, kind: String, center: Vector3, scale: float, turn: float) -> bool:
	if kind not in KINDS: return false
	var local:=SurfaceTool.new(); local.begin(Mesh.PRIMITIVE_TRIANGLES)
	match kind:
		"firefly_bush": _bush(local,kit)
		"burning_barrel": _barrel(local)
		"burning_car": _burning_car(local,kit)
		"abandoned_warehouse": PropWarehouse.build(local)
		"lantern_post": _lantern(local)
		"neon_arrow": _neon(local)
	PropGeometry.append_transformed(tool,local,center,scale,turn)
	return true

static func _burning_car(tool: SurfaceTool, kit: Node) -> void:
	# Retain the original wreck's crushed roofline, missing wheel, bent hood and
	# fitted chassis details. Open the actual engine bay and roof before burning.
	var original:=SurfaceTool.new(); original.begin(Mesh.PRIMITIVE_TRIANGLES)
	PropStructures.append(original,kit,"car_wreck",Vector3.ZERO,1,0,false)
	var arrays: Array=original.commit_to_arrays()
	var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var pigments: PackedColorArray=arrays[Mesh.ARRAY_COLOR]
	var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
	var count: int=indices.size() if not indices.is_empty() else points.size()
	for i: int in range(0,count,3):
		var ids: Array[int]=[]
		for j: int in range(3): ids.append(indices[i+j] if not indices.is_empty() else i+j)
		var hood: bool=true; var roof: bool=true
		for id: int in ids:
			var p: Vector3=points[id]
			hood=hood and p.x>=0.979 and absf(p.y-(0.88-(p.x-0.98)*0.08/1.12))<0.002
			roof=roof and absf(p.y-1.15)<0.002 and p.x>=-0.901 and p.x<=0.101 and absf(p.z)<=0.681
		if hood or roof: continue
		for id: int in ids:
			var p: Vector3=points[id]
			var heat: float=exp(-Vector2(p.x-1.35,p.z).length_squared()*1.8)
			var color: Color=pigments[id].lerp(Color("2b2b29"),0.70+0.20*heat)
			color=color.lerp(Color("68503b"),heat*0.26); color.a=0.0
			tool.set_color(color); tool.set_normal(normals[id]); tool.set_smooth_group(-1); tool.add_vertex(p)
	# Seats and exposed fuel sit below the opened cabin/engine apertures.
	for z: float in [-0.34,0.34]:
		PropGeometry.box(tool,Vector3(-0.25,0.68,z),Vector3(0.50,0.18,0.43),SOOT,0.07)
		PropGeometry.beam(tool,Vector3(-0.55,0.65,z),Vector3(-0.60,1.06,z),0.08,0.30,STEEL.darkened(0.55))
	for i: int in range(6):
		var x: float=1.18+(i%3)*0.17; var z: float=-0.22+(i/3)*0.35
		PropGeometry.box(tool,Vector3(x,0.96,z),Vector3(0.12,0.025,0.11),WARM,0.012)
	PropGeometry.beam(tool,Vector3(-0.73,0.91,-0.45),Vector3(-0.12,0.91,0.43),0.016,0.014,WARM.darkened(0.28))

static func _bush(tool: SurfaceTool, _kit: Node) -> void:
	# Real attached folded foliage and exposed woody branch ends, no alpha cards.
	for branch: int in range(18):
		var angle: float=branch*2.39996
		var tip:=Vector3(cos(angle)*(0.65+(branch%3)*0.09),0.55+(branch%5)*0.14,sin(angle)*(0.65+(branch%3)*0.09))
		var root:=Vector3(cos(angle)*0.07,0.03,sin(angle)*0.07)
		var elbow: Vector3=root.lerp(tip,0.44)+Vector3.UP*0.13
		PropGeometry.tube(tool,root,elbow,0.024,0.015,Color(0.29,0.24,0.16,0),7)
		PropGeometry.tube(tool,elbow,tip,0.015,0.004,Color(0.34,0.29,0.19,0),7)
		for leaf: int in range(11):
			var t: float=0.20+leaf*0.075
			var p: Vector3=elbow.lerp(tip,(t-0.5)*2.0) if t>0.5 else root.lerp(elbow,t*2.0)
			var axis:=Vector3(cos(angle+(-0.9 if leaf%2==0 else 0.9)),0.35+0.2*sin(leaf*2.1),sin(angle+(-0.9 if leaf%2==0 else 0.9))).normalized()
			var side: Vector3=axis.cross(Vector3.UP).normalized()
			var length: float=0.27+(leaf%3)*0.032
			var pigment:=Color(0.24+(branch%3)*0.025,0.38+(leaf%3)*0.025,0.25+(branch%4)*0.018,0)
			_leaf(tool,p,axis,side,length,pigment)

static func _leaf(tool: SurfaceTool, p: Vector3, axis: Vector3, side: Vector3, length: float, pigment: Color) -> void:
	var widths: Array[float]=[0.0,0.061,0.086,0.071,0.037,0.0]
	for row: int in range(5):
		var t: float=row/5.0; var next: float=(row+1)/5.0
		var a: Vector3=p+axis*length*t+Vector3.UP*sin(t*PI)*0.027
		var b: Vector3=p+axis*length*next+Vector3.UP*sin(next*PI)*0.027
		var ar: Vector3=a+Vector3.UP*sin(t*PI)*0.017
		var br: Vector3=b+Vector3.UP*sin(next*PI)*0.017
		for sign_value: float in [-1.0,1.0]:
			var lo: Vector3=a+side*widths[row]*sign_value
			var hi: Vector3=b+side*widths[row+1]*sign_value
			if row==0: _surface(tool,[ar,hi,br],pigment,Vector3.UP,1)
			elif row==4: _surface(tool,[ar,lo,br],pigment,Vector3.UP,1)
			else: _surface(tool,[ar,lo,hi,br],pigment.darkened(0.09 if sign_value<0 else 0.0),Vector3.UP,1)

static func _surface(tool: SurfaceTool, points: Array, color: Color, outward: Vector3, group: int) -> void:
	tool.set_smooth_group(group); tool.set_color(color)
	var flip: bool=(points[1]-points[0]).cross(points[2]-points[0]).dot(outward)<0
	for i: int in range(1,points.size()-1):
		for j: int in ([0,i,i+1] if flip else [0,i+1,i]): tool.add_vertex(points[j])

static func _barrel(tool: SurfaceTool) -> void:
	# An open, double-walled rolled drum; fuel and light sit below the rim.
	var profile: Array[Vector2]=[Vector2(0.46,0.03),Vector2(0.50,0.07),Vector2(0.50,0.12),Vector2(0.485,0.15),Vector2(0.49,0.42),Vector2(0.515,0.45),Vector2(0.515,0.49),Vector2(0.49,0.52),Vector2(0.49,0.76),Vector2(0.51,0.79),Vector2(0.51,0.83),Vector2(0.49,0.85),Vector2(0.48,1.03),Vector2(0.50,1.045),Vector2(0.50,1.075),Vector2(0.463,1.075),Vector2(0.453,1.04),Vector2(0.457,0.25)]
	for row: int in range(profile.size()-1):
		for i: int in range(40):
			var a: float=TAU*i/40; var b: float=TAU*(i+1)/40
			var lo: Vector2=profile[row]; var hi: Vector2=profile[row+1]
			var pigment: Color=SOOT if row>14 else STEEL.lerp(RUST,0.20+0.22*sin(i*1.71+row*0.35)).darkened(0.48 if row>10 else 0.0)
			var normal:=Vector3(cos((a+b)*0.5)*(hi.y-lo.y),lo.x-hi.x,sin((a+b)*0.5)*(hi.y-lo.y))
			_surface(tool,[Vector3(cos(a)*lo.x,lo.y,sin(a)*lo.x),Vector3(cos(b)*lo.x,lo.y,sin(b)*lo.x),Vector3(cos(b)*hi.x,hi.y,sin(b)*hi.x),Vector3(cos(a)*hi.x,hi.y,sin(a)*hi.x)],pigment,normal,row+100)
	PropGeometry.tube(tool,Vector3(0,0.22,0),Vector3(0,0.24,0),0.45,0.45,SOOT,40)
	for i: int in range(7):
		var a: float=i*2.39996
		var p:=Vector3(cos(a)*0.21,0.69+(i%3)*0.055,sin(a)*0.21)
		var axis:=Vector3(cos(a+0.4),0.14,sin(a+0.4))*0.25
		PropGeometry.tube(tool,p-axis,p+axis,0.075,0.06,SOOT.lightened(0.05*(i%3)),9)
		PropGeometry.tube(tool,p-axis*0.85+Vector3.UP*0.035,p+axis*0.75+Vector3.UP*0.035,0.014,0.006,WARM,6)
	# Welded side seam, rust runs and a real folded seam on the outer sheet.
	PropGeometry.beam(tool,Vector3(0,0.14,0.492),Vector3(0,1.02,0.485),0.018,0.009,RUST)
	for i: int in range(13):
		var a: float=i*2.39996; var y: float=0.18+(i%5)*0.13
		var p:=Vector3(cos(a)*0.493,y,sin(a)*0.493)
		PropGeometry.tube(tool,p,p+Vector3.UP*(0.04+(i%3)*0.028),0.009,0.002,RUST,5)

static func _lantern(tool: SurfaceTool) -> void:
	PropGeometry.box(tool,Vector3(0,0.08,0),Vector3(0.48,0.16,0.48),STEEL,0.045)
	PropGeometry.tube(tool,Vector3(0,0.14,0),Vector3(0,2.75,0),0.074,0.05,STEEL,16)
	for h: float in [0.22,0.40,2.46]: PropGeometry.ring(tool,Vector3(0,h,0),Vector3.UP,0.09,0.055,0.06,STEEL.lightened(0.12))
	var hook: Array[Vector3]=[Vector3(0,2.64,0),Vector3(0.17,2.87,0),Vector3(0.40,2.94,0),Vector3(0.61,2.83,0),Vector3(0.65,2.65,0)]
	for i: int in range(hook.size()-1): PropGeometry.tube(tool,hook[i],hook[i+1],0.028,0.028,STEEL,8)
	PropGeometry.ring(tool,Vector3(0.65,2.57,0),Vector3.FORWARD,0.095,0.071,0.022,STEEL)
	var p:=Vector3(0.65,2.22,0)
	PropGeometry.tube(tool,p-Vector3.UP*0.27,p-Vector3.UP*0.22,0.24,0.22,STEEL,8)
	PropGeometry.tube(tool,p+Vector3.UP*0.20,p+Vector3.UP*0.31,0.28,0.10,STEEL,8)
	PropGeometry.tube(tool,p+Vector3.UP*0.31,p+Vector3.UP*0.35,0.10,0.04,STEEL.lightened(0.1),8)
	# Inset amber panes, with four real metal cage uprights in front.
	PropGeometry.box(tool,p,Vector3(0.30,0.37,0.30),Color(0.76,0.43,0.15,0.4),0.018)
	PropGeometry.tube(tool,p-Vector3.UP*0.16,p+Vector3.UP*0.14,0.055,0.014,WARM,12)
	for x: float in [-0.18,0.18]:
		for z: float in [-0.18,0.18]: PropGeometry.beam(tool,p+Vector3(x,-0.22,z),p+Vector3(x,0.23,z),0.028,0.028,STEEL)
	for h: float in [-0.21,0.20]: PropGeometry.box(tool,p+Vector3.UP*h,Vector3(0.43,0.035,0.43),STEEL,0.025)

static func _neon(tool: SurfaceTool) -> void:
	for x: float in [-0.68,0.68]:
		PropGeometry.box(tool,Vector3(x,0.05,0),Vector3(0.44,0.10,0.65),STEEL,0.04)
		PropGeometry.beam(tool,Vector3(x,0.10,0),Vector3(x,1.20,0),0.085,0.085,STEEL)
	PropGeometry.box(tool,Vector3(0,1.48,0),Vector3(2.0,0.95,0.14),SOOT.lightened(0.06),0.075)
	for side: float in [-1.0,1.0]:
		var z: float=side*0.095
		# Rounded continuous luminous tubes over an inset, bolted backing plate.
		var path: Array[Vector3]=[Vector3(-0.72,1.48,z),Vector3(0.65,1.48,z),Vector3(0.21,1.81,z)]
		for i: int in range(path.size()-1): PropGeometry.tube(tool,path[i],path[i+1],0.030,0.030,NEON,10)
		PropGeometry.tube(tool,Vector3(0.65,1.48,z),Vector3(0.21,1.15,z),0.030,0.030,NEON,10)
		for x: float in [-0.88,0.88]:
			for y: float in [1.12,1.84]: PropGeometry.tube(tool,Vector3(x,y,side*0.073),Vector3(x,y,side*0.087),0.022,0.022,STEEL.lightened(0.25),8)
