extends RefCounted
## Industrial cosmetic assemblies: formed panels, rolled edges and bolted hardpoints.
const Model = preload("res://vehicle/forklift_model.gd")
const Surface = preload("res://vehicle/forklift_kit_surface.gd")

static func _finish(color: String, metal: float = 0.18) -> StandardMaterial3D:
	var result := CompactFinish.paint(Color(color))
	result.roughness = 0.66
	result.metallic = metal
	result.metallic_specular = 0.24
	result.clearcoat_enabled = false
	return result

static func _box(parent: Node3D, label: String, size: Vector3, at: Vector3, material: Material, simple: bool, bevel: float = 0.006) -> MeshInstance3D:
	return Model._box(parent,size,at,bevel,material,1 if simple else 2,label)

static func _bolt(parent: Node3D, at: Vector3, normal: Vector3, radius: float, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius=radius; mesh.bottom_radius=radius; mesh.height=0.012
	mesh.radial_segments=6; mesh.rings=1
	var node := MeshInstance3D.new()
	node.name="FlushHexFastener"
	node.mesh=mesh; node.material_override=material
	node.position=at; node.quaternion=Quaternion(Vector3.UP,normal)
	parent.add_child(node)

static func _beam(parent: Node3D, label: String, a: Vector3, b: Vector3, size: Vector2, material: Material, simple: bool) -> void:
	Surface.tube(parent,label,[a,b],size,0.007,material,simple)

static func build(car: CarVisual, category: String) -> void:
	var kind: String = str(car.customisation[category])
	if category == "rims":
		_wheels(car,kind)
		return
	var frame: Node3D = car.new_kit_frame(category,car.body)
	if kind == "stock":
		match category:
			"hood": Model.stock_engine_cover(car,frame)
			"aero": Model.stock_rear_guard(car,frame)
			"body": Model.stock_cabin(car,frame)
		return
	match category:
		"hood": _hood(car,frame,kind)
		"aero": _rear(car,frame,kind)
		"body": _cabin(car,frame,kind)

static func _hood(car: CarVisual, frame: Node3D, kind: String) -> void:
	var simple: bool = car.simple_model
	var charcoal: Material = _finish("273338")
	var gasket: Material = CompactFinish.rubber(Color("172024"))
	var hardware: Material = _finish("747e7a",0.46)
	var paint: Material = car.paint_materials.accent if kind in ["fork_vent","fork_louvre","fork_flush","fork_channel"] else car.paint_materials.body
	var pockets: Array[Rect2] = []
	var crown: float = 0.022
	match kind:
		"fork_vent": pockets=[Rect2(-0.45,0.81,0.90,0.47)]
		"fork_rib": pockets=[Rect2(-0.47,0.87,0.94,0.32)]
		"fork_twin": pockets=[Rect2(-0.48,0.82,0.38,0.45),Rect2(0.10,0.82,0.38,0.45)]
		"fork_scoop": pockets=[Rect2(-0.44,1.08,0.88,0.21)]; crown=0.035
		"fork_louvre": pockets=[Rect2(-0.48,0.84,0.40,0.42),Rect2(0.08,0.84,0.40,0.42)]
		"fork_split": pockets=[Rect2(-0.07,0.78,0.14,0.53)]
		"fork_dome": crown=0.043; pockets=[Rect2(-0.48,1.17,0.96,0.11)]
		"fork_fan": pockets=[Rect2(-0.43,0.81,0.86,0.48)]
		"fork_cross": pockets=[Rect2(-0.44,0.81,0.88,0.18),Rect2(-0.44,1.10,0.88,0.18)]
		"fork_flush": crown=0.010; pockets=[Rect2(-0.42,1.16,0.84,0.11)]
		"fork_armour": crown=0.027; pockets=[Rect2(-0.45,0.84,0.90,0.39)]
		"fork_channel":
			for x: float in [-0.39,-0.13,0.13,0.39]: pockets.append(Rect2(x-0.055,0.83,0.11,0.44))
		"fork_race": pockets=[Rect2(-0.47,0.90,0.34,0.36),Rect2(0.13,0.90,0.34,0.36)]; crown=0.032
	_box(frame,"EngineLidGasket",Vector3(1.43,0.045,0.83),Vector3(0,1.441,1.04),gasket,simple,0.018)
	Surface.deck(frame,"FormedEngineCover",Rect2(-0.695,0.645,1.39,0.79),1.499,crown,pockets,paint,charcoal,simple)
	# Hinges and a flush latch establish a removable assembly, rather than a stack of blocks.
	for x: float in [-0.48,0.48]:
		_box(frame,"LidHinge",Vector3(0.10,0.018,0.065),Vector3(x,1.503,0.69),hardware,simple,0.003)
		_bolt(frame,Vector3(x,1.516,0.69),Vector3.UP,0.008,charcoal)
	_box(frame,"FlushLatch",Vector3(0.10,0.014,0.037),Vector3(0,1.506,1.389),charcoal,simple,0.004)
	for pocket: Rect2 in pockets:
		var longitudinal: bool = kind in ["fork_fan","fork_channel","fork_race"]
		var count: int = maxi(2,int((pocket.size.x if longitudinal else pocket.size.y)/0.065))
		if kind in ["fork_split","fork_flush"]: count=2
		for i: int in range(count):
			var fraction: float = (i+0.5)/count
			var center: Vector2 = pocket.position+pocket.size*Vector2(fraction if longitudinal else 0.5,0.5 if longitudinal else fraction)
			var size := Vector3(0.022 if longitudinal else pocket.size.x-0.025,0.016,pocket.size.y-0.022 if longitudinal else 0.025)
			var louvre := _box(frame,"RecessedCoolingLouvre",size,Vector3(center.x,1.495,center.y),charcoal,simple,0.003)
			if not longitudinal: louvre.rotation.x=-0.28
	if kind == "fork_armour":
		for x: float in [-0.58,0.58]:
			_box(frame,"CoverEdgeReinforcement",Vector3(0.055,0.016,0.51),Vector3(x,1.513,1.05),hardware,simple,0.004)
	if kind == "fork_rib":
		for x: float in [-0.58,0,0.58]:
			var path: Array[Vector3]=[]
			for i: int in range(9):
				var z: float=lerpf(0.79,1.29,i/8.0)
				path.append(Vector3(x,Surface._lid_height(Vector2(x,z),Rect2(-0.695,0.645,1.39,0.79),1.499,crown)+0.002,z))
			Surface.tube(frame,"PressedStiffener",path,Vector2(0.035,0.012),0.005,paint,simple)
	if kind == "fork_cross": _box(frame,"ServicePanelDivider",Vector3(0.86,0.008,0.032),Vector3(0,1.523,1.045),paint,simple,0.003)

static func _guard_outline(width: float, depth: float, sweep: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(-width*0.5,1.47),Vector2(-width*0.5+0.09,1.43),Vector2(width*0.5-0.09,1.43),Vector2(width*0.5,1.47),Vector2(width*0.5,depth-sweep),Vector2(width*0.5-0.11,depth),Vector2(-width*0.5+0.11,depth),Vector2(-width*0.5,depth-sweep)])

