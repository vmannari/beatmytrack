extends RefCounted
## Offline recipe: regenerate every scene; reuse LODs only for exact masters.
const Original=preload("res://vehicle/car_mesh_lods.gd")
var saved: Dictionary={}
var materials: Dictionary={}
func hash_bytes(bytes: PackedByteArray)->String:
	var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(bytes);return h.finish().hex_encode()
func value_key(value: Variant)->Variant:
	if value is Material:return material_key(value)
	if value is Shader:return value.code
	if value is Texture2D:
		var pic: Image=value.get_image()
		return [value.get_class(),pic.get_size(),pic.get_format(),pic.has_mipmaps(),hash_bytes(pic.get_data())] if pic!=null else [value.get_class(),value.resource_path]
	if value is Resource:return [value.get_class(),value.resource_path]
	return value
func material_key(material: Material)->String:
	if material==null:return "null"
	if materials.has(material):return materials[material]
	var data: Array=[material.get_class()]
	for p: Dictionary in material.get_property_list():
		if int(p.usage)&PROPERTY_USAGE_STORAGE and not str(p.name).begins_with("resource_") and p.name!="script":data.append([p.name,value_key(material.get(p.name))])
	var result: String=hash_bytes(var_to_bytes(data));materials[material]=result;return result
func fingerprint(part: MeshInstance3D)->String:
	var packets: Array=part.mesh.get("_surfaces").duplicate(true)
	for index: int in range(packets.size()):
		packets[index].erase("lods");packets[index].erase("material")
		packets[index].appearance=material_key(part.get_active_material(index))
	return hash_bytes(var_to_bytes([packets,part.mesh.custom_aabb,part.transform,part.visible,part.layers,part.cast_shadow]))
func capture(path: String)->void:
	var scene: PackedScene=load(path)
	if scene==null:return
	var holder: Node=scene.instantiate();var entries: Dictionary={}
	for part: MeshInstance3D in holder.find_children("*","MeshInstance3D",true,false):
		if not part.mesh is ArrayMesh:continue
		var levels: Array=[]
		for packet: Dictionary in part.mesh.get("_surfaces"):levels.append(packet.get("lods",[]).duplicate(true))
		entries[str(holder.get_path_to(part))]={"signature":fingerprint(part),"levels":levels,"bias":part.lod_bias}
	saved[path]=entries;holder.free()
func scan(path: String)->void:
	for file: String in DirAccess.get_files_at(path):
		if file.ends_with(".scn"):capture(path.path_join(file))
	for folder: String in DirAccess.get_directories_at(path):scan(path.path_join(folder))
func _init()->void:
	var kind: String="kits";var id: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--reuse-kind="):kind=arg.trim_prefix("--reuse-kind=")
		if arg.begins_with("--vehicle="):id=arg.trim_prefix("--vehicle=")
	var root_path: String="res://assets/vehicles/modular_kits_v1" if kind=="kits" else "res://assets/vehicles/modular_car_bases_v1" if kind=="bases" else "res://assets/garage/cars_v1"
	if kind=="kits" and not id.is_empty():root_path=root_path.path_join(id)
	scan(root_path);materials.clear()
func bake(path: String,vehicle: String="",bias: float=1.0)->Error:
	var scene: PackedScene=load(path);var holder: Node=scene.instantiate()
	var parts: Array=holder.find_children("*","MeshInstance3D",true,false)
	var entries: Dictionary=saved.get(path,{})
	var valid: bool=true;var meshes: int=0
	for part: MeshInstance3D in parts:
		if not part.mesh is ArrayMesh:continue
		meshes+=1;var key: String=str(holder.get_path_to(part))
		if not entries.has(key) or entries[key].signature!=fingerprint(part) or entries[key].bias!=bias:valid=false;break
	if meshes!=entries.size():valid=false
	if not valid:
		holder.free();print("LOD_REUSE_REGENERATE ",path)
		return Original.new().bake(path,vehicle,bias)
	for part: MeshInstance3D in parts:
		part.lod_bias=bias
		if not part.mesh is ArrayMesh:continue
		var source: ArrayMesh=part.mesh;var packets: Array=source.get("_surfaces").duplicate(true)
		var levels: Array=entries[str(holder.get_path_to(part))].levels
		for index: int in range(packets.size()):
			if not levels[index].is_empty():packets[index].lods=levels[index]
			else:packets[index].erase("lods")
		var result:=ArrayMesh.new();result.set("_surfaces",packets);result.custom_aabb=source.custom_aabb;result.shadow_mesh=source.shadow_mesh
		for key: StringName in source.get_meta_list():result.set_meta(key,source.get_meta(key))
		part.mesh=result;part.lod_bias=bias
	var packed:=PackedScene.new();var error: Error=packed.pack(holder)
	if error==OK:error=ResourceSaver.save(packed,path,ResourceSaver.FLAG_COMPRESS)
	holder.free();print("LOD_REUSE_EXACT ",path," meshes=",meshes);return error
