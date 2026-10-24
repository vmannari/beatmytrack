extends Node3D
## Original P1 parking hall with an open driving view; no roof or ceiling.
const HallData = preload("res://garage/parking_hall_data.gd")
var _batches: Dictionary = {}
var _materials: Dictionary = {}
var column_count: int = 0
var bay_count: int = 0
var parked_count: int = 0
var bay_rects: Array[Rect2] = []
var bay_codes: Array[String] = []

func build(data: PlaygroundData) -> void:
	name = "ParkingHall"
	_materials = {
		"concrete":VisualGeometry.material(Color("8c908a")),
		"cream":VisualGeometry.material(Color("c0beb0")),
		"dark":VisualGeometry.material(Color("283238")),
		"white":VisualGeometry.material(Color("c8c7b5")),
		"yellow":VisualGeometry.material(Color("c7aa59")),
		"teal":VisualGeometry.material(Color("39756f")),
		"red":VisualGeometry.material(Color("995c49"))}
	_materials["arrow"] = VisualGeometry.material(Color("c8c7b5"))
	_materials.arrow.cull_mode = BaseMaterial3D.CULL_DISABLED
	var floor_material := ShaderMaterial.new()
	floor_material.shader = preload("res://garage/parking_hall_floor.gdshader")
	floor_material.set_shader_parameter("concrete_map",preload("res://assets/textures/parking_concrete_v1.png"))
	floor_material.set_shader_parameter("walkway_bounds",Vector4(HallData.PEDESTRIAN_CORRIDOR.position.x,-HallData.PEDESTRIAN_CORRIDOR.end.y,HallData.PEDESTRIAN_CORRIDOR.end.x,-HallData.PEDESTRIAN_CORRIDOR.position.y))
	VisualGeometry.box(self,Vector3(HallData.SIZE.x,0.18,HallData.SIZE.y),Vector3(0,-0.09,0),floor_material)
	_build_enclosure(data)
	_build_columns(data)
	_build_bays()
	_build_aisles()
	_build_services()
	_build_parked_cars()
	# Static cylindrical parts are merged; live player car is outside this node.
	VisualGeometry.batch_static_parts(self)
	for key: String in _batches:
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.mesh = mesh
		batch.instance_count = _batches[key].size()
		for index: int in range(batch.instance_count): batch.set_instance_transform(index,_batches[key][index])
		var instance := MultiMeshInstance3D.new()
		instance.name = key.capitalize()+"Fixtures"
		instance.multimesh = batch
		instance.material_override = _materials[key]
		add_child(instance)
	_batches.clear()

func _build_enclosure(data: PlaygroundData) -> void:
	var extent: Vector2 = data.half_extent
	for side: float in [-1.0,1.0]:
		_box("concrete",Vector3(0.6,3.6,HallData.SIZE.y+1.2),Vector3(side*(extent.x+0.3),1.8,0))
		_box("concrete",Vector3(HallData.SIZE.x,3.6,0.6),Vector3(0,1.8,side*(extent.y+0.3)))
		_box("cream",Vector3(0.03,1.5,HallData.SIZE.y),Vector3(side*(extent.x-0.02),2.25,0))
		_box("cream",Vector3(HallData.SIZE.x,1.5,0.03),Vector3(0,2.25,side*(extent.y-0.02)))
		_box("teal",Vector3(0.04,0.38,HallData.SIZE.y),Vector3(side*(extent.x-0.045),1.1,0))
		_box("teal" if side < 0 else "red",Vector3(HallData.SIZE.x,0.38,0.04),Vector3(0,1.1,side*(extent.y-0.045)))
		_box("dark",Vector3(HallData.SIZE.x,0.12,0.12),Vector3(0,0.12,side*(extent.y-0.07)))
		if side < 0:
			# Stop the parking-edge line at both sides of the pedestrian route.
			_box("yellow",Vector3(6.2,0.012,0.12),Vector3(-55.9,0.017,side*34.6))
			_box("yellow",Vector3(108.2,0.012,0.12),Vector3(4.9,0.017,side*34.6))
		else:
			_box("yellow",Vector3(HallData.SIZE.x-2,0.012,0.12),Vector3(0,0.017,side*34.6))
		for x: int in [-48,-24,0,24,48]:
			_box("dark",Vector3(3.5,0.95,0.08),Vector3(x,2.5,side*35.9))
			for slat: int in range(5):
				_box("concrete",Vector3(3.4,0.07,0.13),Vector3(x,2.12+slat*0.18,side*35.8))
			_wall_label("P1",Vector3(x+6,1.9,side*35.91),0.021,PI if side > 0 else 0.0)
	for x: float in [-59.8,59.8]:
		for z: float in [-35.7,35.7]:
			_box("yellow",Vector3(0.18,1.25,0.55),Vector3(x,0.625,z))

