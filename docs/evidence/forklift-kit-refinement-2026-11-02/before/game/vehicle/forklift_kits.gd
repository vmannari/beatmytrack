extends RefCounted
## Original cosmetic fittings in forklift model metres. No handling changes.
const Model = preload("res://vehicle/forklift_model.gd")

static func box(parent: Node3D, label: String, size: Vector3, at: Vector3, material: Material, simple: bool) -> MeshInstance3D:
	return Model._box(parent,size,at,0.035,material,1 if simple else 2,label)

static func beam(parent: Node3D, label: String, a: Vector3, b: Vector3, width: float, material: Material, simple: bool, tube: bool = false) -> void:
	var part: MeshInstance3D
	if tube:
		part = VisualGeometry.cylinder(parent,width*0.5,a.distance_to(b),(a+b)*0.5,material,simple)
	else:
		part = box(parent,label,Vector3(width,a.distance_to(b),width),(a+b)*0.5,material,simple)
	part.name = label
	part.quaternion = Quaternion(Vector3.UP,(b-a).normalized())

static func build(car: CarVisual, category: String) -> void:
	var kind: String = str(car.customisation[category])
	if category == "rims":
		_wheels(car,kind)
		return
	var frame: Node3D = car.new_kit_frame(category,car.body)
	if category == "body":
		if kind == "stock": Model.stock_cabin(car,frame)
		else: _cabin(car,frame,kind)
		return
	if kind == "stock": return
	var paint: Material = car.paint_materials.body
	var metal: Material = CompactFinish.alloy(Color("9ba7a5"))
	var dark: Material = CompactFinish.rubber(Color("263034"))
	if category == "hood": _hood(frame,kind,paint,metal,dark,car.simple_model)
	elif category == "aero": _rear(frame,kind,paint,metal,dark,car.simple_model)

static func _hood(frame: Node3D, kind: String, paint: Material, metal: Material, dark: Material, simple: bool) -> void:
	match kind:
		"fork_vent", "fork_louvre":
			box(frame,"VentCover",Vector3(0.90,0.045,0.54),Vector3(0,1.55,1.06),paint,simple)
			if kind == "fork_vent":
				for i: int in range(6): box(frame,"Vent",Vector3(0.65,0.009,0.025),Vector3(0,1.577,0.87+i*0.075),dark,simple)
			else:
				for side: float in [-1.0,1.0]:
					for i: int in range(5):
						var slat := box(frame,"SplitLouvre",Vector3(0.34,0.025,0.065),Vector3(side*0.23,1.595,0.87+i*0.09),metal,simple)
						slat.rotation.x = -0.25
		"fork_rib", "fork_channel":
			var count: int = 3 if kind == "fork_rib" else 5
			for i: int in range(count): box(frame,"EngineRib",Vector3(0.075,0.045 if count==3 else 0.085,0.65),Vector3((i-(count-1)*0.5)*0.21,1.56,1.04),metal,simple)
		"fork_twin", "fork_race":
			for side: float in [-1.0,1.0]:
				var intake := box(frame,"Intake",Vector3(0.27,0.075,0.49),Vector3(side*0.27,1.56,1.04),paint,simple)
				if kind == "fork_race":
					intake.rotation.y = side*0.23
					box(frame,"IntakeMouth",Vector3(0.19,0.04,0.018),Vector3(side*0.22,1.565,0.79),dark,simple)
			if kind == "fork_race": box(frame,"CentreSpine",Vector3(0.055,0.08,0.69),Vector3(0,1.57,1.04),metal,simple)
		"fork_scoop":
			box(frame,"Scoop",Vector3(0.77,0.18,0.55),Vector3(0,1.61,1.04),paint,simple)
			box(frame,"ScoopMouth",Vector3(0.63,0.095,0.012),Vector3(0,1.61,0.758),dark,simple)
			for i: int in range(4): box(frame,"ScoopDivider",Vector3(0.018,0.09,0.019),Vector3(-0.22+i*0.147,1.61,0.747),metal,simple)
		"fork_split":
			for side: float in [-1.0,1.0]: box(frame,"CoverShoulder",Vector3(0.38,0.115,0.67),Vector3(side*0.29,1.59,1.04),paint,simple)
			box(frame,"CentreChannel",Vector3(0.15,0.024,0.63),Vector3(0,1.55,1.04),dark,simple)
		"fork_dome":
			Model._box(frame,Vector3(0.83,0.20,0.61),Vector3(0,1.60,1.04),0.095,paint,2 if simple else 4,"EngineDome")
		"fork_fan":
			var disk := VisualGeometry.cylinder(frame,0.29,0.035,Vector3(0,1.55,1.04),dark,simple)
			disk.name = "FanRecess"
			VisualGeometry.ring(frame,Vector3(0,1.58,1.04),0.27,0.018,metal)
			for i: int in range(10):
				var angle: float = i*TAU/10
				beam(frame,"CoolingSpoke",Vector3(cos(angle)*0.06,1.58,1.04+sin(angle)*0.06),Vector3(cos(angle)*0.25,1.58,1.04+sin(angle)*0.25),0.024,metal,simple)
		"fork_cross":
			box(frame,"CrossPanel",Vector3(1.02,0.035,0.66),Vector3(0,1.55,1.04),paint,simple)
			for side: float in [-1.0,1.0]: beam(frame,"CrossRib",Vector3(-0.46,1.59,1.04+side*0.28),Vector3(0.46,1.59,1.04-side*0.28),0.045,metal,simple)
		"fork_flush":
			box(frame,"PanelSurround",Vector3(1.08,0.028,0.68),Vector3(0,1.55,1.04),metal,simple)
			box(frame,"InsetPanel",Vector3(0.96,0.015,0.56),Vector3(0,1.572,1.04),paint,simple)
		"fork_armour":
			for i: int in range(3):
				var plate := box(frame,"ArmourPanel",Vector3(1.04-i*0.10,0.055,0.25),Vector3(0,1.56+i*0.035,0.82+i*0.22),paint,simple)
				plate.rotation.x = -0.10

