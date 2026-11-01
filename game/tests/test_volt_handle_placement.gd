extends SceneTree
## Check actual handle meshes against the trailing door seams on both sides.
const M = preload("res://vehicle/electric_reference_mesh.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", message)

func run() -> void:
	preload("res://ui/garage_car_cache.gd").enabled = false
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--baseline-source="):
			var source: String = FileAccess.get_file_as_string(argument.trim_prefix("--baseline-source="))
			assert(not source.is_empty())
			var details: GDScript = load("res://vehicle/electric_reference_details.gd")
			details.source_code = source
			assert(details.reload() == OK)
	M.use_baked = "--prepared" in OS.get_cmdline_user_args()
	M.meshes.clear()
	for simple: bool in [false, true]:
		var car := CarVisual.new()
		car.vehicle_id = "electric"
		car.simple_model = simple
		car.batch_parts = false
		car.cache_rest_pose = false
		root.add_child(car)
		while not car.model_ready: await process_frame
		var handles: Array[Node] = car.body.find_children("RefHandleOutline*", "MeshInstance3D", false, false)
		check(handles.size() == 4, "four distinct door handles, simple=" + str(simple))
		var centers: Dictionary = {}
		for handle: MeshInstance3D in handles:
			var box: AABB = handle.mesh.get_aabb()
			var center: Vector3 = handle.transform * box.get_center()
			var side: int = -1 if center.x < 0 else 1
			var rear: bool = center.z > 0
			var key: String = str(side) + ("-rear" if rear else "-front")
			centers[key] = center
			var seam_t: float = (0.96 - center.y) / 0.65
			var trailing_seam: float = (0.93 - 0.18 * seam_t) if rear else (0.02 + 0.03 * seam_t)
			var gap: float = trailing_seam - (box.position.z + box.size.z)
			check(gap >= 0.04 and gap <= 0.14, "handle sits just ahead of trailing seam " + key + " gap=" + str(gap))
			check(absf(center.y - 0.84) < 0.01, "handle is below the waist " + key)
			check(box.size.z > 0.14 and box.size.z < 0.20 and box.size.y < 0.05, "handle is a horizontal flush pull " + key)
		for position: String in ["front", "rear"]:
			var left: Vector3 = centers.get("-1-" + position, Vector3.INF)
			var right: Vector3 = centers.get("1-" + position, Vector3.INF)
			check(left.is_finite() and right.is_finite() and absf(left.y-right.y) < 0.0001 and absf(left.z-right.z) < 0.0001 and absf(left.x+right.x) < 0.0001, "mirrored " + position + " handles")
		car.free()
	print("VOLT_HANDLE_PLACEMENT: ", checks, " checks, ", failures, " failures; prepared=", M.use_baked)
	quit(1 if failures else 0)
