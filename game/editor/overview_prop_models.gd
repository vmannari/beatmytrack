extends RefCounted
## Cheap, recognizable planning meshes. Coordinates fit a unit box centred at zero.
static func color(kind: String, biome: String, object: Dictionary) -> Color:
	if kind == "container": return Color(ContainerPaint.value(object))
	if kind in ["tree","broadleaf","bush","grass_clump","flowers","firefly_bush"]: return TrackTheme.foliage(biome).lightened(0.10)
	return Color("d8e3e7") if biome == "winter" else Color("d28b31") if kind == "cone" else Color("899b90") if kind == "parked_car" else Color("b4b5a1") if kind == "van" else Color("815842") if kind == "car_wreck" else Color("6e807d") if kind in ["barrel","burning_barrel"] else Color("997b56") if kind in ["crate","pallet","hut","shed"] else Color("aaa18c")

static func height(kind: String) -> float:
	return 5.0 if kind == "tree" else 4.0 if kind == "broadleaf" else 3.0 if kind in ["shed","hut"] else 2.6 if kind == "container" else 2.12 if kind == "van" else 1.55 if kind == "parked_car" else 1.15 if kind == "car_wreck" else 0.85 if kind == "cone" else 0.5 if kind in ["grass_clump","flowers","pallet"] else 1.2

static func mesh(kind: String, tint: Color) -> ArrayMesh:
	var tool: SurfaceTool = PropGeometry.model()
	var dark: Color = tint.darkened(0.48)
	if kind in ["parked_car","van","car_wreck"]:
		PropGeometry.box(tool,Vector3(0,-0.13,0),Vector3(0.98,0.38,0.9),tint,0.07)
		var cabin: Vector3 = Vector3(0,0.18,0) if kind != "car_wreck" else Vector3(-0.12,0.06,0.05)
		var size := Vector3(0.54,0.52,0.77) if kind != "van" else Vector3(0.81,0.65,0.79)
		PropGeometry.box(tool,cabin,size,tint.lightened(0.12),0.05)
		for side: float in [-1.0,1.0]:
			PropGeometry.box(tool,cabin+Vector3(0,0.03,side*0.394),Vector3(size.x*0.65,size.y*0.45,0.018),Color("294854"),0)
			for x: float in [-0.31,0.31]: PropGeometry.box(tool,Vector3(x,-0.30,side*0.46),Vector3(0.16,0.30,0.10),Color("2b3333"),0.025)
		PropGeometry.box(tool,Vector3(0.497,-0.10,0),Vector3(0.015,0.08,0.56),Color("d5d2ad"),0)
		if kind == "car_wreck": PropGeometry.box(tool,Vector3(0.30,0.13,-0.08),Vector3(0.34,0.12,0.48),dark,0.02)
	elif kind in ["barrel","burning_barrel","snow_lantern","ice_lantern"]:
		PropGeometry.tube(tool,Vector3(0,-0.48,0),Vector3(0,0.48,0),0.45,0.45,tint,10)
		for y: float in [-0.25,0.25]: PropGeometry.tube(tool,Vector3(0,y-0.025,0),Vector3(0,y+0.025,0),0.47,0.47,tint.lightened(0.22),10)
	elif kind == "cone":
		PropGeometry.box(tool,Vector3(0,-0.45,0),Vector3(0.95,0.10,0.95),Color("39413e"),0.03)
		PropGeometry.tube(tool,Vector3(0,-0.40,0),Vector3(0,0.50,0),0.40,0.06,Color("dc8429"),10)
		PropGeometry.tube(tool,Vector3(0,-0.05,0),Vector3(0,0.13,0),0.27,0.20,Color("eee6ce"),10)
	elif kind in ["hut","shed"]:
		PropGeometry.box(tool,Vector3(0,-0.12,0),Vector3(0.95,0.74,0.95),tint,0.02)
		for side: float in [-1.0,1.0]:
			PropGeometry.face(tool,[Vector3(-0.5,0.23,side*0.5),Vector3(0.5,0.23,side*0.5),Vector3(0.5,0.5,0),Vector3(-0.5,0.5,0)],Color("665b50"))
		PropGeometry.box(tool,Vector3(0,-0.13,-0.48),Vector3(0.30,0.54,0.025),dark,0)
	elif kind == "tree":
		PropGeometry.tube(tool,Vector3(0,-0.5,0),Vector3(0,0.15,0),0.07,0.05,Color("71644d"),6)
		for tier: int in range(3): PropGeometry.tube(tool,Vector3(0,-0.30+tier*0.22,0),Vector3(0,0.12+tier*0.19,0),0.48-tier*0.09,0.02,tint.lightened(tier*0.035),7)
	elif kind in ["broadleaf","bush","rock","boulder","slate","snowman","firefly_bush"]:
		PropGeometry.tube(tool,Vector3(0,-0.5,0),Vector3(0,-0.10,0),0.12,0.08,dark,6)
		PropGeometry.tube(tool,Vector3(0,-0.22,0),Vector3(0,0.16,0),0.48,0.37,tint,7)
		PropGeometry.tube(tool,Vector3(0,0.16,0),Vector3(0,0.46,0),0.37,0.12,tint.lightened(0.12),7)
	else:
		PropGeometry.box(tool,Vector3.ZERO,Vector3(0.97,0.96,0.97),tint,0.035)
		if kind in ["crate","pallet"]:
			for x: float in [-0.35,0.0,0.35]: PropGeometry.box(tool,Vector3(x,0.49,0),Vector3(0.055,0.018,0.94),tint.lightened(0.25),0)
		if kind == "container":
			for x: float in [-0.35,-0.17,0.0,0.17,0.35]: PropGeometry.box(tool,Vector3(x,0.49,0),Vector3(0.035,0.018,0.92),tint.lightened(0.18),0)
	return PropGeometry.finish(tool)
