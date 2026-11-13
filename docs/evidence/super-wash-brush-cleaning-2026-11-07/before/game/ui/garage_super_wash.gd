extends Node3D
## Presentation only: a reusable rollover wash in the existing Garage world.
const SECONDS: float = 3.6
const WATER_COUNT: int = 96
const LAYERS: int = 1 | GarageReflections.ROOM_LAYER | GarageReflections.CAR_LAYER
var elapsed: float = 0.0
var bounds := AABB()
var gantry: Node3D
var rollers: Array[Node3D] = []
var water: MultiMeshInstance3D
var travel := Vector2.ZERO
var width: float = 0.0
var height: float = 0.0

func prepare(car: CarVisual) -> void:
	name = "GarageSuperWashEffect"
	# Bind to the actual model's frame, so orbiting the pedestal carries the rig.
	car.add_child(self)
	var first: bool = true
	var inverse: Transform3D = car.global_transform.affine_inverse()
	for node: Node in car.find_children("*","MeshInstance3D",true,false):
		var part := node as MeshInstance3D
		if part.mesh == null or not part.is_visible_in_tree(): continue
		if part.material_override is ShaderMaterial and part.material_override.shader == preload("res://ui/studio_contact.gdshader"): continue
		var box: AABB = inverse * part.global_transform * part.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	width = bounds.size.x + 0.68
	height = bounds.end.y + 0.46
	travel = Vector2(bounds.position.z-0.60,bounds.end.z+0.60)
	gantry = Node3D.new()
	add_child(gantry)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("8c999b")
	metal.metallic = 0.55
	metal.roughness = 0.48
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("263b43")
	dark.metallic = 0.25
	dark.roughness = 0.65
	var frame := SurfaceTool.new()
	frame.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hardware := SurfaceTool.new()
	hardware.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: float in [-1.0,1.0]:
		var x: float = side*width*0.5
		_box(frame,Vector3(x,height*0.5,0),Vector3(0.11,height,0.15))
		_box(hardware,Vector3(x,0.06,0),Vector3(0.30,0.12,0.70))
		_box(hardware,Vector3(x,height-0.12,0),Vector3(0.23,0.27,0.24))
		var roller := _roller(maxf(0.25,height-0.60),0.23)
		roller.position = Vector3(x-side*0.16,(height-0.60)*0.5+0.12,0)
		rollers.append(roller)
	_box(frame,Vector3(0,height,0),Vector3(width+0.20,0.18,0.24))
	_box(hardware,Vector3(0,height-0.15,0.12),Vector3(width-0.15,0.07,0.06))
	_part("SteelArch",frame.commit(),metal)
	_part("DriveHousings",hardware.commit(),dark)
	var overhead := _roller(width-0.30,0.23)
	overhead.position = Vector3(0,height-0.24,0)
	overhead.rotation.z = PI*0.5
	rollers.append(overhead)
	var drop := SphereMesh.new()
	drop.radius = 1.0
	drop.height = 2.0
	drop.radial_segments = 8
	drop.rings = 4
	var finish := ShaderMaterial.new()
	finish.shader = preload("res://ui/garage_wash_water.gdshader")
	water = _pool("RinseSpray",WATER_COUNT,drop,finish,true)
	water.multimesh.visible_instance_count = 0
	reset()

func _box(tool: SurfaceTool, at: Vector3, size: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	tool.append_from(mesh,0,Transform3D(Basis.IDENTITY,at))

func _part(label: String, mesh: Mesh, finish: Material) -> void:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = finish
	node.layers = LAYERS
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gantry.add_child(node)

func _pool(label: String, count: int, mesh: Mesh, finish: Material, custom: bool = false) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = MultiMesh.new()
	node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	node.multimesh.use_colors = not custom
	node.multimesh.use_custom_data = custom
	node.multimesh.mesh = mesh
	node.multimesh.instance_count = count
	node.material_override = finish
	node.layers = LAYERS
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gantry.add_child(node)
	return node

func _roller(length: float, radius: float) -> Node3D:
	var root := Node3D.new()
	gantry.add_child(root)
	var fiber := CapsuleMesh.new()
	fiber.radius = 0.032
	fiber.height = 0.16
	fiber.radial_segments = 6
	fiber.rings = 2
	var finish := StandardMaterial3D.new()
	finish.vertex_color_use_as_albedo = true
	finish.roughness = 0.92
	var rows: int = clampi(ceili(length/0.075),6,40)
	var bristles := _pool("MicrofiberRoller",rows*18,fiber,finish)
	bristles.reparent(root)
	for row: int in range(rows):
		for spoke: int in range(18):
			var angle: float = TAU*spoke/18.0+row*0.23
			var direction := Vector3(cos(angle),0,sin(angle))
			var at: Vector3 = direction*(radius-0.07)
			at.y = lerpf(-length*0.5,length*0.5,float(row)/maxi(1,rows-1))
			var pose := Basis(Vector3.UP,-angle)*Basis(Vector3.FORWARD,PI*0.5)
			var index: int = row*18+spoke
			bristles.multimesh.set_instance_transform(index,Transform3D(pose,at))
			bristles.multimesh.set_instance_color(index,Color("c5c4af") if (spoke+row/4)%6<4 else Color("4f747d"))
	return root

func play() -> void:
	elapsed = 0.0
	show()
	_present()

func reset() -> void:
	elapsed = SECONDS
	hide()
	if water != null: water.multimesh.visible_instance_count = 0

func advance(delta: float) -> void:
	if not visible: return
	elapsed = minf(SECONDS,elapsed+maxf(0.0,delta))
	if elapsed >= SECONDS:
		reset()
		return
	_present()

func _present() -> void:
	var progress: float = smoothstep(0.08,0.92,elapsed/SECONDS)
	gantry.position = Vector3(bounds.get_center().x,0,lerpf(travel.x,travel.y,progress))
	# Deployment and retraction happen beyond the car's ends.
	var deployment: float = smoothstep(0.0,0.25,elapsed)*(1.0-smoothstep(SECONDS-0.25,SECONDS,elapsed))
	gantry.scale = Vector3.ONE*maxf(0.001,deployment)
	for index: int in range(rollers.size()):
		var roller: Node3D = rollers[index]
		roller.rotation = Vector3(0,elapsed*12.0*(1.0 if index==0 else -1.0),0) if index<2 else Vector3(elapsed*12.0,0,PI*0.5)
	water.multimesh.visible_instance_count = WATER_COUNT
	for index: int in range(WATER_COUNT):
		var age: float = fposmod(elapsed*1.9+float(index)*0.618034,1.0)
		var across: float = float(index%16)/15.0
		var side: bool = index>=64
		var at := Vector3(lerpf(-width*0.45,width*0.45,across),height-0.22,-0.14)
		if side:
			var sign_x: float = -1.0 if index%2==0 else 1.0
			at = Vector3(sign_x*(width*0.5-0.14-age*0.38),height*(0.2+across*0.6),-0.14)
		at += Vector3(sin(index*2.4)*age*0.08,-age*age*(height+0.10),-age*0.34)
		var size: float = 0.014+0.008*float(index%3)/2.0
		var shape := Basis.from_scale(Vector3(size,size*(2.0+age*3.0),size))
		if at.y<0.025: shape = Basis.from_scale(Vector3.ZERO)
		water.multimesh.set_instance_transform(index,Transform3D(shape,at))
		water.multimesh.set_instance_custom_data(index,Color(0,age,1,0))
