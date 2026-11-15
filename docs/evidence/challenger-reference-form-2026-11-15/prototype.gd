extends SceneTree
func _initialize() -> void:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../build/challenger-reference-form-2026-11-15/candidate-form.json"))
	var prefix: String="res://../build/challenger-reference-form-2026-11-15/native/"
	for tier: String in ["full","simple"]:
		for name: String in data[tier]:
			var source: ArrayMesh=load("res://../build/challenger-reference-form-2026-11-15/baseline/"+tier+"_"+name+".res")
			var a: Array=source.surface_get_arrays(0)
			var p:=PackedVector3Array();var n:=PackedVector3Array()
			for value: Array in data[tier][name].points:p.append(Vector3(value[0],value[1],value[2]))
			for value: Array in data[tier][name].normals:n.append(Vector3(value[0],value[1],value[2]))
			a[Mesh.ARRAY_VERTEX]=p;a[Mesh.ARRAY_NORMAL]=n;a[Mesh.ARRAY_INDEX]=PackedInt32Array(data[tier][name].indices)
			a[Mesh.ARRAY_TANGENT]=null;a[Mesh.ARRAY_TEX_UV2]=null
			var uv:=PackedVector2Array();uv.resize(p.size());a[Mesh.ARRAY_TEX_UV]=uv
			var colors:=PackedColorArray();colors.resize(p.size());colors.fill(Color.WHITE);a[Mesh.ARRAY_COLOR]=colors
			var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
			for meta: StringName in source.get_meta_list():mesh.set_meta(meta,source.get_meta(meta))
			assert(ResourceSaver.save(mesh,prefix+tier+"_"+name+".res")==OK)
	print("REFERENCE_FORM_PROTOTYPE private meshes only")
	quit()
