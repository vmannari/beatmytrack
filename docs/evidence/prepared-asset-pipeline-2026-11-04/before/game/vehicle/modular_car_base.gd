extends RefCounted
## Offline stock assemblies. Immutable meshes are shared; mutable finishes are
## rebound per instance. A base never contains another car's fitted kit.
const SNAPSHOT = preload("res://vehicle/prepared_car_cache.gd")
const DIRECTORY: String = "res://assets/vehicles/modular_car_bases_v1"
const SCHEMA: String = "modular-car-base-1"
static var enabled: bool = true
static var hits: int = 0
static var _sources: Dictionary = {}

static func build_revision(id: String) -> String:
	var identity: GDScript = load("res://core/build_identity.gd")
	var revisions: Dictionary = identity.get_script_constant_map().get("MODULAR_CAR_SHA256",{})
	return str(revisions.get(id,""))

static func path_for(car: CarVisual) -> String:
	return DIRECTORY.path_join("%s_%s_%s.scn" % [car.vehicle_id,"simple" if car.simple_model else "full","editable" if car.editable_kits else "fixed"])

static func key_for(car: CarVisual) -> Array:
	var config: HandlingConfig = VehicleCatalog.config(car.vehicle_id)
	return [SCHEMA,Engine.get_version_info().string,build_revision(car.vehicle_id),car.vehicle_id,car.simple_model,car.editable_kits,car.batch_parts,VisualGeometry.optimize_model_geometry,HandlingConfig.BODY_SCALE,config.wheelbase,config.track_width]

static func source_hashes(id: String) -> Dictionary:
	# Builders share helpers between car families (including Compact finishes
	# and Hovercraft surface generation). Be conservative in a source checkout.
	var result: Dictionary = {}
	for file: String in DirAccess.get_files_at("res://vehicle"):
		if file.ends_with(".gd") or file.ends_with(".gdshader") or file.ends_with(".gdshaderinc"):
			result["vehicle/"+file] = FileAccess.get_sha256("res://vehicle/"+file)
	for file: String in DirAccess.get_files_at("res://track"):
		if file.ends_with(".gdshader") or file.ends_with(".gdshaderinc"):
			result["track/"+file] = FileAccess.get_sha256("res://track/"+file)
	for path: String in ["res://resources/cars/"+id+".tres","res://vehicle/handling_config.gd","res://assets/fonts/BarlowCondensed-SemiBold.ttf"]:
		if FileAccess.file_exists(path): result[path] = FileAccess.get_sha256(path)
	return result

static func _eligible(car: CarVisual) -> bool:
	var revision: String = build_revision(car.vehicle_id)
	return enabled and car.vehicle_id in VehicleCatalog.IDS and revision.length() == 64 and revision.is_valid_hex_number(false) and car.batch_parts and (not car.editable_kits or VehicleCustomisation.supported(car.vehicle_id))

static func restore(car: CarVisual) -> bool:
	if not _eligible(car): return false
	var path: String = path_for(car)
	if not ResourceLoader.exists(path): return false
	var scene: PackedScene = load(path) as PackedScene
	if scene == null: return false
	var holder: Node3D = scene.instantiate() as Node3D
	if holder == null: return false
	var data: Dictionary = holder.get_meta("modular_car_base",{})
	if data.get("key",[]) != key_for(car):
		holder.free()
		return false
	# Packaged builds may contain compiled scripts rather than source files.
	# In a source checkout, reject any stale scene before touching the car.
	if FileAccess.file_exists("res://vehicle/car_visual.gd"):
		if not _sources.has(car.vehicle_id): _sources[car.vehicle_id] = source_hashes(car.vehicle_id)
		if data.get("sources",{}) != _sources[car.vehicle_id]:
			holder.free()
			return false
	# Validate every stored path before mutating the live car. A corrupt or
	# mismatched scene must fall back to its normal procedural construction.
	if not _valid_holder(holder,data):
		holder.free()
		return false
	var copies: Dictionary = {"mutable":SNAPSHOT._mutable_roles(data)}
	SNAPSHOT._isolate(holder,copies)
	for child: Node in holder.get_children():
		holder.remove_child(child)
		SNAPSHOT._own(child,null)
		car.add_child(child)
	holder.free()
	car.body = car.get_node(data.body)
	for field: String in ["front_wheels","rear_wheels","rolling_wheels","brake_lights"]:
		var nodes: Array = car.get(field)
		for node_path: NodePath in data[field]: nodes.append(car.get_node(node_path))
	car.wheel_radii.assign(data.wheel_radii)
	car.wheel_rest_positions.assign(data.wheel_rest_positions)
	for field: String in ["brake_material","accent_roof","underside_material"]: car.set(field,SNAPSHOT._material(data[field],copies))
	for slot: String in data.paint_materials: car.paint_materials[slot] = SNAPSHOT._material(data.paint_materials[slot],copies)
	for declaration: Dictionary in data.paint_variants:
		var value: Dictionary = declaration.duplicate()
		value.material = SNAPSHOT._material(declaration.material,copies)
		car.paint_variants.append(value)
	for category: String in data.kit_frames:
		car.kit_frames[category] = []
		for node_path: NodePath in data.kit_frames[category]: car.kit_frames[category].append(car.get_node(node_path))
	hits += 1
	return true

