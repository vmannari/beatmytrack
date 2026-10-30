extends SceneTree
## Actual mesh fit: compact chin, open seat cavity and no cloth/seat crossings.
var checks: int = 0
var failures: int = 0
var output: String = "res://../docs/evidence/kart-driver-fit-2026-10-25/fit"
var measurements: Dictionary = {}

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-root="): output = arg.trim_prefix("--evidence-root=")
	if "--unbaked" in OS.get_cmdline_user_args(): preload("res://vehicle/kart_geometry.gd").use_baked = false
	if "--old-source" in OS.get_cmdline_user_args():
		# Reload the exact task-start sources in this disposable process only.
		preload("res://vehicle/kart_geometry.gd").use_baked = false
		for file: String in ["kart_helmet.gd","kart_model.gd"]:
			var script: GDScript = load("res://vehicle/"+file)
			script.source_code = FileAccess.get_file_as_string("res://../docs/evidence/kart-driver-fit-2026-10-25/before/game/vehicle/"+file)
			check(script.reload() == OK,"task-start source reloaded in isolated process "+file)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for simple: bool in [false,true]:
		var car := CarVisual.new()
		car.vehicle_id = "kart"
		car.simple_model = simple
		car.batch_parts = false
		root.add_child(car)
		var label: String = "simple" if simple else "full"
		var seat: MeshInstance3D = car.find_child("MouldedSeatBucket*",true,false)
		var shell: TriangleMesh = seat.mesh.generate_triangle_mesh()
		var helmet: MeshInstance3D = car.find_child("HelmetReferenceShell",true,false)
		var helmet_mesh: TriangleMesh = helmet.mesh.generate_triangle_mesh()
		var chin: Dictionary = helmet_mesh.intersect_ray(Vector3(0,0.815,-0.5),Vector3.BACK)
		check(not chin.is_empty() and chin.position.z >= 0.008 and chin.position.z < 0.04,label+" chin is short and close to the visor")
		var lowest: float = INF
		for point: Vector3 in helmet.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]: lowest = minf(lowest,point.y)
		check(lowest >= 0.760,label+" chin lower edge is lifted away from the chest")
		# Rays start inside the occupied volume. A real bucket has no seat material
		# above the lap, ahead of the chest, or through the driver's hip centre.
		for origin: Vector3 in [Vector3(0,0.35,-0.04),Vector3(0.10,0.35,-0.04),Vector3(-0.10,0.35,-0.04)]:
			check(shell.intersect_ray(origin,Vector3.UP).is_empty(),label+" open cavity above hips "+str(origin.x))
			check(shell.intersect_ray(origin,Vector3.FORWARD).is_empty(),label+" open cavity ahead of hips "+str(origin.x))
		var pan: Dictionary = shell.intersect_ray(Vector3(0,0.35,-0.04),Vector3.DOWN)
		check(not pan.is_empty() and pan.position.y >= 0.24 and pan.position.y <= 0.28,label+" seat pan supports hips from below")
		var back: Dictionary = shell.intersect_ray(Vector3(0,0.54,0.22),Vector3.BACK)
		check(not back.is_empty() and back.position.z >= 0.34 and back.position.z <= 0.39,label+" backrest supports the torso from behind")
		var crossings: Dictionary = {}
		var edges_tested: int = 0
		for part: MeshInstance3D in car.body.find_children("*","MeshInstance3D",true,false):
			if not (str(part.name).begins_with("TailoredRaceSuit") or str(part.name).begins_with("DriverPelvis") or str(part.name).begins_with("ContinuousTrouserLeg") or str(part.name).begins_with("UpperSleeve") or str(part.name).begins_with("LowerSleeve")): continue
			var transform: Transform3D = seat.global_transform.affine_inverse()*part.global_transform
			var faces: PackedVector3Array = part.mesh.get_faces()
			for triangle: int in range(faces.size()/3):
				for edge: int in range(3):
					var a: Vector3 = transform*faces[triangle*3+edge]
					var b: Vector3 = transform*faces[triangle*3+(edge+1)%3]
					var length: float = a.distance_to(b)
					if length < 0.00001: continue
					edges_tested += 1
					var hit: Dictionary = shell.intersect_ray(a,(b-a)/length)
					if not hit.is_empty() and a.distance_to(hit.position) < length-0.00001:
						crossings[str(part.name)] = int(crossings.get(str(part.name),0))+1
		check(edges_tested > 5000,label+" actual cloth edges sampled against seat triangles")
		check(crossings.is_empty(),label+" no driver cloth crosses seat shell "+JSON.stringify(crossings))
		# Compare the actual support surfaces to the suit, rather than design constants.
		var torso: MeshInstance3D = car.find_child("TailoredRaceSuit*",true,false)
		var torso_mesh: TriangleMesh = torso.mesh.generate_triangle_mesh()
		var torso_transform: Transform3D = car.body.global_transform.affine_inverse()*torso.global_transform
		var inverse: Transform3D = torso_transform.affine_inverse()
		var cloth_back: Dictionary = torso_mesh.intersect_ray(inverse*Vector3(0,0.54,0.55),inverse.basis*Vector3.FORWARD)
		var back_gap: float = INF
		if not cloth_back.is_empty() and not back.is_empty(): back_gap = back.position.z-(torso_transform*Vector3(cloth_back.position)).z
		check(back_gap >= 0.004 and back_gap <= 0.035,label+" actual torso is supported close to the backrest")
		var neck: MeshInstance3D = car.find_child("BalaclavaNeck",true,false)
		check(neck != null and neck.position.y+neck.mesh.get_aabb().end.y >= 0.85 and neck.position.y+neck.mesh.get_aabb().position.y <= 0.73,label+" neck connects collar to helmet lining")
		measurements[label] = {"chin_z":chin.get("position",Vector3.ZERO).z,"lowest_helmet_y":lowest,"seat_pan":pan.get("position"),"seat_back":back.get("position"),"torso_back_gap":back_gap,"cloth_edges":edges_tested,"seat_cloth_crossings":crossings}
		car.free()
	FileAccess.open(output+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"measurements":measurements},"\t"))
	print("KART_DRIVER_FIT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
