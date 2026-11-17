extends "res://tests/register_volt_front_door.gd"
var files: Dictionary = {}
var migrations: Array = []

func remap_glass(source: ArrayMesh, previous: Dictionary) -> ArrayMesh:
	var old: ArrayMesh = load(S.ROOT.path_join(previous.mesh))
	var arrays: Array = old.surface_get_arrays(0)
	var native: Array = source.surface_get_arrays(0)
	var positions: PackedVector3Array = native[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = native[Mesh.ARRAY_NORMAL]
	var chart: PackedVector2Array = native[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = native[Mesh.ARRAY_INDEX]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var points := PackedVector3Array()
	var directions := PackedVector3Array()
	for q: Vector2 in uv:
		var found: bool = false
		for at: int in range(0, indices.size(), 3):
			var a: int = indices[at]
			var b: int = indices[at + 1]
			var c: int = indices[at + 2]
			var ab: Vector2 = chart[b] - chart[a]
			var ac: Vector2 = chart[c] - chart[a]
			var offset: Vector2 = q - chart[a]
			var determinant: float = ab.cross(ac)
			if absf(determinant) < 0.000000001: continue
			var v: float = offset.cross(ac) / determinant
			var w: float = ab.cross(offset) / determinant
			if minf(1.0 - v - w, minf(v, w)) < -0.00001: continue
			points.append(positions[a] * (1.0 - v - w) + positions[b] * v + positions[c] * w)
			directions.append((normals[a] * (1.0 - v - w) + normals[b] * v + normals[c] * w).normalized())
			found = true
			break
		assert(found, "Every retained glass chart vertex maps onto the new pane")
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = directions
	arrays[Mesh.ARRAY_TANGENT] = null
	var draft := ArrayMesh.new()
	draft.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var tool := SurfaceTool.new()
	tool.create_from(draft, 0)
	tool.generate_tangents()
	var generated: ArrayMesh = tool.commit()
	var packets: Array = generated.get("_surfaces")
	for packet: Dictionary in packets: packet.aabb = source.get_aabb()
	var result := ArrayMesh.new()
	result.set("_surfaces", packets)
	result.custom_aabb = source.get_aabb()
	result.set_meta("car_surface_source", D.mesh_key(source))
	assert(result.get_faces().size() == old.get_faces().size(), "Glass triangle counts retained")
	return result

func migrate(group: Dictionary, surface_stage: bool) -> void:
	var registry: Dictionary = post if surface_stage else raw
	assert(registry.has(key(group)), "Every unaffected frame member remains exact")
	var before: Dictionary = registry[key(group)]
	var data: Dictionary = before.recipe.duplicate(true)
	data.context = group.code
	if surface_stage:
		for entry: Dictionary in group.entries:
			for changed: Dictionary in before.changed_rows:
				if changed.name != str(entry.part.name): continue
				var mesh: ArrayMesh = remap_glass(entry.part.mesh, changed.row)
				var file: String = "electric_front_door_" + D.mesh_key(mesh) + ".res"
				assert(ResourceSaver.save(mesh, WORK.path_join("staged").path_join(file), ResourceSaver.FLAG_COMPRESS) == OK)
				files[file] = "game/" + S.ROOT.trim_prefix("res://").path_join(file)
				S.meshes[S.ROOT.path_join(file)] = mesh
				data.parts[entry.code] = {"source": entry.source, "mesh": file, "result": D.mesh_key(mesh)}
	var module: GDScript = S if surface_stage else D
	module.recipes["electric_" + group.code] = data
	if group.code != before.context:
		var file: String = "electric_" + group.code + ".json"
		var staged: String = ("surface_" if surface_stage else "detail_") + file
		FileAccess.open(WORK.path_join("staged").path_join(staged), FileAccess.WRITE).store_string(JSON.stringify(data, "  "))
		files[staged] = "game/" + module.ROOT.trim_prefix("res://").path_join(file)
		migrations.append({"stage": "surface" if surface_stage else "detail", "before": before.context, "after": group.code, "retained_rows": data.parts.size(), "changed_rows": before.get("changed_rows", [])})
	if surface_stage: S.apply_group(group, D)
	else: D.apply_group(group)

func detail(group: Dictionary) -> void: migrate(group, false)
func surface(group: Dictionary) -> void: migrate(group, true)

func run() -> void:
	var registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUT.path_join("frame-registry.json")))
	raw = registry.raw
	post = registry.post
	preload("res://vehicle/modular_car_base.gd").enabled = false
	preload("res://vehicle/modular_car_kits.gd").enabled = false
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	D.offline = detail
	S.offline = surface
	for editable: bool in [false, true]:
		var car := CarVisual.new()
		car.vehicle_id = "electric"
		car.editable_kits = editable
		car.cache_rest_pose = false
		root.add_child(car)
		while not car.model_ready: await process_frame
		car.free()
		await process_frame
	FileAccess.open(OUT.path_join("recipes-staged.json"), FileAccess.WRITE).store_string(JSON.stringify({"files": files, "migrations": migrations}, "  "))
	print("VFD_MIGRATION ", files.size(), " exact frame recipes")
	quit()