static func _valid_holder(holder: Node3D, data: Dictionary) -> bool:
	for field: String in ["body","front_wheels","rear_wheels","rolling_wheels","brake_lights","wheel_radii","wheel_rest_positions","paint_materials","paint_variants","kit_frames","brake_material","accent_roof","underside_material"]:
		if not data.has(field): return false
	if not data.body is NodePath or not holder.has_node(data.body): return false
	for field: String in ["front_wheels","rear_wheels","rolling_wheels","brake_lights"]:
		if not data[field] is Array: return false
		for node_path: Variant in data[field]:
			if not node_path is NodePath or not holder.has_node(node_path): return false
	if not data.kit_frames is Dictionary: return false
	for category: Variant in data.kit_frames:
		if not data.kit_frames[category] is Array: return false
		for node_path: Variant in data.kit_frames[category]:
			if not node_path is NodePath or not holder.has_node(node_path): return false
	return data.paint_materials is Dictionary and data.paint_variants is Array and data.wheel_radii is Array and data.wheel_rest_positions is Array

static func bake(car: CarVisual) -> Error:
	if not _eligible(car) or not car.model_ready or car.customisation != VehicleCustomisation.defaults() or car.body == null: return ERR_INVALID_PARAMETER
	SNAPSHOT._stable_names(car)
	var nodes: Array = car.find_children("*","Node3D",true,false)
	for node: Node in nodes:
		if node.get_script() != null or node.get_class() not in ["Node3D","MeshInstance3D"]: return ERR_UNAVAILABLE
	nodes.sort_custom(func(a: Node,b: Node) -> bool: return a.get_instance_id() < b.get_instance_id())
	var snapshot: Array[Dictionary] = []
	for node: Node3D in nodes:
		var properties: Dictionary = {}
		for property: Dictionary in node.get_property_list():
			if not int(property.usage)&PROPERTY_USAGE_STORAGE or property.name in ["script","owner"]: continue
			properties[property.name] = node.get(property.name)
		var surfaces: Array[Material] = []
		if node is MeshInstance3D and node.mesh != null and node.material_override == null:
			for surface: int in range(node.mesh.get_surface_count()): surfaces.append(node.get_active_material(surface))
		snapshot.append({"path":car.get_path_to(node),"parent":car.get_path_to(node.get_parent()),"name":str(node.name),"index":node.get_index(),"type":node.get_class(),"properties":properties,"transform":node.transform,"surfaces":surfaces,"groups":node.get_groups()})
	var entry: Dictionary = {"nodes":snapshot,"paint_materials":car.paint_materials.duplicate(),"paint_variants":car.paint_variants.duplicate(true),"kit_frames":{},"wheel_radii":car.wheel_radii.duplicate(),"wheel_rest_positions":car.wheel_rest_positions.duplicate(),"body":car.get_path_to(car.body)}
	for field: String in ["front_wheels","rear_wheels","rolling_wheels","brake_lights"]:
		entry[field] = []
		for node: Node in car.get(field): entry[field].append(car.get_path_to(node))
	for field: String in ["brake_material","accent_roof","underside_material"]: entry[field] = car.get(field)
	for category: String in car.kit_frames:
		entry.kit_frames[category] = []
		for node: Node in car.kit_frames[category]: entry.kit_frames[category].append(car.get_path_to(node))
	var copies: Dictionary = {"mutable":SNAPSHOT._mutable_roles(entry)}
	var holder: Node3D = SNAPSHOT._instantiate(entry,copies)
	# ResourceSaver cannot serialize ImmediateMesh drawing commands.
	for node: MeshInstance3D in holder.find_children("*","MeshInstance3D",true,false):
		if not node.mesh is ImmediateMesh: continue
		var mesh := ArrayMesh.new()
		for surface: int in range(node.mesh.get_surface_count()):
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,node.mesh.surface_get_arrays(surface))
			mesh.surface_set_material(surface,node.mesh.surface_get_material(surface))
		node.mesh = mesh
	var data: Dictionary = {"key":key_for(car),"sources":source_hashes(car.vehicle_id),"body":entry.body,"wheel_radii":entry.wheel_radii,"wheel_rest_positions":entry.wheel_rest_positions,"paint_materials":{},"paint_variants":[],"kit_frames":entry.kit_frames}
	for field: String in ["front_wheels","rear_wheels","rolling_wheels","brake_lights"]: data[field] = entry[field]
	for field: String in ["brake_material","accent_roof","underside_material"]: data[field] = SNAPSHOT._material(entry[field],copies)
	for slot: String in entry.paint_materials: data.paint_materials[slot] = SNAPSHOT._material(entry.paint_materials[slot],copies)
	for declaration: Dictionary in entry.paint_variants:
		var value: Dictionary = declaration.duplicate()
		value.material = SNAPSHOT._material(declaration.material,copies)
		data.paint_variants.append(value)
	holder.set_meta("modular_car_base",data)
	for child: Node in holder.get_children(): SNAPSHOT._own(child,holder)
	var scene := PackedScene.new()
	var error: Error = scene.pack(holder)
	if error == OK:
		DirAccess.make_dir_recursive_absolute(DIRECTORY)
		error = ResourceSaver.save(scene,path_for(car),ResourceSaver.FLAG_COMPRESS)
	holder.free()
	return error