func _build_columns(data: PlaygroundData) -> void:
	for pillar: Vector3 in data.get("columns"):
		var point := Vector3(pillar.x,0,-pillar.y)
		var zone: String = "teal" if pillar.y >= 0 else "red"
		VisualGeometry.cylinder(self,pillar.z,3.6,point+Vector3.UP*1.8,_materials.concrete)
		VisualGeometry.cylinder(self,pillar.z+0.003,1.55,point+Vector3.UP*0.775,_materials[zone])
		VisualGeometry.cylinder(self,pillar.z+0.006,0.24,point+Vector3.UP*0.12,_materials.dark)
		_box("dark",Vector3(1.18,0.3,0.12),point+Vector3(0,0.55,0.61))
		for stripe: int in range(4):
			_box("yellow",Vector3(0.13,0.29,0.03),point+Vector3(-0.43+stripe*0.28,0.55,0.69),-0.35)
		var letter: String = "A" if pillar.y >= 0 else "B"
		_wall_label(letter,point+Vector3(0,1.14,0.66),0.011)
		_wall_label(letter,point+Vector3(0,1.14,-0.66),0.011,PI)
		column_count += 1

func _build_bays() -> void:
	for side: float in [-1.0,1.0]:
		for index: int in range(36):
			# The two former A bays are a dedicated route to the stair door.
			if side < 0 and index < 2: continue
			var x: float = -54.0+index*3.0
			var code: String = ("A" if side < 0 else "B")+"%02d" % (index-1 if side < 0 else index+1)
			bay_codes.append(code)
			bay_rects.append(Rect2(x,-side*31.6-2.7,3.0,5.4))
			_box("white",Vector3(0.1,0.012,5.4),Vector3(x,0.018,side*31.6))
			_box("white",Vector3(3,0.012,0.1),Vector3(x+1.5,0.018,side*34.25))
			if index%2 == 0:
				_floor_label(code,Vector2(x+1.5,-side*28.0),0.36)
			bay_count += 1
		_box("white",Vector3(0.1,0.012,5.4),Vector3(54,0.018,side*31.6))
	for index: int in range(14):
		var x: float = 5.0+index*3.0
		for side: float in [-1.0,1.0]:
			var code: String = "A%02d" % (index+35+(14 if side > 0 else 0))
			bay_codes.append(code)
			bay_rects.append(Rect2(x,-side*4.0-2.55,3.0,5.1))
			_box("white",Vector3(0.1,0.012,5.1),Vector3(x,0.02,side*4.0))
			_box("white",Vector3(3.0,0.012,0.1),Vector3(x+1.5,0.02,side*1.45))
			if index%2 == 0: _floor_label(code,Vector2(x+1.5,-side*7.5),0.32)
			bay_count += 1
	for side: float in [-1.0,1.0]:
		_box("white",Vector3(0.1,0.012,5.1),Vector3(47,0.02,side*4.0))
	for stripe: int in range(14):
		_box("white",Vector3(HallData.CROSSING.size.x,0.012,0.48),Vector3(HallData.CROSSING.get_center().x,0.022,-(22.24+stripe)))
	for side: float in [-1.0,1.0]:
		_box("yellow",Vector3(0.1,0.012,14.0),Vector3(-51+side*1.8,0.024,-29))
	_floor_label("STAIRS",Vector2(-51,20.3),0.46)

func _build_aisles() -> void:
	# Discreet aisle paint replaces the old proving-ground grid and target rings.
	for side: float in [-1.0,1.0]:
		for x: int in range(-42,49,18):
			_arrow(Vector2(x,side*18),-PI*0.5 if side < 0 else PI*0.5)
	for x: int in range(-45,46,15):
		_box("yellow",Vector3(0.12,0.012,0.7),Vector3(x,0.024,24.0))
		_floor_label(str(x+45),Vector2(x,-25.0),0.29)
	_floor_label("P1",Vector2(-44,-12),1.65,Color("d1cbb1"))
	_floor_label("NORTH GARAGE",Vector2(-43,-15),0.38)
	_floor_label("KEEP CLEAR",Vector2(-24,8),0.55)
	for index: int in range(5):
		var point := Vector3(30+(-2.2 if index%2 == 0 else 2.2),0,-(11+index*2.7))
		_box("dark",Vector3(0.5,0.07,0.5),point+Vector3.UP*0.035)
		var cone := VisualGeometry.cylinder(self,0.22,0.5,point+Vector3.UP*0.29,_materials.red)
		(cone.mesh as CylinderMesh).top_radius = 0.04
	for index: int in range(10):
		_box("yellow",Vector3(0.12,0.012,3.0),Vector3(-51+index*0.55,0.023,4.5),-0.5)

