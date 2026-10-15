extends RefCounted
## Rest-pose presentation templates. Meshes are immutable; materials/nodes are owned.
const MAX_ENTRIES: int = 4
const MAX_BYTES: int = 32 * 1024 * 1024
static var entries: Array[Dictionary] = []
static var enabled: bool = true
static var hits: int = 0

static func rest_scene(car: CarVisual) -> Node3D:
	var key: Array = key_for(car)
	for entry: Dictionary in entries:
		if entry.key == key: return entry.scene.instantiate()
	return null

static func key_for(car: CarVisual) -> Array:
	var key: Array = [car.vehicle_id,car.simple_model,car.batch_parts,car.editable_kits,VisualGeometry.optimize_model_geometry]
	if car.vehicle_id == "compact":
		for category: String in VehicleCustomisation.CATEGORIES: key.append(car.customisation[category])
	return key

static func restore(car: CarVisual) -> bool:
	if not enabled: return false
	var key: Array = key_for(car)
	for index: int in range(entries.size()):
		if entries[index].key != key: continue
		var entry: Dictionary = entries.pop_at(index)
		entries.append(entry)
		var holder: Node3D = entry.scene.instantiate()
		var copies: Dictionary = {}
		for child: Node in holder.get_children():
			holder.remove_child(child)
			_own(child,null)
			_isolate(child,copies)
			car.add_child(child)
		holder.free()
		for field: String in ["body"]: car.set(field,car.get_node(entry[field]))
		for field: String in ["front_wheels","rolling_wheels","brake_lights"]:
			var nodes: Array = car.get(field)
			for path: NodePath in entry[field]: nodes.append(car.get_node(path))
		car.wheel_radii.assign(entry.wheel_radii)
		car.wheel_rest_positions.assign(entry.wheel_rest_positions)
		for field: String in ["brake_material","accent_roof","underside_material"]: car.set(field,_material(entry[field],copies))
		for slot: String in entry.paint_materials: car.paint_materials[slot] = _material(entry.paint_materials[slot],copies)
		for variant: Dictionary in entry.paint_variants:
			var copy: Dictionary = variant.duplicate()
			copy.material = _material(variant.material,copies)
			car.paint_variants.append(copy)
		for category: String in entry.kit_frames:
			car.kit_frames[category] = []
			for path: NodePath in entry.kit_frames[category]: car.kit_frames[category].append(car.get_node(path))
		hits += 1
		return true
	return false

static func remember(car: CarVisual) -> void:
	if not enabled: return
	var seen: Dictionary = {}
	var bytes: int = preload("res://track/prepared_world_cache.gd")._resource_bytes(car,seen)
	# Include materials and template/property overhead conservatively.
	bytes += car.find_children("*","MeshInstance3D",true,false).size()*2048
	if bytes > MAX_BYTES: return
	var holder := Node3D.new()
	for child: Node in car.get_children():
		var copy: Node = child.duplicate(0)
		holder.add_child(copy)
		_own(copy,holder)
	var scene := PackedScene.new()
	var error: Error = scene.pack(holder)
	holder.free()
	if error != OK: return
	var entry: Dictionary = {"key":key_for(car),"scene":scene,"bytes":bytes,"paint_materials":car.paint_materials.duplicate(),"paint_variants":car.paint_variants.duplicate(true),"kit_frames":{},"wheel_radii":car.wheel_radii.duplicate(),"wheel_rest_positions":car.wheel_rest_positions.duplicate()}
	entry.body = car.get_path_to(car.body)
	for field: String in ["front_wheels","rolling_wheels","brake_lights"]:
		entry[field] = []
		for node: Node in car.get(field): entry[field].append(car.get_path_to(node))
	for field: String in ["brake_material","accent_roof","underside_material"]: entry[field] = car.get(field)
	for category: String in car.kit_frames:
		entry.kit_frames[category] = []
		for node: Node in car.kit_frames[category]: entry.kit_frames[category].append(car.get_path_to(node))
	# Detach the template finishes before the original car can be painted/washed.
	var copies: Dictionary = {}
	var frozen: Node3D = scene.instantiate()
	_isolate(frozen,copies)
	_own(frozen,null)
	for child: Node in frozen.get_children(): _own(child,frozen)
	if scene.pack(frozen) != OK:
		frozen.free()
		return
	frozen.free()
	for field: String in ["brake_material","accent_roof","underside_material"]: entry[field] = _material(entry[field],copies)
	for slot: String in entry.paint_materials: entry.paint_materials[slot] = _material(entry.paint_materials[slot],copies)
	for variant: Dictionary in entry.paint_variants: variant.material = _material(variant.material,copies)
	var total: int = bytes
	for old: Dictionary in entries: total += int(old.bytes)
	while not entries.is_empty() and (entries.size() >= MAX_ENTRIES or total > MAX_BYTES): total -= int(entries.pop_front().bytes)
	entries.append(entry)

static func _material(source: Material, copies: Dictionary) -> Material:
	if source == null: return null
	var id: int = source.get_instance_id()
	if not copies.has(id):
		var copy: Material = source.duplicate()
		copies[id] = copy
		copy.next_pass = _material(source.next_pass,copies)
	return copies[id]

static func _isolate(node: Node, copies: Dictionary) -> void:
	if node is MeshInstance3D:
		node.material_override = _material(node.material_override,copies)
		node.material_overlay = _material(node.material_overlay,copies)
		# Embedded surface materials stay immutable; mutable bindings live on nodes.
		for surface: int in range(node.mesh.get_surface_count()):
			if node.material_override == null: node.set_surface_override_material(surface,_material(node.get_active_material(surface),copies))
	for child: Node in node.get_children(): _isolate(child,copies)

static func _own(node: Node, owner_node: Node) -> void:
	node.owner = owner_node
	for child: Node in node.get_children(): _own(child,owner_node)
