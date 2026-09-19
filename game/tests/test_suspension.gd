extends SceneTree
## Presentation contract checks and optional staged in-engine evidence.
var failures: int = 0
var checks: int = 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var car := CarVisual.new()
	world.add_child(car)
	var state := VehicleState.new()
	car.present_suspension(state, 0.0)
	for i: int in range(1, 121):
		state.tick = i
		state.velocity = Vector2(0, i / 12.0)
		car.present_suspension(state, 0.0)
	check(car.suspension.y > 0.025, "acceleration lifts nose")
	for i: int in range(60):
		state.tick += 1
		state.velocity.y -= 0.12
		car.present_suspension(state, 0.0)
	check(car.suspension.y < -0.025, "deceleration dives nose")
	for i: int in range(60):
		state.tick += 1
		state.velocity.x += 0.12
		car.present_suspension(state, 0.0)
	check(car.suspension.z > 0.03, "rightward force rolls body outward")
	var snapshot: Array = state.snapshot()
	var pose: Vector3 = car.suspension
	for i: int in range(90): car.present_suspension(state, 0.0)
	check(car.suspension == pose, "paused and duplicate render snapshots freeze suspension")
	check(state.snapshot() == snapshot, "presentation does not mutate canonical state")
	for i: int in range(360):
		state.tick += 1
		car.present_suspension(state, 0.0)
	check(car.suspension.length() < 0.0001, "body settles after force stops")
	state.velocity = Vector2(0, 20)
	state.jump_height = 1.0
	state.jump_velocity = -6.0
	state.tick += 1
	car.present_suspension(state, 0.0)
	check(car.sparks.is_empty(), "airborne car emits no scrape sparks")
	state.jump_height = 0.0
	state.tick += 1
	car.present_suspension(state, 0.0)
	check(car.suspension_speed.x < -0.5 and car.spark_cursor == 8, "hard landing compresses suspension and emits sparks")
	state.tick += 1
	car.present_suspension(state, 0.25)
	check(car.spark_cursor == 8, "scrape cooldown prevents repeated bursts")
	state.tick = 0
	car.present_suspension(state, 0.0)
	check(car.suspension == Vector3.ZERO and not car.sparks[0].mesh.visible, "restart clears motion and particles")
	state.tick = 1
	car.present_suspension(state, 0.2, false)
	check(car.spark_cursor == 8, "submerged contact suppresses sparks")
	state.tick = 2
	car.present_suspension(state, 0.4)
	check(car.spark_cursor == 16, "severe dry bridge transition emits sparks")
	for i: int in range(120):
		state.tick += 1
		car.present_suspension(state, 0.4)
	check(not car.sparks[8].mesh.visible and car.spark_cursor == 16, "steady incline emits no sparks; particles expire")
	if "--capture" in OS.get_cmdline_user_args():
		root.size = Vector2i(1280,720)
		var ground := VisualGeometry.material(Color("55595a"))
		VisualGeometry.box(world, Vector3(40,0.1,40), Vector3(0,-0.1,0), ground)
		var light := DirectionalLight3D.new()
		world.add_child(light)
		light.rotation_degrees = Vector3(-50,-25,0)
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.position = Vector3(6,3,-6)
		camera.look_at(Vector3(0,0.5,0))
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 7
		for scenario: String in ["rest", "corner", "braking", "landing"]:
			state.tick = 0
			state.velocity = Vector2(0,20)
			car.present_suspension(state, 0.0)
			for i: int in range(60):
				state.tick += 1
				if scenario == "corner": state.velocity.x += 0.18
				if scenario == "braking": state.velocity.y -= 0.16
				car.present_suspension(state, 0.0)
			if scenario == "landing":
				state.jump_height = 0.1
				state.jump_velocity = -7.0
				state.tick += 1
				car.present_suspension(state, 0.0)
				state.jump_height = 0.0
				for i: int in range(8):
					state.tick += 1
					car.present_suspension(state, 0.0)
			await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png("res://../build/suspension-" + scenario + ".png") == OK, "capture " + scenario)
	world.queue_free()
	await process_frame
	print("SUSPENSION_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
