class_name CreatorPropVisual
extends RefCounted
## Original shared meshes for world placement and browser thumbnails.
const VERSION: String = "authored-props-1"
const CACHE_LIMIT: int = 96
static var meshes: Dictionary = {}
static var pine_meshes: Dictionary = {}

static func append(tool: SurfaceTool, kit: Node, kind: String, center: Vector3, scale: float, turn: float, section_length: float = -1.0) -> bool:
	var length: float = section_length/scale if section_length >= 0 else -1.0
	var key: String = "%s/%s/%s/%s" % [VERSION,kind,kit.theme_id,str(length)]
	if not meshes.has(key):
		var local := SurfaceTool.new(); local.begin(Mesh.PRIMITIVE_TRIANGLES)
		var found: bool = PropNature.append(local,kit,kind,Vector3.ZERO,1,0)
		if not found: found = PropEquipment.append(local,kit,kind,Vector3.ZERO,1,0,length)
		if not found: found = PropStructures.append(local,kit,kind,Vector3.ZERO,1,0)
		if not found: return false
		local.generate_normals()
		if meshes.size() >= CACHE_LIMIT: meshes.erase(meshes.keys()[0])
		meshes[key] = local.commit()
	tool.append_from(meshes[key],0,Transform3D(Basis(Vector3.UP,turn).scaled(Vector3.ONE*scale),center))
	return true

static func _face(tool: SurfaceTool, kit: Node, center: Vector3, scale: float, turn: float, points: Array, color: Color) -> void:
	var vertices: Array[Vector3] = []
	for point: Vector3 in points: vertices.append(center+(point*scale).rotated(Vector3.UP,turn))
	tool.set_color(color)
	if vertices.size() == 4: kit._quad(tool,vertices[0],vertices[1],vertices[2],vertices[3])
	else:
		for index: int in [0,2,1]: tool.add_vertex(vertices[index])

static func _stone(tool: SurfaceTool, kit: Node, center: Vector3, size: Vector3, turn: float, color: Color) -> void:
	# Three fractured strata and an offset split cap, inside the original footprint.
	var rings: Array = []
	for row: int in range(3):
		var ring: Array[Vector3] = []
		for i: int in range(12):
			var angle: float = TAU*i/12
			var radial: float = 0.92+0.08*sin(i*2.31)
			var reach: float = radial * ([1.0,0.93,0.67][row] + (0.055*sin(i*1.83+row) if row > 0 else 0.0))
			var y: float = [0.0,0.38,0.81][row] + (0.10*sin(i*1.73+row*0.83) if row > 0 else 0.0)
			ring.append(Vector3(cos(angle)*reach+row*0.025,y,sin(angle)*reach-row*0.018)*size)
		rings.append(ring)
	for row: int in range(2):
		for i: int in range(12):
			var j: int = (i+1)%12
			var shade: Color = color.darkened(0.12+0.045*((i+row)%3))
			var a: Vector3 = rings[row][i]; var b: Vector3 = rings[row][j]
			var c: Vector3 = rings[row+1][j]; var d: Vector3 = rings[row+1][i]
			var split: Vector3 = (a+b+c+d)*0.25 + Vector3(cos(i*TAU/12)*0.025,0,sin(i*TAU/12)*0.025)*size
			_leaf_face(tool,kit,center,1,turn,[a,b,split],shade.darkened(0.03))
			_leaf_face(tool,kit,center,1,turn,[b,c,split],shade)
			_leaf_face(tool,kit,center,1,turn,[c,d,split],shade.lightened(0.04))
			_leaf_face(tool,kit,center,1,turn,[d,a,split],shade)
			if row == 1 and i in [1,5,9]:
				var offset := Vector3(cos(i*TAU/12),0,sin(i*TAU/12))*0.004
				_leaf_face(tool,kit,center,1,turn,[a.lerp(d,0.22)+offset,d+offset,d.lerp(c,0.025)+offset],color.darkened(0.42))
	for i: int in range(12):
		var j: int = (i+1)%12
		var cap := Vector3(-0.08,1.0,0.07)*size
		_leaf_face(tool,kit,center,1,turn,[rings[2][i],rings[2][j],cap],color.lightened(0.12+(i%3)*0.04))
	# Short oblique sediment trace sits on one real slope, not a floating decal.
	for i: int in [2,3,7]:
		var a: Vector3 = rings[1][i].lerp(rings[2][i],0.23)
		var b: Vector3 = rings[1][(i+1)%12].lerp(rings[2][(i+1)%12],0.30)
		var offset := Vector3(cos(i*TAU/12)*0.005,0.003,sin(i*TAU/12)*0.005)
		_leaf_face(tool,kit,center,1,turn,[a+offset,b+offset,b+offset+Vector3.UP*size.y*0.009,a+offset+Vector3.UP*size.y*0.009],color.lightened(0.10))

