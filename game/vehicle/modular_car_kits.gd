extends RefCounted
## Offline, independently replaceable kit frames. A failed lookup never changes a car.
const DIRECTORY: String = "res://assets/vehicles/modular_kits_v1/"
const SCHEMA: String = "modular-car-kit-v1"
const Cache = preload("res://vehicle/prepared_car_cache.gd")
const Base = preload("res://vehicle/modular_car_base.gd")
static var enabled: bool = true
static var hits: int = 0
static var source_hashes: Dictionary = {}

static func engine_key() -> Array:
	var info: Dictionary = Engine.get_version_info()
	return [str(info.get("string","")),str(info.get("hash",""))]

static func geometry_sources(id: String) -> Dictionary:
	var sources: Dictionary = Base.source_hashes(id)
	sources["vehicle/modular_car_kits.gd"] = FileAccess.get_sha256("res://vehicle/modular_car_kits.gd")
	return sources

static func key_for(car: CarVisual, category: String, option: String) -> Array:
	var config: HandlingConfig = VehicleCatalog.config(car.model_id)
	var key: Array = [SCHEMA,car.model_id,car.simple_model,car.editable_kits,car.batch_parts,VisualGeometry.optimize_model_geometry,HandlingConfig.BODY_SCALE,config.wheelbase,config.track_width,category,option,engine_key(),Base.build_revision(car.model_id)]
	# Superseded Rally modules cannot be reused in packaged builds, where
	# source-file hash validation is unavailable.
	if car.model_id == "compact" and category == "body": key.append("rally-body-2")
	if car.model_id == "compact" and category == "aero": key.append("rally-aero-2")
	if car.model_id == "electric": key.append("volt-visible-kits-2")
	if car.model_id == "electric" and category == "body": key.append(load("res://vehicle/electric_body_kits.gd").REVISION)
	if car.model_id == "electric" and category == "hood": key.append(load("res://vehicle/electric_kits.gd").HOOD_REVISION)
	return key

static func path_for(car: CarVisual, category: String, option: String) -> String:
	return DIRECTORY.path_join(car.model_id).path_join("simple" if car.simple_model else "full").path_join(category).path_join(option+".scn")

static func _valid_option(car: CarVisual, category: String, option: String) -> bool:
	if not VehicleCustomisation.supported(car.model_id) or category not in VehicleCustomisation.CATEGORIES: return false
	for item: Array in VehicleCustomisation.options(category,car.model_id):
		if item[0] == option: return true
	return false

static func _role(car: CarVisual, name: String) -> Material:
	if name.begins_with("paint:"): return car.paint_materials.get(name.trim_prefix("paint:"))
	if name.begins_with("variant:"):
		var index: int = int(name.trim_prefix("variant:"))
		return car.paint_variants[index].get("material") if index >= 0 and index < car.paint_variants.size() else null
	if name in ["brake_material","accent_roof","underside_material"]: return car.get(name)
	return null

static func _roles(car: CarVisual) -> Array:
	var roles: Array = []
	for slot: String in car.paint_materials:
		if car.paint_materials[slot] != null: roles.append({"name":"paint:"+slot,"material":car.paint_materials[slot]})
	for index: int in range(car.paint_variants.size()):
		var material: Material = car.paint_variants[index].get("material")
		if material != null: roles.append({"name":"variant:"+str(index),"material":material})
	for name: String in ["brake_material","accent_roof","underside_material"]:
		var material: Material = car.get(name)
		if material != null: roles.append({"name":name,"material":material})
	return roles

static func _replace_material(value: Material, bindings: Dictionary) -> Material:
	return bindings.get(value,value) if value != null else null

static func _bind(node: Node, bindings: Dictionary) -> void:
	if node is MeshInstance3D:
		node.material_override = _replace_material(node.material_override,bindings)
		node.material_overlay = _replace_material(node.material_overlay,bindings)
		if node.mesh != null and node.material_override == null:
			for surface: int in range(node.mesh.get_surface_count()):
				var current: Material = node.get_active_material(surface)
				if bindings.has(current): node.set_surface_override_material(surface,bindings[current])
	for child: Node in node.get_children(): _bind(child,bindings)

