extends "res://tests/export_car15_proof.gd"
func normal_vectors(mesh: Mesh, surface: int) -> Array:
	var result: Array=[]
	for normal: Vector3 in mesh.surface_get_arrays(surface)[Mesh.ARRAY_NORMAL]: result.append([normal.x,normal.y,normal.z])
	return result
func vectors2(mesh: Mesh, surface: int, slot: int) -> Array:
	var result: Array=[];var data: Variant=mesh.surface_get_arrays(surface)[slot]
	if data!=null:
		for value: Vector2 in data: result.append([value.x,value.y])
	return result
func colors(mesh: Mesh, surface: int) -> Array:
	var result: Array=[];var data: Variant=mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
	if data!=null:
		for value: Color in data: result.append([value.r,value.g,value.b,value.a])
	return result
func _initialize() -> void:
	var catalog: Dictionary=load(WORK.path_join("survey.res")).get_meta("catalog")
	var plan: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT.path_join("candidate-plan.json")))
	var blocked: Dictionary={}
	for key: String in plan.blocked_keys: blocked[key]=true
	var result: Dictionary={}
	var contacts: Dictionary={}
	for key: String in catalog:
		var part_source: Mesh=catalog[key].source
		var contact_surfaces: Array=[]
		for at: int in range(part_source.get_surface_count()): contact_surfaces.append({"vertices":vertices(part_source,at),"indices":indices(part_source,at)})
		contacts[key]={"surfaces":contact_surfaces}
		if blocked.has(key): continue
		var source: Mesh=catalog[key].source
		if source.has_meta("car_surface_guide_locked"): continue
		var surfaces: Array=[]
		for surface: int in range(source.get_surface_count()): surfaces.append({"vertices":vertices(source,surface),"indices":indices(source,surface),"attributes":attributes(source,surface),"normals":normal_vectors(source,surface),"uv":vectors2(source,surface,Mesh.ARRAY_TEX_UV),"uv2":vectors2(source,surface,Mesh.ARRAY_TEX_UV2),"colors":colors(source,surface),"tangents":Array(source.surface_get_arrays(surface)[Mesh.ARRAY_TANGENT]) if source.surface_get_arrays(surface)[Mesh.ARRAY_TANGENT]!=null else []})
		result[key]={"name":catalog[key].name,"surfaces":surfaces}
	FileAccess.open(WORK.path_join("retessellation-input.json"),FileAccess.WRITE).store_string(JSON.stringify(result))
	FileAccess.open(WORK.path_join("contacts-input.json"),FileAccess.WRITE).store_string(JSON.stringify(contacts))
	print("CAR15_RETESSELLATION_INPUT ",result.size());quit()
