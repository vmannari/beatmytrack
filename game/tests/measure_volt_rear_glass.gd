extends SceneTree
## Native prepared-buffer measurements for the rear-glass extension.
func _initialize() -> void:
	var result: Dictionary={}
	var buffers: Dictionary={}
	for version: int in [21,22]:
		var directory: String="res://assets/vehicles/electric_coachwork_v"+str(version)
		var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(directory+"/manifest.json"))
		for entry: Dictionary in manifest.meshes:
			var mesh: ArrayMesh=load(directory.path_join(entry.file))
			var hashes: Array[String]=[]
			for surface: int in range(mesh.get_surface_count()):
				var context:=HashingContext.new()
				context.start(HashingContext.HASH_SHA256)
				context.update(var_to_bytes(mesh.surface_get_arrays(surface)))
				hashes.append(context.finish().hex_encode())
			buffers[str(version)+entry.part]=hashes
			if entry.part not in ["RearScreen","RearScreen_simple"]: continue
			var arrays: Array=mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
			for i: int in range(vertices.size()):
				if uv[i].distance_squared_to(Vector2(0.5,1))<0.000001:
					result[str(version)+entry.part]={"centre_lower_edge_model_metres":[vertices[i].x,vertices[i].y,vertices[i].z]}
					break
	var changed: Array[String]=[]
	var parts: int=0
	for key: String in buffers:
		if not key.begins_with("21"): continue
		parts+=1
		var part: String=key.trim_prefix("21")
		if buffers[key]!=buffers["22"+part]: changed.append(part)
	result["buffer_comparison"]={"total_parts":parts,"unchanged":parts-changed.size(),"changed_parts":changed}
	var output: String="res://../docs/evidence/volt-rear-glass-lower-2026-10-29/measurements.json"
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	print("VOLT_REAR_GLASS_MEASUREMENTS: ",JSON.stringify(result))
	quit()