static func _cliff(tool: SurfaceTool, kit: Node, center: Vector3, size: Vector3, turn: float, color: Color) -> void:
	# Continuous rectangular rock wall: exact solid footprint, broken upper ledge.
	var front: Array = []
	var back: Array = []
	for row: int in range(6):
		var f: Array[Vector3] = []
		var b: Array[Vector3] = []
		for i: int in range(7):
			var x: float = -0.5+float(i)/6.0
			var h: float = [0.0,0.25,0.29,0.56,0.61,0.91][row]+(0.14*sin(i*1.9) if row==5 else 0.035*sin(i*1.9) if row>0 else 0.0)
			var z: float = 0.5 if row==0 else [0.5,0.46,0.36,0.43,0.29,0.34][row]+0.035*sin(i*2.4)
			if i>0 and i<6 and row>0: x+=0.025*sin(i*3.2+row*0.8)
			f.append(Vector3(x,h,-z)*size)
			b.append(Vector3(x,h+0.015 if row>0 else 0.0,z)*size)
		front.append(f); back.append(b)
	for row: int in range(5):
		for i: int in range(6):
			var shade: Color = color.darkened(0.27 if i%3==0 else 0.12)
			_leaf_face(tool,kit,center,1,turn,[front[row][i],front[row][i+1],front[row+1][i+1],front[row+1][i]],shade)
			_leaf_face(tool,kit,center,1,turn,[back[row][i+1],back[row][i],back[row+1][i],back[row+1][i+1]],shade.darkened(0.10))
		for i: int in [0,6]:
			var points: Array = [front[row][i],back[row][i],back[row+1][i],front[row+1][i]]
			if i==0: points.reverse()
			_leaf_face(tool,kit,center,1,turn,points,color.darkened(0.30))
	for i: int in range(6):
		_leaf_face(tool,kit,center,1,turn,[front[5][i],front[5][i+1],back[5][i+1],back[5][i]],color.lightened(0.22))
	for row: int in [0,2,4]:
		for i: int in [1,3,5]:
			for side: int in [-1,1]:
				var rings: Array = front if side<0 else back
				var lo: Vector3 = rings[row][i].lerp(rings[row][i+1],0.45)
				var hi: Vector3 = rings[row+1][i].lerp(rings[row+1][i+1],0.30)
				var offset := Vector3(0,0,side*0.015)
				var points: Array = [lo.lerp(hi,0.18)+offset,hi+offset,hi+Vector3(size.x*0.008,0,side*0.015)]
				if side>0: points.reverse()
				_leaf_face(tool,kit,center,1,turn,points,color.darkened(0.55))
	# Narrow, interrupted sediment seams on both faces.
	for row: int in [2,4]:
		for i: int in range(6):
			if (i+row)%4==0: continue
			for side: int in [-1,1]:
				var ring: Array = front[row] if side<0 else back[row]
				var a: Vector3 = ring[i]+Vector3(0,0,side*0.012)
				var b: Vector3 = ring[i+1]+Vector3(0,0,side*0.012)
				var points: Array = [a,b,b+Vector3.UP*size.y*0.013,a+Vector3.UP*size.y*0.013]
				if side>0: points.reverse()
				_leaf_face(tool,kit,center,1,turn,points,color.darkened(0.47))

static func _crown(tool: SurfaceTool, kit: Node, center: Vector3, size: Vector3, turn: float, color: Color) -> void:
	# Serrated canopy edge with a single broad light plane and dark underside.
	# Deliberately no rounded rings or spherical leaf clusters.
	var rim: Array[Vector3] = []
	var upper: Array[Vector3] = []
	for i: int in range(18):
		var angle: float = TAU*i/18.0
		var radius: float = (1.0 if i%3 != 1 else 0.77)*(0.91+0.09*sin(i*2.1))
		rim.append(Vector3(cos(angle)*radius,0.24+0.08*sin(i*1.7),sin(angle)*radius)*size)
		upper.append(Vector3(cos(angle)*radius*0.57,0.73+0.07*sin(i*0.9),sin(angle)*radius*0.57)*size)
	for i: int in range(18):
		var j: int = (i+1)%18
		var side_color: Color = color.lightened(0.12) if cos(TAU*i/18.0+turn)>0.2 else color.darkened(0.22)
		_leaf_face(tool,kit,center,1,turn,[rim[i],rim[j],upper[j],upper[i]],side_color)
		_leaf_face(tool,kit,center,1,turn,[upper[i],upper[j],Vector3(-0.13,0.90,0.04)*size],color.lightened(0.26))
		_leaf_face(tool,kit,center,1,turn,[rim[j],rim[i],Vector3(0,0.0,0)*size],color.darkened(0.43))

static func pine(tool: SurfaceTool, kit: Node, center: Vector3, scale: float, turn: float, color: Color) -> void:
	var key: String = color.to_html()
	if not pine_meshes.has(key):
		var local := SurfaceTool.new(); local.begin(Mesh.PRIMITIVE_TRIANGLES)
		_pine_model(local,kit,Vector3.ZERO,1,0,color)
		local.generate_normals()
		if pine_meshes.size() >= 32: pine_meshes.erase(pine_meshes.keys()[0])
		pine_meshes[key] = local.commit()
	tool.append_from(pine_meshes[key],0,Transform3D(Basis(Vector3.UP,turn).scaled(Vector3.ONE*scale),center))

