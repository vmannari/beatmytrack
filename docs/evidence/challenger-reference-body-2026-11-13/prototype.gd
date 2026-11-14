extends SceneTree
func _initialize() -> void:
	for tier: String in ["simple","full"]:
		for role: String in ["paint","contour"]:
			var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../build/challenger-reference-body-2026-11-13/converted/"+tier+"_"+role+"_prototype.json"))
			var positions := PackedVector3Array(); var normals := PackedVector3Array()
			for v: Array in data.vertices:positions.append(Vector3(v[0],v[1],v[2]))
			for n: Array in data.normals:normals.append(Vector3(n[0],n[1],n[2]))
			var uv := PackedVector2Array();uv.resize(positions.size())
			var colors := PackedColorArray();colors.resize(positions.size());colors.fill(Color.WHITE)
			var arrays: Array = [];arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX]=positions;arrays[Mesh.ARRAY_NORMAL]=normals
			arrays[Mesh.ARRAY_INDEX]=PackedInt32Array(data.indices);arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_COLOR]=colors
			var mesh := ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			assert(ResourceSaver.save(mesh,"res://assets/vehicles/challenger_hellcat_v1/"+tier+"_body_"+role+".res")==OK)
	print("LOCAL_SURFACE_PROTOTYPE saved")
	quit()
