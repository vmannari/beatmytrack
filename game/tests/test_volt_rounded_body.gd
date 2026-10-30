extends SceneTree
## Exercises the rounded body functions and their full/simple prepared meshes.
const BODY = preload("res://vehicle/electric_reference_body.gd")
const MESH = preload("res://vehicle/electric_reference_mesh.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)

func at_uv(mesh: ArrayMesh, target: Vector2) -> Vector3:
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var best: float = INF
	var result := Vector3(INF, INF, INF)
	for i: int in range(vertices.size()):
		var distance: float = uvs[i].distance_squared_to(target)
		if distance < best:
			best = distance
			result = vertices[i]
	return result if best < 0.00000001 else Vector3(INF, INF, INF)

func verify_mesh(mesh: ArrayMesh, sample: Callable, label: String) -> void:
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var maximum_error: float = 0.0
	var finite: bool = vertices.size() > 0 and vertices.size() == uvs.size() and vertices.size() == normals.size()
	if finite:
		for i: int in range(vertices.size()):
			if not vertices[i].is_finite() or not normals[i].is_finite() or not uvs[i].is_finite():
				finite = false
				break
			maximum_error = maxf(maximum_error, vertices[i].distance_to(sample.call(uvs[i].x, uvs[i].y)))
	check(finite, label + " has finite prepared vertices, normals and UVs")
	check(finite and maximum_error < 0.00001, label + " matches current procedural geometry; maximum error " + str(maximum_error))

func run() -> void:
	# Compare the marked longitudinal sections with their task-start curves.
	var z: float = -1.60
	var d: float = z + 0.90
	var old_curve: float = (0.97 - 0.035 * 1.35 - 0.790) / (1.35 * 1.35)
	var old_front: float = 0.97 + 0.035 * d - old_curve * d * d
	check(BODY.shoulder(z) > old_front + 0.03, "front shoulder has a visibly fuller longitudinal arc")
	check(BODY.hood_point(0.5, 0.0).y - BODY.shoulder(-2.30) > 0.09, "hood has a fuller transverse crown")
	check(BODY.shoulder(1.95) > 0.915, "rear deck shoulder has a fuller arc")
	check(BODY.rear_shoulder_round(2.01) > 0.06, "rear shoulder rolls into the side")
	var previous: float = BODY.hood_point(0.5, 0.0).y
	var monotonic: bool = true
	for i: int in range(1, 101):
		var height: float = BODY.hood_point(0.5, float(i) / 100.0).y
		if height + 0.000001 < previous:
			monotonic = false
		previous = height
	check(monotonic, "hood centre rises smoothly toward the cowl without a hump")
	for u: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
		check(BODY.hood_point(u, 0.0).distance_to(BODY.cap_point(false, u, 1.0)) < 0.00001, "procedural hood meets front cap " + str(u))
		check(BODY.deck_point(u, 1.0).distance_to(BODY.cap_point(true, u, 1.0)) < 0.00001, "procedural rear deck meets rear cap " + str(u))
	for simple: bool in [false, true]:
		var label: String = "simple" if simple else "full"
		var car := CarVisual.new()
		car.vehicle_id = "electric"
		car.simple_model = simple
		car.batch_parts = false
		root.add_child(car)
		while not car.model_ready:
			await process_frame
		var names: Array[String] = ["ReferenceHood", "ReferenceRearDeck", "ReferenceFrontUpper", "ReferenceRear"]
		var samples: Array[Callable] = [BODY.hood_point, BODY.deck_point, func(u: float, v: float) -> Vector3: return BODY.cap_point(false, u, lerpf(0.58, 1.0, v)), func(u: float, v: float) -> Vector3: return BODY.cap_point(true, u, v)]
		var meshes: Array[ArrayMesh] = []
		for i: int in range(names.size()):
			var key: String = names[i] + ("_simple" if simple else "")
			var path: String = MESH.ASSET_ROOT.path_join(key.sha256_text().left(24) + ".res")
			check(ResourceLoader.exists(path), label + " prepared asset exists for " + names[i])
			var node: MeshInstance3D = car.body.get_node_or_null(names[i])
			check(node != null and node.mesh is ArrayMesh, label + " contains " + names[i])
			if node == null or not node.mesh is ArrayMesh:
				car.free()
				quit(1)
				return
			var mesh: ArrayMesh = node.mesh
			check(MESH.use_baked and mesh == load(path), label + " uses the prepared asset for " + names[i])
			meshes.append(mesh)
			verify_mesh(mesh, samples[i], label + " " + names[i])
		for u: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
			check(at_uv(meshes[0], Vector2(u, 0)).distance_to(at_uv(meshes[2], Vector2(u, 1))) < 0.00001, label + " prepared hood/front seam " + str(u))
			check(at_uv(meshes[1], Vector2(u, 1)).distance_to(at_uv(meshes[3], Vector2(u, 1))) < 0.00001, label + " prepared deck/rear seam " + str(u))
		car.free()
	print("VOLT_ROUNDED_BODY: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
