extends SceneTree
## Actual hood-buffer profile and fit checks for the lower automotive nose.
const M = preload("res://vehicle/electric_reference_mesh.gd")
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func row(mesh: Mesh, u: float) -> Array[Dictionary]:
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var by_v: Dictionary = {}
	for i: int in range(vertices.size()):
		if absf(uvs[i].x-u) < 0.00001:
			by_v[uvs[i].y] = vertices[i]
	var result: Array[Dictionary] = []
	for v: float in by_v: result.append({"v":v,"point":by_v[v]})
	result.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.v < b.v)
	return result

func end_point(mesh: Mesh, u: float, v: float) -> Vector3:
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var best := INF
	var point := Vector3.ZERO
	for i: int in range(vertices.size()):
		var distance: float = uvs[i].distance_squared_to(Vector2(u,v))
		if distance < best:
			best = distance
			point = vertices[i]
	return point

func run() -> void:
	preload("res://ui/garage_car_cache.gd").enabled = false
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	M.use_baked = "--prepared" in OS.get_cmdline_user_args()
	M.meshes.clear()
	for simple: bool in [false,true]:
		var car := CarVisual.new()
		car.vehicle_id = "electric"
		car.simple_model = simple
		car.batch_parts = false
		car.cache_rest_pose = false
		root.add_child(car)
		while not car.model_ready: await process_frame
		var label: String = "simple="+str(simple)
		var hood: MeshInstance3D = car.body.get_node_or_null("ReferenceHood")
		var canopy: MeshInstance3D = car.body.get_node_or_null("ReferenceCanopyGlass")
		check(hood != null and canopy != null and car.front_wheels.size() == 2,"hood, windscreen and front wheels exist "+label)
		if hood == null or canopy == null or car.front_wheels.size() != 2:
			car.free()
			continue
		var center: Array[Dictionary] = row(hood.mesh,0.5)
		var max_upturn := 0.0
		for u: float in [0.25,0.5,0.75]:
			var stripe: Array[Dictionary] = row(hood.mesh,u)
			var upturn := 0.0
			for i: int in range(1,stripe.size()):
				var front: Vector3 = stripe[i-1].point
				var rear: Vector3 = stripe[i].point
				upturn = maxf(upturn,front.y-rear.y)
			max_upturn = maxf(max_upturn,upturn)
			check(stripe.size() >= 16 and upturn < 0.003,"hood falls without a forward upturn at u="+str(u)+" "+label)
		var hood_front: Vector3 = end_point(hood.mesh,0.5,0.0)
		var hood_rear: Vector3 = end_point(hood.mesh,0.5,1.0)
		var windshield_foot: Vector3 = end_point(canopy.mesh,0.5,0.0)
		var overhang: float = car.front_wheels[0].position.z-hood_front.z
		print("MODEL_S_HOOD ",label," center_front=",hood_front," cowl=",hood_rear," max_upturn=",max_upturn," wheel_to_nose=",overhang," windshield_gap=",hood_rear.distance_to(windshield_foot))
		check(center.size() >= 16,"hood centreline has sufficient samples "+label)
		check(hood_front.y < hood_rear.y-0.04,"hood descends from windscreen to front "+label)
		check(hood_rear.distance_to(windshield_foot) < 0.005,"hood meets windscreen "+label)
		check(overhang > 0.60 and overhang < 1.02,"front wheel and nose have a balanced overhang "+label)
		car.free()
	print("VOLT_MODEL_S_HOOD: ",checks," checks, ",failures," failures; prepared=",M.use_baked)
	quit(1 if failures else 0)