static func _open(car: CarVisual, category: String, option: String) -> Dictionary:
	if not enabled or not car.editable_kits or not car.batch_parts or option == "stock" or not _valid_option(car,category,option): return {}
	var revision: String = Base.build_revision(car.model_id)
	if revision.length() != 64 or not revision.is_valid_hex_number(): return {}
	var path: String = path_for(car,category,option)
	if not ResourceLoader.exists(path): return {}
	var packed: PackedScene = load(path) as PackedScene
	if packed == null: return {}
	var node: Node = packed.instantiate()
	if not node is Node3D:
		if node != null: node.free()
		return {}
	var holder: Node3D = node
	var data: Dictionary = holder.get_meta("modular_kit",{})
	if data.get("key",[]) != key_for(car,category,option): holder.free(); return {}
	if FileAccess.file_exists("res://vehicle/car_visual.gd"):
		var validation=load("res://vehicle/prepared_asset_sources.gd")
		if not source_hashes.has(car.model_id):
			var current: Dictionary=validation.runtime_hashes(car.model_id)
			current["vehicle/modular_car_kits.gd"]=FileAccess.get_sha256("res://vehicle/modular_car_kits.gd")
			source_hashes[car.model_id]=current
		if validation.runtime_projection(data.get("sources",{})) != source_hashes[car.model_id]: holder.free(); return {}
	var bindings: Dictionary = {}
	var has_body: bool = false
	for role: Dictionary in data.get("roles",[]):
		var source: Material = role.get("material")
		var target: Material = _role(car,str(role.get("name","")))
		if source == null or target == null: holder.free(); return {}
		if not bindings.has(source): bindings[source] = target
		if role.name == "paint:body": has_body = true
	if not has_body: holder.free(); return {}
	var declarations: Array = data.get("frames",[])
	if declarations.is_empty(): holder.free(); return {}
	var seen: Dictionary = {}
	var auxiliary: int = 0
	var kit_count: int = 0
	for entry: Dictionary in declarations:
		if not holder.has_node(entry.get("node",NodePath())) or not car.has_node(entry.get("parent",NodePath())):
			holder.free(); return {}
		if not holder.get_node(entry.node) is Node3D or not car.get_node(entry.parent) is Node3D:
			holder.free(); return {}
		var frame: Node = holder.get_node(entry.node)
		if frame.get_parent() != holder or seen.has(frame) or str(entry.get("name","")).is_empty(): holder.free(); return {}
		seen[frame] = true
		if not bool(entry.get("kit",true)):
			if category != "rims" or car.model_id != "hovercraft" or str(entry.name) != "FanRotor" or car.get_node(entry.parent) != car.body: holder.free(); return {}
			auxiliary += 1
		else: kit_count += 1
		for old: Node3D in car.kit_frames.get(category,[]):
			var parent: Node = car.get_node(entry.parent)
			if parent == old or old.is_ancestor_of(parent): holder.free(); return {}
	if category == "rims" and car.model_id == "hovercraft" and car.body.get_node_or_null("FanRotor") == null:
		holder.free(); return {}
	if kit_count == 0: holder.free(); return {}
	if category == "rims" and car.model_id == "hovercraft" and auxiliary != 1: holder.free(); return {}
	return {"holder":holder,"data":data,"bindings":bindings}

static func available(car: CarVisual, parts: Dictionary) -> bool:
	if not enabled or not VehicleCustomisation.valid(parts,car.model_id): return false
	for category: String in VehicleCustomisation.CATEGORIES:
		var option: String = parts[category]
		if option == "stock": continue
		var prepared: Dictionary = _open(car,category,option)
		if prepared.is_empty(): return false
		(prepared.holder as Node).free()
	return true

static func apply(car: CarVisual, category: String, option: String) -> bool:
	var prepared: Dictionary = _open(car,category,option)
	if prepared.is_empty(): return false
	var holder: Node3D = prepared.holder
	var data: Dictionary = prepared.data
	var frames: Array[Node3D] = []
	var parents: Array[Node3D] = []
	var declarations: Array = data.frames
	for entry: Dictionary in declarations:
		frames.append(holder.get_node(entry.node))
		parents.append(car.get_node(entry.parent))
	# Everything required to attach the replacement has been validated first.
	for frame: Node3D in car.kit_frames.get(category,[]):
		frame.get_parent().remove_child(frame)
		frame.queue_free()
	car.kit_frames[category] = []
	if category == "rims" and car.model_id == "hovercraft":
		var previous: Node = car.body.get_node("FanRotor")
		car.body.remove_child(previous)
		previous.queue_free()
	for index: int in range(frames.size()):
		var frame: Node3D = frames[index]
		holder.remove_child(frame)
		Cache._own(frame,null)
		_bind(frame,prepared.bindings)
		frame.name = declarations[index].name
		parents[index].add_child(frame)
		if bool(declarations[index].get("kit",true)): car.kit_frames[category].append(frame)
	holder.free()
	hits += 1
	return true

static func bake(car: CarVisual, category: String, option: String) -> Error:
	if not car.editable_kits or not car.batch_parts or option == "stock" or not _valid_option(car,category,option) or car.customisation.get(category) != option: return ERR_INVALID_PARAMETER
	var revision: String = Base.build_revision(car.model_id)
	if revision.length() != 64 or not revision.is_valid_hex_number(): return ERR_INVALID_DATA
	var source_frames: Array = car.kit_frames.get(category,[]).duplicate()
	if source_frames.is_empty(): return ERR_CANT_CREATE
	var kit_count: int = source_frames.size()
	if category == "rims" and car.model_id == "hovercraft":
		var rotor: Node = car.body.get_node_or_null("FanRotor")
		if rotor == null: return ERR_CANT_CREATE
		source_frames.append(rotor)
	var holder := Node3D.new()
	var declarations: Array = []
	for index: int in range(source_frames.size()):
		var original: Node3D = source_frames[index]
		var copy: Node3D = original.duplicate()
		copy.name = "ModuleFrame_"+str(index)
		holder.add_child(copy)
		declarations.append({"node":holder.get_path_to(copy),"parent":car.get_path_to(original.get_parent()),"name":str(original.name),"kit":index < kit_count})
		for mesh_node: Node in copy.find_children("*","MeshInstance3D",true,false):
			if not mesh_node.mesh is ImmediateMesh: continue
			var saved := ArrayMesh.new()
			for surface: int in range(mesh_node.mesh.get_surface_count()):
				saved.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,mesh_node.mesh.surface_get_arrays(surface))
				saved.surface_set_material(surface,mesh_node.mesh.surface_get_material(surface))
			mesh_node.mesh = saved
	holder.set_meta("modular_kit",{"key":key_for(car,category,option),"sources":geometry_sources(car.model_id),"roles":_roles(car),"frames":declarations})
	for child: Node in holder.get_children(): Cache._own(child,holder)
	var packed := PackedScene.new()
	var error: Error = packed.pack(holder)
	if error == OK:
		var path: String = path_for(car,category,option)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
		error = ResourceSaver.save(packed,path,ResourceSaver.FLAG_COMPRESS)
	holder.free()
	return error
