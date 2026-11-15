extends SceneTree
var WORK: String=OS.get_environment("BMT_CAR_BUDGET_WORK") if OS.has_environment("BMT_CAR_BUDGET_WORK") else "res://../build/car-10k-models-2026-11-14"
func _initialize() -> void:
	var data: Resource=load(WORK.path_join("bake-cache.res"))
	var catalog: Dictionary=data.get_meta("catalog");var result: Dictionary={}
	for key: String in catalog:
		if catalog[key].vehicle=="super_rally": continue
		var source: Mesh=catalog[key].source;var surfaces: Array=[]
		for surface: int in range(source.get_surface_count()):
			var arrays: Array=source.surface_get_arrays(surface)
			var vertices: Array=[]
			for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]: vertices.append([vertex.x,vertex.y,vertex.z])
			var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			if indices.is_empty():
				indices.resize(vertices.size())
				for at: int in range(indices.size()): indices[at]=at
			surfaces.append({"vertices":vertices,"indices":Array(indices)})
		result[key]={"surfaces":surfaces,"name":catalog[key].name}
	FileAccess.open(WORK.path_join("surfaces.json"),FileAccess.WRITE).store_string(JSON.stringify(result))
	print("TEN_K_EXPORTED ",result.size()," pieces");quit()
