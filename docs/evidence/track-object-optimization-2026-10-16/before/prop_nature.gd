class_name PropNature
extends RefCounted
## Authored deterministic silhouettes and broad leaf/stone planes, no alpha cards.
static func append(tool: SurfaceTool, kit: Node, kind: String, center: Vector3, scale: float, turn: float) -> bool:
	if kind not in ["broadleaf","bush","grass_clump","flowers","pebbles","log","rock","boulder","slate","cliff"]: return false
	var local := SurfaceTool.new(); local.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaf: Color = TrackTheme.foliage(kit.theme_id).lightened(0.06)
	var stone: Color = TrackTheme.stone(kit.theme_id)
	match kind:
		"broadleaf":
			PropGeometry.tube(local,Vector3.ZERO,Vector3(0.06,1.9,0.03),0.26,0.15,Color("796547"),12)
			for i: int in range(5):
				var angle: float = i*2.4
				var foot := Vector3(cos(angle)*0.38,0.03,sin(angle)*0.38)
				PropGeometry.tube(local,foot,Vector3(0,0.52,0),0.04,0.10,Color("67553e"),7)
			for i: int in range(9):
				var angle: float = i*2.4
				var p := Vector3(cos(angle)*(0.92 if i < 6 else 0.43),1.78+(i%4)*0.26,sin(angle)*(0.83 if i < 6 else 0.38))
				PropGeometry.tube(local,Vector3(0.03,1.15+i*0.07,0),p+Vector3(0,0.17,0),0.10,0.034,Color("796547"),8)
				_cluster(local,kit,p,Vector3(0.93,0.82,0.84),angle,leaf.lightened((i%3)*0.04))
		"bush":
			for i: int in range(6):
				var p := Vector3(cos(i*2.4)*0.39,0.04+(i%3)*0.09,sin(i*2.4)*0.32)
				PropGeometry.tube(local,Vector3(0,0.01,0),p+Vector3.UP*0.39,0.033,0.012,Color("716044"),6)
				_cluster(local,kit,p,Vector3(0.52,0.68,0.48),i*1.3,leaf.lightened((i%3)*0.035))
		"grass_clump", "flowers":
			for i: int in range(15):
				var angle: float = i*2.4
				var p := Vector3(cos(angle)*(0.10+(i%3)*0.105),0,sin(angle)*(0.10+(i%3)*0.105))
				var height: float = 0.34+(i%5)*0.067
				var lean := Vector3(cos(angle)*0.15,0,sin(angle)*0.15)
				_blade(local,p,lean,height,0.035,leaf.lightened((i%3)*0.06),angle)
				if kind == "flowers" and i%2 == 0:
					var top: Vector3 = p+lean*0.6+Vector3.UP*(height+0.06)
					PropGeometry.tube(local,p,top,0.011,0.007,leaf.darkened(0.1),5)
					for petal: int in range(5):
						var a: float = TAU*petal/5
						var radial := Vector3(cos(a),0,sin(a))
						var side := Vector3(-sin(a),0,cos(a))
						PropGeometry.face(local,[top,top+radial*0.075+side*0.044+Vector3.UP*0.008,top+radial*0.13+Vector3.UP*0.027,top+radial*0.075-side*0.044+Vector3.UP*0.008],Color("c5b17a") if i%4 == 0 else Color("d3cbb0"))
					PropGeometry.tube(local,top,top+Vector3.UP*0.027,0.025,0.020,Color("94763e"),8)
		"pebbles":
			for i: int in range(7):
				var size := Vector3(0.13+(i%3)*0.018,0.075+(i%2)*0.036,0.10+(i%3)*0.021)
				CreatorPropVisual._stone(local,kit,Vector3(cos(i*2.4)*0.31,0,sin(i*2.4)*0.27),size,i*0.9,stone.lightened((i%3)*0.035))
		"log": _log(local)
		"rock", "boulder", "slate":
			var bounds: Vector2 = CreatorObjects.dimensions(kind)
			var height: float = 2.1 if kind == "boulder" else 0.85 if kind == "slate" else 0.7
			CreatorPropVisual._stone(local,kit,Vector3.ZERO,Vector3(bounds.x*0.5,height,bounds.y*0.5),0,stone)
			# A second fractured shoulder stays inside the existing selectable footprint.
			CreatorPropVisual._stone(local,kit,Vector3(-bounds.x*0.22,0,bounds.y*0.12),Vector3(bounds.x*0.18,height*0.49,bounds.y*0.21),0.83,stone.darkened(0.09))
			if kind == "slate":
				for i: int in range(3):
					var p := Vector3(-0.25+i*0.46,0.10+i*0.09,-0.50)
					CreatorPropVisual._stone(local,kit,p,Vector3(0.53,0.20,0.29),0.14,stone.lightened(i*0.035))
		"cliff":
			CreatorPropVisual._cliff(local,kit,Vector3.ZERO,Vector3(8,4,3),0,stone)
			for i: int in range(7):
				var p := Vector3(-3.43+i*1.12,0,-1.12+(i%3)*0.14)
				CreatorPropVisual._stone(local,kit,p,Vector3(0.28+(i%3)*0.08,0.33+(i%2)*0.13,0.20),i*0.71,stone.darkened(0.15))
	PropGeometry.append_transformed(tool,local,center,scale,turn)
	return true

