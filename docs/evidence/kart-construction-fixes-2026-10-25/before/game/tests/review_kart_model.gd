extends SceneTree
## Read-only construction review: actual prepared geometry and native close-ups.
const EVIDENCE: String = "res://../docs/evidence/kart-construction-review-2026-10-25"
var output: String
var report: Dictionary = {"sources":{},"detail":{}}
var camera: Camera3D

func _initialize() -> void: run.call_deferred()

func parts(car: CarVisual, prefix: String) -> Array[MeshInstance3D]:
	var resources: Array[Mesh] = []
	for key: String in preload("res://vehicle/kart_geometry.gd").meshes:
		if key.get_slice("|",0).begins_with(prefix): resources.append(preload("res://vehicle/kart_geometry.gd").meshes[key])
	var result: Array[MeshInstance3D] = []
	for part: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		if part.mesh in resources: result.append(part)
	return result

func segment_distance(p: Vector3, a: Vector3, b: Vector3) -> float:
	var d: Vector3 = b-a
	return p.distance_to(a+d*clampf((p-a).dot(d)/maxf(d.length_squared(),1e-20),0,1))

func triangle_distance(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> float:
	var normal: Vector3 = (b-a).cross(c-a)
	var length_squared: float = normal.length_squared()
	if length_squared > 1e-20:
		var projected: Vector3 = p-normal*((p-a).dot(normal)/length_squared)
		if (b-a).cross(projected-a).dot(normal) >= -1e-14 and (c-b).cross(projected-b).dot(normal) >= -1e-14 and (a-c).cross(projected-c).dot(normal) >= -1e-14:
			return p.distance_to(projected)
	return minf(segment_distance(p,a,b),minf(segment_distance(p,b,c),segment_distance(p,c,a)))

func nearest(p: Vector3, faces: PackedVector3Array) -> float:
	var distance: float = INF
	for offset: int in range(0,faces.size(),3): distance = minf(distance,triangle_distance(p,faces[offset],faces[offset+1],faces[offset+2]))
	return distance

func body_faces(car: CarVisual, part: MeshInstance3D) -> PackedVector3Array:
	var faces: PackedVector3Array = part.mesh.get_faces()
	var transform: Transform3D = car.body.global_transform.affine_inverse()*part.global_transform
	for index: int in range(faces.size()): faces[index] = transform*faces[index]
	return faces

func inspect(car: CarVisual, simple: bool) -> Dictionary:
	var seat: MeshInstance3D = car.find_child("MouldedSeatBucket*",true,false)
	var seat_faces: PackedVector3Array = body_faces(car,seat)
	var stays: Array[Dictionary] = []
	for stay: MeshInstance3D in parts(car,"SeatStay"):
		var vertices: PackedVector3Array = stay.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var columns: int = 4 if simple else 8
		var first: int = vertices.size()-columns-1
		var closest: float = INF
		var center := Vector3.ZERO
		for index: int in range(first,first+columns):
			center += vertices[index]
			closest = minf(closest,nearest(vertices[index],seat_faces))
		stays.append({"tip":center/columns,"tip_rim_to_seat_gap_model_m":closest})
	var torso: MeshInstance3D = car.find_child("TailoredRaceSuit*",true,false)
	var torso_mesh: TriangleMesh = torso.mesh.generate_triangle_mesh()
	var inverse: Transform3D = torso.global_transform.affine_inverse()*car.body.global_transform
	var torso_faces: PackedVector3Array = body_faces(car,torso)
	var joins: Array[Dictionary] = []
	for prefix: String in ["UpperSleeveContinuous","ContinuousTrouserLeg"]:
		for part: MeshInstance3D in parts(car,prefix):
			var columns: int = 12 if simple else 24
			var vertices: PackedVector3Array = part.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var outside: int = 0
			var furthest: float = 0
			var worst := Vector3.ZERO
			for index: int in range(columns):
				var point: Vector3 = vertices[index]
				var side: float = signf(point.x)
				var origin := Vector3(side*0.8,point.y,point.z)
				var hit: Dictionary = torso_mesh.intersect_ray(inverse*origin,inverse.basis*Vector3(-side,0,0))
				if hit.is_empty() or absf(point.x) > absf(Vector3(hit.position).x)+0.0005:
					outside += 1
					var gap: float = nearest(point,torso_faces)
					if gap > furthest:
						furthest = gap
						worst = point
			joins.append({"part":str(part.name),"root_ring_samples":columns,"root_ring_samples_outside_torso":outside,"maximum_rim_to_torso_gap_model_m":furthest,"worst_rim_point":worst})
	return {"seat_stays":stays,"open_cloth_joins":joins}

func capture(label: String, position_model: Vector3, target_model: Vector3) -> void:
	if DisplayServer.get_name() == "headless": return
	camera.look_at_from_position(position_model*HandlingConfig.BODY_SCALE,target_model*HandlingConfig.BODY_SCALE)
	for tick: int in range(8): await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK)

func run() -> void:
	output = EVIDENCE.path_join(RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for file: String in ["kart_model.gd","kart_driver.gd","kart_helmet.gd","kart_geometry.gd"]: report.sources[file] = FileAccess.get_sha256("res://vehicle/"+file)
	root.size = Vector2i(1280,960)
	for simple: bool in [false,true]:
		var label: String = "simple" if simple else "full"
		var world := Node3D.new()
		root.add_child(world)
		var car := CarVisual.new()
		car.vehicle_id = "kart"
		car.simple_model = simple
		car.batch_parts = false
		world.add_child(car)
		report.detail[label] = inspect(car,simple)
		ShowroomStudio.build(world,car)
		camera = Camera3D.new()
		camera.fov = 34
		world.add_child(camera)
		camera.current = true
		await capture(label+"-seat-support",Vector3(-1.35,0.70,1.00),Vector3(-0.20,0.43,0.38))
		await capture(label+"-shoulder",Vector3(-0.60,1.15,1.30),Vector3(0.12,0.65,0.25))
		await capture(label+"-shoulder-front",Vector3(-0.80,1.15,-0.25),Vector3(-0.15,0.63,0.24))
		await capture(label+"-hip",Vector3(-1.25,0.36,0.14),Vector3(-0.10,0.33,-0.04))
		await capture(label+"-controls",Vector3(-0.85,0.85,-1.05),Vector3(0,0.40,-0.42))
		VisualGeometry.batch_static_parts(car)
		await capture(label+"-batched-seat-support",Vector3(-1.35,0.70,1.00),Vector3(-0.20,0.43,0.38))
		await capture(label+"-batched-shoulder",Vector3(-0.60,1.15,1.30),Vector3(0.12,0.65,0.25))
		await capture(label+"-batched-hip",Vector3(-1.25,0.36,0.14),Vector3(-0.10,0.33,-0.04))
		world.free()
	FileAccess.open(output.path_join("metrics.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("KART_CONSTRUCTION_REVIEW: ",JSON.stringify(report.detail))
	quit()
