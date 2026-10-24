extends RefCounted
## Fabricated listening console, 12-inch vinyl and matching LP sleeves.
const Library = preload("res://soundtrack/record_library.gd")
const CENTER := Vector3(9.80,0.73,4.70)
const CAMERA := Vector3(7.32,1.82,3.89)
static var walnut: ShaderMaterial

static func wood() -> Material:
	if walnut == null:
		walnut = ShaderMaterial.new()
		walnut.shader = preload("res://ui/garage_audio_wood.gdshader")
	return walnut

static func build(root: Node3D) -> void:
	var station := Node3D.new()
	station.name = "GarageRecordStation"
	station.position = Vector3(9.80,0,4.70)
	station.rotation.y = PI*0.5
	root.add_child(station)
	var wood: Material = wood()
	var metal: Material = GarageFurnishings.metal()
	var dark: Material = GarageFurnishings.rubber()
	var brass: Material = GarageMaterials.finish("recordbrass","ad8852",0.65,0.39,1)
	var deck: Material = GarageMaterials.finish("recorddeck","23313a",0.40,0.42,1)
	var cone: Material = GarageEnvironment.surface("recorddriver","535e63",0.04,0.68)
	# One small shadowless listening lamp warms only this cabinet and hardware.
	var lamp := OmniLight3D.new()
	lamp.name = "GarageListeningLight"
	lamp.position = Vector3(-0.55,1.90,-0.36)
	lamp.light_color = Color("ffcf91")
	lamp.light_energy = 0.65
	lamp.omni_range = 2.2
	lamp.omni_attenuation = 1.6
	lamp.shadow_enabled = false
	station.add_child(lamp)
	# Solid cabinet with inset doors, record shelf and four seated feet.
	GarageEnvironment.box(station,Vector3(0,0.85,0),Vector3(2.10,0.08,0.68),wood)
	GarageEnvironment.box(station,Vector3(0,0.805,-0.015),Vector3(2.06,0.012,0.64),dark)
	for x: float in [-1.0,1.0]: GarageEnvironment.box(station,Vector3(x,0.51,0.02),Vector3(0.055,0.62,0.61),wood)
	GarageEnvironment.box(station,Vector3(0,0.215,0.02),Vector3(2.04,0.06,0.61),wood)
	GarageEnvironment.box(station,Vector3(0,0.53,0.31),Vector3(2.04,0.60,0.025),wood)
	GarageEnvironment.box(station,Vector3(0,0.52,0.02),Vector3(0.04,0.60,0.61),wood)
	GarageEnvironment.box(station,Vector3(-0.5,0.51,-0.30),Vector3(0.94,0.53,0.035),wood)
	GarageEnvironment.box(station,Vector3(-0.5,0.51,-0.320),Vector3(0.90,0.49,0.005),dark)
	GarageEnvironment.box(station,Vector3(-0.5,0.51,-0.324),Vector3(0.884,0.474,0.011),wood)
	GarageEnvironment.box(station,Vector3(-0.12,0.66,-0.336),Vector3(0.07,0.014,0.02),metal)
	# Fitted inner shelf and restrained metal door pull.
	GarageEnvironment.box(station,Vector3(0.50,0.46,0.025),Vector3(0.94,0.025,0.56),wood)
	# A short seated stack of jackets gives the open bay a real listening-room use.
	for index: int in range(3):
		var jacket := Node3D.new()
		jacket.position = Vector3(0.58+index*0.004,0.251+index*0.007,-0.06)
		jacket.rotation.y = (index-1)*0.024
		station.add_child(jacket)
		GarageEnvironment.box(jacket,Vector3.ZERO,Vector3(0.335,0.005,0.335),dark)
		var art := StandardMaterial3D.new()
		art.albedo_texture = Library.cover(Library.CATALOG[index].id)
		art.roughness = 0.80
		var square := PlaneMesh.new()
		square.size = Vector2(0.33,0.33)
		GarageFurnishings.mesh(jacket,Vector3(0,0.0027,0),square,art)
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
	GarageEnvironment.box(player,Vector3(0,0.038,0),Vector3(0.548,0.015,0.406),deck)
	GarageEnvironment.box(player,Vector3(0,0.010,-0.216),Vector3(0.55,0.008,0.003),brass)
	for x: float in [-0.22,0.22]:
		for z: float in [-0.15,0.15]: GarageFurnishings.tube(player,Vector3(x,-0.033,z),Vector3(x,-0.051,z),0.026,dark)
	GarageFurnishings.tube(player,Vector3(-0.065,0.054,0),Vector3(-0.065,0.064,0),0.160,metal,64)
	GarageFurnishings.tube(player,Vector3(-0.065,0.063,0),Vector3(-0.065,0.067,0),0.157,dark,64)
	# A rolled platter lip catches the room light instead of a flat painted edge.
	var platter_rim: MeshInstance3D = GarageFurnishings.lathe(player,Vector3(-0.065,0.060,0),[Vector2(0.155,0),Vector2(0.160,0.001),Vector2(0.161,0.004),Vector2(0.159,0.007),Vector2(0.155,0.008)],metal)
	platter_rim.name = "GaragePlatterRim"
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
	GarageEnvironment.box(player,Vector3(0.049,0.065,-0.106),Vector3(0.013,0.004,0.011),brass)
	# Turned alloy controls: dark skirt, machined rim, inset face and ivory marker.
	for x: float in [0.18,0.235]:
		GarageFurnishings.tube(player,Vector3(x,0.048,-0.163),Vector3(x,0.052,-0.163),0.021,dark,32)
		GarageFurnishings.lathe(player,Vector3(x,0.052,-0.163),[Vector2(0.014,0),Vector2(0.016,0.002),Vector2(0.016,0.012),Vector2(0.014,0.015),Vector2(0.012,0.016)],metal)
		GarageFurnishings.tube(player,Vector3(x,0.067,-0.163),Vector3(x,0.068,-0.163),0.013,deck,32)
		GarageEnvironment.box(player,Vector3(x-0.004,0.0686,-0.169),Vector3(0.002,0.001,0.008),brass)
	for x: float in [-0.245,-0.205]:
		GarageFurnishings.tube(player,Vector3(x,0.047,-0.166),Vector3(x,0.051,-0.166),0.010,metal,24)
	for x: float in [-0.254,0.254]:
		for z: float in [-0.185,0.185]:
			GarageFurnishings.tube(player,Vector3(x,0.046,z),Vector3(x,0.047,z),0.0038,metal,12)
	# One small amber pilot light, no extra light or animated material.
	GarageFurnishings.tube(player,Vector3(-0.168,0.047,-0.166),Vector3(-0.168,0.049,-0.166),0.003,brass,12)
	# Open cover is a framed smoked solid, clear of the left poster.
	var lid := Node3D.new()
	lid.position = Vector3(0,0.045,0.20)
	lid.rotation.x = PI*0.40
	player.add_child(lid)
	var smoke := ShaderMaterial.new()
	smoke.shader = preload("res://ui/garage_audio_lid.gdshader")
	GarageEnvironment.box(lid,Vector3(0,0,-0.195),Vector3(0.57,0.005,0.40),smoke)
	for x: float in [-0.282,0.282]:
		GarageEnvironment.box(lid,Vector3(x,-0.022,-0.195),Vector3(0.004,0.044,0.40),smoke)
	GarageEnvironment.box(lid,Vector3(0,-0.022,-0.394),Vector3(0.566,0.044,0.004),smoke)
	for x: float in [-0.282,0.282]: GarageEnvironment.box(lid,Vector3(x,-0.006,-0.195),Vector3(0.004,0.014,0.40),deck)
	GarageEnvironment.box(lid,Vector3(0,-0.006,-0.394),Vector3(0.566,0.014,0.004),metal)
	for x: float in [-0.20,0.20]:
		GarageEnvironment.box(player,Vector3(x,0.045,0.199),Vector3(0.040,0.022,0.018),brass)
	# Compact matched speakers with separate cone, surround and tweeter.
	for x: float in [-0.86,0.86]:
		GarageEnvironment.box(station,Vector3(x,1.09,0.04),Vector3(0.27,0.40,0.28),wood)
		GarageEnvironment.box(station,Vector3(x,1.09,-0.106),Vector3(0.24,0.37,0.014),dark)
		for dx: float in [-0.102,0.102]:
			for y: float in [0.927,1.253]:
				GarageFurnishings.tube(station,Vector3(x+dx,y,-0.114),Vector3(x+dx,y,-0.117),0.003,metal,12)
		for spec: Vector2 in [Vector2(1.035,0.087),Vector2(1.215,0.035)]:
			_driver(station,Vector3(x,spec.x,-0.115),spec.y,metal,dark,cone)
		GarageEnvironment.box(station,Vector3(x,0.926,-0.116),Vector3(0.032,0.006,0.003),brass)
	var sleeves := Node3D.new()
	# A tabletop record crate, with solid slatted returns and an open hand slot.
	var crate_center := Vector3(0.43,0.94,0)
	GarageEnvironment.box(station,crate_center,Vector3(0.41,0.025,0.42),wood)
	for x: float in [-0.198,0.198]:
		GarageEnvironment.box(station,crate_center+Vector3(x,0.067,0),Vector3(0.014,0.134,0.42),wood)
	for z: float in [-0.203,0.203]:
		GarageEnvironment.box(station,crate_center+Vector3(0,0.035,z),Vector3(0.39,0.065,0.014),wood)
		GarageEnvironment.box(station,crate_center+Vector3(0,0.118,z),Vector3(0.39,0.032,0.014),wood)
		for x: float in [-0.125,0.125]: GarageEnvironment.box(station,crate_center+Vector3(x,0.085,z),Vector3(0.14,0.037,0.014),wood)
		GarageEnvironment.box(station,crate_center+Vector3(0,0.136,z),Vector3(0.39,0.004,0.017),brass)
	sleeves.name = "GarageRecordSleeves"
	station.add_child(sleeves)
	update(station,{})

static func _driver(parent: Node3D, at: Vector3, radius: float, alloy: Material, rubber: Material, cone: Material) -> void:
	# Smooth rolled surround, recessed diaphragm and convex dust cap; all opaque
	# and prepared into the existing static material batches.
	var profiles: Array[Array] = [
		[Vector2(radius*1.06,0),Vector2(radius*1.065,0.002),Vector2(radius,0.004)],
		[Vector2(radius,0.003),Vector2(radius*0.96,0.008),Vector2(radius*0.90,0.011),Vector2(radius*0.82,0.004)],
		[Vector2(radius*0.82,0.004),Vector2(radius*0.70,-0.004),Vector2(radius*0.28,-0.018)],
		[Vector2(radius*0.29,-0.018),Vector2(radius*0.26,-0.009),Vector2(radius*0.16,-0.002),Vector2(0,0.001)]
	]
	var materials: Array[Material] = [alloy,rubber,cone,rubber]
	for index: int in range(profiles.size()):
		var profile: Array[Vector2] = []
		profile.assign(profiles[index])
		var part: MeshInstance3D = GarageFurnishings.lathe(parent,at,profile,materials[index])
		part.rotation.x = -PI*0.5

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