static func _cluster(tool: SurfaceTool, kit: Node, p: Vector3, size: Vector3, angle: float, color: Color) -> void:
	CreatorPropVisual._crown(tool,kit,p,size,angle,color)
	# Folded sprays sit on upper surfaces and break the broad crown into leaf masses.
	for i: int in range(8):
		var a: float = i*2.4+angle
		var leaf_p: Vector3 = p+Vector3(cos(a)*size.x*0.53,size.y*(0.59+(i%3)*0.08),sin(a)*size.z*0.53)
		var reach := Vector3(cos(a)*0.18,0.015,sin(a)*0.18)
		var side := Vector3(-sin(a)*0.065,0,cos(a)*0.065)
		PropGeometry.face(tool,[leaf_p-reach*0.3,leaf_p+side,leaf_p+reach+Vector3.UP*0.04,leaf_p-side],color.lightened(0.18+(i%2)*0.05))

static func _blade(tool: SurfaceTool, base: Vector3, lean: Vector3, height: float, width: float, color: Color, angle: float) -> void:
	var side := Vector3(cos(angle)*width,0,sin(angle)*width)
	var mid: Vector3 = base+lean*0.28+Vector3.UP*height*0.58
	var tip: Vector3 = base+lean+Vector3.UP*height
	PropGeometry.face(tool,[base-side,base+side,mid+side*0.63,mid-side*0.63],color)
	PropGeometry.face(tool,[mid-side*0.63,mid+side*0.63,tip],color.lightened(0.13))
	PropGeometry.face(tool,[base,mid+Vector3(0.01,0,0.01),tip],color.darkened(0.14))

static func _log(tool: SurfaceTool) -> void:
	var ends: Array = []
	for side: float in [-1.0,1.0]:
		var ring: Array[Vector3] = []
		for i: int in range(16):
			var a: float = TAU*i/16
			var radius: float = 0.365+0.022*sin(i*2.1)
			ring.append(Vector3(side*1.99,0.40+cos(a)*radius,sin(a)*radius))
		ends.append(ring)
	for i: int in range(16):
		var j: int = (i+1)%16
		PropGeometry.face(tool,[ends[0][i],ends[0][j],ends[1][j],ends[1][i]],Color("66543e").lightened((i%3)*0.07))
		var a: Vector3 = ends[0][i].lerp(ends[0][j],0.24)
		var b: Vector3 = ends[1][i].lerp(ends[1][j],0.35)
		PropGeometry.beam(tool,a+Vector3(-0.003,0.002,0.002),b+Vector3(0.003,0.002,0.002),0.017,0.008,Color("443b2e"))
	for side: float in [-1.0,1.0]:
		PropGeometry.tube(tool,Vector3(side*2.001,0.40,0),Vector3(side*2.008,0.40,0),0.329,0.329,Color("b79b71"),16)
		for radius: float in [0.12,0.23,0.29]: PropGeometry.ring(tool,Vector3(side*2.012,0.40,0),Vector3.RIGHT,radius,radius-0.012,0.004,Color("957b55"),20)
		PropGeometry.beam(tool,Vector3(side*2.017,0.39,0),Vector3(side*2.017,0.62,0.14),0.011,0.003,Color("66523b"))
	for x: float in [-0.75,0.68]:
		PropGeometry.tube(tool,Vector3(x,0.59,-0.14),Vector3(x+0.12,0.80,-0.22),0.095,0.053,Color("6a563e"),8)
		PropGeometry.tube(tool,Vector3(x+0.12,0.80,-0.22),Vector3(x+0.13,0.81,-0.22),0.046,0.046,Color("b89a6e"),8)
