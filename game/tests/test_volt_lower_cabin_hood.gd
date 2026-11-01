extends SceneTree
## Inspect actual hood and windscreen buffers, including prepared meshes.
const M = preload("res://vehicle/electric_reference_mesh.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func point_at(mesh: MeshInstance3D, wanted: Vector2) -> Vector3:
	var arrays: Array = mesh.mesh.surface_get_arrays(0)
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var best := INF
	var result := Vector3.INF
	for i: int in positions.size():
		var distance: float = uvs[i].distance_squared_to(wanted)
		if distance < best:
			best = distance
			result = mesh.transform * positions[i]
	return result

func run() -> void:
	preload("res://ui/garage_car_cache.gd").enabled = false
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--before-body=") or arg.begins_with("--before-cabin="):
			var body: bool = arg.begins_with("--before-body=")
			var source: String = FileAccess.get_file_as_string(arg.trim_prefix("--before-body=" if body else "--before-cabin="))
			assert(not source.is_empty())
			var script: GDScript = load("res://vehicle/electric_reference_body.gd" if body else "res://vehicle/electric_reference_cabin.gd")
			script.source_code = source
			assert(script.reload() == OK)
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
		var hood: MeshInstance3D = car.body.get_node("ReferenceHood")
		var glass: MeshInstance3D = car.body.get_node("ReferenceCanopyGlass")
		var points: Array[Vector3] = []
		for v: float in [0.0,0.25,0.5,0.75,1.0]:
			points.append(point_at(hood,Vector2(0.5,v)))
		var slopes: Array[float] = []
		for i: int in range(points.size()-1):
			slopes.append((points[i+1].y-points[i].y)/(points[i+1].z-points[i].z))
		var label := " simple="+str(simple)
		print("LOWER_CABIN_HOOD ",label," points=",points," slopes=",slopes)
		check(slopes.all(func(s: float)->bool:return s>0.0),"hood rises continuously from nose to cowl"+label)
		check(slopes[0]>slopes[1] and slopes[1]>slopes[2] and slopes[2]>slopes[3],"hood curve flattens continuously toward windscreen"+label)
		var foot: Vector3 = point_at(glass,Vector2(0.5,0.0))
		check(foot.distance_to(points[4])<0.005,"lower windscreen remains fitted to hood"+label)
		check(foot.y < 0.985 and foot.y > 0.95,"windscreen base is modestly lowered"+label)
		for side: String in ["-1_0","1_0"]:
			var belt: MeshInstance3D = car.body.get_node("ReferenceWindowBottom"+side)
			var low := INF
			var high := -INF
			for u: float in [0.1,0.3,0.5,0.7,0.85]:
				var y: float = point_at(belt,Vector2(u,0.0)).y
				low = minf(low,y)
				high = maxf(high,y)
			check(high-low < 0.002,"side window base follows the straight marked line "+side+label)
		car.free()
	print("VOLT_LOWER_CABIN_HOOD: ",checks," checks, ",failures," failures prepared=",M.use_baked)
	quit(1 if failures else 0)
