class_name GarageWorkshop
extends RefCounted
## Original reference-led furnishings and architectural lighting, menu only.

static func build(root: Node3D) -> void:
	var metal: Material = GarageEnvironment.surfaces.edges
	var dark: Material = GarageEnvironment.surfaces.inset
	var brass: Material = GarageEnvironment.surface("brass","bba060",0.65,0.38)
	var lamp: Material = GarageEnvironment.surface("warmstrip","f1cd7f",0,0.4,1.3)
	# Everything functional belongs to the back wall.
	GarageFurnishings.shelves(root)
	# Three safety cans, with inset panels and formed handles.
	for index: int in range(3):
		var can := Node3D.new()
		can.name = "WorkshopSafetyCan"
		can.position = Vector3(-9.15+index*0.50,0.12,8.0)
		root.add_child(can)
		GarageEnvironment.box(can,Vector3(0,0.34,0),Vector3(0.38,0.65,0.24),GarageEnvironment.surface("cans","304852",0.2))
		GarageEnvironment.box(can,Vector3(0,0.34,-0.125),Vector3(0.27,0.47,0.012),dark)
		for x: float in [-0.08,0.08]: GarageEnvironment.box(can,Vector3(x,0.73,0),Vector3(0.035,0.10,0.035),metal)
		GarageEnvironment.box(can,Vector3(0,0.78,0),Vector3(0.20,0.035,0.035),metal)
	for x: float in [-5.0,5.0]:
		GarageEnvironment.box(root,Vector3(x,4.47,8.35),Vector3(0.42,0.16,0.22),dark)
		GarageEnvironment.box(root,Vector3(x,4.38,8.30),Vector3(0.29,0.035,0.18),lamp)
		_spot(root,Vector3(x,4.35,8.05),Vector3(x,1.15,8.80),3.8,7.0,42.0)
	# Steel roof trusses, with open triangular webs and suspended luminaires.
	var roof: Node3D = root.find_child("GarageRoof",true,false)
	for z: float in [-2.0,3.5,8.3]:
		for x: float in [-8.0,-4.0,0.0,4.0,8.0]:
			_beam(roof,Vector3(x-2,5.66,z),Vector3(x,5.15,z),0.045,metal)
			_beam(roof,Vector3(x,5.15,z),Vector3(x+2,5.66,z),0.045,metal)
		GarageEnvironment.box(roof,Vector3(0,5.13,z),Vector3(20.7,0.055,0.065),dark)
		if z<8:
			GarageEnvironment.box(roof,Vector3(0,5.1,z),Vector3(5.8,0.09,0.32),dark)
			GarageEnvironment.box(roof,Vector3(0,5.04,z),Vector3(5.55,0.025,0.24),lamp)
	for x: float in [-10.38,10.38]:
		GarageEnvironment.box(root,Vector3(x,0.08,0),Vector3(0.035,0.16,17.5),dark)
		GarageEnvironment.box(root,Vector3(x,0.019,0),Vector3(0.11,0.018,17.5),brass)
	_poster(root)
	_compressor(root)
	_plant(root)
	for item: Array in [[Vector3(-6.9,0.006,7.65),Vector2(4.5,1.6)],[Vector3(6.35,0.006,7.65),Vector2(3.9,1.5)],[Vector3(9.2,0.006,7.6),Vector2(2.5,1.4)]]:
		ShowroomStudio._contact(root,item[0],item[1],0.42)

static func _spot(root: Node3D, at: Vector3, target: Vector3, energy: float, distance: float, angle: float) -> void:
	var light := SpotLight3D.new()
	light.name = "WorkshopWallLight"
	light.position = at
	light.light_color = Color("ffe0a3")
	light.light_energy = energy
	light.spot_range = distance
	light.spot_angle = angle
	light.spot_attenuation = 0.5
	root.add_child(light)
	light.look_at(root.to_global(target))

static func _beam(root: Node3D, a: Vector3, b: Vector3, width: float, material: Material) -> void:
	var beam: MeshInstance3D = GarageEnvironment.box(root,(a+b)*0.5,Vector3(width,a.distance_to(b),width),material)
	beam.quaternion = Quaternion(Vector3.UP,(b-a).normalized())

static func _bottle(root: Node3D, at: Vector3, height: float) -> void:
	GarageFurnishings.bottle(root,at,height)

static func _toolbox(root: Node3D, at: Vector3) -> void:
	GarageFurnishings.case_model(root,at)

static func _poster(root: Node3D) -> void:
	var poster := Node3D.new()
	poster.name = "GarageLeftPoster"
	poster.position = Vector3(10.35,2.75,5.4)
	poster.rotation.y = PI*0.5
	root.add_child(poster)
	var trim: Material = GarageEnvironment.surface("postertrim","a58b4d",0.5,0.45)
	GarageEnvironment.box(poster,Vector3.ZERO,Vector3(2.30,3.30,0.13),GarageEnvironment.surfaces.inset)
	GarageEnvironment.box(poster,Vector3(0,0,-0.08),Vector3(2.12,3.12,0.025),trim)
	GarageEnvironment.box(poster,Vector3(0,0,-0.105),Vector3(2.06,3.06,0.012),GarageEnvironment.surface("posterink","101a21"))
	var stripe: MeshInstance3D = GarageEnvironment.box(poster,Vector3(0.67,-0.26,-0.13),Vector3(0.11,2.55,0.01),trim)
	stripe.rotation.z = -0.28
	var text := Label3D.new()
	text.text = "DRIVE\nIMPROVE\nREPEAT"
	text.font = MenuStyle.DISPLAY
	text.font_size = 64
	text.pixel_size = 0.0049
	text.modulate = Color("d2d5cb")
	text.outline_size = 0
	text.rotation.y = PI
	text.position = Vector3(-0.18,0.10,-0.14)
	poster.add_child(text)
	for x: float in [-1.05,1.05]:
		GarageEnvironment.box(poster,Vector3(x,0,-0.130),Vector3(0.016,3.02,0.018),trim)
		for y: float in [-1.51,1.51]: GarageFurnishings.bolt(poster,Vector3(x,y,-0.139),0.013)
	for y: float in [-1.51,1.51]: GarageEnvironment.box(poster,Vector3(0,y,-0.130),Vector3(2.10,0.016,0.018),trim)

static func _compressor(root: Node3D) -> void:
	var compressor := Node3D.new()
	compressor.name = "GarageCompressor"
	compressor.position = Vector3(5.4,0,7.1)
	root.add_child(compressor)
	GarageFurnishings.compressor(compressor)

static func _plant(root: Node3D) -> void:
	preload("res://ui/garage_plant.gd").build(root)
