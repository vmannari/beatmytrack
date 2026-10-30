extends SceneTree
## Compare prepared full/simple buffers against the owner's current v20 car.
const BASE: String="res://assets/vehicles/electric_coachwork_v20"
var output: String="res://../docs/evidence/volt-reference-refinement-2026-10-29/refinement"
var checks: int=0
var failures: int=0
var metrics: Dictionary={}
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;print("FAIL: ",label)
func at(mesh: ArrayMesh,u: float,v: float) -> Vector3:
	var arrays: Array=mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
	var best: float=INF
	var result:=Vector3.ZERO
	for i: int in range(vertices.size()):
		var distance: float=uv[i].distance_squared_to(Vector2(u,v))
		if distance<best: best=distance;result=vertices[i]
	return result
func line_error(mesh: ArrayMesh) -> float:
	var arrays: Array=mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
	var points: Array[Vector3]=[]
	for i: int in range(vertices.size()):
		if uv[i].y<0.000001 and vertices[i].z<0.072: points.append(vertices[i])
	points.sort_custom(func(a: Vector3,b: Vector3)->bool:return a.z<b.z)
	if points.size()<8: return INF
	var axis: Vector3=(points[-1]-points[0]).normalized()
	var maximum: float=0
	for point: Vector3 in points: maximum=maxf(maximum,(point-points[0]).cross(axis).length())
	return maximum
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-root="): output=arg.trim_prefix("--evidence-root=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(BASE+"/manifest.json"))
	var previous: Dictionary={}
	for entry: Dictionary in manifest.meshes: previous[entry.part]=load(BASE.path_join(entry.file))
	for simple: bool in [false,true]:
		var suffix: String="_simple" if simple else ""
		var label: String="simple" if simple else "full"
		var car:=CarVisual.new()
		car.vehicle_id="electric"
		car.simple_model=simple
		car.batch_parts=false
		root.add_child(car)
		while not car.model_ready: await process_frame
		var roof: ArrayMesh=car.body.get_node("CrownedRoof").mesh
		var roof_drop: float=(previous["CrownedRoof"+suffix].get_aabb().end.y-roof.get_aabb().end.y)*HandlingConfig.BODY_SCALE
		check(roof_drop>0.03 and roof_drop<0.05,"cabin lowered slightly by 3-5 cm "+label)
		var hood: ArrayMesh=car.body.get_node("ClamshellHood").mesh
		var old_hood: ArrayMesh=previous["ClamshellHood"+suffix]
		var front: Vector3=at(hood,0.5,0)
		var rear: Vector3=at(hood,0.5,1)
		var old_front: Vector3=at(old_hood,0.5,0)
		var old_rear: Vector3=at(old_hood,0.5,1)
		var pitch: float=rad_to_deg(atan2(rear.y-front.y,rear.z-front.z))
		var old_pitch: float=rad_to_deg(atan2(old_rear.y-old_front.y,old_rear.z-old_front.z))
		check(pitch<old_pitch*0.82 and pitch>5,"shallower hood with a continuous forward fall "+label)
		check((front.z-old_front.z)*HandlingConfig.BODY_SCALE>0.06 and (front.z-old_front.z)*HandlingConfig.BODY_SCALE<0.08,"shorter nose overhang "+label)
		check(front.y>old_front.y+0.04,"nose meets hood without the former deep droop "+label)
		var screen: ArrayMesh=car.body.get_node("Windscreen").mesh
		var old_screen: ArrayMesh=previous["Windscreen"+suffix]
		check(absf(screen.get_aabb().position.z-old_screen.get_aabb().position.z)<0.0001 and absf(screen.get_aabb().end.z-old_screen.get_aabb().end.z)<0.0001,"retains requested windshield forward position "+label)
		for side: float in [-1.0,1.0]:
			var glass: ArrayMesh=car.body.get_node(("SideGlazing"+str(side)).validate_node_name()).mesh
			var error: float=line_error(glass)
			check(error<0.0001,"front door window lower edge is straight "+label+str(side))
			var corner: Vector3=at(glass,0,1)
			check(absf(corner.z-screen.get_aabb().end.z)<0.04,"front window upper corner follows the windshield roof junction "+label+str(side))
			var old_glass: ArrayMesh=previous["SideGlazing"+str(side)+suffix]
			metrics[label+"_window_"+str(side)]={"sill_line_error_model_metres":error,"previous_sill_line_error_model_metres":line_error(old_glass),"leading_upper_corner":str(corner)}
		metrics[label]={"roof_drop_world_metres":roof_drop,"hood_pitch_degrees":pitch,"previous_hood_pitch_degrees":old_pitch,"nose_reduction_world_metres":(front.z-old_front.z)*HandlingConfig.BODY_SCALE}
		car.free()
	FileAccess.open(output.path_join("refinement.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t")+"\n")
	print("VOLT_REFERENCE: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