static func _pine_model(tool: SurfaceTool, kit: Node, center: Vector3, scale: float, turn: float, color: Color) -> void:
	_lathe(tool,kit,center,scale,turn,[Vector2(0.16,0),Vector2(0.10,2.7),Vector2(0,3.2)],[Color("65513c"),Color("8e7951")],true)
	var branches := SurfaceTool.new(); branches.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(7):
		var a: float = i*2.4
		PropGeometry.tube(branches,Vector3(0,0.035,0),Vector3(cos(a)*0.24,0.008,sin(a)*0.24),0.055,0.014,Color("63523e"),6)
	# Swept, tapered boughs: dark lower blades and connected upper ridges.
	for tier: int in range(5):
		var radius: float = 1.02-tier*0.17
		var height: float = 0.66+tier*0.49
		for branch: int in range(7):
			var angle: float = turn+branch*TAU/7.0+tier*0.63
			var reach: float = radius*(0.91+0.09*sin(branch*2.7+tier))
			var points: Array[Vector3] = [Vector3(-0.15,height+0.47,0),Vector3(reach*0.63,height+0.12,-reach*0.36),Vector3(reach,height-0.10,-reach*0.13),Vector3(reach*0.83,height-0.02,reach*0.08),Vector3(reach*0.95,height-0.15,reach*0.24),Vector3(reach*0.45,height+0.04,reach*0.40)]
			var ridge := Vector3(reach*0.38,height+0.37,0)
			PropGeometry.tube(branches,Vector3(0,height+0.10,0),Vector3(reach*0.77,height-0.045,0).rotated(Vector3.UP,angle-turn),0.025,0.007,Color("746044"),6)
			for i: int in range(points.size()):
				var j: int = (i+1)%points.size()
				var shade: Color = color.lightened(0.23) if i<3 else color.darkened(0.12)
				_leaf_face(tool,kit,center,scale,angle,[points[i],points[j],ridge],shade)
				_leaf_face(tool,kit,center,scale,angle,[points[j],points[i],Vector3(0,height-0.02,0)],color.darkened(0.40))
			# Split needle tips, rather than a single unbroken triangular blade.
			for spray: int in range(3):
				var p := Vector3(reach*(0.47+spray*0.17),height+0.14-spray*0.075,reach*(-0.19+spray*0.16))
				_leaf_face(tool,kit,center,scale,angle,[p+Vector3(-0.17,0.06,-0.05),p+Vector3(0.16,-0.06,-0.09),p+Vector3(0.13,-0.08,0.09),p+Vector3(-0.13,0.07,0.06)],color.lightened(0.17+(spray%2)*0.06))
	# Small pointed leader rather than a round cap.
	_lathe(tool,kit,center,scale,turn,[Vector2(0.22,2.65),Vector2(0.0,3.3)],[color.lightened(0.20)],true)
	PropGeometry.append_transformed(tool,branches,center,scale,turn)

static func _lathe(tool: SurfaceTool, kit: Node, center: Vector3, scale: float, turn: float, profile: Array, colors: Array, reverse: bool = false) -> void:
	for row: int in range(profile.size()-1):
		for i: int in range(20):
			var a: float=TAU*i/20+turn
			var b: float=TAU*(i+1)/20+turn
			var lo: Vector2=profile[row]
			var hi: Vector2=profile[row+1]
			tool.set_color(colors[row])
			var points: Array[Vector3] = [Vector3(cos(a)*lo.x,lo.y,sin(a)*lo.x),Vector3(cos(b)*lo.x,lo.y,sin(b)*lo.x),Vector3(cos(b)*hi.x,hi.y,sin(b)*hi.x),Vector3(cos(a)*hi.x,hi.y,sin(a)*hi.x)]
			if reverse: points.reverse()
			kit._quad(tool,center+points[0]*scale,center+points[1]*scale,center+points[2]*scale,center+points[3]*scale)

static func _roof(tool: SurfaceTool, kit: Node, center: Vector3, scale: float, turn: float, width: float, depth: float, color: Color) -> void:
	var count: int=ceili(width/0.4)
	for side: float in [-1.0,1.0]:
		for i: int in range(count):
			var x0: float=lerpf(-width*0.5-0.15,width*0.5+0.15,float(i)/count)
			var x1: float=lerpf(-width*0.5-0.15,width*0.5+0.15,float(i+1)/count)
			var points: Array[Vector3]=[Vector3(x0,3.02,side*(depth*0.5+0.15)),Vector3(x1,3.02,side*(depth*0.5+0.15)),Vector3(x1,4.0,0),Vector3(x0,4.0,0)]
			if side<0: points.reverse()
			for j: int in range(4): points[j]=center+(points[j]*scale).rotated(Vector3.UP,turn)
			tool.set_color(color.lightened((i%3)*0.025).darkened(0.08 if side<0 else 0))
			kit._quad(tool,points[0],points[1],points[2],points[3])

static func _leaf_face(tool: SurfaceTool, kit: Node, center: Vector3, scale: float, turn: float, points: Array, color: Color) -> void:
	# Godot's clockwise front faces must point outwards for the ink hull.
	points.reverse()
	_face(tool,kit,center,scale,turn,points,color)
