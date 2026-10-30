extends SceneTree
## Actual attachment, opaque lining and shared suit-boundary regressions.
var checks: int = 0
var failures: int = 0
var output: String = "res://../docs/evidence/kart-construction-fixes-2026-10-25/construction"
var measurements: Dictionary = {}

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func parts(car: CarVisual, prefix: String) -> Array[MeshInstance3D]:
	var resources: Array[Mesh] = []
	for key: String in preload("res://vehicle/kart_geometry.gd").meshes:
		if key.get_slice("|",0).begins_with(prefix): resources.append(preload("res://vehicle/kart_geometry.gd").meshes[key])
	var result: Array[MeshInstance3D] = []
	for part: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		if part.mesh in resources: result.append(part)
	return result

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-root="): output = arg.trim_prefix("--evidence-root=")
	if "--unbaked" in OS.get_cmdline_user_args(): preload("res://vehicle/kart_geometry.gd").use_baked = false
	if "--old-task-source" in OS.get_cmdline_user_args():
		preload("res://vehicle/kart_geometry.gd").use_baked = false
		for name: String in ["kart_driver.gd","kart_helmet.gd","kart_model.gd"]:
			var script: GDScript = load("res://vehicle/"+name)
			script.source_code = FileAccess.get_file_as_string("res://../docs/evidence/kart-construction-fixes-2026-10-25/before/game/vehicle/"+name)
			assert(script.reload() == OK)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for simple: bool in [false,true]:
		var car := CarVisual.new()
		car.vehicle_id = "kart"
		car.simple_model = simple
		car.batch_parts = false
		root.add_child(car)
		var label: String = "simple" if simple else "full"
		var seat: MeshInstance3D = car.find_child("MouldedSeatBucket*",true,false)
		var seat_mesh: TriangleMesh = seat.mesh.generate_triangle_mesh()
		check(parts(car,"SeatMountPad").size() == 2 and parts(car,"SeatStay").size() == 2,label+" two fitted seat attachment pads and stays")
		var gaps: Array[float] = []
		for stay: MeshInstance3D in parts(car,"SeatStay"):
			var vertices: PackedVector3Array = stay.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var columns: int = 4 if simple else 8
			var tip := Vector3.ZERO
			for index: int in range(vertices.size()-columns-1,vertices.size()-1): tip += vertices[index]/columns
			var hit: Dictionary = seat_mesh.intersect_ray(tip+Vector3.BACK*0.05,Vector3.FORWARD)
			var gap: float = absf(tip.z-Vector3(hit.position).z) if not hit.is_empty() else INF
			gaps.append(gap)
			check(gap <= 0.035,label+" actual stay end meets fitted bucket mount")
		var liner: MeshInstance3D = car.find_child("HelmetReferenceNeckLining",true,false)
		var neck: MeshInstance3D = car.find_child("BalaclavaNeck",true,false)
		var covered: int = 0
		for x: float in [-0.08,0.0,0.08]:
			for z: float in [0.12,0.20,0.32]:
				var closed: bool = false
				for part: MeshInstance3D in [liner,neck]:
					var transform: Transform3D = car.body.global_transform.affine_inverse()*part.global_transform
					var inverse: Transform3D = transform.affine_inverse()
					var hit: Dictionary = part.mesh.generate_triangle_mesh().intersect_ray(inverse*Vector3(x,0.65,z),inverse.basis*Vector3.UP)
					if not hit.is_empty() and (transform*Vector3(hit.position)).y <= 0.80: closed = true
				if closed: covered += 1
				check(closed,label+" opaque lower helmet backing "+str(Vector2(x,z)))
		var torso: MeshInstance3D = car.find_child("TailoredRaceSuit*",true,false)
		var torso_arrays: Array = torso.mesh.surface_get_arrays(0)
		var normal_map: Dictionary = {}
		for index: int in range(torso_arrays[Mesh.ARRAY_VERTEX].size()): normal_map[torso_arrays[Mesh.ARRAY_VERTEX][index].snapped(Vector3.ONE*0.00001)] = torso_arrays[Mesh.ARRAY_NORMAL][index]
		var cloth: Array[MeshInstance3D] = [torso]
		cloth.append_array(parts(car,"UpperSleeveContinuous"))
		cloth.append_array(parts(car,"ContinuousTrouserLeg"))
		var edges: Dictionary = {}
		var directions: Dictionary = {}
		var contributors: Dictionary = {}
		var matched: int = 0
		var maximum_angle: float = 0
		for part: MeshInstance3D in cloth:
			var faces: PackedVector3Array = part.mesh.get_faces()
			for face: int in range(0,faces.size(),3):
				for edge: int in range(3):
					var a: Vector3 = faces[face+edge].snapped(Vector3.ONE*0.00001)
					var b: Vector3 = faces[face+(edge+1)%3].snapped(Vector3.ONE*0.00001)
					if a == b: continue
					var key: String = str(a)+":"+str(b) if a < b else str(b)+":"+str(a)
					edges[key] = int(edges.get(key,0))+1
					directions[key] = int(directions.get(key,0))+(1 if a < b else -1)
					if not contributors.has(key): contributors[key] = []
					contributors[key].append(str(part.name))
			if part == torso: continue
			var arrays: Array = part.mesh.surface_get_arrays(0)
			for index: int in range(12 if simple else 24):
				var point: Vector3 = arrays[Mesh.ARRAY_VERTEX][index].snapped(Vector3.ONE*0.00001)
				if normal_map.has(point):
					matched += 1
					maximum_angle = maxf(maximum_angle,rad_to_deg(Vector3(normal_map[point]).angle_to(arrays[Mesh.ARRAY_NORMAL][index])))
		var open: int = 0
		var inconsistent: int = 0
		var inconsistent_examples: Array = []
		var inconsistent_by_part: Dictionary = {}
		for count: int in edges.values():
			if count != 2: open += 1
		for key: String in directions:
			if int(directions[key]) != 0:
				inconsistent += 1
				if inconsistent_examples.size() < 12: inconsistent_examples.append({"edge":key,"parts":contributors[key]})
				for name: String in contributors[key]: inconsistent_by_part[name] = int(inconsistent_by_part.get(name,0))+1
		check(open == 0,label+" complete suit has no open/unmatched triangle boundaries")
		check(inconsistent == 0,label+" joined cloth triangles have consistent outward winding")
		check(matched == (48 if simple else 96),label+" all limb roots share actual torso boundary positions")
		check(maximum_angle <= 2.0,label+" shared cloth joins retain smooth normals")
		measurements[label] = {"stay_gaps":gaps,"helmet_rays_covered":covered,"unmatched_suit_edges":open,"inconsistent_suit_edges":inconsistent,"inconsistent_examples":inconsistent_examples,"inconsistent_by_part":inconsistent_by_part,"matched_join_vertices":matched,"maximum_join_normal_degrees":maximum_angle}
		car.free()
	FileAccess.open(output+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"measurements":measurements},"\t"))
	print("KART_CONSTRUCTION: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
