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
		"broadleaf":
			box.call(Vector3(0,1.1,0),Vector3(0.6,2.2,0.6),wood)
			for p: Vector3 in [Vector3(-0.6,2,0),Vector3(0.6,2.1,0.4),Vector3(0,2.7,-0.3)]: mound.call(p,Vector3(1.1,1.0,1.1),leaf)
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
			mound.call(Vector3(0,0.12,0),Vector3(0.27,0.75,0.27),Color("d67b38"))
			box.call(Vector3(0,0.5,0),Vector3(0.25,0.12,0.25),Color("e0dfcb"))
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
			mound.call(Vector3.ZERO,Vector3(0.55,1.1,0.55),Color("906d51"))
			for h: float in [0.25,0.8]: box.call(Vector3(0,h,0),Vector3(1.0,0.1,1.0),metal)
		"pallet":
			for x: int in range(5): box.call(Vector3(-0.8+x*0.4,0.14,0),Vector3(0.3,0.16,1.4),wood)
		"parked_car", "van":
			var length: float = 4.2 if kind == "parked_car" else 5.0
			box.call(Vector3(0,0.55,0),Vector3(length,0.65,1.8),Color("8e9f9a"))
			box.call(Vector3(-0.3,1.15,0),Vector3(length*0.55,0.6 if kind == "parked_car" else 1.3,1.55),Color("b7c0b8"))
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
			box.call(Vector3(0,3.1,0),Vector3(width+0.4,0.25,depth+0.4),Color("586361"))
			box.call(Vector3(0,1.25,-depth*0.5-0.02),Vector3(width*0.5,2.5,0.05),metal.darkened(0.3))
		"grandstand":
			for i: int in range(4): box.call(Vector3(0,0.25+i*0.4,-1.5+i),Vector3(8,0.35,0.85),metal)
		_: return false
	return true
