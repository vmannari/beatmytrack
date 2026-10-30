extends RefCounted
## Offline rest-pose geometry for the Garage. Meshes are shared; finishes are owned.
const Cache=preload("res://vehicle/prepared_car_cache.gd")
const DIRECTORY: String="res://assets/garage/cars_v1/"
const SCHEMA: String="garage-rest-v1"
static var enabled: bool=true
static var hits: int=0
static var source_hashes: Dictionary={}

static func geometry_key(car: CarVisual) -> Array:
	var config: HandlingConfig=VehicleCatalog.config(car.vehicle_id)
	return [SCHEMA,car.vehicle_id,car.editable_kits,car.batch_parts,VisualGeometry.optimize_model_geometry,HandlingConfig.BODY_SCALE,config.wheelbase,config.track_width]

static func geometry_sources() -> Dictionary:
	var result: Dictionary={}
	for file: String in DirAccess.get_files_at("res://vehicle"):
		if not file.ends_with(".gd"): continue
		if file in ["car_visual.gd","vehicle_models.gd","visual_geometry.gd"] or file.begins_with("compact_") or file.begins_with("electric_") or file.begins_with("kart_") or file.begins_with("forklift_"):
			result[file]=FileAccess.get_sha256("res://vehicle/"+file)
	return result

static func restore(car: CarVisual) -> bool:
	if not enabled or car.simple_model or car.customisation!=VehicleCustomisation.defaults(): return false
	var path: String=DIRECTORY+car.vehicle_id+".scn"
	if not ResourceLoader.exists(path): return false
	var scene: PackedScene=load(path)
	var holder: Node3D=scene.instantiate()
	var data: Dictionary=holder.get_meta("garage_rest",{})
	if OS.has_feature("editor") and FileAccess.file_exists("res://vehicle/car_visual.gd"):
		if source_hashes.is_empty(): source_hashes=geometry_sources()
		if data.get("sources",{})!=source_hashes:
			holder.free()
			return false
	if data.get("key",[])!=geometry_key(car):
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

static func bake(car: CarVisual) -> Error:
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
	var data: Dictionary={"schema":SCHEMA,"sources":geometry_sources(),"key":geometry_key(car),"vehicle":car.vehicle_id,"editable":car.editable_kits,
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
		error=ResourceSaver.save(scene,DIRECTORY+car.vehicle_id+".scn",ResourceSaver.FLAG_COMPRESS)
	holder.free()
	return error
