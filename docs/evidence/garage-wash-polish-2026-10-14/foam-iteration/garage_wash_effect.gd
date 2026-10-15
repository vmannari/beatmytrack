extends Node3D
## Garage-only contact animation. Fixed pools; no condition or simulation ownership.
const FOAM_COUNT: int = 24
const WATER_COUNT: int = 32
const LAYERS: int = 1 | GarageReflections.ROOM_LAYER | GarageReflections.CAR_LAYER
const Geometry = preload("res://ui/garage_wash_geometry.gd")
var mitt: Node3D
var foam: MultiMeshInstance3D
var water: MultiMeshInstance3D
var foam_slots: Array[Dictionary] = []
var water_slots: Array[Dictionary] = []
var foam_cursor: int = 0
var water_cursor: int = 0
var contact: Dictionary = {}
var clock: float = 0.0
var emission: float = 0.0
var last_position := Vector3.ZERO
var last_normal := Vector3.ZERO
var stroke := Vector3.ZERO
var mitt_axis := Vector3.ZERO
var touching_previous: bool = false

func _ready() -> void:
	name = "GarageWashEffect"
	mitt = Node3D.new()
	mitt.name = "WashMitt"
	add_child(mitt)
	var cloth := ShaderMaterial.new()
	cloth.shader = preload("res://ui/garage_wash_cloth.gdshader")
	cloth.set_shader_parameter("pigment",Color("b8b09c"))
	var cuff := ShaderMaterial.new()
	cuff.shader = cloth.shader
	cuff.set_shader_parameter("pigment",Color("283e46"))
	cuff.set_shader_parameter("cuff",true)
	_part("Microfiber",Geometry.mitt(),cloth)
	_part("StitchedCuff",Geometry.cuff(),cuff)
	var lather := ShaderMaterial.new()
	lather.shader = preload("res://ui/garage_wash_lather.gdshader")
	foam = _pool("Suds",FOAM_COUNT,Geometry.lather(),lather)
	var drops := ShaderMaterial.new()
	drops.shader = preload("res://ui/garage_wash_water.gdshader")
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	water = _pool("Droplets",WATER_COUNT,sphere,drops)
	for index: int in range(FOAM_COUNT): foam_slots.append({})
	for index: int in range(WATER_COUNT): water_slots.append({})
	reset()

func _part(label: String, mesh: Mesh, material: Material) -> void:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = material
	node.layers = LAYERS
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mitt.add_child(node)

func _pool(label: String, count: int, mesh: Mesh, material: Material) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.material_override = material
	node.multimesh = MultiMesh.new()
	node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	node.multimesh.use_custom_data = true
	node.multimesh.mesh = mesh
	node.multimesh.instance_count = count
	node.layers = LAYERS
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

func reset() -> void:
	contact.clear()
	clock = 0.0
	emission = 0.0
	foam_cursor = 0
	water_cursor = 0
	stroke = Vector3.ZERO
	mitt_axis = Vector3.ZERO
	touching_previous = false
	if mitt == null: return
	mitt.hide()
	for index: int in range(FOAM_COUNT):
		foam_slots[index] = {}
		_hide_slot(foam, index)
	for index: int in range(WATER_COUNT):
		water_slots[index] = {}
		_hide_slot(water, index)
	hide()

func begin_frame() -> void:
	contact.clear()

func set_contact(surface: Dictionary) -> void:
	contact = surface.duplicate()

