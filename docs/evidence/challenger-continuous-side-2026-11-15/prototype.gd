extends SceneTree
func _initialize() -> void:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../build/challenger-continuous-side-2026-11-15/candidate-side.json"))
	var prefix: String="res://../build/challenger-continuous-side-2026-11-15/native/"
	for tier: String in ["full","simple"]:
		for role: String in ["paint","contour"]:
			var file: String=prefix+tier+"_body_"+role+".res"
			var source: ArrayMesh=load("res://../build/challenger-continuous-side-2026-11-15/baseline/"+tier+"_body_"+role+".res")
			var a: Array=source.surface_get_arrays(0)
			var p:=PackedVector3Array();var n:=PackedVector3Array()
			for value: Array in data[tier]["points" if role=="paint" else "contour_points"]:p.append(Vector3(value[0],value[1],value[2]))
			a[Mesh.ARRAY_VERTEX]=p
			if role=="paint":
				for value: Array in data[tier].normals:n.append(Vector3(value[0],value[1],value[2]))
				a[Mesh.ARRAY_NORMAL]=n;a[Mesh.ARRAY_INDEX]=PackedInt32Array(data[tier].indices)
				a[Mesh.ARRAY_TANGENT]=null
				var uv:=PackedVector2Array();uv.resize(p.size());a[Mesh.ARRAY_TEX_UV]=uv
				var colors:=PackedColorArray();colors.resize(p.size());colors.fill(Color.WHITE);a[Mesh.ARRAY_COLOR]=colors
				a[Mesh.ARRAY_TEX_UV2]=null
			var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
			assert(mesh.get_surface_count()==1)
			for meta: StringName in source.get_meta_list():mesh.set_meta(meta,source.get_meta(meta))
			assert(ResourceSaver.save(mesh,file)==OK)
	print("SIDE_PROTOTYPE private meshes only")
	quit()
