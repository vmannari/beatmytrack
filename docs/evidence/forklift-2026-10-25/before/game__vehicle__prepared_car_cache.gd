extends RefCounted
## Rest-pose presentation templates. Meshes are immutable; materials/nodes are owned.
const MAX_ENTRIES: int = 4
const MAX_BYTES: int = 16 * 1024 * 1024
static var entries: Array[Dictionary] = []
static var enabled: bool = true
static var hits: int = 0

static func rest_scene(car: CarVisual) -> Node3D:
	var key: Array = key_for(car)
	for entry: Dictionary in entries:
		if entry.key == key:
			var holder: Node3D = _instantiate(entry)
			for path: NodePath in entry.transforms: holder.get_node(path).transform = entry.transforms[path]
			return holder
	return null

static func key_for(car: CarVisual) -> Array:
	var key: Array = ["prepared-car-2",car.vehicle_id,car.simple_model,car.batch_parts,car.editable_kits,VisualGeometry.optimize_model_geometry]
	if car.vehicle_id == "compact":
		for category: String in VehicleCustomisation.CATEGORIES: key.append(car.customisation[category])
	return key

static func restore(car: CarVisual) -> bool:
	# Only the stock detailed Compact currently passes exact renderer comparisons.
	# Other models/kits retain their original material/shadow construction sequence.
	# All models can still reuse their immutable rest-pose ghost geometry.
	if not enabled or car.simple_model or car.editable_kits or car.vehicle_id != "compact" or car.customisation != VehicleCustomisation.defaults(): return false
	var key: Array = key_for(car)
	for index: int in range(entries.size()):
		if entries[index].key != key: continue
		var entry: Dictionary = entries.pop_at(index)
		entries.append(entry)
		var copies: Dictionary = {"mutable":_mutable_roles(entry),"snapshots":entry.material_snapshots}
		var holder: Node3D = _instantiate(entry,copies)
		for child: Node in holder.get_children():
			holder.remove_child(child)
			_own(child,null)
			_isolate(child,copies)
			car.add_child(child)
		holder.free()
		for path: NodePath in entry.transforms: car.get_node(path).transform = entry.transforms[path]
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
	_stable_names(car)
	var seen: Dictionary = {}
	var bytes: int = preload("res://track/prepared_world_cache.gd")._resource_bytes(car,seen)
	# Include materials and template/property overhead conservatively.
	bytes += car.find_children("*","MeshInstance3D",true,false).size()*2048
	if bytes > MAX_BYTES: return
	var material_snapshots: Dictionary = {}
	var materials: Array = car.paint_materials.values()+[car.brake_material,car.accent_roof,car.underside_material]
	for variant: Dictionary in car.paint_variants: materials.append(variant.material)
	for material: Material in materials:
		if material == null or material_snapshots.has(material.get_instance_id()): continue
		var properties: Dictionary = {}
		for property: Dictionary in material.get_property_list():
			if int(property.usage)&PROPERTY_USAGE_STORAGE and not str(property.name).begins_with("resource_"): properties[property.name] = material.get(property.name)
		material_snapshots[material.get_instance_id()] = {"type":material.get_class(),"properties":properties}

	var nodes: Array = car.find_children("*","Node3D",true,false)
	for node: Node in nodes:
		if node.get_script() != null or node.get_class() not in ["Node3D","MeshInstance3D"]: return
	nodes.sort_custom(func(a: Node,b: Node) -> bool: return a.get_instance_id() < b.get_instance_id())
	var snapshot: Array[Dictionary] = []
	for node: Node3D in nodes:
		var properties: Dictionary = {}
		for property: Dictionary in node.get_property_list():
			if not int(property.usage)&PROPERTY_USAGE_STORAGE or property.name in ["script","owner"]: continue
			var value: Variant = node.get(property.name)
			properties[property.name] = value
		var surfaces: Array[Material] = []
		if node is MeshInstance3D and node.material_override == null:
			for surface: int in range(node.mesh.get_surface_count()): surfaces.append(node.get_active_material(surface))
		snapshot.append({"path":car.get_path_to(node),"parent":car.get_path_to(node.get_parent()),"name":str(node.name),"index":node.get_index(),"type":node.get_class(),"properties":properties,"transform":node.transform,"surfaces":surfaces,"groups":node.get_groups()})
	var entry: Dictionary = {"key":key_for(car),"nodes":snapshot,"material_snapshots":material_snapshots,"bytes":bytes,"transforms":{},"paint_materials":car.paint_materials.duplicate(),"paint_variants":car.paint_variants.duplicate(true),"kit_frames":{},"wheel_radii":car.wheel_radii.duplicate(),"wheel_rest_positions":car.wheel_rest_positions.duplicate()}
	for node: Node3D in nodes: entry.transforms[car.get_path_to(node)] = node.transform
	entry.body = car.get_path_to(car.body)
	for field: String in ["front_wheels","rolling_wheels","brake_lights"]:
		entry[field] = []
		for node: Node in car.get(field): entry[field].append(car.get_path_to(node))
	for field: String in ["brake_material","accent_roof","underside_material"]: entry[field] = car.get(field)
	for category: String in car.kit_frames:
		entry.kit_frames[category] = []
		for node: Node in car.kit_frames[category]: entry.kit_frames[category].append(car.get_path_to(node))
	for index: int in range(entries.size()-1,-1,-1):
		if entries[index].key == entry.key: entries.remove_at(index)
	var total: int = bytes
	for old: Dictionary in entries: total += int(old.bytes)
	while not entries.is_empty() and (entries.size() >= MAX_ENTRIES or total > MAX_BYTES): total -= int(entries.pop_front().bytes)
	entries.append(entry)

