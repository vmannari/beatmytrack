extends "res://tests/test_racing_car_models.gd"
## Frozen component profile. No race/account/records adapters; repetitions retained.
func sample(car: CarVisual, seconds: float) -> Dictionary:
	car.show()
	await settle()
	var gpu: Array[float] = []
	var cpu: Array[float] = []
	var draws: Array[float] = []
	var triangles: Array[float] = []
	var started: int = Time.get_ticks_usec()
	while Time.get_ticks_usec()-started < seconds*1000000:
		await process_frame
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		triangles.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	gpu.sort(); cpu.sort(); draws.sort(); triangles.sort()
	car.hide()
	return {"gpu_ms":gpu[gpu.size()/2],"render_cpu_ms":cpu[cpu.size()/2],"draws":draws[draws.size()/2],"primitives":triangles[triangles.size()/2],"samples":gpu.size()}
func _run() -> void:
	root.size = Vector2i(1600,900)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var world := Node3D.new()
	root.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50,-25,0)
	light.shadow_enabled = true
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	light.directional_shadow_max_distance = 65
	world.add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_energy = 0.5
	world.add_child(environment)
	VisualGeometry.box(world,Vector3(30,0.1,30),Vector3(0,-0.1,0),VisualGeometry.material(Color("a7a79d")))
	camera = Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 8
	camera.position = Vector3(-5,7,-9)
	camera.look_at(Vector3.ZERO)
	var cars: Array[CarVisual] = []
	var builds: Array[float] = []
	for variant: int in range(3):
		var started: int = Time.get_ticks_usec()
		var car := CarVisual.new()
		car.batch_parts = variant != 0
		car.simple_model = variant == 2
		world.add_child(car)
		if variant == 0: legacy_batches(car)
		builds.append((Time.get_ticks_usec()-started)/1000.0)
		car.hide()
		cars.append(car)
	var stages: Array[Dictionary] = []
	for repetition: int in range(3):
		for variant: int in ([0,1,2] if repetition%2 == 0 else [2,1,0]):
			var value: Dictionary = await sample(cars[variant],0.5)
			value.variant = ["old","batched","simple"][variant]
			value.repetition = repetition
			stages.append(value)
			print("RACING_MODEL_PROFILE ",value)
	var folder: String = "res://../build/racing-car-models-2026-10-13"
	FileAccess.open(folder.path_join("profile-"+RenderingServer.get_current_rendering_method()+".json"),FileAccess.WRITE).store_string(JSON.stringify({"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"resolution":[1600,900],"build_ms":builds,"note":"Frozen car+ground component, no phone/FPS prediction; per-instance first construction includes different cache warmth.","stages":stages},"\t"))
	world.queue_free()
	await process_frame
	quit()
