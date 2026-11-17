extends SceneTree
func _initialize() -> void:
	var work: String="res://../build/car-mechanics-2026-11-17"
	var plan: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../docs/evidence/car-mechanics-2026-11-17/selected-plan.json"))
	var catalog: Dictionary=load(work.path_join("survey.res")).get_meta("catalog")
	for key: String in plan.parts:
		if plan.parts[key].has("required_bindings"):continue
		var source: Mesh=catalog[key].source
		var path: String=work.path_join("candidates").path_join(plan.parts[key].file)
		var candidate: Mesh=load(path)
		var arrays: Array=candidate.surface_get_arrays(0)
		var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		var maximum: float=0
		var z_low: float=INF;var z_high: float=-INF
		for p: Vector3 in points:
			maximum=maxf(maximum,absf(p.x));z_low=minf(z_low,p.z);z_high=maxf(z_high,p.z)
		var scale_x: float=(source.get_aabb().size.x*0.5)/maximum
		var profile: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(work.path_join("pin-profile.json")))
		assert(profile.phase==0.0 and profile.xfill==1.0)
		var scale_z: float=source.get_aabb().size.z*float(profile.zfill)/(z_high-z_low)
		var z_center: float=(z_low+z_high)*0.5
		for at: int in range(points.size()):
			points[at].x*=scale_x
			points[at].z=(points[at].z-z_center)*scale_z
			normals[at]=Vector3(normals[at].x/scale_x,normals[at].y,normals[at].z/scale_z).normalized()
			assert(source.get_aabb().grow(0.000001).has_point(points[at]))
		arrays[Mesh.ARRAY_VERTEX]=points;arrays[Mesh.ARRAY_NORMAL]=normals
		# No normal map is used by this dark-metal finish. Generate the matching
		# tangent basis offline after the affine fit instead of retaining old axes.
		arrays[Mesh.ARRAY_TANGENT]=null
		var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var tool:=SurfaceTool.new();tool.create_from(mesh,0);tool.generate_tangents();mesh=tool.commit()
		var packets: Array=mesh.get("_surfaces").duplicate(true)
		for packet: Dictionary in packets:packet.aabb=source.get_aabb()
		mesh.set("_surfaces",packets);mesh.custom_aabb=source.get_aabb();mesh.set_meta("car_pass10_source",key)
		assert(ResourceSaver.save(mesh,path,ResourceSaver.FLAG_COMPRESS)==OK)
		print("PIN_AFFINE_FIT ",scale_x," triangles=",mesh.get_faces().size()/3)
	quit()
