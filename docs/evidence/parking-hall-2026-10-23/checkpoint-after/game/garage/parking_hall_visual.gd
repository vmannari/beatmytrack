extends Node3D
## Original concrete parking hall, presented as a cutaway for the overhead camera.
## Repeated fixtures are batched; there are no per-bay lights or physics bodies.
const HallData = preload("res://garage/parking_hall_data.gd")
var _batches: Dictionary = {}
var _materials: Dictionary = {}

func build(data: PlaygroundData) -> void:
	name = "ParkingHall"
	_materials = {
		"concrete":VisualGeometry.material(Color("7c8587")),
		"dark":VisualGeometry.material(Color("253239")),
		"white":VisualGeometry.material(Color("c0c4ba")),
		"yellow":VisualGeometry.material(Color("d4b565")),
		"blue":VisualGeometry.material(Color("436a7c")),
		"red":VisualGeometry.material(Color("a65d4a")),
		"lamp":VisualGeometry.material(Color("dce8df"))}
	_materials.lamp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var floor_material := ShaderMaterial.new()
	floor_material.shader = preload("res://garage/parking_hall_floor.gdshader")
	VisualGeometry.box(self,Vector3(240,0.18,160),Vector3(0,-0.09,0),floor_material)
	# Inner faces exactly match PlaygroundData's enclosing wall bounds.
	for side: float in [-1.0,1.0]:
		_box("concrete",Vector3(0.8,4.8,161.6),Vector3(side*120.4,2.4,0))
		_box("concrete",Vector3(240,4.8,0.8),Vector3(0,2.4,side*80.4))
		_box("blue",Vector3(0.04,0.8,160),Vector3(side*119.98,1.3,0))
		_box("blue",Vector3(240,0.8,0.04),Vector3(0,1.3,side*79.98))
		# Perimeter roof/ventilation reveals imply a ceiling without hiding the car.
		_box("dark",Vector3(2.8,0.5,160),Vector3(side*118.6,5.0,0))
		_box("dark",Vector3(240,0.5,2.8),Vector3(0,5.0,side*78.6))
		for x: int in range(-108,109,24):
			_box("dark",Vector3(8,1.8,0.08),Vector3(x,2.9,side*79.9))
			for louver: int in range(5):
				_box("concrete",Vector3(7.8,0.08,0.12),Vector3(x,2.2+louver*0.3,side*79.82))
	for pillar: Vector3 in data.islands:
		var point := Vector3(pillar.x,0,-pillar.y)
		# Round columns and their painted base share the exact swept-circle radius.
		VisualGeometry.cylinder(self,pillar.z,5.4,point+Vector3.UP*2.7,_materials.concrete)
		VisualGeometry.cylinder(self,pillar.z+0.002,0.8,point+Vector3.UP*0.4,_materials.yellow)
		_box("dark",Vector3(3.6,0.25,0.7),point+Vector3.UP*5.3)
		_box("lamp",Vector3(3.2,0.04,0.35),point+Vector3(0,5.44,0))
		for stripe: int in range(3):
			_box("dark",Vector3(0.7,0.12,0.04),point+Vector3(0,0.2+stripe*0.23,0.805))
	# Empty parking bays have a 7 m approach and 3.2 m widths.
	for side: float in [-1.0,1.0]:
		for x: int in range(-112,113,8):
			for bay: int in range(2):
				var bx: float = x+bay*3.2
				_box("white",Vector3(0.1,0.012,5.8),Vector3(bx,0.016,side*73.0))
				_box("white",Vector3(3.2,0.012,0.1),Vector3(bx+1.6,0.016,side*75.85))
	# 200 m clear acceleration/braking lane. No collision or checkpoint on paint.
	for side: float in [-1.0,1.0]:
		_box("yellow",Vector3(208,0.012,0.12),Vector3(0,0.018,48+side*6))
	for x: int in range(-100,101,20):
		_box("white",Vector3(0.18,0.012,10),Vector3(x,0.02,48))
		_label(str(x+100)+" m",Vector2(x,-39),0.7)
	_label("ACCELERATION / BRAKING",Vector2(-68,-58),0.85)
	_label("PARKING HALL",Vector2(-99,-27),1.0)
	_label("FREE DRIVE",Vector2(-99,-32),0.7)
	var center := Vector3(HallData.TURNING_CENTER.x,0.024,-HallData.TURNING_CENTER.y)
	for radius: float in [12.0,20.0,HallData.TURNING_RADIUS]:
		VisualGeometry.ring(self,center,radius,0.12,_materials.white)
	_label("TURNING AREA",HallData.TURNING_CENTER,1.0)
	# Flexible markers are deliberately cosmetic; solid columns have yellow bases.
	for index: int in range(8):
		var point := Vector3(61+(-3.0 if index%2 == 0 else 3.0),0,-(8+index*6.0))
		_box("dark",Vector3(0.7,0.08,0.7),point+Vector3.UP*0.04)
		var cone := VisualGeometry.cylinder(self,0.28,0.6,point+Vector3.UP*0.34,_materials.red)
		(cone.mesh as CylinderMesh).top_radius = 0.06
	_label("SLALOM",Vector2(61,59),0.9)
	_label("PARKING",Vector2(35,-69),0.85)
	# Flush boxes into one instanced draw per material rather than hundreds of nodes.
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

func _box(material: String, dimensions: Vector3, point: Vector3) -> void:
	if not _batches.has(material): _batches[material] = []
	_batches[material].append(Transform3D(Basis.from_scale(dimensions),point))

func _label(text: String, point: Vector2, scale_factor: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 64
	label.pixel_size = 0.02*scale_factor
	label.modulate = Color("b8beb7")
	label.outline_size = 0
	label.rotation.x = -PI*0.5
	label.position = Vector3(point.x,0.035,-point.y)
	add_child(label)
