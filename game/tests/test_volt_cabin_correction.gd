extends SceneTree
## Independent checks on prepared waist vertices and joined visual door perimeters.
var output: String="res://../docs/evidence/volt-straight-shoulder-2026-10-28/cabin"
var checks: int=0
var failures: int=0
var metrics: Dictionary={}
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;print("FAIL: ",label)
func mesh_part(car: CarVisual,label: String) -> MeshInstance3D:
	return car.body.get_node_or_null(label.validate_node_name()) as MeshInstance3D
func edge(mesh: MeshInstance3D,top_edge: bool) -> Array[Vector3]:
	var points: Array[Vector3]=[]
	var arrays: Array=mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
	for i: int in range(vertices.size()):
		if absf(uv[i].y-(1.0 if top_edge else 0.0))<0.000001 and vertices[i].z>=0.10: points.append(vertices[i])
	points.sort_custom(func(a: Vector3,b: Vector3)->bool:return a.z<b.z)
	return points
func deviation(points: Array[Vector3]) -> float:
	if points.size()<8: return INF
	var direction: Vector3=(points[-1]-points[0]).normalized()
	var maximum: float=0
	for point: Vector3 in points: maximum=maxf(maximum,(point-points[0]).cross(direction).length())
	return maximum
func endpoint(mesh: MeshInstance3D,end: float) -> Vector3:
	var arrays: Array=mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
	var point:=Vector3.ZERO
	var count: int=0
	for i: int in range(vertices.size()):
		if absf(uv[i].x-end)<0.000001: point+=vertices[i];count+=1
	return point/maxi(1,count)
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-root="): output=arg.trim_prefix("--evidence-root=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for simple: bool in [false,true]:
		var car:=CarVisual.new()
		car.vehicle_id="electric"
		car.simple_model=simple
		car.batch_parts=false
		root.add_child(car)
		while not car.model_ready: await process_frame
		var label: String="simple" if simple else "full"
		for side: float in [-1.0,1.0]:
			var side_glass: MeshInstance3D=mesh_part(car,"SideGlazing"+str(side))
			var last_pillar: MeshInstance3D=mesh_part(car,"DoorPillarCut"+str(side)+"2")
			check(side_glass.mesh.get_aabb().end.z<=last_pillar.mesh.get_aabb().end.z+0.002,"no fixed quarter window behind the rear door "+label+str(side))
			for part: String in ["SideGlazing","SculptedSide"]:
				var points: Array[Vector3]=edge(mesh_part(car,part+str(side)),part=="SculptedSide")
				var error: float=deviation(points)
				check(error<0.000002,"actual straight rear waist "+label+part+str(side))
				metrics[label+part+str(side)]={"samples":points.size(),"maximum_line_deviation_model_metres":error}
			for front: bool in [true,false]:
				var left: int=0 if front else 1
				var right: int=1 if front else 2
				var roof: MeshInstance3D=mesh_part(car,"DoorRoofCut"+str(side)+str(front))
				var a: MeshInstance3D=mesh_part(car,"DoorPillarCut"+str(side)+str(left))
				var b: MeshInstance3D=mesh_part(car,"DoorPillarCut"+str(side)+str(right))
				check(roof!=null and a!=null and b!=null,"door perimeter includes its upper window frame "+label+str(side)+str(front))
				if roof==null or a==null or b==null: continue
				var lower_a: MeshInstance3D=mesh_part(car,"DoorCut"+str(side)+str(front)+"0")
				var lower_b: MeshInstance3D=mesh_part(car,"DoorCut"+str(side)+str(front)+"2")
				var lower_gap: float=maxf(endpoint(a,0).distance_to(endpoint(lower_a,0)),endpoint(b,0).distance_to(endpoint(lower_b,1)))
				var upper_gap: float=maxf(endpoint(a,1).distance_to(endpoint(roof,0)),endpoint(b,1).distance_to(endpoint(roof,1)))
				check(lower_gap<0.003,"body door seams meet the same window pillars "+label+str(side)+str(front))
				check(upper_gap<0.003,"door window frames close at the roof "+label+str(side)+str(front))
				metrics[label+"door"+str(side)+str(front)]={"lower_join_gap_model_metres":lower_gap,"roof_join_gap_model_metres":upper_gap}
		var glass: MeshInstance3D=car.body.get_node("RearScreen")
		var bounds: AABB=glass.mesh.get_aabb()
		check(bounds.position.z>1.08,"upper X-marked area is painted rather than glass "+label)
		check(bounds.end.z>1.75 and bounds.end.z<1.82,"rear glass lower edge reaches the marked deck position "+label)
		check(car.body.find_children("DoorCut*","MeshInstance3D",true,false).size()==12,"no closed rectangular door lid below the windows "+label)
		metrics[label+"rear_glass"]={"front_z_model_metres":bounds.position.z,"rear_z_model_metres":bounds.end.z}
		var previous_root: String="res://assets/vehicles/electric_coachwork_v19"
		if not FileAccess.file_exists(previous_root+"/manifest.json"): previous_root="res://../docs/evidence/volt-straight-shoulder-2026-10-28/intermediate-v19-resources"
		var previous: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(previous_root+"/manifest.json"))
		for entry: Dictionary in previous.meshes:
			if entry.part!=("Windscreen_simple" if simple else "Windscreen"): continue
			var old: ArrayMesh=load(previous_root.path_join(str(entry.file)))
			var screen: MeshInstance3D=car.body.get_node("Windscreen")
			var current_bounds: AABB=screen.mesh.get_aabb()
			var front_move: float=(old.get_aabb().position.z-current_bounds.position.z)*HandlingConfig.BODY_SCALE
			var top_move: float=(old.get_aabb().end.z-current_bounds.end.z)*HandlingConfig.BODY_SCALE
			check(absf(front_move-0.20)<0.002,"windshield lower edge advances 20 cm "+label)
			check(absf(top_move-0.20)<0.002,"windshield upper edge advances 20 cm "+label)
			metrics[label+"windscreen_advance_world_metres"]={"lower_edge":front_move,"upper_edge":top_move}
		car.free()
	FileAccess.open(output.path_join("cabin.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t")+"\n")
	print("VOLT_CABIN: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
