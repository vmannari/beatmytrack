extends RefCounted
## Stock-kit reduced Compact header geometry; fail closed on source or engine changes.
const Cache=preload("res://vehicle/prepared_car_cache.gd")
const DIRECTORY: String="res://assets/menu/header_car_templates_v1/"
const SCHEMA: String="header-reduced-rest-v4"
const Build = preload("res://core/build_identity.gd")
static var enabled: bool=true
static var hits: int=0
static var source_hashes: Dictionary={}

static func engine_key() -> Array:
	var version: Dictionary = Engine.get_version_info()
	return [str(version.get("string","")),str(version.get("hash",""))]

static func valid_data(data: Dictionary, car: CarVisual, revision: String) -> bool:
	return data.get("schema","")==SCHEMA and data.get("revision","")==revision and data.get("engine",[])==engine_key() and data.get("key",[])==geometry_key(car)

static func geometry_key(car: CarVisual) -> Array:
	var config: HandlingConfig=VehicleCatalog.config(car.model_id)
	return [SCHEMA,car.model_id,car.simple_model,car.editable_kits,car.batch_parts,VisualGeometry.optimize_model_geometry,HandlingConfig.BODY_SCALE,config.wheelbase,config.track_width]

static func geometry_sources() -> Dictionary:
	var result: Dictionary=preload("res://vehicle/modular_car_base.gd").source_hashes("compact")
	result["game/ui/header_simple_cache.gd"]=FileAccess.get_sha256("res://ui/header_simple_cache.gd")
	return result

static func geometry_revision() -> String:
	return preload("res://vehicle/modular_car_base.gd").build_revision("compact")

static func restore(car: CarVisual) -> bool:
	if not enabled or not car.simple_model or car.model_id!="compact" or car.customisation!=VehicleCustomisation.defaults(): return false
	var revision: String = geometry_revision()
	if revision.length()!=64 or not revision.is_valid_hex_number(): return false
	var path: String=DIRECTORY+car.model_id+".scn"
	if not ResourceLoader.exists(path): return false
	var scene: PackedScene=load(path) as PackedScene
	if scene==null: return false
	var instance: Node=scene.instantiate()
	if not instance is Node3D:
		if instance!=null: instance.free()
		return false
	var holder: Node3D=instance
	var data: Dictionary=holder.get_meta("garage_rest",{})
	if not valid_data(data,car,revision):
		holder.free()
		return false
	if OS.has_feature("editor") and FileAccess.file_exists("res://vehicle/car_visual.gd"):
		var validation=preload("res://vehicle/prepared_asset_sources.gd")
		if source_hashes.is_empty(): source_hashes=validation.runtime_hashes("compact")
		if validation.runtime_projection(data.get("sources",{}))!=source_hashes:
			holder.free()
			return false
	var copies: Dictionary={"mutable":Cache._mutable_roles(data)}
	Cache._isolate(holder,copies)
	for child: Node in holder.get_children():
		holder.remove_child(child)
		Cache._own(child,null)
		car.add_child(child)
	holder.free()
	car.body=car.get_node(data.body)
	for field: String in ["front_wheels","rear_wheels","rolling_wheels","brake_lights"]:
		var nodes: Array=car.get(field)
		for path_to_node: NodePath in data[field]: nodes.append(car.get_node(path_to_node))
	car.wheel_radii.assign(data.wheel_radii)
	car.wheel_rest_positions.assign(data.wheel_rest_positions)
	for field: String in ["brake_material","accent_roof","underside_material"]: car.set(field,Cache._material(data[field],copies))
	for slot: String in data.paint_materials: car.paint_materials[slot]=Cache._material(data.paint_materials[slot],copies)
	for declaration: Dictionary in data.paint_variants:
		var value: Dictionary=declaration.duplicate()
		value.material=Cache._material(declaration.material,copies)
		car.paint_variants.append(value)
	for category: String in data.kit_frames:
		car.kit_frames[category]=[]
		for path_to_node: NodePath in data.kit_frames[category]: car.kit_frames[category].append(car.get_node(path_to_node))
	hits+=1
	return true

static func bake(car: CarVisual, revision: String) -> Error:
	if car.model_id!="compact" or not car.simple_model or car.customisation!=VehicleCustomisation.defaults() or revision.length()!=64 or not revision.is_valid_hex_number(): return ERR_INVALID_PARAMETER
	var entry: Dictionary={}
	for candidate: Dictionary in Cache.entries:
		if candidate.key==Cache.key_for(car): entry=candidate;break
	if entry.is_empty(): return ERR_CANT_CREATE
	var copies: Dictionary={"mutable":Cache._mutable_roles(entry),"snapshots":entry.material_snapshots}
	var holder: Node3D=Cache._instantiate(entry,copies)
	# ImmediateMesh drawing commands are not stored by ResourceSaver. Preserve
	# their actual surface arrays in a serializable mesh before packing.
	for node: Node in holder.find_children("*","MeshInstance3D",true,false):
		if not node.mesh is ImmediateMesh: continue
		var saved:=ArrayMesh.new()
		for index: int in range(node.mesh.get_surface_count()):
			saved.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,node.mesh.surface_get_arrays(index))
			saved.surface_set_material(index,node.mesh.surface_get_material(index))
		node.mesh=saved
	var data: Dictionary={"schema":SCHEMA,"revision":revision,"engine":engine_key(),"sources":geometry_sources(),"key":geometry_key(car),"vehicle":car.model_id,"editable":car.editable_kits,
		"body":entry.body,"wheel_radii":entry.wheel_radii,"wheel_rest_positions":entry.wheel_rest_positions,
		"paint_materials":{},"paint_variants":[],"kit_frames":entry.kit_frames}
	for field: String in ["front_wheels","rear_wheels","rolling_wheels","brake_lights"]: data[field]=entry[field]
	for field: String in ["brake_material","accent_roof","underside_material"]: data[field]=Cache._material(entry[field],copies)
	for slot: String in entry.paint_materials: data.paint_materials[slot]=Cache._material(entry.paint_materials[slot],copies)
	for declaration: Dictionary in entry.paint_variants:
		var value: Dictionary=declaration.duplicate()
		value.material=Cache._material(declaration.material,copies)
		data.paint_variants.append(value)
	holder.set_meta("garage_rest",data)
	for child: Node in holder.get_children(): Cache._own(child,holder)
	var scene:=PackedScene.new()
	var error: Error=scene.pack(holder)
	if error==OK:
		DirAccess.make_dir_recursive_absolute(DIRECTORY)
		error=ResourceSaver.save(scene,DIRECTORY+car.model_id+".scn",ResourceSaver.FLAG_COMPRESS)
	holder.free()
	return error
