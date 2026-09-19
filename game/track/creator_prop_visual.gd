class_name CreatorPropVisual
extends RefCounted
## Original shared meshes for world placement and browser thumbnails.
static func append(tool: SurfaceTool, kit: Node, kind: String, center: Vector3, scale: float, turn: float) -> bool:
	var wood := Color("887354")
	var metal := Color("858b87")
	var leaf: Color = TrackTheme.foliage(kit.theme_id).lightened(0.08)
	var stone: Color = TrackTheme.stone(kit.theme_id)
	var box: Callable = func(p: Vector3, size: Vector3, color: Color) -> void:
		kit._colored_box(tool,center+(p*scale).rotated(Vector3.UP,turn),size*scale,turn,color)
	var mound: Callable = func(p: Vector3, size: Vector3, color: Color) -> void:
		kit._mound(tool,center+(p*scale).rotated(Vector3.UP,turn),size*scale,turn,color)
	match kind:
		"rock", "boulder", "slate", "cliff":
			var bounds: Vector2 = CreatorObjects.dimensions(kind)
			var height: float = {"rock":0.7,"boulder":2.1,"slate":0.85,"cliff":4.0}[kind]
			if kind == "cliff":
				_cliff(tool,kit,center,Vector3(bounds.x,height,bounds.y)*scale,turn,stone)
			else:
				_stone(tool,kit,center,Vector3(bounds.x*0.5,height,bounds.y*0.5)*scale,turn,stone)
		"broadleaf":
			_lathe(tool,kit,center,scale,turn,[Vector2(0.32,0),Vector2(0.21,1.4),Vector2(0.11,2.7),Vector2(0,2.8)],[wood.darkened(0.26),wood,wood],true)
			for i: int in range(6):
				var angle: float=i*2.4
				var radius: float=0.20 if i>3 else 0.78
				_crown(tool,kit,center+(Vector3(sin(angle)*radius,1.85+(i%3)*0.34,cos(angle)*radius)*scale).rotated(Vector3.UP,turn),Vector3(1.03,0.78,0.92)*scale,turn+angle,leaf.lightened((i%3)*0.045))
		"bush":
			for p: Vector3 in [Vector3(-0.4,0,0),Vector3(0.4,0,0.2),Vector3(0,0,-0.3)]: _crown(tool,kit,center+(p*scale).rotated(Vector3.UP,turn),Vector3(0.6,0.75,0.6)*scale,turn+p.x,leaf)
		"grass_clump", "flowers":
			for i: int in range(7):
				var p := Vector3(sin(i*2.4)*0.35,0.25,cos(i*2.4)*0.35)
				_face(tool,kit,center,scale,turn,[Vector3(p.x-0.055,0,p.z),Vector3(p.x+0.055,0,p.z),Vector3(p.x+sin(i)*0.18,0.55+0.035*i,p.z+0.12)],leaf.lightened((i%3)*0.08))
				_face(tool,kit,center,scale,turn,[Vector3(p.x,0,p.z-0.06),Vector3(p.x,0,p.z+0.06),Vector3(p.x-0.16,0.48+0.035*i,p.z)],leaf)
				if kind == "flowers": mound.call(p+Vector3.UP*0.25,Vector3(0.12,0.08,0.12),Color("c7bc80"))
		"pebbles":
			for i: int in range(5): mound.call(Vector3(sin(i*2.4)*0.3,0,cos(i*2.4)*0.3),Vector3(0.12,0.08,0.14),stone)
		"log":
			# Bark and inset end grain, with a real round cross-section.
			for i: int in range(10):
				var a: float = TAU*i/10.0
				var b: float = TAU*(i+1)/10.0
				var p := Vector3(0,0.42+cos(a)*0.4,sin(a)*0.4)
				var q := Vector3(0,0.42+cos(b)*0.4,sin(b)*0.4)
				_face(tool,kit,center,scale,turn,[p+Vector3.LEFT*2,q+Vector3.LEFT*2,q+Vector3.RIGHT*2,p+Vector3.RIGHT*2],wood.darkened(0.18+(i%3)*0.06))
				for side: float in [-1.0,1.0]:
					_face(tool,kit,center,scale,turn,[Vector3(side*2.005,0.42,0),p+Vector3.RIGHT*side*2.005,q+Vector3.RIGHT*side*2.005],Color("bda079"))
		"barrier":
			# Original solid block and three red bands; graphic shadow foot and bevel.
			box.call(Vector3(0,0.43,0),Vector3(6,0.86,1),Color("a8aaa0"))
			box.call(Vector3(0,0.10,0),Vector3(6.005,0.20,1.005),Color("505d59"))
			box.call(Vector3(0,0.885,0),Vector3(5.94,0.07,0.88),Color("d9d7c4"))
			for side: float in [-1.0,1.0]:
				_face(tool,kit,center,scale,turn,[Vector3(-3,0.85,side*0.5),Vector3(3,0.85,side*0.5),Vector3(2.97,0.92,side*0.44),Vector3(-2.97,0.92,side*0.44)],Color("c8c9b9"))
			for x: int in [-2,0,2]:
				box.call(Vector3(x,0.775,0),Vector3(0.9,0.30,1.018),Color("9d392c"))
				box.call(Vector3(x,0.935,0),Vector3(0.9,0.025,1.018),Color("cf6045"))
		"guardrail", "wire_fence":
			for x: float in [-2.9,0,2.9]: box.call(Vector3(x,0.7,0),Vector3(0.12,1.4,0.12),metal.darkened(0.2))
			if kind == "guardrail":
				box.call(Vector3(0,0.8,0),Vector3(6,0.42,0.10),metal.darkened(0.15))
				for h: float in [0.66,0.94]: box.call(Vector3(0,h,0.015),Vector3(6,0.10,0.17),metal.lightened(0.1))
				for x: float in [-2.9,0,2.9]: box.call(Vector3(x,0.8,0.072),Vector3(0.07,0.07,0.035),Color("d1cfbd"))
			else:
				for h: float in [0.3,0.6,0.9,1.2]: box.call(Vector3(0,h,0),Vector3(6,0.025,0.025),metal)
				for x: int in range(-5,6): box.call(Vector3(x*0.5,0.75,0),Vector3(0.02,0.9,0.02),metal)
		"cone":
			box.call(Vector3(0,0.06,0),Vector3(0.7,0.12,0.7),Color("303837"))
			_lathe(tool,kit,center,scale,turn,[Vector2(0.29,0.12),Vector2(0.22,0.38),Vector2(0.16,0.57),Vector2(0.045,0.88),Vector2(0,0.88)],[Color("cc6b32"),Color("e9e7d7"),Color("cc6b32"),Color("cc6b32")])
		"chevron", "braking_board", "banner":
			var width: float = 4.0 if kind == "banner" else 1.5
			for x: float in [-0.4,0.4]: box.call(Vector3(x*width,0.6,0),Vector3(0.08,1.2,0.08),metal)
			box.call(Vector3(0,1.15,0),Vector3(width,0.8,0.12),Color("d5d8c7"))
			for side: float in [-1.0,1.0]:
				if kind == "chevron":
					for x: float in [-0.42,0.18]:
						_face(tool,kit,center,scale,turn,[Vector3(x-0.16,0.83,side*0.065),Vector3(x+0.04,0.83,side*0.065),Vector3(x+0.30,1.15,side*0.065),Vector3(x+0.10,1.15,side*0.065)],Color("303c3d"))
						_face(tool,kit,center,scale,turn,[Vector3(x+0.10,1.15,side*0.065),Vector3(x+0.30,1.15,side*0.065),Vector3(x+0.04,1.47,side*0.065),Vector3(x-0.16,1.47,side*0.065)],Color("303c3d"))
				else:
					for x: float in [-0.3,0,0.3]: box.call(Vector3(x*width,1.15,side*0.07),Vector3(0.14,0.48,0.02),Color("38484a"))
		"flag":
			box.call(Vector3(0,1.5,0),Vector3(0.07,3,0.07),metal)
			box.call(Vector3(0.4,2.7,0),Vector3(0.8,0.45,0.035),Color("b7a171"))
		"light":
			box.call(Vector3(0,2.4,0),Vector3(0.2,4.8,0.2),metal)
			box.call(Vector3(0.4,4.8,0),Vector3(1,0.2,0.4),Color("c8c9b2"))
		"gantry":
			for x: float in [-5.7,5.7]: box.call(Vector3(x,2.5,0),Vector3(0.6,5,1),metal)
			box.call(Vector3(0,4.8,0),Vector3(12,0.8,0.4),Color("d7d8c8"))
			for x: int in range(-5,6): box.call(Vector3(x,4.8,-0.22),Vector3(0.45,0.75,0.02),Color("354344"))
		"crate":
			box.call(Vector3(0,0.5,0),Vector3(1.06,0.98,1.06),wood.darkened(0.3))
			for side: float in [-1.0,1.0]:
				for i: int in range(5):
					box.call(Vector3(-0.44+i*0.22,0.5,side*0.54),Vector3(0.20,0.95,0.035),wood.lightened((i%2)*0.06))
				for h: float in [0.12,0.88]: box.call(Vector3(0,h,side*0.58),Vector3(1.1,0.13,0.06),wood.lightened(0.16))
			for i: int in range(5): box.call(Vector3(-0.44+i*0.22,1.0,0),Vector3(0.20,0.05,1.1),wood.lightened(0.08))
		"barrel":
			_lathe(tool,kit,center,scale,turn,[Vector2(0.48,0),Vector2(0.51,0.18),Vector2(0.54,0.25),Vector2(0.51,0.32),Vector2(0.51,0.76),Vector2(0.54,0.83),Vector2(0.51,0.90),Vector2(0.48,1.08),Vector2(0,1.08)],[wood,metal,metal,wood,metal,metal,wood,metal])
		"pallet":
			for z: float in [-0.52,0.52]: box.call(Vector3(0,0.06,z),Vector3(1.9,0.12,0.16),wood.darkened(0.15))
			for x: int in range(5): box.call(Vector3(-0.8+x*0.4,0.14,0),Vector3(0.3,0.16,1.4),wood)
		"parked_car", "van":
			var length: float = 4.2 if kind == "parked_car" else 5.0
			box.call(Vector3(0,0.55,0),Vector3(length,0.65,1.8),Color("8e9f9a"))
			var roof_y: float = 1.55 if kind == "parked_car" else 2.12
			var rear: float = -1.48 if kind == "parked_car" else -2.18
			var roof_rear: float = rear+0.28
			_face(tool,kit,center,scale,turn,[Vector3(roof_rear,roof_y,-0.65),Vector3(0.38,roof_y,-0.65),Vector3(0.38,roof_y,0.65),Vector3(roof_rear,roof_y,0.65)],Color("a1afa4"))
			_face(tool,kit,center,scale,turn,[Vector3(0.92,0.90,-0.76),Vector3(0.92,0.90,0.76),Vector3(0.38,roof_y,0.65),Vector3(0.38,roof_y,-0.65)],Color("314c58"))
			_face(tool,kit,center,scale,turn,[Vector3(rear,0.90,0.76),Vector3(rear,0.90,-0.76),Vector3(roof_rear,roof_y,-0.65),Vector3(roof_rear,roof_y,0.65)],Color("42545a"))
			box.call(Vector3(1.65,0.9,0),Vector3(0.6,0.04,1.6),Color("9baea8"))
			for z: float in [-0.76,0.76]:
				_face(tool,kit,center,scale,turn,[Vector3(rear,0.9,z),Vector3(0.92,0.9,z),Vector3(0.38,roof_y,signf(z)*0.65),Vector3(roof_rear,roof_y,signf(z)*0.65)],Color("8e9f9a"))
				_face(tool,kit,center,scale,turn,[Vector3(rear+0.19,1.02,z*0.98),Vector3(0.70,1.02,z*0.98),Vector3(0.27,roof_y-0.1,signf(z)*0.68),Vector3(roof_rear+0.1,roof_y-0.1,signf(z)*0.68)],Color("314c58"))
				box.call(Vector3(1.1,1.0,z*1.3),Vector3(0.25,0.15,0.18),Color("687e78"))
			for z: float in [-0.6,0.6]:
				box.call(Vector3(length*0.5+0.01,0.64,z),Vector3(0.035,0.18,0.36),Color("e1dfba"))
				box.call(Vector3(-length*0.5-0.01,0.64,z),Vector3(0.035,0.18,0.3),Color("9b4438"))
			for z: float in [-0.73,0.73]: box.call(Vector3(-0.25,(roof_y+0.94)*0.5,z),Vector3(0.10,roof_y-0.94,0.035),Color("8e9f9a"))
			for x: float in [-1.3,1.3]:
				for z: float in [-0.9,0.9]:
					for i: int in range(12):
						var a: float = TAU*i/12.0
						var b: float = TAU*(i+1)/12.0
						var p := Vector3(x+cos(a)*0.34,0.34+sin(a)*0.34,z)
						var q := Vector3(x+cos(b)*0.34,0.34+sin(b)*0.34,z)
						_face(tool,kit,center,scale,turn,[p-Vector3.BACK*0.12,q-Vector3.BACK*0.12,q+Vector3.BACK*0.12,p+Vector3.BACK*0.12],Color("242e2f"))
						_face(tool,kit,center,scale,turn,[Vector3(x,0.34,z+signf(z)*0.125),p+Vector3.BACK*signf(z)*0.125,q+Vector3.BACK*signf(z)*0.125],Color("394243"))
					box.call(Vector3(x,0.34,z+signf(z)*0.13),Vector3(0.20,0.20,0.025),metal)
		"container":
			box.call(Vector3(0,1.3,0),Vector3(6,2.6,2.5),Color("6a8279"))
			for side: float in [-1.0,1.0]:
				for x: int in range(-7,8): box.call(Vector3(x*0.38,1.3,side*1.26),Vector3(0.11,2.4,0.06),Color("7e9183"))
				for h: float in [0.08,2.52]: box.call(Vector3(0,h,side*1.27),Vector3(6,0.16,0.08),Color("415b54"))
				for z: float in [-0.58,0.58]: box.call(Vector3(side*3.02,1.3,z),Vector3(0.07,2.36,0.07),metal)
			for x: int in range(-7,8): box.call(Vector3(x*0.38,2.62,0),Vector3(0.10,0.04,2.4),Color("819285"))
		"shed", "hut":
			var width: float = 7.0 if kind == "shed" else 2.5
			var depth: float = 5.0 if kind == "shed" else 2.5
			box.call(Vector3(0,1.5,0),Vector3(width,3,depth),wood.darkened(0.1))
			_roof(tool,kit,center,scale,turn,width,depth,Color("646c68") if kind=="shed" else Color("815d47"))
			for side: float in [-1.0,1.0]:
				_face(tool,kit,center,scale,turn,[Vector3(side*width*0.5,3.0,-depth*0.5),Vector3(side*width*0.5,3.0,depth*0.5),Vector3(side*width*0.5,4.0,0)],wood.darkened(0.18))
				box.call(Vector3(0,3.0,side*(depth*0.5+0.12)),Vector3(width+0.3,0.12,0.12),Color("444f4c"))
			for x: float in [-width*0.42,width*0.42]:
				box.call(Vector3(x,1.9,-depth*0.5-0.04),Vector3(width*0.14,0.8,0.08),Color("d1c8ac"))
				box.call(Vector3(x,1.9,-depth*0.5-0.09),Vector3(width*0.11,0.61,0.035),Color("324f57"))
			for h: int in range(10):
				box.call(Vector3(0,0.15+h*0.28,depth*0.5+0.015),Vector3(width,0.03,0.035),wood.darkened(0.25))
			box.call(Vector3(-width*0.28,3.65,depth*0.15),Vector3(0.45,1.0,0.45),Color("8a7c68"))
			box.call(Vector3(0,1.25,-depth*0.5-0.02),Vector3(width*0.5,2.5,0.05),metal.darkened(0.3))
			if kind == "shed":
				for h: int in range(8): box.call(Vector3(0,0.2+h*0.29,-depth*0.5-0.052),Vector3(width*0.48,0.025,0.018),metal.darkened(0.46))
		"grandstand":
			for i: int in range(4):
				box.call(Vector3(0,0.25+i*0.4,-1.5+i),Vector3(8,0.18,0.85),metal.darkened(0.1))
				box.call(Vector3(0,0.46+i*0.4,-1.3+i),Vector3(7.7,0.12,0.32),wood)
				for x: float in [-3.7,3.7]: box.call(Vector3(x,(0.25+i*0.4)*0.5,-1.5+i),Vector3(0.12,0.25+i*0.4,0.12),metal.darkened(0.28))
			for x: float in [-3.9,3.9]: box.call(Vector3(x,1.25,1.7),Vector3(0.10,2.5,0.10),metal)
			box.call(Vector3(0,2.5,1.7),Vector3(8,0.10,0.10),metal)
		_: return false
	return true