static func _rear(frame: Node3D, kind: String, paint: Material, metal: Material, dark: Material, simple: bool) -> void:
	for side: float in [-1.0,1.0]: box(frame,"RearMount",Vector3(0.10,0.10,0.20),Vector3(side*0.55,0.67,1.61),dark,simple)
	match kind:
		"fork_bar", "fork_wrap", "fork_twin", "fork_step", "fork_rib":
			box(frame,"RearGuard",Vector3(1.60,0.10,0.10),Vector3(0,0.67,1.70),metal,simple)
			if kind == "fork_twin": box(frame,"RearGuardUpper",Vector3(1.55,0.08,0.09),Vector3(0,0.84,1.68),metal,simple)
			if kind == "fork_wrap":
				for side: float in [-1.0,1.0]: box(frame,"GuardReturn",Vector3(0.09,0.10,0.42),Vector3(side*0.76,0.67,1.52),metal,simple)
			if kind == "fork_step":
				box(frame,"RearStep",Vector3(0.68,0.06,0.21),Vector3(0,0.75,1.68),dark,simple)
				for i: int in range(6): box(frame,"StepRib",Vector3(0.026,0.012,0.18),Vector3(-0.25+i*0.10,0.786,1.68),metal,simple)
			if kind == "fork_rib":
				for i: int in range(5): box(frame,"RearBuffer",Vector3(0.10,0.24,0.14),Vector3(-0.62+i*0.31,0.70,1.72),dark,simple)
		"fork_low":
			box(frame,"LowGuard",Vector3(1.66,0.15,0.14),Vector3(0,0.57,1.72),dark,simple)
			box(frame,"LowGuardTrim",Vector3(1.40,0.035,0.022),Vector3(0,0.59,1.802),metal,simple)
		"fork_bow":
			for side: float in [-1.0,1.0]: beam(frame,"ChevronGuard",Vector3(0,0.80,1.74),Vector3(side*0.79,0.62,1.69),0.11,metal,simple)
		"fork_mesh", "fork_cage":
			for y: float in [0.62,0.86]: box(frame,"GuardRail",Vector3(1.52,0.065,0.09),Vector3(0,y,1.72),metal,simple)
			if kind == "fork_mesh":
				for i: int in range(9): box(frame,"GuardGrille",Vector3(0.028,0.24,0.055),Vector3(-0.69+i*0.1725,0.74,1.72),dark,simple)
			else:
				for side: float in [-1.0,1.0]: beam(frame,"GuardBrace",Vector3(side*0.71,0.62,1.72),Vector3(-side*0.71,0.86,1.72),0.035,dark,simple)
		"fork_roller":
			for x: float in [-0.53,0.0,0.53]:
				var roller := VisualGeometry.cylinder(frame,0.105,0.45,Vector3(x,0.72,1.72),dark,simple)
				roller.rotation.z = PI*0.5
		"fork_plate":
			box(frame,"RearShield",Vector3(1.50,0.28,0.10),Vector3(0,0.76,1.72),paint,simple)
			for side: float in [-1.0,1.0]: box(frame,"ShieldBuffer",Vector3(0.12,0.23,0.035),Vector3(side*0.61,0.76,1.79),dark,simple)
		"fork_arc":
			for i: int in range(8):
				var a: float = lerpf(-1.1,1.1,i/8.0)
				var b: float = lerpf(-1.1,1.1,(i+1)/8.0)
				beam(frame,"CurvedGuard",Vector3(sin(a)*0.86,0.73,1.40+cos(a)*0.36),Vector3(sin(b)*0.86,0.73,1.40+cos(b)*0.36),0.105,metal,simple,true)
		"fork_tow":
			for side: float in [-1.0,1.0]: box(frame,"SplitGuard",Vector3(0.61,0.13,0.11),Vector3(side*0.47,0.69,1.72),metal,simple)
			var eye := Node3D.new()
			frame.add_child(eye)
			eye.position = Vector3(0,0.67,1.76)
			eye.rotation.x = PI*0.5
			VisualGeometry.ring(eye,Vector3.ZERO,0.09,0.025,dark)

