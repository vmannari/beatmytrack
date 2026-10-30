extends SceneTree
## Measure the actual prepared hood, including the old dome control.
const OLD: String="res://assets/vehicles/electric_reference_v3"
var checks: int=0
var failures: int=0
var metrics: Dictionary={}
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;print("FAIL: ",label)
func at(mesh: ArrayMesh,point: Vector2) -> Vector3:
	var arrays: Array=mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
	var nearest: float=INF
	var result:=Vector3.ZERO
	for i: int in range(vertices.size()):
		var distance: float=uv[i].distance_squared_to(point)
		if distance<nearest: nearest=distance;result=vertices[i]
	return result
func shape(mesh: ArrayMesh) -> Dictionary:
	var arrays: Array=mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
	var points: Array[Vector3]=[]
	for i: int in range(vertices.size()):
		if absf(uv[i].x-0.5)<0.000001: points.append(vertices[i])
	points.sort_custom(func(a: Vector3,b: Vector3)->bool:return a.z<b.z)
	var previous: float=INF
	var max_reversal: float=0
	var downhill: float=INF
	for i: int in range(1,points.size()):
		var step: Vector3=points[i]-points[i-1]
		if step.z<0.000001: continue
		var angle: float=rad_to_deg(atan2(step.y,step.z))
		downhill=minf(downhill,angle)
		max_reversal=maxf(max_reversal,angle-previous)
		previous=angle
	var rear: Vector3=at(mesh,Vector2(0.5,1))
	var front: Vector3=at(mesh,Vector2(0.5,0))
	var corners: float=(at(mesh,Vector2(0,0)).y+at(mesh,Vector2(1,0)).y)*0.5
	return {"maximum_hump_above_cowl_model_metres":mesh.get_aabb().end.y-rear.y,"front_centre_over_corners_model_metres":front.y-corners,"centre_minimum_forward_rise_degrees":downhill,"centre_grade_reversal_degrees":max_reversal,"cowl":rear}
func run() -> void:
	var old_manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OLD+"/manifest.json"))
	check(old_manifest.sources["electric_reference_body.gd"]==FileAccess.get_sha256("res://../docs/evidence/electric-hood-reference-correction-2026-10-29/task-base/game/vehicle/electric_reference_body.gd"),"control meshes match the exact task-start hood source")
	for simple: bool in [false,true]:
		var old_mesh: ArrayMesh
		for entry: Dictionary in old_manifest.meshes:
			if entry.part==("ReferenceHood_simple" if simple else "ReferenceHood"): old_mesh=load(OLD.path_join(entry.file))
		var car:=CarVisual.new()
		car.vehicle_id="electric"
		car.simple_model=simple
		car.batch_parts=false
		root.add_child(car)
		while not car.model_ready: await process_frame
		var hood: ArrayMesh=car.body.get_node("ReferenceHood").mesh
		var before: Dictionary=shape(old_mesh)
		var after: Dictionary=shape(hood)
		var label: String="simple" if simple else "full"
		check(after.maximum_hump_above_cowl_model_metres<0.002,"hood has no raised hump above its cowl "+label)
		check(before.maximum_hump_above_cowl_model_metres>after.maximum_hump_above_cowl_model_metres+0.005,"actual old hump is reduced "+label)
		check(absf(after.front_centre_over_corners_model_metres)<0.045,"front cross-section has a restrained crown "+label)
		check(absf(after.front_centre_over_corners_model_metres)<absf(before.front_centre_over_corners_model_metres)*0.65,"front dome is visibly flatter than the control "+label)
		check(after.centre_minimum_forward_rise_degrees>=-0.01,"centre falls monotonically from cowl to nose "+label)
		check(after.centre_grade_reversal_degrees<0.25,"centre profile is one convex fall without an S-shaped shelf "+label)
		check((after.cowl as Vector3).distance_to(before.cowl)<0.00001,"windshield foot position is retained "+label)
		metrics[label]={"before":before,"after":after}
		car.free()
	var output: String="res://../docs/evidence/electric-hood-reference-correction-2026-10-29/hood-measurements.json"
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t")+"\n")
	print("ELECTRIC_HOOD_REFERENCE: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
