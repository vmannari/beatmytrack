extends SceneTree
var failures: int = 0
var checks: int = 0

func _initialize() -> void: call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func inspect(node: Node3D, transform: Transform3D = Transform3D.IDENTITY) -> Dictionary:
	transform *= node.transform
	var result: Dictionary = {"meshes":0,"triangles":0,"bounds":AABB(),"has_bounds":false}
	if node is MeshInstance3D:
		var instance := node as MeshInstance3D
		result.meshes = 1
		result.bounds = transform * instance.mesh.get_aabb()
		result.has_bounds = true
		for i: int in range(instance.mesh.get_surface_count()):
			var arrays: Array = instance.mesh.surface_get_arrays(i)
			result.triangles += (arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null and arrays[Mesh.ARRAY_INDEX].size() > 0 else arrays[Mesh.ARRAY_VERTEX].size()) / 3
	for child: Node in node.get_children():
		if not child is Node3D: continue
		var child_result: Dictionary = inspect(child,transform)
		result.meshes += child_result.meshes
		result.triangles += child_result.triangles
		if child_result.has_bounds:
			result.bounds = result.bounds.merge(child_result.bounds) if result.has_bounds else child_result.bounds
			result.has_bounds = true
	return result

func run() -> void:
	root.size = Vector2i(1280,720)
	var world := Node3D.new()
	root.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50,-25,0)
	world.add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("34434a")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_energy = 0.5
	world.add_child(environment)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10
	camera.position = Vector3(-5,7,-9)
	camera.look_at(Vector3.ZERO)
	for id: String in VehicleCatalog.IDS:
		var source := CarVisual.new()
		source.vehicle_id = id
		source.batch_parts = false
		world.add_child(source)
		var batched := CarVisual.new()
		batched.vehicle_id = id
		world.add_child(batched)
		var before: Dictionary = inspect(source)
		var after: Dictionary = inspect(batched)
		check(before.triangles == after.triangles,id+" keeps all model triangles")
		check(before.bounds.is_equal_approx(after.bounds),id+" retains model bounds")
		check(after.meshes < before.meshes*0.6,id+" substantially reduces mesh submissions")
		check(batched.rolling_wheels.size() == source.rolling_wheels.size(),id+" keeps independent rolling wheels")
		var state := VehicleState.new()
		state.steering = 0.4
		state.tick = 1
		batched.present(Vector2.ZERO,0,state,DriveFrame.sample(0,0,1))
		check(batched.brake_material.albedo_color == Color("f17158"),id+" shared brake material still responds")
		print("VEHICLE_BATCH ",id," meshes=",before.meshes," -> ",after.meshes," triangles=",after.triangles)
		source.position.x = -2.3
		batched.position.x = 2.3
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://../docs/evidence/mobile-followup/batch-"+id+".png") == OK,"comparison capture saved")
		source.queue_free()
		batched.queue_free()
		await process_frame
	print("VEHICLE_BATCH_TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