static func _face(tool: SurfaceTool, kit: Node, center: Vector3, scale: float, turn: float, points: Array, color: Color) -> void:
	var vertices: Array[Vector3] = []
	for point: Vector3 in points: vertices.append(center+(point*scale).rotated(Vector3.UP,turn))
	tool.set_color(color)
	if vertices.size() == 4: kit._quad(tool,vertices[0],vertices[1],vertices[2],vertices[3])
	else:
		for index: int in [0,2,1]: tool.add_vertex(vertices[index])

static func _stone(tool: SurfaceTool, kit: Node, center: Vector3, size: Vector3, turn: float, color: Color) -> void:
	# Off-centre fractured cap; broad shaded faces, not a rounded bevel stack.
	var footprint: Array[Vector2] = [Vector2(1,0),Vector2(0.66,0.73),Vector2(-0.12,0.99),Vector2(-0.78,0.60),Vector2(-1,-0.03),Vector2(-0.55,-0.82),Vector2(0.16,-0.98),Vector2(0.81,-0.57)]
	var lower: Array[Vector3] = []
	var upper: Array[Vector3] = []
	for i: int in range(8):
		var p: Vector2 = footprint[i]
		lower.append(Vector3(p.x,0,p.y)*size)
		var inset: float = [0.76,0.69,0.81,0.63,0.83,0.77,0.58,0.71][i]
		upper.append(Vector3(p.x*inset+0.06,[0.64,0.86,0.95,0.83,0.69,0.88,0.94,0.72][i],p.y*inset-0.04)*size)
	for i: int in range(8):
		var j: int = (i+1)%8
		var shade: Color = color.darkened(0.32 if i in [0,1,7] else 0.12)
		_leaf_face(tool,kit,center,1,turn,[lower[i],lower[j],upper[j],upper[i]],shade)
		_leaf_face(tool,kit,center,1,turn,[upper[i],upper[j],Vector3(-0.08,0.99,0.08)*size],color.lightened(0.20 if i<4 else 0.07))
		# Short tapered fissure follows a real face, offset to avoid z-fighting.
		if i in [0,3,6]:
			var outward := Vector3(footprint[i].x,0,footprint[i].y).normalized()*0.012
			var a: Vector3 = lower[i].lerp(upper[i],0.32)+outward
			var b: Vector3 = lower[i].lerp(upper[i],0.83)+outward
			var c: Vector3 = b.lerp(lower[j].lerp(upper[j],0.83)+outward,0.045)
			_leaf_face(tool,kit,center,1,turn,[a,b,c],color.darkened(0.58))

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
	_lathe(tool,kit,center,scale,turn,[Vector2(0.16,0),Vector2(0.10,2.7),Vector2(0,3.2)],[Color("65513c"),Color("8e7951")],true)
	# Swept, tapered boughs: dark lower blades and connected upper ridges.
	for tier: int in range(5):
		var radius: float = 1.02-tier*0.17
		var height: float = 0.66+tier*0.49
		for branch: int in range(7):
			var angle: float = turn+branch*TAU/7.0+tier*0.63
			var reach: float = radius*(0.91+0.09*sin(branch*2.7+tier))
			var points: Array[Vector3] = [Vector3(-0.15,height+0.47,0),Vector3(reach*0.63,height+0.12,-reach*0.36),Vector3(reach,height-0.10,-reach*0.13),Vector3(reach*0.83,height-0.02,reach*0.08),Vector3(reach*0.95,height-0.15,reach*0.24),Vector3(reach*0.45,height+0.04,reach*0.40)]
			var ridge := Vector3(reach*0.38,height+0.37,0)
			for i: int in range(points.size()):
				var j: int = (i+1)%points.size()
				var shade: Color = color.lightened(0.23) if i<3 else color.darkened(0.12)
				_leaf_face(tool,kit,center,scale,angle,[points[i],points[j],ridge],shade)
				_leaf_face(tool,kit,center,scale,angle,[points[j],points[i],Vector3(0,height-0.02,0)],color.darkened(0.40))
	# Small pointed leader rather than a round cap.
	_lathe(tool,kit,center,scale,turn,[Vector2(0.22,2.65),Vector2(0.0,3.3)],[color.lightened(0.20)],true)

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
