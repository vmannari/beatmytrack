extends "res://tests/register_volt_front_door.gd"
const M = preload("res://vehicle/electric_reference_mesh.gd")
var files: Dictionary = {}
var rows: Array = []

func fit_contour(mesh: ArrayMesh, backing: Mesh, side: float) -> ArrayMesh:
	var tree: TriangleMesh = backing.generate_triangle_mesh()
	var arrays: Array = mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	for at: int in range(points.size()):
		var half := Vector3(tangents[at * 4], tangents[at * 4 + 1], tangents[at * 4 + 2]) * uv[at].y
		var hit: Dictionary = tree.intersect_ray(points[at] + Vector3(side * 0.20, 0, 0), Vector3(-side, 0, 0))
		var center: Dictionary = tree.intersect_ray(points[at] - half + Vector3(side * 0.20, 0, 0), Vector3(-side, 0, 0))
		assert(not hit.is_empty() and not center.is_empty(), "Complete changed contour backing")
		points[at].x = hit.position.x + side * 0.00105
		var delta: Vector3 = points[at] - Vector3(center.position.x + side * 0.00105, points[at].y - half.y, points[at].z - half.z)
		var axis: Vector3 = delta.normalized()
		tangents[at * 4] = axis.x
		tangents[at * 4 + 1] = axis.y
		tangents[at * 4 + 2] = axis.z
		uv[at].y = delta.length()
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_TEX_UV] = uv
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	for property: StringName in mesh.get_meta_list(): result.set_meta(property, mesh.get_meta(property))
	result.set_meta("volt_contour_backing", D.mesh_key(backing))
	return result

func run() -> void:
	var stage: String = WORK.path_join("staged")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(stage))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(M.ASSET_ROOT.path_join("manifest.json")))
	# Preserve all existing authored surfaces, including offline normal fields.
	for row: Dictionary in manifest.meshes:
		var mesh: Mesh = load(M.ASSET_ROOT.path_join(row.file))
		M.meshes[row.part] = mesh
		if selected(row.part):
			M.meshes.erase(row.part)
	M.use_baked = false
	preload("res://vehicle/modular_car_base.gd").enabled = false
	preload("res://vehicle/modular_car_kits.gd").enabled = false
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	for simple: bool in [false, true]:
		var car := CarVisual.new()
		car.vehicle_id = "electric"
		car.simple_model = simple
		car.batch_parts = false
		car.cache_rest_pose = false
		root.add_child(car)
		while not car.model_ready: await process_frame
		for part: MeshInstance3D in car.body.find_children("*", "MeshInstance3D", false, false):
			if not selected(str(part.name)) or not part.mesh.has_meta("pixel_integrated_contour"): continue
			var side: float = -1 if "-1_0" in str(part.name) else 1
			var skin: MeshInstance3D = car.body.get_node(NodePath("ReferenceSide" + str(side).replace(".", "_")))
			part.mesh.set_meta("car_authored_far", true)
			part.mesh.set_meta("car_surface_guide_locked", true)
			if simple: part.mesh.set_meta("car_keep_master", true)
			var backing: Mesh = skin.mesh
			if simple:
				var reduced: ArrayMesh = preload("res://vehicle/car_static_reduction.gd").resolve(skin.mesh, "electric")
				reduced = preload("res://vehicle/car_coarse_reduction.gd").resolve(reduced, "electric")
				var registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUT.path_join("frame-registry.json")))
				for frame: Dictionary in registry.raw.values():
					for row: Dictionary in frame.recipe.get("parts", {}).values():
						if row.source == D.mesh_key(reduced): backing = load(D.ROOT.path_join(row.mesh))
				assert(backing.get_meta("car_keep_master", false), "Use the actual protected racing side")
			var fitted: ArrayMesh = fit_contour(part.mesh, backing, side)
			for label: String in M.meshes:
				if M.meshes[label] == part.mesh: M.meshes[label] = fitted
		car.free()
		await process_frame
	var updated: Array = []
	for row: Dictionary in manifest.meshes:
		# Retire old handle stations and obsolete fitted-v1 seam entries.
		if selected(row.part): continue
		updated.append(row)
	for label: String in M.meshes:
		if not selected(label) or label.contains("_fitted_v1"): continue
		var mesh: Mesh = M.meshes[label]
		var file: String = label.sha256_text().left(24) + ".res"
		assert(ResourceSaver.save(mesh, stage.path_join(file), ResourceSaver.FLAG_COMPRESS) == OK)
		files[file] = "game/" + M.ASSET_ROOT.trim_prefix("res://").path_join(file)
		updated.append({"part": label, "file": file, "triangles": mesh.get_faces().size() / 3})
		rows.append({"part": label, "triangles": mesh.get_faces().size() / 3})
	manifest.meshes = updated
	for name: String in ["electric_reference_body.gd", "electric_reference_cabin.gd", "electric_reference_details.gd"]:
		manifest.sources[name] = FileAccess.get_sha256("res://vehicle/" + name)
	FileAccess.open(stage.path_join("manifest.json"), FileAccess.WRITE).store_string(JSON.stringify(manifest, "\t"))
	files["manifest.json"] = "game/" + M.ASSET_ROOT.trim_prefix("res://").path_join("manifest.json")
	FileAccess.open(OUT.path_join("native-staged.json"), FileAccess.WRITE).store_string(JSON.stringify({"files": files, "rows": rows}, "  "))
	print("VFD_NATIVE ", rows.size(), " door meshes staged")
	quit()
