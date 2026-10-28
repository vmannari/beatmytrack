extends SceneTree
## Read-only native modelling review: current geometry, close-ups and topology.
var output: String
var graphical: bool
var metrics: Dictionary = {}
var camera: Camera3D

func _initialize() -> void: run.call_deferred()

func topology(part: MeshInstance3D) -> Dictionary:
	var faces: PackedVector3Array = part.mesh.get_faces()
	var edges: Dictionary = {}
	var directions: Dictionary = {}
	var volume: float = 0.0
	var normal_disagreements: int = 0
	for surface: int in range(part.mesh.get_surface_count()):
		var arrays: Array = part.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count: int = indices.size() if not indices.is_empty() else vertices.size()
		for offset: int in range(0,count,3):
			var ids: Array[int] = []
			for k: int in range(3): ids.append(indices[offset+k] if not indices.is_empty() else offset+k)
			var cross: Vector3 = (vertices[ids[1]]-vertices[ids[0]]).cross(vertices[ids[2]]-vertices[ids[0]])
			if not normals.is_empty() and cross.dot(normals[ids[0]])>0.00000001: normal_disagreements += 1
	for index: int in range(0,faces.size(),3):
		volume += faces[index].dot(faces[index+1].cross(faces[index+2]))/6.0
		for edge: int in range(3):
			var a: String = str(faces[index+edge].snapped(Vector3.ONE*0.000001))
			var b: String = str(faces[index+(edge+1)%3].snapped(Vector3.ONE*0.000001))
			var key: String = a+"/"+b if a<b else b+"/"+a
			edges[key] = int(edges.get(key,0))+1
			directions[key] = int(directions.get(key,0))+(1 if a<b else -1)
	var boundary: int = 0
	var inconsistent: int = 0
	for key: String in edges:
		if edges[key] != 2: boundary += 1
		if directions[key] != 0: inconsistent += 1
	return {"triangles":faces.size()/3,"boundary_edges":boundary,"inconsistent_edges":inconsistent,"normal_disagreements":normal_disagreements,"signed_volume":volume}

func capture(label: String, position_model: Vector3, target_model: Vector3) -> void:
	if not graphical: return
	camera.look_at_from_position(position_model*HandlingConfig.BODY_SCALE,target_model*HandlingConfig.BODY_SCALE)
	for tick: int in range(8): await process_frame
	await RenderingServer.frame_post_draw
	var pixels: Image = root.get_texture().get_image()
	var result: Error = pixels.save_png(output.path_join(label+".png"))
	if result != OK: push_error("Capture failed: "+label)

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	graphical = DisplayServer.get_name() != "headless"
	output = ProjectSettings.globalize_path("res://../docs/evidence/forklift-review-2026-10-25").path_join(RenderingServer.get_current_rendering_method() if graphical else "headless")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,960)
	var world := Node3D.new()
	root.add_child(world)
	var car := CarVisual.new()
	car.vehicle_id = "forklift"
	car.batch_parts = false
	world.add_child(car)
	var value: Dictionary = VehicleLivery.defaults("forklift")
	value.stickers.hood.id = "crest"
	value.stickers.hood.size = 0.95
	car.apply_livery(value)
	for simple: bool in [false,true]:
		var probe: CarVisual = car
		if simple:
			probe = CarVisual.new()
			probe.vehicle_id = "forklift"; probe.batch_parts = false; probe.simple_model = true
			world.add_child(probe)
		var parts: Dictionary = {}
		for pattern: String in ["ForgedFork*","FormedSideSkin*","RolledWheelArch*"]:
			for part: MeshInstance3D in probe.find_children(pattern,"MeshInstance3D",true,false): parts[part.name] = topology(part)
		metrics["simple_parts" if simple else "detailed_parts"] = parts
		if simple: probe.free()
	# Find the actual steering assembly by its configured mount and inspect its ring.
	for node: Node in car.body.get_children():
		if node is Node3D and node.position.is_equal_approx(Vector3(-0.16,1.61,-0.40)):
			for mesh: MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):
				if mesh.mesh is ImmediateMesh:
					metrics.steering_ring = {"geometry":topology(mesh),"local_bounds":str(mesh.mesh.get_aabb()),"material_cull_mode":(mesh.get_active_material(0) as BaseMaterial3D).cull_mode}
	# Locate the terminal segment of the actual upper exhaust.
	var exhaust_end := Vector3(0.59,2.12,1.02)
	var exhaust_start := Vector3(0.62,2.03,0.98)
	for node: Node in car.body.get_children():
		if node is MeshInstance3D and node.position.is_equal_approx((exhaust_start+exhaust_end)*0.5):
			var cylinder: CylinderMesh = node.mesh
			metrics.exhaust_outlet = {"cap_top":cylinder.cap_top,"cap_bottom":cylinder.cap_bottom,"radius_model_m":cylinder.top_radius}
	metrics.chain_link_gap_detailed_model_m = 1.75/26.0-0.030
	metrics.chain_link_gap_simple_model_m = 1.75/10.0-0.030
	if graphical:
		ShowroomStudio.build(world,car)
		camera = Camera3D.new()
		world.add_child(camera)
		camera.current = true
		camera.fov = 35
		await capture("front-overview",Vector3(-5.4,3.6,-6.4),Vector3(0,1.25,-0.38))
		await capture("rear-overview",Vector3(-4.7,3.2,5.2),Vector3(0,1.22,0.15))
		await capture("mast-front",Vector3(-1.7,1.95,-4.2),Vector3(0,1.65,-1.35))
		await capture("cockpit-top",Vector3(-1.6,3.4,1.5),Vector3(-0.05,1.45,-0.23))
		await capture("cockpit-low",Vector3(-1.9,1.33,-0.05),Vector3(-0.16,1.61,-0.40))
		await capture("exhaust-outlet",Vector3(1.25,2.74,1.85),Vector3(0.61,1.99,1.0))
		await capture("fork-underside",Vector3(-1.6,0.38,-3.4),Vector3(0,0.89,-2.05))
		await capture("fork-side",Vector3(-2.8,1.0,-2.1),Vector3(-0.43,0.98,-1.95))
		var state := VehicleState.new()
		state.steering = 1.0
		car.present(Vector2.ZERO,0.0,state,DriveFrame.new())
		await capture("rear-full-steering",Vector3(-3.8,1.5,4.0),Vector3(0,0.71,0.8))
		# The production merger preserves these surfaces; retain actual batched views.
		VisualGeometry.batch_static_parts(car)
		await capture("batched-fork-side",Vector3(-2.8,1.0,-2.1),Vector3(-0.43,0.98,-1.95))
		await capture("batched-cockpit-low",Vector3(-1.9,1.33,-0.05),Vector3(-0.16,1.61,-0.40))
		await capture("batched-mast-front",Vector3(-1.7,1.95,-4.2),Vector3(0,1.65,-1.35))
		await capture("batched-exhaust-outlet",Vector3(1.25,2.74,1.85),Vector3(0.61,1.99,1.0))
	var report := FileAccess.open(output.path_join("metrics.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify(metrics,"\t"))
	report.close()
	print("FORKLIFT_MODEL_REVIEW ",JSON.stringify(metrics))
	world.free()
	quit()