static func _cabin(car: CarVisual, frame: Node3D, kind: String) -> void:
	var simple: bool = car.simple_model
	var paint: Material = car.paint_materials.body
	var metal: Material = CompactFinish.alloy(Color("899694"))
	var dark := CompactFinish.paint(Color("273439"))
	dark.roughness = 0.54
	var tube: bool = kind in ["fork_rail","fork_round","fork_arch","fork_safari"]
	var width: float = 0.12 if kind == "fork_heavy" else 0.095 if kind == "fork_plate" else 0.075
	var top_x: float = 0.66 if kind in ["fork_canted","fork_sport"] else 0.71
	var top_front: float = -0.60 if kind in ["fork_canted","fork_sport"] else -0.79
	for side: float in [-1.0,1.0]:
		for z: float in [-0.77,0.74]:
			box(frame,"CabinFoot",Vector3(0.18,0.11,0.19),Vector3(side*0.65,1.05,z),metal,simple)
			var top_z: float = top_front if z < 0 else 0.80
			if kind == "fork_round":
				beam(frame,"CabinPost",Vector3(side*0.65,1.05,z),Vector3(side*0.71,2.48,top_z),width,dark,simple,true)
				beam(frame,"CabinCorner",Vector3(side*0.71,2.48,top_z),Vector3(side*0.64,2.65,top_z),width,dark,simple,true)
			else:
				beam(frame,"CabinPost",Vector3(side*0.65,1.05,z),Vector3(side*top_x,2.65,top_z),width,paint if kind in ["fork_plate","fork_heavy"] else dark,simple,tube)
			if kind == "fork_plate": box(frame,"PillarFlange",Vector3(0.045,1.31,0.14),Vector3(side*0.67,1.82,z+0.025),paint,simple)
		beam(frame,"CabinRoofRail",Vector3(side*top_x,2.65,top_front-0.06),Vector3(side*top_x,2.65,0.90),width+0.025,dark,simple,tube)
		if kind == "fork_twin":
			beam(frame,"SecondHoop",Vector3(side*0.58,1.15,0.69),Vector3(side*0.60,2.58,0.69),0.058,metal,simple,true)
			beam(frame,"TwinRoofRail",Vector3(side*0.60,2.58,-0.69),Vector3(side*0.60,2.58,0.80),0.058,metal,simple,true)
		if kind == "fork_safari": beam(frame,"RackSide",Vector3(side*0.71,2.78,-0.80),Vector3(side*0.71,2.78,0.90),0.045,metal,simple,true)
	for z: float in [top_front-0.06,0.90]:
		beam(frame,"CabinHeader",Vector3(-top_x,2.65,z),Vector3(top_x,2.65,z),width+0.025,dark,simple,tube)
		if kind == "fork_safari":
			beam(frame,"RackHeader",Vector3(-0.71,2.78,z),Vector3(0.71,2.78,z),0.045,metal,simple,true)
			for side: float in [-1.0,1.0]: beam(frame,"RackStay",Vector3(side*0.71,2.65,z),Vector3(side*0.71,2.78,z),0.045,metal,simple,true)
	if kind == "fork_canopy":
		box(frame,"SunCanopy",Vector3(1.52,0.065,1.83),Vector3(0,2.70,0.03),paint,simple)
	elif kind == "fork_arch":
		for z: float in [-0.64,-0.15,0.34,0.78]:
			for i: int in range(8):
				var x0: float = lerpf(-0.71,0.71,i/8.0)
				var x1: float = lerpf(-0.71,0.71,(i+1)/8.0)
				beam(frame,"RoofArch",Vector3(x0,2.65+0.10*(1.0-pow(x0/0.71,2)),z),Vector3(x1,2.65+0.10*(1.0-pow(x1/0.71,2)),z),0.045,metal,simple,true)
	elif kind == "fork_sport":
		for side: float in [-1.0,1.0]: beam(frame,"RoofSpine",Vector3(side*0.11,2.70,top_front),Vector3(side*0.23,2.70,0.86),0.065,paint,simple)
		for z: float in [-0.42,0.16,0.72]: box(frame,"SportRoofSlat",Vector3(1.27,0.04,0.075),Vector3(0,2.67,z),dark,simple)
	else:
		var count: int = 10 if kind == "fork_mesh" else 4 if kind == "fork_round" else 6
		for i: int in range(count): box(frame,"CabinRoofSlat",Vector3(top_x*2,0.045,0.10 if kind=="fork_plate" else 0.045),Vector3(0,2.675,lerpf(top_front+0.12,0.76,i/float(count-1))),paint if kind=="fork_plate" else dark,simple)
	if kind in ["fork_lattice","fork_mesh"]:
		for x: float in [-0.43,0.0,0.43]: box(frame,"RoofLongitudinal",Vector3(0.035,0.04,1.58),Vector3(x,2.71,0.02),metal,simple)
	if kind == "fork_lattice":
		for side: float in [-1.0,1.0]: beam(frame,"RoofDiagonal",Vector3(side*0.65,2.71,-0.69),Vector3(-side*0.65,2.71,0.80),0.03,paint,simple)
	if kind in ["fork_cross","fork_heavy"]:
		for side: float in [-1.0,1.0]: beam(frame,"RearCabinBrace",Vector3(side*0.65,1.62,0.77),Vector3(-side*top_x,2.61,0.80),0.045 if kind=="fork_cross" else 0.07,metal,simple)
	if kind == "fork_heavy":
		for side: float in [-1.0,1.0]: beam(frame,"CornerGusset",Vector3(side*0.71,2.24,0.80),Vector3(side*0.32,2.65,0.85),0.10,paint,simple)