func advance(delta: float, active: bool) -> void:
	var step: float = clampf(delta, 0.0, 0.1)
	clock += step
	var touching: bool = active and not contact.is_empty()
	mitt.visible = touching
	if touching:
		var normal: Vector3 = contact.normal
		var tangent: Vector3 = Vector3.UP.cross(normal).normalized() if absf(normal.y) < 0.9 else Vector3.RIGHT
		var movement: Vector3 = contact.position-last_position if touching_previous and last_normal.dot(normal)>0.75 else Vector3.ZERO
		movement -= normal*movement.dot(normal)
		stroke = stroke.lerp(movement/maxf(step,0.001),1.0-exp(-step*12.0)).limit_length(1.0)
		if stroke.length() > 0.06: tangent = stroke.normalized()
		if touching_previous and last_normal.dot(normal)>0.75:
			var axis: Vector3 = (mitt_axis-normal*mitt_axis.dot(normal)).normalized()
			if axis.dot(tangent)<0.0: tangent = -tangent
			var angle: float = atan2(normal.dot(axis.cross(tangent)),axis.dot(tangent))
			tangent = axis.rotated(normal,clampf(angle,-step*6.0,step*6.0))
		mitt_axis = tangent
		var frame := Basis(tangent, normal, tangent.cross(normal))
		# Gentle pressure and an oval scrub keep the soft underside seated on the patch.
		var phase: float = clock*TAU*1.7
		mitt.global_transform = Transform3D(frame.rotated(normal,sin(phase)*0.07),contact.position+normal*0.004+tangent*sin(phase)*0.013+frame.z*cos(phase)*0.005)
		mitt.scale.y = 0.96+sin(phase)*0.035
		emission += step*36.0
		while emission >= 1.0:
			emission -= 1.0
			_emit(frame)
	else:
		emission = 0.0
		stroke = Vector3.ZERO
	if touching:
		last_position = contact.position
		last_normal = contact.normal
	touching_previous = touching
	var alive: int = _advance_pool(foam, foam_slots, step, false)
	alive += _advance_pool(water, water_slots, step, true)
	visible = touching or alive > 0

func _emit(frame: Basis) -> void:
	# Indexed sequences avoid global RNG side effects and remain bounded forever.
	var angle: float = float(foam_cursor) * 2.399963
	var radial: Vector3 = frame.x * cos(angle) + frame.z * sin(angle)
	var normal: Vector3 = frame.y
	var size: float = 0.052+float(foam_cursor%5)*0.007
	var gravity: Vector3 = Vector3.DOWN-normal*Vector3.DOWN.dot(normal)
	foam_slots[foam_cursor] = {"position": contact.position+radial*(0.075+float(foam_cursor%3)*0.020)+normal*0.002-stroke*0.045,
		"velocity": gravity*0.013, "basis": frame, "age": 0.0, "life": 0.57+float(foam_cursor%4)*0.065,
		"radius": size, "seed": float((foam_cursor*7)%24)/24.0}
	foam_cursor = (foam_cursor + 1) % FOAM_COUNT
	water_slots[water_cursor] = {"position": contact.position+normal*0.014+radial*0.082,
		"velocity": normal*0.075+radial*0.07+Vector3.DOWN*0.10+stroke*0.07, "basis": Basis.IDENTITY,
		"age": 0.0, "life": 0.43+float(water_cursor%5)*0.028, "radius": 0.0045+float(water_cursor%4)*0.0012,
		"seed": float(water_cursor)/32.0}
	water_cursor = (water_cursor + 1) % WATER_COUNT

func _advance_pool(node: MultiMeshInstance3D, slots: Array[Dictionary], delta: float, falling: bool) -> int:
	var alive: int = 0
	for index: int in range(slots.size()):
		var slot: Dictionary = slots[index]
		if slot.is_empty(): continue
		slot.age += delta
		if slot.age >= slot.life:
			slots[index] = {}
			_hide_slot(node, index)
			continue
		if falling: slot.velocity += Vector3.DOWN * 2.8 * delta
		slot.position += slot.velocity * delta
		var phase: float = slot.age / slot.life
		var radius: float = slot.radius*(minf(1.0,phase*9.0) if falling else 0.80+phase*0.2)
		var scale: Vector3 = Vector3(radius,radius*(1.0+minf(1.8,(slot.velocity as Vector3).length()*1.8) if falling else 1.0),radius)
		var frame: Basis = (slot.basis as Basis) * Basis.from_scale(scale)
		node.multimesh.set_instance_transform(index, Transform3D(frame, slot.position))
		node.multimesh.set_instance_custom_data(index,Color(slot.seed,phase,0.80,slot.radius))
		alive += 1
	return alive

func _hide_slot(node: MultiMeshInstance3D, index: int) -> void:
	node.multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO))
	node.multimesh.set_instance_custom_data(index,Color(0,1,0,0))