func _build_services() -> void:
	_box("dark",Vector3(0.09,3.1,6.0),Vector3(-59.91,1.55,18.0))
	for slat: int in range(18):
		_box("concrete",Vector3(0.12,0.075,5.8),Vector3(-59.83,0.15+slat*0.16,18.0))
	_box("yellow",Vector3(0.2,0.18,6.1),Vector3(-59.7,3.12,18.0))
	_box("teal",Vector3(2.1,2.7,0.12),Vector3(-51,1.35,-35.9))
	_box("dark",Vector3(0.12,0.7,0.04),Vector3(-50.2,1.1,-35.81))
	_box("teal",Vector3(2.6,0.55,0.18),Vector3(-51,2.98,-35.75))
	_wall_label("EXIT  ↑",Vector3(-51,2.98,-35.63),0.006)
	for x: float in [-42.0,42.0]:
		_box("red",Vector3(0.8,1.1,0.18),Vector3(x,1.0,-35.85))
		_box("white",Vector3(0.44,0.55,0.025),Vector3(x,1.12,-35.74))
		_wall_label("F",Vector3(x,1.15,-35.71),0.005,0.0,Color("9a4434"))
		_box("red",Vector3(0.08,2.8,0.09),Vector3(x-0.65,1.4,-35.82))
	_sign("P1  /  A",Vector2(-36,35.8),"teal")
	_sign("EXIT  →",Vector2(-48,-35.8),"teal")
	_sign("B  /  PARKING",Vector2(30,-35.8),"red")
	_sign("←  STAIRS",Vector2(18,35.8),"dark")

func _build_parked_cars() -> void:
	for parked: Dictionary in HallData.PARKED_CARS:
		var car := CarVisual.new()
		car.name = "Parked_"+str(parked.vehicle)
		car.vehicle_id = parked.vehicle
		car.simple_model = true
		car.livery = VehicleLivery.defaults(parked.vehicle)
		car.livery.colors.body = parked.colour
		car.position = Vector3(parked.position.x,0,-parked.position.y)
		car.rotation.y = PI if parked.position.y < 0 else 0.0
		add_child(car)
		car.process_mode = Node.PROCESS_MODE_DISABLED
		parked_count += 1

func _box(material: String, dimensions: Vector3, point: Vector3, angle: float = 0.0) -> void:
	if not _batches.has(material): _batches[material] = []
	var basis: Basis = Basis(Vector3.UP,angle)*Basis.from_scale(dimensions)
	_batches[material].append(Transform3D(basis,point))

func _floor_label(text: String, point: Vector2, scale_factor: float, colour: Color = Color("babba9")) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 64
	label.pixel_size = 0.02*scale_factor
	label.modulate = colour
	label.outline_size = 0
	label.rotation.x = -PI*0.5
	label.position = Vector3(point.x,0.035,-point.y)
	add_child(label)

func _wall_label(text: String, point: Vector3, pixel_size: float, yaw: float = 0.0, colour: Color = Color("e1ddca"), parent: Node3D = null) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 64
	label.pixel_size = pixel_size
	label.modulate = colour
	label.outline_size = 0
	label.position = point
	label.rotation.y = yaw
	(self if parent == null else parent).add_child(label)

func _arrow(point: Vector2, angle: float) -> void:
	var center := Vector3(point.x,0.024,-point.y)
	var points := PackedVector3Array([Vector3(0,0,-1.6),Vector3(-0.65,0,-0.45),Vector3(-0.2,0,-0.45),Vector3(-0.2,0,1),Vector3(0.2,0,1),Vector3(0.2,0,-0.45),Vector3(0.65,0,-0.45)])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var basis := Basis(Vector3.UP,angle)
	for index: int in [0,2,1,0,5,2,0,6,5,2,4,3,2,5,4]:
		surface.set_normal(Vector3.UP)
		surface.add_vertex(center+basis*points[index])
	var arrow := MeshInstance3D.new()
	arrow.mesh = surface.commit()
	arrow.name = "AisleArrow"
	arrow.material_override = _materials.arrow
	arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(arrow)

func _sign(text: String, point: Vector2, colour: String) -> void:
	var sign := Node3D.new()
	sign.name = "WallSign"
	sign.position = Vector3(point.x,2.15,-point.y)
	if point.y < 0: sign.rotation.y = PI
	add_child(sign)
	VisualGeometry.box(sign,Vector3(4.3,0.9,0.16),Vector3.ZERO,_materials[colour])
	_wall_label(text,Vector3(0,0,0.09),0.009,0.0,Color("e7e5ce"),sign)