static func _wheels(car: CarVisual, kind: String) -> void:
	var metal: Material = CompactFinish.alloy(Color("a9b5b4"))
	var dark: Material = CompactFinish.rubber(Color("263034"))
	for index: int in range(car.rolling_wheels.size()):
		var rotor: Node3D = car.rolling_wheels[index]
		var frame: Node3D = car.new_kit_frame("rims",rotor)
		if kind == "stock": continue
		var side: float = signf((rotor.get_parent() as Node3D).position.x)
		var radius: float = car.wheel_radii[index]/HandlingConfig.BODY_SCALE
		var face: float = (0.32 if rotor.get_parent().position.z < 0.0 else 0.25)*0.48+0.056
		var wheel := Node3D.new()
		wheel.name = "WheelCover"
		frame.add_child(wheel)
		wheel.position.x = side*face
		wheel.rotation.z = -side*PI*0.5
		if kind == "fork_ring":
			VisualGeometry.ring(wheel,Vector3.ZERO,radius*0.56,0.018,metal)
			continue
		var closed: bool = kind in ["fork_disc","fork_spoke","fork_dish","fork_bolt","fork_slots"]
		if closed: VisualGeometry.cylinder(wheel,radius*0.53,0.018,Vector3.ZERO,metal,car.simple_model)
		if kind == "fork_disc": continue
		VisualGeometry.ring(wheel,Vector3(0,0.018,0),radius*0.53,0.015 if kind!="fork_dish" else 0.028,metal)
		VisualGeometry.cylinder(wheel,radius*0.12,0.045,Vector3(0,0.018,0),metal,car.simple_model)
		if kind == "fork_dish":
			VisualGeometry.cylinder(wheel,radius*0.37,0.022,Vector3(0,0.018,0),dark,car.simple_model)
			continue
		var counts: Dictionary = {"fork_spoke":6,"fork_three":3,"fork_four":4,"fork_five":5,"fork_eight":8,"fork_turbine":9,"fork_mesh":8,"fork_bolt":8,"fork_slots":10,"fork_star":5}
		var count: int = counts[kind]
		for spoke: int in range(count):
			var angle: float = spoke*TAU/count
			var inner: Vector3 = Vector3(cos(angle)*radius*0.10,0.022,sin(angle)*radius*0.10)
			var swept: float = 0.30 if kind=="fork_turbine" else 0.0
			var outer: Vector3 = Vector3(cos(angle+swept)*radius*0.50,0.022,sin(angle+swept)*radius*0.50)
			if kind == "fork_bolt":
				VisualGeometry.cylinder(wheel,0.012,0.014,outer*0.8+Vector3(0,0.018,0),dark,true)
			elif kind in ["fork_mesh","fork_star"]:
				for split: float in [-0.16,0.16]: beam(wheel,"PairedSpoke",inner,Vector3(cos(angle+split)*radius*0.50,0.022,sin(angle+split)*radius*0.50),radius*0.055,metal,car.simple_model)
			else:
				beam(wheel,"CoverSpoke",inner,outer,radius*(0.14 if count<=5 else 0.085),dark if kind in ["fork_spoke","fork_slots"] else metal,car.simple_model)
