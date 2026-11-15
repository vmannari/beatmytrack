extends RefCounted
## Offline-selected indices only. Normal Garage entry loads the prepared scene;
## source construction applies this bounded plan without running a simplifier.
const PATH: String="res://assets/garage/workshop_v1.reduction.json"
const SCHEMA: String="garage-mesh-reduction-1"
const Cleanup=preload("res://ui/garage_mesh_cleanup.gd")
static var enabled: bool=true
static var _recipes: Dictionary={}

static func signature(mesh: ArrayMesh) -> String:
	var streams: Array=[mesh.custom_aabb]
	for surface: int in range(mesh.get_surface_count()):
		streams.append([mesh.surface_get_primitive_type(surface),mesh.surface_get_arrays(surface)])
	return var_to_bytes(streams).hex_encode().sha256_text()

static func _indices(bytes: PackedByteArray,count: int) -> PackedInt32Array:
	var stride: int=2 if count<=65536 else 4
	var result:=PackedInt32Array()
	for at: int in range(0,bytes.size(),stride): result.append(bytes.decode_u16(at) if stride==2 else bytes.decode_u32(at))
	return result

static func _encoded(indices: PackedInt32Array) -> String:
	return Marshalls.raw_to_base64(indices.to_byte_array().compress(FileAccess.COMPRESSION_DEFLATE))

static func _decoded(value: String) -> PackedInt32Array:
	var bytes: PackedByteArray=Marshalls.base64_to_raw(value).decompress_dynamic(16*1024*1024,FileAccess.COMPRESSION_DEFLATE)
	var result:=PackedInt32Array()
	if bytes.size()%4!=0: return result
	for at: int in range(0,bytes.size(),4): result.append(bytes.decode_u32(at))
	return result

static func _encode_remapped(indices: PackedInt32Array,remap: PackedInt32Array,count: int) -> PackedByteArray:
	var stride: int=2 if count<=65536 else 4
	var result:=PackedByteArray();result.resize(indices.size()*stride)
	for at: int in range(indices.size()):
		if stride==2: result.encode_u16(at*stride,remap[indices[at]])
		else: result.encode_u32(at*stride,remap[indices[at]])
	return result

static func _protected_indices(selected: PackedInt32Array,original: PackedInt32Array,inside: PackedByteArray) -> PackedInt32Array:
	if inside.is_empty(): return selected
	var result:=PackedInt32Array()
	# Remove collapsed faces touching a protected object before restoring its
	# exact original faces. This also prevents overlaps and cross-object bridges.
	for at: int in range(0,selected.size(),3):
		if not (inside[selected[at]] or inside[selected[at+1]] or inside[selected[at+2]]):
			result.append_array(selected.slice(at,at+3))
	for at: int in range(0,original.size(),3):
		if inside[original[at]] and inside[original[at+1]] and inside[original[at+2]]:
			result.append_array(original.slice(at,at+3))
	return result

static func plan(mesh: ArrayMesh,keep: bool=false,bounds: Array=[]) -> Dictionary:
	var entry: Dictionary={"keep":keep,"surfaces":[]}
	if keep or mesh.get_blend_shape_count()>0:
		entry.keep=true;return entry
	var packets: Array=mesh.get("_surfaces")
	for surface: int in range(packets.size()):
		var packet: Dictionary=packets[surface]
		if int(packet.format)&(Mesh.ARRAY_FORMAT_BONES|Mesh.ARRAY_FORMAT_WEIGHTS) or int(packet.primitive)!=Mesh.PRIMITIVE_TRIANGLES or not packet.has("index_data") or packet.index_data.is_empty():
			entry.keep=true;entry.surfaces=[];return entry
		var count: int=packet.vertex_count
		var master: PackedInt32Array=_indices(packet.index_data,count)
		var original: PackedInt32Array=master
		var inside:=PackedByteArray()
		if not bounds.is_empty():
			inside.resize(count)
			var vertices: PackedVector3Array=mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for index: int in range(count):
				for box: AABB in bounds:
					if box.has_point(vertices[index]): inside[index]=1;break
			if not inside.has(1): inside.clear()
		var original_count: int=master.size()
		var levels: Array=packet.get("lods",[])
		var selected_size: float=0
		var best: float=0.5
		for at: int in range(0,levels.size(),2):
			var candidate: PackedInt32Array=_indices(levels[at+1],count)
			var error: float=absf(float(candidate.size())/original_count-0.5)
			if not candidate.is_empty() and error<best:
				master=candidate;selected_size=float(levels[at]);best=error
		var retained: Array=[]
		for at: int in range(0,levels.size(),2):
			if float(levels[at])>selected_size:
				retained.append([float(levels[at]),_encoded(_protected_indices(_indices(levels[at+1],count),original,inside))])
		entry.surfaces.append({"vertices":count,"master":_encoded(_protected_indices(master,original,inside)),"lods":retained})
	return entry