static func _instantiate(entry: Dictionary, copies: Dictionary = {}) -> Node3D:
	if copies.is_empty(): copies = {"mutable":_mutable_roles(entry),"snapshots":entry.material_snapshots}
	var holder := Node3D.new()
	var nodes: Dictionary = {NodePath("."):holder}
	var parents: Dictionary = {}
	# Retain construction order, hierarchy and exact matrices separately from
	# the independent mutable materials created for this instance.
	for data: Dictionary in entry.nodes:
		var node: Node3D = ClassDB.instantiate(data.type)
		node.name = data.name
		for property: String in data.properties:
			var value: Variant = data.properties[property]
			node.set(property,_material(value,copies) if value is Material else value)
		node.transform = data.transform
		for group: StringName in data.groups: node.add_to_group(group)
		if node is MeshInstance3D:
			for surface: int in range(data.surfaces.size()): node.set_surface_override_material(surface,_material(data.surfaces[surface],copies))
		nodes[data.path] = node
		if not parents.has(data.parent): parents[data.parent] = []
		parents[data.parent].append(data)
	for path: NodePath in parents:
		parents[path].sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.index) < int(b.index))
		for data: Dictionary in parents[path]: nodes[path].add_child(nodes[data.path])
	return holder

static func _material(source: Material, copies: Dictionary) -> Material:
	if source == null: return null
	var id: int = source.get_instance_id()
	if copies.has("mutable") and not copies.mutable.has(id): return source
	if not copies.has(id):
		var copy: Material
		if copies.has("snapshots") and copies.snapshots.has(id):
			var declaration: Dictionary = copies.snapshots[id]
			copy = ClassDB.instantiate(declaration.type)
			for property: String in declaration.properties: copy.set(property,declaration.properties[property])
		else: copy = source.duplicate()
		copies[id] = copy
		if not copies.has("snapshots"): copy.next_pass = _material(source.next_pass,copies)
	return copies[id]

static func _mutable_roles(entry: Dictionary) -> Dictionary:
	var roles: Dictionary = {}
	for material: Material in entry.paint_materials.values(): roles[material.get_instance_id()] = true
	for variant: Dictionary in entry.paint_variants: roles[variant.material.get_instance_id()] = true
	for field: String in ["brake_material","accent_roof","underside_material"]:
		var material: Material = entry[field]
		if material != null: roles[material.get_instance_id()] = true
	return roles

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

static func _stable_names(node: Node) -> void:
	# Stored articulation paths need explicit sibling names before restoration.
	for child: Node in node.get_children():
		if str(child.name).begins_with("@"):
			child.name = "PreparedNode_"+str(child.get_index())
		_stable_names(child)
