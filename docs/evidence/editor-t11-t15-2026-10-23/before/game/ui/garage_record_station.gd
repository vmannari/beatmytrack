extends RefCounted
## Fabricated listening console, 12-inch vinyl and matching LP sleeves.
const Library = preload("res://soundtrack/record_library.gd")
const CENTER := Vector3(9.80,1.15,4.70)
const CAMERA := Vector3(6.65,2.10,3.75)

static func build(root: Node3D) -> void:
	var station := Node3D.new()
	station.name = "GarageRecordStation"
	station.position = Vector3(9.80,0,4.70)
	station.rotation.y = PI*0.5
	root.add_child(station)
	var wood: Material = GarageFurnishings.wood()
	var metal: Material = GarageFurnishings.metal()
	var dark: Material = GarageFurnishings.rubber()
	# Solid cabinet with inset doors, record shelf and four seated feet.
	GarageEnvironment.box(station,Vector3(0,0.85,0),Vector3(2.10,0.08,0.68),wood)
	for x: float in [-1.0,1.0]: GarageEnvironment.box(station,Vector3(x,0.51,0.02),Vector3(0.055,0.62,0.61),wood)
	GarageEnvironment.box(station,Vector3(0,0.215,0.02),Vector3(2.04,0.06,0.61),wood)
	GarageEnvironment.box(station,Vector3(0,0.53,0.31),Vector3(2.04,0.60,0.025),wood)
	GarageEnvironment.box(station,Vector3(0,0.52,0.02),Vector3(0.04,0.60,0.61),wood)
	GarageEnvironment.box(station,Vector3(-0.5,0.51,-0.30),Vector3(0.94,0.53,0.035),wood)
	GarageEnvironment.box(station,Vector3(-0.12,0.66,-0.326),Vector3(0.045,0.018,0.018),metal)
	for x: float in [-0.9,0.9]:
		for z: float in [-0.24,0.24]:
			GarageFurnishings.tube(station,Vector3(x,0.018,z),Vector3(x,0.19,z),0.028,GarageFurnishings.steel())
			GarageEnvironment.box(station,Vector3(x,0.015,z),Vector3(0.065,0.025,0.065),dark)
	# The player is actual LP scale: 30cm record on a 57cm plinth.
	var player := Node3D.new()
	player.name = "GarageRecordPlayer"
	player.position = Vector3(-0.26,0.93,-0.07)
	station.add_child(player)
	GarageEnvironment.box(player,Vector3.ZERO,Vector3(0.57,0.065,0.43),wood)
	GarageEnvironment.box(player,Vector3(0,0.038,0),Vector3(0.548,0.015,0.406),GarageFurnishings.steel())
	for x: float in [-0.22,0.22]:
		for z: float in [-0.15,0.15]: GarageFurnishings.tube(player,Vector3(x,-0.033,z),Vector3(x,-0.051,z),0.026,dark)
	GarageFurnishings.tube(player,Vector3(-0.065,0.054,0),Vector3(-0.065,0.064,0),0.160,metal,64)
	var disc := Node3D.new()
	disc.name = "GarageVinyl"
	disc.position = Vector3(-0.065,0.070,0)
	player.add_child(disc)
	var vinyl := ShaderMaterial.new()
	vinyl.shader = preload("res://ui/garage_vinyl.gdshader")
	GarageFurnishings.tube(disc,Vector3(0,-0.002,0),Vector3(0,0.002,0),0.152,vinyl,64)
	var label: MeshInstance3D = GarageFurnishings.tube(disc,Vector3(0,0.0022,0),Vector3(0,0.0028,0),0.047,GarageEnvironment.surface("recordlabel","dfbc72",0.03,0.60),48)
	label.name = "GarageVinylLabel"
	GarageFurnishings.tube(disc,Vector3(0,0.003,0),Vector3(0,0.010,0),0.003,metal,12)
	GarageEnvironment.box(disc,Vector3(0.024,0.0035,0),Vector3(0.011,0.001,0.009),dark)
	# Tonearm with pivot, counterweight, bent tube and stylus cartridge.
	GarageFurnishings.tube(player,Vector3(0.19,0.048,0.12),Vector3(0.19,0.088,0.12),0.020,metal)
	GarageFurnishings.tube(player,Vector3(0.19,0.082,0.154),Vector3(0.19,0.082,0.183),0.019,dark)
	GarageFurnishings.tube(player,Vector3(0.19,0.084,0.14),Vector3(0.19,0.084,-0.08),0.0055,metal)
	GarageFurnishings.tube(player,Vector3(0.19,0.084,-0.08),Vector3(0.06,0.080,-0.106),0.0055,metal)
	GarageEnvironment.box(player,Vector3(0.055,0.074,-0.106),Vector3(0.032,0.013,0.018),dark)
	for x: float in [-0.235,-0.20]:
		GarageFurnishings.tube(player,Vector3(x,0.053,-0.175),Vector3(x,0.057,-0.175),0.011,metal,20)
	# Open cover is a framed smoked solid, clear of the left poster.
	var lid := Node3D.new()
	lid.position = Vector3(0,0.045,0.20)
	lid.rotation.x = PI*0.40
	player.add_child(lid)
	GarageEnvironment.box(lid,Vector3(0,0,-0.195),Vector3(0.57,0.007,0.40),GarageEnvironment.surface("recordlid","35444b",0.15,0.26))
	for x: float in [-0.27,0.27]: GarageEnvironment.box(lid,Vector3(x,-0.014,-0.195),Vector3(0.008,0.035,0.40),metal)
	# Compact matched speakers with separate cone, surround and tweeter.
	for x: float in [-0.86,0.86]:
		GarageEnvironment.box(station,Vector3(x,1.09,0.04),Vector3(0.27,0.40,0.28),wood)
		GarageEnvironment.box(station,Vector3(x,1.09,-0.106),Vector3(0.24,0.37,0.014),dark)
		for spec: Vector2 in [Vector2(1.035,0.087),Vector2(1.215,0.035)]:
			GarageFurnishings.tube(station,Vector3(x,spec.x,-0.115),Vector3(x,spec.x,-0.128),spec.y,dark,32)
			GarageFurnishings.tube(station,Vector3(x,spec.x,-0.131),Vector3(x,spec.x,-0.136),spec.y*0.73,GarageEnvironment.surface("speakercone","465157",0.08,0.71),32)
			GarageFurnishings.tube(station,Vector3(x,spec.x,-0.137),Vector3(x,spec.x,-0.149),spec.y*0.26,dark,24)
	var sleeves := Node3D.new()
	# A tabletop record crate, with solid slatted returns and an open hand slot.
	var crate_center := Vector3(0.43,0.94,0)
	GarageEnvironment.box(station,crate_center,Vector3(0.41,0.025,0.42),wood)
	for x: float in [-0.198,0.198]:
		GarageEnvironment.box(station,crate_center+Vector3(x,0.053,0),Vector3(0.014,0.105,0.42),wood)
	for z: float in [-0.203,0.203]:
		GarageEnvironment.box(station,crate_center+Vector3(0,0.02,z),Vector3(0.39,0.035,0.014),wood)
		GarageEnvironment.box(station,crate_center+Vector3(0,0.075,z),Vector3(0.39,0.035,0.014),wood)
		for x: float in [-0.13,0.13]: GarageEnvironment.box(station,crate_center+Vector3(x,0.045,z),Vector3(0.13,0.02,0.014),wood)
	sleeves.name = "GarageRecordSleeves"
	station.add_child(sleeves)
	update(station,{})

