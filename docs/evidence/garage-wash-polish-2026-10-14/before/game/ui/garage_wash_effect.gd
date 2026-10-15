extends Node3D
## Garage-only contact animation. Fixed pools; no condition or simulation ownership.
const FOAM_COUNT: int = 24
const WATER_COUNT: int = 32
const LAYERS: int = 1 | GarageReflections.ROOM_LAYER | GarageReflections.CAR_LAYER
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

func _ready() -> void:
	name = "GarageWashEffect"
	mitt = Node3D.new()
	mitt.name = "WashMitt"
	add_child(mitt)
	var cloth: Material = GarageMaterials.finish("washmitt", "d4bb78", 0.0, 0.93, 5)
	var grip: Material = GarageMaterials.finish("washgrip", "304853", 0.0, 0.88, 3)
	var pad: MeshInstance3D = GarageEnvironment.box(mitt, Vector3(0, 0.027, 0), Vector3(0.25, 0.054, 0.18), cloth)
	pad.layers = LAYERS
	var back: MeshInstance3D = GarageEnvironment.box(mitt, Vector3(0, 0.061, 0), Vector3(0.18, 0.025, 0.13), grip)
	back.layers = LAYERS
	foam = _pool("Suds", FOAM_COUNT, Color("edf3eb"), 0.68)
	water = _pool("Droplets", WATER_COUNT, Color("b7d7df"), 0.16)
	for index: int in range(FOAM_COUNT): foam_slots.append({})
	for index: int in range(WATER_COUNT): water_slots.append({})
	reset()

func _pool(label: String, count: int, color: Color, roughness: float) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.name = label
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic_specular = 0.65 if label == "Droplets" else 0.25
	node.material_override = material
	node.multimesh = MultiMesh.new()
	node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
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
	contact = surface

func advance(delta: float, active: bool) -> void:
	var step: float = clampf(delta, 0.0, 0.1)
	clock += step
	var touching: bool = active and not contact.is_empty()
	mitt.visible = touching
	if touching:
		var normal: Vector3 = contact.normal
		var tangent: Vector3 = Vector3.UP.cross(normal).normalized() if absf(normal.y) < 0.9 else Vector3.RIGHT
		var frame := Basis(tangent, normal, tangent.cross(normal))
		# A short rocking scrub stays centred on the same physically picked patch.
		mitt.global_transform = Transform3D(frame.rotated(normal, sin(clock * 17.0) * 0.12), contact.position + normal * 0.012 + tangent * sin(clock * 23.0) * 0.025)
		emission += step * 48.0
		while emission >= 1.0:
			emission -= 1.0
			_emit(frame)
	else:
		emission = 0.0
	var alive: int = _advance_pool(foam, foam_slots, step, false)
	alive += _advance_pool(water, water_slots, step, true)
	visible = touching or alive > 0

func _emit(frame: Basis) -> void:
	# Indexed sequences avoid global RNG side effects and remain bounded forever.
	var angle: float = float(foam_cursor) * 2.399963
	var radial: Vector3 = frame.x * cos(angle) + frame.z * sin(angle)
	var normal: Vector3 = frame.y
	var size: float = 0.022 + float(foam_cursor % 5) * 0.004
	foam_slots[foam_cursor] = {"position": contact.position + radial * (0.11 + float(foam_cursor % 3) * 0.022) + normal * size * 0.45,
		"velocity": radial * 0.028, "basis": frame, "age": 0.0, "life": 0.48 + float(foam_cursor % 4) * 0.045, "radius": size}
	foam_cursor = (foam_cursor + 1) % FOAM_COUNT
	water_slots[water_cursor] = {"position": contact.position + normal * 0.07 + radial * 0.1,
		"velocity": normal * 0.35 + radial * 0.24 + Vector3.DOWN * 0.18, "basis": Basis.IDENTITY,
		"age": 0.0, "life": 0.36 + float(water_cursor % 5) * 0.028, "radius": 0.008 + float(water_cursor % 3) * 0.002}
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
		var radius: float = slot.radius * minf(1.0, phase * 9.0) * (1.0 - phase * phase)
		var scale: Vector3 = Vector3(radius, radius * (1.7 if falling else 0.55), radius)
		var frame: Basis = (slot.basis as Basis) * Basis.from_scale(scale)
		node.multimesh.set_instance_transform(index, Transform3D(frame, slot.position))
		alive += 1
	return alive

func _hide_slot(node: MultiMeshInstance3D, index: int) -> void:
	node.multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO))