static func _rear(car: CarVisual, frame: Node3D, kind: String) -> void:
	var simple: bool = car.simple_model
	var steel: Material = _finish("48565a",0.30)
	var rubber: Material = CompactFinish.rubber(Color("20292b"))
	var hardware: Material = _finish("7e8884",0.45)
	var paint: Material = car.paint_materials.body
	var width: float = 1.63 if kind in ["fork_wrap","fork_arc","fork_plate"] else 1.56
	var depth: float = 1.70 if kind!="fork_low" else 1.67
	var height: float = 0.16 if kind!="fork_plate" else 0.24
	var center_y: float = 0.58 if kind!="fork_plate" else 0.63
	# Two bolted mounting shoes meet the existing chassis. The bumper replaces the factory part.
	for side: float in [-1.0,1.0]:
		_box(frame,"GuardMountingShoe",Vector3(0.16,0.18,0.18),Vector3(side*0.54,0.56,1.47),steel,simple)
		_bolt(frame,Vector3(side*0.54,0.56,1.573),Vector3.BACK,0.017,hardware)
	if kind == "fork_arc":
		var path: Array[Vector3] = []
		for i: int in range(21):
			var x: float = lerpf(-0.75,0.75,i/20.0)
			path.append(Vector3(x,0.59,1.57+0.13*sqrt(maxf(0,1-pow(x/0.84,2)))))
		Surface.tube(frame,"RolledRearGuard",path,Vector2(0.115,0.115),0.052,steel,simple)
	else:
		var bumper: MeshInstance3D = Surface.plate(frame,"FormedRearGuard",_guard_outline(width,depth,0.045 if kind!="fork_bow" else 0.085),height,rubber if kind in ["fork_low","fork_roller"] else paint if kind=="fork_plate" else steel,0.009)
		bumper.position.y = center_y
	if kind == "fork_wrap":
		for side: float in [-1.0,1.0]: _box(frame,"CornerBuffer",Vector3(0.12,0.18,0.14),Vector3(side*0.75,0.59,1.61),rubber,simple,0.018)
	if kind == "fork_twin":
		_box(frame,"UpperImpactRail",Vector3(1.32,0.045,0.075),Vector3(0,0.72,1.64),steel,simple)
		for side: float in [-1.0,1.0]: _box(frame,"RailEndCheek",Vector3(0.095,0.12,0.095),Vector3(side*0.61,0.68,1.64),steel,simple)
	if kind == "fork_step":
		_box(frame,"InsetServiceStep",Vector3(0.70,0.024,0.19),Vector3(0,0.675,1.57),rubber,simple,0.006)
		for i: int in range(7): _box(frame,"StepGrip",Vector3(0.018,0.007,0.14),Vector3(-0.27+i*0.09,0.691,1.57),hardware,simple,0.002)
	if kind == "fork_mesh":
		_box(frame,"ServiceGrilleRecess",Vector3(0.72,0.09,0.009),Vector3(0,0.59,1.708),rubber,simple,0.003)
		for i: int in range(9): _box(frame,"ServiceGrilleSlat",Vector3(0.025,0.075,0.012),Vector3(-0.31+i*0.0775,0.59,1.719),steel,simple,0.003)
	if kind in ["fork_roller","fork_rib"]:
		for side: float in [-1.0,1.0]:
			_box(frame,"DockBuffer",Vector3(0.25 if kind=="fork_roller" else 0.18,0.23,0.085),Vector3(side*0.50,0.60,1.714),rubber,simple,0.023)
			if kind == "fork_rib":
				for i: int in range(3): _box(frame,"BufferGroove",Vector3(0.13,0.008,0.005),Vector3(side*0.50,0.54+i*0.05,1.760),steel,simple,0.002)
	if kind == "fork_cage":
		for side: float in [-1.0,1.0]:
			_box(frame,"BoxGuardEndCap",Vector3(0.16,0.21,0.10),Vector3(side*0.65,0.59,1.67),rubber,simple,0.012)
			_box(frame,"GuardEndInsert",Vector3(0.08,0.10,0.014),Vector3(side*0.65,0.59,1.729),hardware,simple,0.005)
	if kind in ["fork_bar","fork_bow","fork_plate","fork_low"]:
		for side: float in [-1.0,1.0]: _bolt(frame,Vector3(side*0.58,center_y,depth+0.009),Vector3.BACK,0.013,hardware)
	if kind == "fork_tow":
		for side: float in [-1.0,1.0]:
			_box(frame,"ClevisMount",Vector3(0.028,0.09,0.15),Vector3(side*0.065,0.57,1.665),steel,simple,0.003)
			var ear: MeshInstance3D = Surface.lathe(frame,"ClevisEar",PackedVector2Array([Vector2(0.014,-0.014),Vector2(0.043,-0.014),Vector2(0.048,-0.009),Vector2(0.048,0.009),Vector2(0.043,0.014),Vector2(0.014,0.014)]),steel,simple)
			ear.rotation.z=PI*0.5; ear.position=Vector3(side*0.065,0.57,1.73)
		var pin := VisualGeometry.cylinder(frame,0.013,0.19,Vector3(0,0.57,1.73),hardware,true)
		pin.rotation.z=PI*0.5

