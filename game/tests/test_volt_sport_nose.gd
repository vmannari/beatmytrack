extends SceneTree
## Reject the previously reported projecting upper fascia and tight corners.
## All measurements use actual full/simple mesh buffers before body scaling.
const M = preload("res://vehicle/electric_reference_mesh.gd")
var checks: int=0
var failures: int=0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		print("FAIL: ",label)
func _initialize() -> void: run.call_deferred()
func point(mesh: MeshInstance3D, wanted: Vector2) -> Vector3:
	var a: Array=mesh.mesh.surface_get_arrays(0)
	var positions: PackedVector3Array=a[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array=a[Mesh.ARRAY_TEX_UV]
	var best: float=INF
	var result:=Vector3.INF
	for i: int in positions.size():
		var d: float=uvs[i].distance_squared_to(wanted)
		if d<best:
			best=d
			result=mesh.transform*positions[i]
	return result
func radius(a: Vector3,b: Vector3,c: Vector3) -> float:
	var x:=Vector2(a.x,a.z)
	var y:=Vector2(b.x,b.z)
	var z:=Vector2(c.x,c.z)
	var cross: float=absf((y-x).cross(z-x))
	return x.distance_to(y)*y.distance_to(z)*z.distance_to(x)/(2.0*cross) if cross>1e-10 else INF
func run() -> void:
	preload("res://ui/garage_car_cache.gd").enabled=false
	preload("res://vehicle/prepared_car_cache.gd").enabled=false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--baseline-source="):
			var code: String=FileAccess.get_file_as_string(arg.trim_prefix("--baseline-source="))
			assert(not code.is_empty())
			var script: GDScript=load("res://vehicle/electric_reference_body.gd")
			script.source_code=code
			assert(script.reload()==OK)
	M.use_baked="--prepared" in OS.get_cmdline_user_args()
	M.meshes.clear()
	for simple: bool in [false,true]:
		var car:=CarVisual.new()
		car.vehicle_id="electric"
		car.simple_model=simple
		car.batch_parts=false
		car.cache_rest_pose=false
		root.add_child(car)
		while not car.model_ready: await process_frame
		var hood: MeshInstance3D=car.body.get_node("ReferenceHood")
		var fascia: MeshInstance3D=car.body.get_node("ReferenceFrontUpper")
		var nose: Vector3=point(hood,Vector2(0.5,0))
		var upper: Vector3=point(fascia,Vector2(0.5,0.7))
		var mid: Vector3=point(fascia,Vector2(0.5,0.5))
		var bottom: Vector3=point(fascia,Vector2(0.5,0))
		var side0: Vector3=point(fascia,Vector2(0.0,0.75))
		var side1: Vector3=point(fascia,Vector2(0.025,0.75))
		var side2: Vector3=point(fascia,Vector2(0.05,0.75))
		var side_radius: float=radius(side0,side1,side2)
		var other_radius: float=radius(point(fascia,Vector2(1.0,0.75)),point(fascia,Vector2(0.975,0.75)),point(fascia,Vector2(0.95,0.75)))
		var projection: float=nose.z-upper.z
		print("SPORT_NOSE_METRICS ",JSON.stringify({"simple":simple,"prepared":M.use_baked,"hood_z":nose.z,"upper_z":upper.z,"upper_y_drop":nose.y-upper.y,"upper_projection":projection,"mid_projection":nose.z-mid.z,"bottom_projection":nose.z-bottom.z,"corner_radius_left":side_radius,"corner_radius_right":other_radius}))
		var label: String=" simple="+str(simple)
		check(projection<=0.060,"upper fascia does not project like a bill"+label)
		check(is_finite(side_radius) and side_radius>=0.100,"left nose corner has a broad geometric radius"+label)
		check(is_finite(other_radius) and other_radius>=0.100,"right nose corner has a broad geometric radius"+label)
		check(absf(side_radius-other_radius)<0.005,"nose corner geometry is symmetric"+label)
		car.free()
	print("VOLT_SPORT_NOSE: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
