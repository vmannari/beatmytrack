extends SceneTree
## Check the actual windscreen and door meshes in both detail levels.
const M = preload("res://vehicle/electric_reference_mesh.gd")
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func uv_point(mesh: MeshInstance3D, wanted: Vector2) -> Vector3:
	var arrays: Array = mesh.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var best := INF
	var result := Vector3.INF
	for i: int in verts.size():
		var d: float = uvs[i].distance_squared_to(wanted)
		if d < best:
			best = d
			result = mesh.transform * verts[i]
	return result

func side_x(mesh: MeshInstance3D, side: float, z: float, y: float) -> float:
	var vertices: PackedVector3Array = mesh.mesh.get_faces()
	var start := Vector3(side*1.7,y,z)
	var finish := Vector3(0,y,z)
	var best := -INF
	for i: int in range(0,vertices.size(),3):
		var a: Vector3 = mesh.transform * vertices[i]
		var b: Vector3 = mesh.transform * vertices[i+1]
		var c: Vector3 = mesh.transform * vertices[i+2]
		if y < minf(a.y,minf(b.y,c.y))-0.00001 or y > maxf(a.y,maxf(b.y,c.y))+0.00001: continue
		if z < minf(a.z,minf(b.z,c.z))-0.00001 or z > maxf(a.z,maxf(b.z,c.z))+0.00001: continue
		var hit: Variant = Geometry3D.segment_intersects_triangle(start,finish,a,b,c)
		if hit != null: best = maxf(best,side*(hit as Vector3).x)
	return best

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
		var label := " simple="+str(simple)
		var glass: MeshInstance3D = car.body.get_node("ReferenceCanopyGlass")
		var upper: Vector3 = uv_point(glass,Vector2(0.5,0.75))
		var foot: Vector3 = uv_point(glass,Vector2(0.5,0.0))
		print("VOLT_LOWER_FRONT ",label," windscreen_upper=",upper," foot=",foot)
		check(upper.y < 1.17,"forward windscreen is noticeably lower"+label)
		check(foot.y > 0.95 and foot.y < 0.985,"marked window line and cowl remain in place"+label)
		for side: float in [-1.0,1.0]:
			var panel: MeshInstance3D = car.body.get_node("ReferenceSide"+str(side).replace(".","_"))
			for z: float in [-0.55,0.0,0.55]:
				var lo: float = side_x(panel,side,z,0.36)
				var hi: float = side_x(panel,side,z,0.88)
				var mid: float = side_x(panel,side,z,0.55)
				var outward: float = mid-lerpf(lo,hi,(0.55-0.36)/0.52)
				print("VOLT_ROUND_SIDE ",label," side=",side," z=",z," outward=",outward)
				check(is_finite(outward) and outward > 0.005,"door is rounded outward "+str(side)+" z="+str(z)+label)
		car.free()
	print("VOLT_LOWER_FRONT_ROUND_SIDES: ",checks," checks, ",failures," failures prepared=",M.use_baked)
	quit(1 if failures else 0)