static func _relative(node: Node,holder: Node) -> Transform3D:
	var result:=Transform3D.IDENTITY
	while node!=holder:
		if node is Node3D: result=node.transform*result
		node=node.get_parent()
	return result

static func generate(holder: Node) -> Dictionary:
	var result: Dictionary={"schema":SCHEMA,"engine":Engine.get_version_info().string,"target_fraction":0.5,"meshes":{}}
	var bounds: Array=[]
	for node: Node3D in holder.find_children("*","Node3D",true,false):
		for box: AABB in node.get_meta("garage_reduction_protected_bounds",[]):
			bounds.append(_relative(node,holder)*box)
	var grouped: Dictionary={}
	for part: MeshInstance3D in holder.find_children("*","MeshInstance3D",true,false):
		if not part.mesh is ArrayMesh: continue
		var key: String=signature(part.mesh)
		if not grouped.has(key): grouped[key]={"mesh":part.mesh,"keep":false,"bounds":[]}
		grouped[key].keep=grouped[key].keep or part.get_meta("garage_keep_detail",false)
		var inverse: Transform3D=_relative(part,holder).affine_inverse()
		for box: AABB in bounds:
			var local: AABB=inverse*box
			if local.intersects(part.mesh.get_aabb()): grouped[key].bounds.append(local)
	for key: String in grouped:
		var group: Dictionary=grouped[key]
		result.meshes[key]=plan(group.mesh,group.keep,group.bounds)
	return result

static func _mesh(source: ArrayMesh,entry: Dictionary) -> ArrayMesh:
	if not entry.get("surfaces") is Array or entry.surfaces.size()!=source.get_surface_count(): return null
	var packets: Array=source.get("_surfaces").duplicate(true)
	for surface: int in range(packets.size()):
		var packet: Dictionary=packets[surface]
		if not entry.surfaces[surface] is Dictionary: return null
		var spec: Dictionary=entry.surfaces[surface]
		var count: int=packet.vertex_count
		if count!=int(spec.get("vertices",0)) or not spec.get("master") is String or not spec.get("lods") is Array: return null
		var master: PackedInt32Array=_decoded(spec.master)
		if master.is_empty() or master.size()%3!=0: return null
		var union: PackedInt32Array=master.duplicate()
		var levels: Array=[]
		for value: Variant in spec.lods:
			if not value is Array or value.size()!=2 or not value[1] is String: return null
			var level: Array=value
			var indices: PackedInt32Array=_decoded(level[1])
			if indices.is_empty() or indices.size()%3!=0: return null
			levels.append([float(level[0]),indices]);union.append_array(indices)
		var used:=PackedByteArray();used.resize(count)
		for index: int in union:
			if index<0 or index>=count: return null
			used[index]=1
		var remap:=PackedInt32Array();remap.resize(count)
		var next: int=0
		for at: int in range(count):
			if used[at]: remap[at]=next;next+=1
		Cleanup.compact(packet,union)
		packet.index_count=master.size();packet.index_data=_encode_remapped(master,remap,next)
		packet.lods=[]
		for level: Array in levels:
			packet.lods.append(level[0]);packet.lods.append(_encode_remapped(level[1],remap,next))
	var result:=ArrayMesh.new();result.set("_surfaces",packets)
	result.custom_aabb=source.custom_aabb;result.shadow_mesh=source.shadow_mesh
	result.lightmap_size_hint=source.lightmap_size_hint
	result.resource_name=source.resource_name;result.resource_local_to_scene=source.resource_local_to_scene
	result.resource_scene_unique_id=source.resource_scene_unique_id
	for key: StringName in source.get_meta_list(): result.set_meta(key,source.get_meta(key))
	return result

static func apply(holder: Node,data: Dictionary={}) -> Dictionary:
	var stats: Dictionary={"matched":0,"kept":0,"missing":0,"invalid":0}
	if not enabled: return stats
	if data.is_empty():
		if _recipes.is_empty() and FileAccess.file_exists(PATH):
			var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(PATH))
			if parsed is Dictionary: _recipes=parsed
		data=_recipes
	if data.get("schema","")!=SCHEMA or data.get("engine","")!=Engine.get_version_info().string or not data.get("meshes") is Dictionary:
		stats.invalid=1;return stats
	var keys: Dictionary={}
	var meshes: Dictionary={}
	for part: MeshInstance3D in holder.find_children("*","MeshInstance3D",true,false):
		if not part.mesh is ArrayMesh: continue
		var source: ArrayMesh=part.mesh
		if not keys.has(source): keys[source]=signature(source)
		var key: String=keys[source]
		if not data.meshes.has(key): stats.missing+=1;continue
		if not data.meshes[key] is Dictionary: stats.invalid+=1;continue
		var entry: Dictionary=data.meshes[key]
		stats.matched+=1
		if entry.get("keep",false): stats.kept+=1;continue
		if not meshes.has(source): meshes[source]=_mesh(source,entry)
		if meshes[source]==null: stats.invalid+=1;continue
		part.mesh=meshes[source]
	return stats