static func update(station: Node3D, settings: Dictionary) -> void:
	var chosen: Dictionary = Library.selected(settings)
	var label: MeshInstance3D = station.find_child("GarageVinylLabel",true,false)
	if label != null:
		var material := StandardMaterial3D.new()
		material.albedo_color = Library.palette(chosen.id)[1]
		material.roughness = 0.65
		label.material_override = material
	var shelf: Node3D = station.find_child("GarageRecordSleeves",true,false)
	for child: Node in shelf.get_children():
		shelf.remove_child(child)
		child.queue_free()
	var collection: Array[Dictionary] = Library.entries(settings)
	for index: int in range(collection.size()):
		var sleeve := Node3D.new()
		sleeve.name = "LPSleeve_" + collection[index].id
		sleeve.position = Vector3(0.43,0.96,-0.12+index*0.036)
		sleeve.set_meta("lp_index",index)
		shelf.add_child(sleeve)
		GarageEnvironment.box(sleeve,Vector3(0,0.165,0),Vector3(0.33,0.33,0.003),GarageEnvironment.surface("sleevepaper","d4cdbf",0,0.9))
		var cover := StandardMaterial3D.new()
		cover.albedo_texture = Library.cover(collection[index].id)
		cover.roughness = 0.8
		var face := PlaneMesh.new()
		face.size = Vector2(0.324,0.324)
		var art: MeshInstance3D = GarageFurnishings.mesh(sleeve,Vector3(0,0.165,-0.002),face,cover)
		art.rotation.x = -PI*0.5
		var title := Label3D.new()
		title.text = collection[index].title.left(24)
		title.font = MenuStyle.DISPLAY
		title.font_size = 32
		title.pixel_size = 0.001
		title.position = Vector3(0,0.271,-0.003)
		title.rotation.y = PI
		title.modulate = Color("f3ead4")
		title.outline_size = 0
		sleeve.add_child(title)
	present_browse(shelf,0.0)

static func present_browse(shelf: Node3D, position: float) -> void:
	for sleeve: Node3D in shelf.get_children():
		var distance: float = float(sleeve.get_meta("lp_index",0))-position
		sleeve.rotation.x = lerpf(0.10,-0.70,clampf(-distance,0.0,1.0))