static func _curve(a: Vector3, corner: Vector3, b: Vector3, steps: int = 8) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for i: int in range(steps+1):
		var t: float = i/float(steps)
		points.append(a.lerp(corner,t).lerp(corner.lerp(b,t),t))
	return points

static func _cabin_side(side: float, front: Vector3, rear: Vector3, radius: float) -> Array[Vector3]:
	# Local anchors stay fixed; the actual roof and pillar silhouettes belong to each design.
	var f: Vector3 = Vector3(side*front.x,front.y,front.z)
	var r: Vector3 = Vector3(side*rear.x,rear.y,rear.z)
	var foot_f := Vector3(side*0.65,1.06,-0.77)
	var foot_r := Vector3(side*0.65,1.06,0.74)
	var path: Array[Vector3] = [foot_f]
	path.append_array(_curve(f.move_toward(foot_f,radius),f,f.move_toward(r,radius)))
	path.append_array(_curve(r.move_toward(f,radius),r,r.move_toward(foot_r,radius)))
	path.append(foot_r)
	return path

static func _cabin(car: CarVisual, frame: Node3D, kind: String) -> void:
	var simple: bool = car.simple_model
	var steel: Material = _finish("2c383c")
	var edge: Material = _finish("71807f",0.35)
	var rubber: Material = CompactFinish.rubber(Color("172024"))
	var paint: Material = car.paint_materials.body
	var front := Vector3(0.70,2.65,-0.79)
	var rear := Vector3(0.70,2.65,0.80)
	var section := Vector2(0.09,0.095)
	var bend: float = 0.12
	var round_section: float = 0.014
	match kind:
		"fork_rail": section=Vector2(0.095,0.095); round_section=0.047
		"fork_plate": section=Vector2(0.075,0.13); front.y=2.59; rear.y=2.67
		"fork_twin": section=Vector2(0.14,0.22); front.y=2.56; rear.y=2.64
		"fork_canted": front=Vector3(0.72,2.61,-0.47); rear=Vector3(0.72,2.67,0.91); bend=0.16
		"fork_round": front.y=2.47; rear.y=2.47; section=Vector2(0.09,0.09); round_section=0.04
		"fork_cross": front.y=2.57; rear.y=2.57; section=Vector2(0.085,0.085)
		"fork_canopy": front.y=2.60; rear.y=2.60; section=Vector2(0.085,0.10)
		"fork_lattice": front.y=2.58; rear.y=2.58; section=Vector2(0.07,0.07)
		"fork_arch": front.y=2.48; rear.y=2.48; section=Vector2(0.075,0.09)
		"fork_sport": front=Vector3(0.73,2.48,-0.64); rear=Vector3(0.60,2.67,0.61); section=Vector2(0.085,0.10)
		"fork_mesh": front.y=2.57; rear.y=2.57; section=Vector2(0.075,0.075)
		"fork_heavy": front.y=2.60; rear.y=2.60; section=Vector2(0.14,0.17); bend=0.22
		"fork_safari": front.y=2.55; rear.y=2.55; section=Vector2(0.085,0.085); round_section=0.04
	var structural: Material = edge if kind=="fork_mesh" else steel
	# Every attachment is seated on the original chassis hardpoints.
	for side: float in [-1.0,1.0]:
		for z: float in [-0.77,0.74]:
			if kind=="fork_twin" and z<0: continue
			_box(frame,"CabinFootIsolator",Vector3(0.18,0.022,0.20),Vector3(side*0.65,1.035,z),rubber,simple)
			_box(frame,"CabinMountPlate",Vector3(0.17,0.035,0.19),Vector3(side*0.65,1.061,z),structural,simple)
			for dz: float in [-0.057,0.057]: _bolt(frame,Vector3(side*0.65,1.083,z+dz),Vector3.UP,0.011,edge)
		var f := Vector3(side*front.x,front.y,front.z)
		var r := Vector3(side*rear.x,rear.y,rear.z)
		if kind=="fork_twin":
			# Rear-mounted goosenecks leave the entry and front corners completely open.
			var path: Array[Vector3] = [Vector3(side*0.65,1.06,0.74)]
			path.append_array(_curve(Vector3(side*0.70,2.36,0.83),r,Vector3(side*0.70,2.63,0.54)))
			path.append(f)
			Surface.tube(frame,"RearCantileverColumn",path,section,0.024,paint,simple)
		elif kind=="fork_rail":
			# Two transverse roll hoops, rather than the side portals used by the factory.
			for z: float in [-0.77,0.74]:
				if side>0: continue
				var path: Array[Vector3] = [Vector3(-0.65,1.06,z)]
				path.append_array(_curve(Vector3(-0.70,2.40,z),Vector3(-0.70,2.65,z),Vector3(-0.45,2.65,z)))
				path.append_array(_curve(Vector3(0.45,2.65,z),Vector3(0.70,2.65,z),Vector3(0.70,2.40,z)))
				path.append(Vector3(0.65,1.06,z))
				Surface.tube(frame,"TransverseRoundHoop",path,section,round_section,steel,simple)
			_beam(frame,"HoopSideTie",f,r,Vector2(0.055,0.055),edge,simple)
		elif kind=="fork_round":
			var path: Array[Vector3] = [Vector3(side*0.65,1.06,-0.77),f]
			for i: int in range(1,17):
				var t: float=i/16.0
				path.append(Vector3(side*0.70,2.47+0.23*sin(t*PI),lerpf(front.z,rear.z,t)))
			path.append(Vector3(side*0.65,1.06,0.74))
			Surface.tube(frame,"BarrelRoofSideArch",path,section,round_section,steel,simple)
		else:
			Surface.tube(frame,"ShapedCabinPortal",_cabin_side(side,front,rear,bend),section,round_section,structural,simple)
		# Accessories connect to the real pillar or hang from the cantilever, without floating.
		var lamp_from: Vector3 = f.lerp(r,0.03)
		if kind not in ["fork_twin","fork_round"]:
			lamp_from=Vector3(side*lerpf(0.65,front.x,0.90),2.47,lerpf(-0.77,front.z,0.90))
		_beam(frame,"WorkLampBracket",lamp_from,Vector3(side*0.70,2.51,-0.81),Vector2(0.055,0.045),structural,simple)
		var mirror_from := Vector3(side*lerpf(0.65,front.x,0.76),2.23,lerpf(-0.77,front.z,0.76))
		if kind=="fork_twin": mirror_from=f
		_beam(frame,"MirrorMountStay",mirror_from,Vector3(side*0.70,2.23,-0.69),Vector2(0.035,0.035),structural,simple)
		# Broad tapered pillar skins and substantial haunches change the side elevation.
		if kind in ["fork_plate","fork_heavy"]:
			var panel: PackedVector2Array
			if kind=="fork_plate":
				panel=PackedVector2Array([Vector2(0.67,1.10),Vector2(0.83,1.10),Vector2(0.89,2.64),Vector2(0.49,2.64),Vector2(0.69,2.28)])
			else:
				panel=PackedVector2Array([Vector2(0.64,1.10),Vector2(0.85,1.10),Vector2(0.90,2.59),Vector2(0.30,2.59),Vector2(0.63,2.15)])
			var skin: MeshInstance3D=Surface.plate(frame,"TaperedRearPillar",panel,0.042,paint,0.006)
			skin.basis=Basis(Vector3.BACK,Vector3.RIGHT,Vector3.UP)
			skin.position.x=side*0.705
			for y: float in [1.22,2.32]: _bolt(frame,Vector3(side*0.735,y,0.76),Vector3(side,0,0),0.014,edge)
		if kind=="fork_cross":
			var gusset:=Surface.plate(frame,"UpperCornerHaunch",PackedVector2Array([Vector2(0.36,2.55),Vector2(0.82,2.55),Vector2(0.75,2.16)]),0.028,paint,0.004)
			gusset.basis=Basis(Vector3.BACK,Vector3.RIGHT,Vector3.UP); gusset.position.x=side*0.70
	# Headers follow the design's height and width. The vault gets full curved transverse ribs.
	if kind not in ["fork_rail","fork_arch"]:
		for p: Vector3 in [front,rear]: _beam(frame,"RoofEndHeader",Vector3(-p.x,p.y,p.z),p,Vector2(0.09,0.09),structural,simple)
	if kind=="fork_arch":
		for i: int in range(6):
			var path: Array[Vector3]=[]
			var z: float=lerpf(front.z,rear.z,i/5.0)
			for j: int in range(17):
				var x: float=lerpf(-0.70,0.70,j/16.0)
				path.append(Vector3(x,2.48+0.23*(1-pow(x/0.70,2)),z))
			Surface.tube(frame,"VaultedRoofRib",path,Vector2(0.055,0.045),0.012,steel,simple)
		for x: float in [-0.35,0.35]: _beam(frame,"VaultPurlin",Vector3(x,2.6525,front.z),Vector3(x,2.6525,rear.z),Vector2(0.03,0.03),edge,simple)
	elif kind=="fork_round":
		for i: int in range(7):
			var t: float=(i+0.5)/7.0
			_beam(frame,"BarrelRoofSlat",Vector3(-0.70,2.47+0.23*sin(t*PI),lerpf(front.z,rear.z,t)),Vector3(0.70,2.47+0.23*sin(t*PI),lerpf(front.z,rear.z,t)),Vector2(0.055,0.035),steel,simple)
	elif kind in ["fork_canopy","fork_safari"]:
		var roof_material: Material = _finish("a6aa9b") if kind=="fork_safari" else paint
		var bounds := Rect2(-0.77,-0.93,1.54,1.88)
		if kind=="fork_safari": bounds=Rect2(-0.765,-0.97,1.53,0.64)
		Surface.deck(frame,"PressedWeatherRoof",bounds,2.65 if kind=="fork_canopy" else 2.60,0.018,[],roof_material,steel,simple)
		for side: float in [-1.0,1.0]:
			_beam(frame,"RoofDripEdge",Vector3(side*0.75,2.63 if kind=="fork_canopy" else 2.58,bounds.position.y+0.03),Vector3(side*0.75,2.63 if kind=="fork_canopy" else 2.58,bounds.end.y-0.03),Vector2(0.02,0.055),steel,simple)
			_beam(frame,"WeatherRoofSpacer",Vector3(side*0.70,front.y,front.z),Vector3(side*0.70,2.65 if kind=="fork_canopy" else 2.60,front.z),Vector2(0.055,0.055),steel,simple)
			if kind=="fork_canopy": _beam(frame,"RearRoofSpacer",Vector3(side*0.70,rear.y,rear.z),Vector3(side*0.70,2.65,rear.z),Vector2(0.055,0.055),steel,simple)
		if kind=="fork_safari":
			for z: float in [-0.20,0.10,0.40,0.70]: _beam(frame,"OpenRearRoofSlat",Vector3(-0.70,2.55,z),Vector3(0.70,2.55,z),Vector2(0.06,0.04),steel,simple)
	elif kind in ["fork_cross","fork_lattice"]:
		var count: int=1 if kind=="fork_cross" else 4
		for i: int in range(count):
			var z0: float=lerpf(front.z,rear.z,i/float(count))
			var z1: float=lerpf(front.z,rear.z,(i+1)/float(count))
			for direction: float in [-1.0,1.0]:
				_beam(frame,"RoofDiagonal",Vector3(-0.69*direction,front.y+0.015,z0),Vector3(0.69*direction,front.y+0.015,z1),Vector2(0.08 if kind=="fork_cross" else 0.035,0.035),steel,simple)
	elif kind=="fork_mesh":
		for axis: int in range(2):
			for i: int in range(11):
				var f: float=(i+0.5)/11.0
				var a:=Vector3(lerpf(-0.68,0.68,f) if axis==0 else -0.70,2.60,front.z if axis==0 else lerpf(front.z,rear.z,f))
				var b:=Vector3(a.x if axis==0 else 0.70,2.60,rear.z if axis==0 else a.z)
				_beam(frame,"FineRoofScreen",a,b,Vector2(0.018,0.018),edge,simple)
	else:
		var longitudinal: bool=kind in ["fork_canted","fork_sport","fork_twin"]
		var count: int=3 if kind=="fork_sport" else 4 if kind in ["fork_canted","fork_heavy"] else 5
		for i: int in range(count):
			var f: float=(i+0.5)/count
			var a: Vector3
			var b: Vector3
			if longitudinal:
				a=Vector3(lerpf(-front.x+0.08,front.x-0.08,f),front.y+0.01,front.z)
				b=Vector3(lerpf(-rear.x+0.08,rear.x-0.08,f),rear.y+0.01,rear.z)
			else:
				var p: Vector3=front.lerp(rear,f)
				a=Vector3(-p.x,p.y+0.015,p.z); b=Vector3(p.x,p.y+0.015,p.z)
			_beam(frame,"RoofProtectionSlat",a,b,Vector2(0.15 if kind in ["fork_heavy","fork_sport"] else 0.055,0.045),steel,simple)
	if kind in ["fork_plate","fork_heavy"]:
		for side: float in [-1.0,1.0]:
			_beam(frame,"DeepRoofSideRail",Vector3(side*front.x,front.y-0.025,front.z),Vector3(side*rear.x,rear.y-0.025,rear.z),Vector2(0.10,0.15 if kind=="fork_heavy" else 0.115),paint,simple)
	# Retained beacon is served by a shoe and two stays meeting actual roof members.
	_box(frame,"BeaconMountingShoe",Vector3(0.23,0.026,0.19),Vector3(0.55,2.705,0.65),steel,simple)
	var beacon_roof_y: float=front.lerp(rear,clampf((0.65-front.z)/(rear.z-front.z),0,1)).y
	if kind=="fork_round": beacon_roof_y=2.47+0.23*sin((0.65-front.z)/(rear.z-front.z)*PI)
	if kind=="fork_arch": beacon_roof_y=2.48+0.23*(1-pow(0.55/0.70,2))
	if kind=="fork_canopy": beacon_roof_y=2.66
	var width: float=front.lerp(rear,clampf((0.65-front.z)/(rear.z-front.z),0,1)).x
	_beam(frame,"BeaconMountStay",Vector3(0.55,beacon_roof_y,0.65),Vector3(width,beacon_roof_y,0.65),Vector2(0.055,0.035),steel,simple)
	_beam(frame,"BeaconRiser",Vector3(0.55,beacon_roof_y,0.65),Vector3(0.55,2.705,0.65),Vector2(0.06,0.06),steel,simple)

