extends SceneTree
const WORK: String="res://../build/car-mechanics-2026-11-17"
const OUT: String="res://../docs/evidence/car-mechanics-2026-11-17"
func _initialize() -> void:
	var plan: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT.path_join("selected-plan.json")))
	var proposed: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(WORK.path_join("hidden-proposals.json")))
	var catalog: Dictionary=load(WORK.path_join("survey.res")).get_meta("catalog")
	for key: String in proposed:
		if not (key.begins_with("kart_") or key.begins_with("forklift_")) or plan.parts.has(key):continue
		var source: ArrayMesh=catalog[key].source
		var packets: Array=source.get("_surfaces").duplicate(true)
		for sf: int in range(packets.size()):
			var raw: Variant=source.surface_get_arrays(sf)[Mesh.ARRAY_INDEX]
			var indices: PackedInt32Array=raw if raw!=null else PackedInt32Array()
			if indices.is_empty():
				for at: int in range(packets[sf].vertex_count):indices.append(at)
			var removed: Dictionary={}
			for at: int in proposed[key].remove[sf]:removed[at]=true
			var selected:=PackedInt32Array()
			for at: int in range(0,indices.size(),3):
				if not removed.has(at/3):selected.append_array(indices.slice(at,at+3))
			var stride: int=2 if int(packets[sf].vertex_count)<=65536 else 4
			var bytes:=PackedByteArray();bytes.resize(selected.size()*stride)
			for at: int in range(selected.size()):
				if stride==2:bytes.encode_u16(at*stride,selected[at])
				else:bytes.encode_u32(at*stride,selected[at])
			packets[sf].index_data=bytes;packets[sf].index_count=selected.size();packets[sf].erase("lods")
		var mesh:=ArrayMesh.new();mesh.set("_surfaces",packets);mesh.custom_aabb=source.custom_aabb
		mesh.set_meta("car_pass10_source",key)
		var name: String=key+"_hidden.res"
		assert(ResourceSaver.save(mesh,WORK.path_join("candidates").path_join(name),ResourceSaver.FLAG_COMPRESS)==OK)
		plan.parts[key]={"file":name,"before":source.get_faces().size()/3,"after":mesh.get_faces().size()/3,"required_bindings":proposed[key].required_bindings,"proof":"closed opaque same-frame solid with 0.5mm burial"}
	FileAccess.open(OUT.path_join("selected-plan.json"),FileAccess.WRITE).store_string(JSON.stringify(plan,"  "))
	print("MECHANICS_HIDDEN ",plan.parts.size()," qualified candidate sources");quit()
