extends SceneTree
const WORK: String="res://../build/car-step10-2026-11-15"
const OUT: String="res://../docs/evidence/car-step10-2026-11-15"
func _initialize() -> void:
	var catalog: Dictionary=load(WORK.path_join("survey.res")).get_meta("catalog")
	var plan: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT.path_join("candidate-plan.json")))
	var review: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT.path_join("geometry-review.json")))
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(WORK.path_join("expanded-retessellated.json")))
	var observations: Array=JSON.parse_string(FileAccess.get_file_as_string(OUT.path_join("survey.json")))
	var weights: Dictionary={};var scales: Dictionary={}
	for row: Dictionary in observations:
		if row.mode=="stock": weights[row.key]=int(weights.get(row.key,0))+1
		scales[row.key]=maxf(float(scales.get(row.key,0)),float(row.maximum_scale))
	var compactor=preload("res://tests/support/car_static_reduction_bake.gd").new()
	var parts: Dictionary={}
	for key: String in plan.parts:
		if review.parts[key].accepted: parts[key]=plan.parts[key]
	for key: String in data:
		var entry: Dictionary=catalog[key];var source: Mesh=entry.source
		var before: int=source.get_faces().size()/3;var after: int=0
		for indices: Array in data[key]: after+=indices.size()/3
		if after>=before: continue

		var packets: Array=[]
		for surface: int in range(source.get_surface_count()):
			var packet: Dictionary=RenderingServer.mesh_get_surface(source.get_rid(),surface).duplicate(true)
			packet.erase("lods");packet.aabb=source.get_aabb()
			var indices:=PackedInt32Array(data[key][surface])
			var stride: int=2 if int(packet.vertex_count)<=65536 else 4
			var bytes:=PackedByteArray();bytes.resize(indices.size()*stride)
			for at: int in range(indices.size()):
				if stride==2: bytes.encode_u16(at*stride,indices[at])
				else: bytes.encode_u32(at*stride,indices[at])
			packet.index_data=bytes;packet.index_count=indices.size();packet.format=int(packet.format)|Mesh.ARRAY_FORMAT_INDEX
			packets.append(packet)
		var raw:=ArrayMesh.new();raw.set("_surfaces",packets);raw.custom_aabb=source.get_aabb()
		var selected: ArrayMesh=compactor.compact(raw)
		for property: StringName in source.get_meta_list(): selected.set_meta(property,source.get_meta(property))
		selected.set_meta("car_step10_source",key)
		var file: String=key+"_expanded.res"
		assert(ResourceSaver.save(selected,WORK.path_join("candidates").path_join(file),ResourceSaver.FLAG_COMPRESS)==OK)
		parts[key+"_expanded"]={"source_key":key,"vehicle":entry.vehicle,"name":entry.name,"before":before,"after":after,"stock_instances":weights.get(key,0),"maximum_scale":scales[key],"file":file,"resource":entry.resource,"retessellated":true}
	plan.parts=parts
	FileAccess.open(OUT.path_join("candidate-plan.json"),FileAccess.WRITE).store_string(JSON.stringify(plan,"  "))
	print("CAR15_RETESSELLATED_CANDIDATES ",parts.size());quit()