static func _wheels(car: CarVisual, kind: String) -> void:
	var steel: Material = _finish("9b9f94",0.35)
	var graphite: Material = _finish("485557",0.27)
	var hardware: Material = _finish("838e88",0.48)
	var dark: Material = CompactFinish.rubber(Color("20292b"))
	var settings: Dictionary = {
		"fork_disc":[0,0.42,0.40,0.07,0.012],"fork_ring":[0,0.42,0.40,0.07,0.012],
		"fork_spoke":[6,0.48,0.42,0.080,0.016],"fork_three":[3,0.47,0.39,0.098,0.024],
		"fork_four":[4,0.48,0.40,0.094,0.025],"fork_five":[5,0.46,0.41,0.088,0.022],
		"fork_eight":[8,0.43,0.43,0.065,0.010],"fork_turbine":[10,0.46,0.43,0.070,0.018],
		"fork_mesh":[12,0.40,0.44,0.041,0.010],"fork_dish":[0,0.4,0.40,0.07,-0.012],
		"fork_bolt":[0,0.4,0.40,0.07,0.008],"fork_slots":[8,0.64,0.40,0.085,0.014],
		"fork_star":[5,0.38,0.42,0.072,0.026]}
	for index: int in range(car.rolling_wheels.size()):
		var rotor: Node3D = car.rolling_wheels[index]
		var frame: Node3D = car.new_kit_frame("rims",rotor)
		var radius: float = car.wheel_radii[index]/HandlingConfig.BODY_SCALE
		var pivot: Node3D = rotor.get_parent()
		var side: float = signf(pivot.position.x)
		var width: float = 0.32 if pivot.position.z<0 else 0.25
		var face: float = width*0.48
		if kind in ["stock","fork_ring"]:
			Model.stock_wheel(frame,radius,width,side,kind=="fork_ring")
			if car.simple_model: RacingCarModels._reduce_primitives(frame)
			if kind=="stock": continue
		var wheel := Node3D.new()
		wheel.name="IndustrialWheelCover"
		frame.add_child(wheel)
		wheel.position.x=side*(face+(0.006 if kind=="fork_ring" else -0.010))
		wheel.rotation.z=-side*PI*0.5
		var profile := PackedVector2Array([Vector2(radius*0.535,-0.008),Vector2(radius*0.605,-0.008),Vector2(radius*0.623,0.001),Vector2(radius*0.623,0.012),Vector2(radius*0.609,0.022),Vector2(radius*0.571,0.022),Vector2(radius*0.548,0.012),Vector2(radius*0.535,0.007)])
		Surface.lathe(wheel,"RolledWheelFlange",profile,hardware if kind=="fork_ring" else steel,car.simple_model)
		if kind=="fork_ring": continue
		Surface.lathe(wheel,"WheelBarrel",PackedVector2Array([Vector2(radius*0.53,-width*0.85),Vector2(radius*0.595,-width*0.85),Vector2(radius*0.595,-0.008),Vector2(radius*0.53,-0.008)]),graphite,car.simple_model)
		var p: Array = settings[kind]
		Surface.wheel_face(wheel,radius,p[0],p[1],Vector2(p[2],p[3]),p[4],graphite if kind in ["fork_three","fork_four","fork_five","fork_star"] else steel,car.simple_model)
		Surface.lathe(wheel,"HubCover",PackedVector2Array([Vector2(0,-0.012),Vector2(radius*0.125,-0.012),Vector2(radius*0.14,0.016),Vector2(radius*0.14,0.031),Vector2(radius*0.10,0.045),Vector2(0,0.045)]),hardware,car.simple_model)
		var count: int = 8 if kind=="fork_bolt" else 6
		for i: int in range(count):
			var angle: float = i*TAU/count
			_bolt(wheel,Vector3(cos(angle)*radius*0.21,0.018+float(p[4])*0.65,sin(angle)*radius*0.21),Vector3.UP,radius*0.025,hardware)
		if kind=="fork_bolt":
			Surface.lathe(wheel,"SplitRimSeam",PackedVector2Array([Vector2(radius*0.49,0.014),Vector2(radius*0.50,0.014),Vector2(radius*0.50,0.017),Vector2(radius*0.49,0.017)]),dark,car.simple_model)
			for i: int in range(12):
				var angle: float = i*TAU/12
				_bolt(wheel,Vector3(cos(angle)*radius*0.515,0.020,sin(angle)*radius*0.515),Vector3.UP,radius*0.017,hardware)
