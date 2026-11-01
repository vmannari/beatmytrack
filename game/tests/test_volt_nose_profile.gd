extends SceneTree
## Inspect the actual fascia/bonnet mesh, including the simplified race model.
const MeshBuilder = preload("res://vehicle/electric_reference_mesh.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",description)

func sample(node: MeshInstance3D, uv: Vector2) -> Vector3:
	var arrays: Array = node.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var nearest := INF
	var point := Vector3.INF
	for i: int in range(vertices.size()):
		var d: float = uvs[i].distance_squared_to(uv)
		if d < nearest:
			nearest = d
			point = node.transform * vertices[i]
	return point

func edge_points(node: MeshInstance3D, edge_v: float) -> Array[Vector3]:
	var arrays: Array = node.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var result: Array[Vector3] = []
	for i: int in range(vertices.size()):
		if absf(uvs[i].y-edge_v) < 0.00001:
			result.append(node.transform * vertices[i])
	return result

func max_boundary_gap(first: Array[Vector3], second: Array[Vector3]) -> float:
	var largest := 0.0
	for point: Vector3 in first:
		var closest := INF
		for other: Vector3 in second:
			closest = minf(closest,point.distance_to(other))
		largest = maxf(largest,closest)
	return largest if not first.is_empty() and not second.is_empty() else INF

func run() -> void:
	preload("res://ui/garage_car_cache.gd").enabled = false
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--baseline-source="):
			var source := FileAccess.get_file_as_string(arg.trim_prefix("--baseline-source="))
			assert(not source.is_empty())
			var body_script: GDScript = load("res://vehicle/electric_reference_body.gd")
			body_script.source_code = source
			assert(body_script.reload() == OK)
	MeshBuilder.use_baked = "--prepared" in OS.get_cmdline_user_args()
	MeshBuilder.meshes.clear()
	for simple: bool in [false,true]:
		var car := CarVisual.new()
		car.vehicle_id = "electric"
		car.simple_model = simple
		car.batch_parts = false
		car.cache_rest_pose = false
		root.add_child(car)
		while not car.model_ready: await process_frame
		var hood: MeshInstance3D = car.body.get_node_or_null("ReferenceHood")
		var front: MeshInstance3D = car.body.get_node_or_null("ReferenceFrontUpper")
		var label := " simple="+str(simple)
		check(hood != null and front != null,"actual hood and fascia exist"+label)
		if hood == null or front == null:
			car.free()
			continue
		var center: Vector3 = sample(hood,Vector2(0.5,0.0))
		var left: Vector3 = sample(hood,Vector2(0.0,0.0))
		var right: Vector3 = sample(hood,Vector2(1.0,0.0))
		var spread: float = maxf(left.z-center.z,right.z-center.z)
		var arrays: Array = front.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var forward := INF
		for i: int in range(vertices.size()):
			if absf(uvs[i].x-0.5) < 0.00001:
				forward = minf(forward,(front.transform*vertices[i]).z)
		var bottom: Vector3 = sample(front,Vector2(0.5,0.0))
		var retreat: float = bottom.z-forward
		var hood_edge: Array[Vector3] = edge_points(hood,0.0)
		var front_edge: Array[Vector3] = edge_points(front,1.0)
		var join: float = maxf(max_boundary_gap(hood_edge,front_edge),max_boundary_gap(front_edge,hood_edge))
		print("VOLT_NOSE_PROFILE ",label," center_to_corner=",spread," bottom_retreat=",retreat," hood_join=",join)
		# Broad guardrails reject the previous extreme bill while leaving room for
		# a rounded bumper. Visual evaluation still decides the final shape.
		check(spread <= 0.22,"nose center does not project more than 0.22 m ahead of corners"+label)
		check(retreat <= 0.10,"lower fascia remains within 0.10 m of its foremost point"+label)
		check(absf(left.z-right.z) < 0.0001,"bonnet nose remains symmetric"+label)
		check(join < 0.004,"bonnet and fascia share the actual front edge"+label)
		car.free()
	print("VOLT_NOSE_PROFILE: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
