class_name CreatorPropVisual
extends RefCounted
## Original shared meshes for world placement and browser thumbnails.
static func append(tool: SurfaceTool, kit: Node, kind: String, center: Vector3, scale: float, turn: float) -> bool:
	var wood := Color("83704e")
	var metal := Color("79858a")
	var leaf := Color("405c2e")
	var stone := Color("858b83")
	var box: Callable = func(p: Vector3, size: Vector3, color: Color) -> void:
		kit._colored_box(tool,center+(p*scale).rotated(Vector3.UP,turn),size*scale,turn,color)
	var mound: Callable = func(p: Vector3, size: Vector3, color: Color) -> void:
		kit._mound(tool,center+(p*scale).rotated(Vector3.UP,turn),size*scale,turn,color)
	match kind:
		"rock", "boulder", "slate", "cliff":
			var bounds: Vector2=CreatorObjects.dimensions(kind)
			var height: float={"rock":0.6,"boulder":2.0,"slate":0.65,"cliff":3.4}[kind]
			mound.call(Vector3.ZERO,Vector3(bounds.x*0.48,height,bounds.y*0.48),stone)
			for i: int in range(4):
				var angle: float=i*2.4
				mound.call(Vector3(sin(angle)*bounds.x*0.19,height*0.12,cos(angle)*bounds.y*0.15),Vector3(bounds.x*0.22,height*(0.5+i*0.07),bounds.y*0.23),stone.darkened(i*0.045))
		"broadleaf":
			box.call(Vector3(0,1.1,0),Vector3(0.6,2.2,0.6),wood)
			for i: int in range(13):
				var angle: float=i*2.4
				var radius: float=0.3 if i>8 else 1.0
				mound.call(Vector3(sin(angle)*radius,1.8+(i%3)*0.35,cos(angle)*radius),Vector3(0.72,0.85,0.68),leaf.lightened((i%4)*0.035))
		"bush":
			for p: Vector3 in [Vector3(-0.4,0,0),Vector3(0.4,0,0.2),Vector3(0,0,-0.3)]: mound.call(p,Vector3(0.6,0.6,0.6),leaf)
		"grass_clump", "flowers":
			for i: int in range(7):
				var p := Vector3(sin(i*2.4)*0.35,0.25,cos(i*2.4)*0.35)
				box.call(p,Vector3(0.06,0.4+0.04*i,0.08),leaf.lightened(0.1))
				if kind == "flowers": mound.call(p+Vector3.UP*0.25,Vector3(0.12,0.08,0.12),Color("c7bc80"))
		"pebbles":
			for i: int in range(5): mound.call(Vector3(sin(i*2.4)*0.3,0,cos(i*2.4)*0.3),Vector3(0.12,0.08,0.14),stone)
		"log": mound.call(Vector3.ZERO,Vector3(2,0.45,0.4),wood)
		"barrier":
			box.call(Vector3(0,0.45,0),Vector3(6,0.9,1),Color("b2b6b0"))
			for x: int in [-2,0,2]: box.call(Vector3(x,0.8,0),Vector3(0.9,0.3,1.02),Color("a44e42"))
		"guardrail", "wire_fence":
			for x: float in [-2.9,0,2.9]: box.call(Vector3(x,0.7,0),Vector3(0.12,1.4,0.12),metal.darkened(0.2))
			if kind == "guardrail": box.call(Vector3(0,0.8,0),Vector3(6,0.42,0.15),metal)
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
			for x: float in [-0.4,0,0.4]: box.call(Vector3(x*width,1.15,-0.07),Vector3(0.15,0.48,0.02),Color("38484a"))
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
			box.call(Vector3(0,0.5,0),Vector3(1.1,1,1.1),wood)
			for x: float in [-0.45,0.45]: box.call(Vector3(x,0.5,-0.57),Vector3(0.12,1,0.05),wood.lightened(0.15))
		"barrel":
			_lathe(tool,kit,center,scale,turn,[Vector2(0.48,0),Vector2(0.51,0.18),Vector2(0.54,0.25),Vector2(0.51,0.32),Vector2(0.51,0.76),Vector2(0.54,0.83),Vector2(0.51,0.90),Vector2(0.48,1.08),Vector2(0,1.08)],[wood,metal,metal,wood,metal,metal,wood,metal])
		"pallet":
			for x: int in range(5): box.call(Vector3(-0.8+x*0.4,0.14,0),Vector3(0.3,0.16,1.4),wood)
		"parked_car", "van":
			var length: float = 4.2 if kind == "parked_car" else 5.0
			box.call(Vector3(0,0.55,0),Vector3(length,0.65,1.8),Color("8e9f9a"))
			box.call(Vector3(-0.3,1.15,0),Vector3(length*0.48,0.6 if kind == "parked_car" else 1.3,1.45),Color("8e9f9a"))
			box.call(Vector3(0.65,1.46,0),Vector3(0.65,0.035,1.36),Color("314c58"))
			box.call(Vector3(-1.05,1.46,0),Vector3(0.45,0.035,1.36),Color("314c58"))
			box.call(Vector3(1.65,0.9,0),Vector3(0.6,0.04,1.6),Color("9baea8"))
			for z: float in [-0.76,0.76]:
				box.call(Vector3(-0.15,1.18,z),Vector3(1.65,0.36,0.025),Color("314c58"))
				box.call(Vector3(1.1,1.0,z*1.3),Vector3(0.25,0.15,0.18),Color("687e78"))
			for z: float in [-0.6,0.6]:
				box.call(Vector3(length*0.5+0.01,0.64,z),Vector3(0.035,0.18,0.36),Color("e1dfba"))
				box.call(Vector3(-length*0.5-0.01,0.64,z),Vector3(0.035,0.18,0.3),Color("9b4438"))
			box.call(Vector3(0.7,1.2,0),Vector3(0.05,0.45,1.57),Color("384e58"))
			for x: float in [-1.3,1.3]:
				for z: float in [-0.9,0.9]: box.call(Vector3(x,0.33,z),Vector3(0.6,0.6,0.22),Color("283233"))
		"container":
			box.call(Vector3(0,1.3,0),Vector3(6,2.6,2.5),Color("6a8279"))
			for x: int in range(-5,6): box.call(Vector3(x*0.5,1.3,-1.27),Vector3(0.08,2.4,0.04),Color("586f66"))
		"shed", "hut":
			var width: float = 7.0 if kind == "shed" else 2.5
			var depth: float = 5.0 if kind == "shed" else 2.5
			box.call(Vector3(0,1.5,0),Vector3(width,3,depth),wood.darkened(0.1))
			_roof(tool,kit,center,scale,turn,width,depth,Color("646c68") if kind=="shed" else Color("815d47"))
			for x: float in [-width*0.42,width*0.42]:
				box.call(Vector3(x,1.9,-depth*0.5-0.04),Vector3(width*0.14,0.8,0.08),Color("d1c8ac"))
				box.call(Vector3(x,1.9,-depth*0.5-0.09),Vector3(width*0.11,0.61,0.035),Color("324f57"))
			for h: int in range(10):
				box.call(Vector3(0,0.15+h*0.28,depth*0.5+0.015),Vector3(width,0.03,0.035),wood.darkened(0.25))
			box.call(Vector3(-width*0.28,3.65,depth*0.15),Vector3(0.45,1.0,0.45),Color("8a7c68"))
			box.call(Vector3(0,1.25,-depth*0.5-0.02),Vector3(width*0.5,2.5,0.05),metal.darkened(0.3))
		"grandstand":
			for i: int in range(4): box.call(Vector3(0,0.25+i*0.4,-1.5+i),Vector3(8,0.35,0.85),metal)
		_: return false
	return true

static func _lathe(tool: SurfaceTool, kit: Node, center: Vector3, scale: float, turn: float, profile: Array, colors: Array) -> void:
	for row: int in range(profile.size()-1):
		for i: int in range(20):
			var a: float=TAU*i/20+turn
			var b: float=TAU*(i+1)/20+turn
			var lo: Vector2=profile[row]
			var hi: Vector2=profile[row+1]
			tool.set_color(colors[row])
			kit._quad(tool,center+Vector3(cos(a)*lo.x,lo.y,sin(a)*lo.x)*scale,center+Vector3(cos(b)*lo.x,lo.y,sin(b)*lo.x)*scale,center+Vector3(cos(b)*hi.x,hi.y,sin(b)*hi.x)*scale,center+Vector3(cos(a)*hi.x,hi.y,sin(a)*hi.x)*scale)

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
