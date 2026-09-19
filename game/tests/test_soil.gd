extends SceneTree
var failures: int = 0
var checks: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var track := NativeTrack.new()
	track.cell_size = 10.0
	track.grid_width = 100
	track.grid_height = 100
	track.half_extent = Vector2(500,500)
	track.cells.resize(10000)
	track.deck_cells.resize(10000)
	track.deck_cells.fill(-1)
	track.route = PackedVector2Array([Vector2(0,-400),Vector2(0,400)])
	var config := HandlingConfig.new()
	for kind: int in [0,1,2]:
		track.cells.fill(kind)
		for side: float in [-1.0,1.0]:
			var sim := VehicleSimulation.new(config)
			var replay := VehicleSimulation.new(config)
			sim.state.velocity = Vector2(30*side,0)
			replay.state.velocity = sim.state.velocity
			sim.step(DriveFrame.new(),track)
			replay.step(DriveFrame.new(),track)
			check((sim.state.roll_ticks > 0) == (kind != 0), "only loose ground trips broadside slides")
			for i: int in range(VehicleSimulation.ROLL_DURATION_TICKS):
				sim.step(DriveFrame.new(),track)
				replay.step(DriveFrame.new(),track)
			check(sim.state.roll_ticks == 0, "always upright after bounded tumble")
			check(sim.state.snapshot() == replay.state.snapshot(), "roll replays exactly")
			check(sim.state.velocity.length() < 30, "roll never adds speed")
		var slow := VehicleSimulation.new(config)
		slow.state.velocity = Vector2(15,0)
		slow.step(DriveFrame.new(),track)
		check(slow.state.roll_ticks == 0,"slow slide stays upright")
		var straight := VehicleSimulation.new(config)
		straight.state.velocity = Vector2(0,30)
		for i: int in range(120): straight.step(DriveFrame.new(),track)
		check(straight.state.roll_ticks == 0,"fast straight travel stays upright")
		if kind == 2: check(straight.state.velocity.length() < 20,"dirt sheds over 10 m/s in one second coasting")
	# One, two and three revolutions from increasing lateral momentum.
	track.cells.fill(2)
	for side: float in [-1.0,1.0]:
		for speed: float in [30.0,46.0,60.0]:
			var multi := VehicleSimulation.new(config)
			var replay := VehicleSimulation.new(config)
			multi.state.velocity = Vector2(side*speed,0)
			replay.state.velocity = multi.state.velocity
			var input := DriveFrame.new()
			input.throttle = 255
			input.steer = 127
			var data: Array = JSON.parse_string(JSON.stringify(input.packed()))
			var decoded := DriveFrame.new()
			decoded.steer = data[0]; decoded.throttle = data[1]; decoded.brake = data[2]
			multi.step(input,track)
			replay.step(decoded,track)
			var ticks: int = 0
			var loses_speed: bool = true
			while multi.state.roll_ticks > 0 and ticks < 360:
				var previous_speed: float = multi.state.velocity.length()
				multi.step(input,track)
				replay.step(decoded,track)
				loses_speed = loses_speed and multi.state.velocity.length() <= previous_speed
				ticks += 1
			var expected: int = 72 if speed == 30.0 else (144 if speed == 46.0 else 216)
			check(ticks == expected and multi.state.roll_ticks == 0,"momentum produces one/two/three flips then upright recovery")
			check(loses_speed,"held throttle/steer cannot sustain or accelerate a tumble")
			check(multi.state.snapshot() == replay.state.snapshot(),"multi-flip JSON inputs replay exactly")
			check(multi.state.roll_cooldown == 240,"cooldown begins after final flip")
			multi.reset(Vector2.ZERO)
			check(multi.state.roll_ticks == 0 and multi.state.roll_cooldown == 0,"reset clears chained roll")
	for id: String in VehicleCatalog.IDS:
		var vehicle := VehicleSimulation.new(VehicleCatalog.config(id))
		vehicle.state.velocity = Vector2(vehicle.config.maximum_speed,0)
		vehicle.step(DriveFrame.new(),track)
		var ticks: int = 0
		while vehicle.state.roll_ticks > 0 and ticks < 720:
			vehicle.step(DriveFrame.new(),track)
			ticks += 1
		check(vehicle.state.roll_ticks == 0 and ticks > 0 and ticks % 72 == 0,id+" recovers upright at its own speed cap")
	# Crossing onto asphalt does not cancel existing tumble momentum.
	var crossing := VehicleSimulation.new(config)
	crossing.state.velocity = Vector2(46,0)
	crossing.step(DriveFrame.new(),track)
	track.cells.fill(0)
	for i: int in range(72): crossing.step(DriveFrame.new(),track)
	check(crossing.state.roll_ticks == 72,"existing tumble continues onto asphalt with enough momentum")
	# Real barrier contact removes the momentum before the continuation decision.
	track.cells.fill(2)
	for y: int in range(100):
		track.cells[y*100+52] = 4
		track.cells[y*100+47] = 4
	for side: float in [-1.0,1.0]:
		var blocked := VehicleSimulation.new(config)
		blocked.state.velocity = Vector2(side*46,0)
		blocked.step(DriveFrame.new(),track)
		for i: int in range(72): blocked.step(DriveFrame.new(),track)
		check(blocked.state.collision_count > 0 and blocked.state.roll_ticks == 0,"barrier contact prevents an unjustified additional flip")
	track.cells.fill(2)
	var world := Node3D.new()
	root.add_child(world)
	var probe := CarVisual.new()
	world.add_child(probe)
	track.cells.fill(2)
	for heading: float in [0.0, PI * 0.5, PI, -PI * 0.5]:
		for side: float in [-1.0, 1.0]:
			var sim := VehicleSimulation.new(config)
			sim.reset(Vector2.ZERO, heading)
			sim.state.velocity = sim.state.right() * side * 30.0
			sim.step(DriveFrame.new(), track)
			check(sim.state.roll_ticks == 72, "tumble lasts 0.6 seconds")
			for i: int in range(18): sim.step(DriveFrame.new(), track)
			probe.rotation = Vector3.ZERO
			probe.present(sim.state.position, heading, sim.state, DriveFrame.new())
			probe.present_roll(sim.state)
			check(probe.global_basis.y.dot(VisualGeometry.world(sim.state.velocity)) > 0.0, "roof tips toward lateral travel at every heading")
			for i: int in range(53): sim.step(DriveFrame.new(), track)
			check(sim.state.roll_ticks == 1, "roll remains active until final tick")
			sim.step(DriveFrame.new(), track)
			check(sim.state.roll_ticks == 0 and sim.state.roll_cooldown == 240, "upright at 0.6 s with two-second cooldown")
	var pose_state := VehicleState.new()
	pose_state.roll_direction = -1.0
	var supported: bool = true
	var centered: bool = true
	var snapshot: Array = pose_state.snapshot()
	for remaining: int in range(72, 0, -1):
		pose_state.roll_ticks = remaining
		snapshot = pose_state.snapshot()
		probe.rotation = Vector3.ZERO
		probe.present(Vector2.ZERO, 0.0, pose_state, DriveFrame.new())
		probe.present_roll(pose_state)
		var lowest: float = INF
		for point: Vector2 in CarVisual.ROLL_OUTLINE:
			lowest = minf(lowest, (probe.transform * Vector3(point.x,point.y,0)).y)
		supported = supported and lowest >= -0.001 and lowest <= 0.07
		centered = centered and absf((probe.transform * Vector3(0,0.70,0)).x) < 0.001
	check(supported, "whole tumble stays within 7 cm of supported ground contact")
	check(centered, "mass center stays over simulation path throughout roll")
	check(snapshot == pose_state.snapshot(), "roll presentation never mutates replay state")
	pose_state.roll_ticks = 36
	probe.rotation = Vector3.ZERO
	probe.present(Vector2.ZERO,0.0,pose_state,DriveFrame.new())
	probe.present_roll(pose_state,0.25)
	var early_angle: float = probe.rotation.z
	probe.rotation = Vector3.ZERO
	probe.present(Vector2.ZERO,0.0,pose_state,DriveFrame.new())
	probe.present_roll(pose_state,0.75)
	check(probe.rotation.z < early_angle, "render interpolation advances within a simulation tick")
	pose_state.tick = 0
	pose_state.roll_ticks = 72
	probe.present_suspension(pose_state,0.0)
	for i: int in range(1,73):
		pose_state.tick = i
		pose_state.roll_ticks = 72-i
		probe.present_suspension(pose_state,0.0)
	check(probe.suspension_speed.x < -0.5, "landing compresses body suspension")
	var landing: Vector3 = probe.suspension
	probe.present_suspension(pose_state,0.0)
	check(probe.suspension == landing, "paused landing does not repeat impulse")
	for i: int in range(120):
		pose_state.tick += 1
		probe.present_suspension(pose_state,0.0)
	check(probe.suspension.length() < 0.001, "landing settles promptly")
	probe.queue_free()
	var trails := SkidTrails.new()
	world.add_child(trails)
	var state := VehicleState.new()
	state.velocity = Vector2(0,10)
	state.tire_dirt = 1.0
	trails.sample(state,DriveFrame.new())
	state.position.y += 1.0
	trails.sample(state,DriveFrame.new())
	var strong: float = trails.mark_colors[0].a
	state.tire_dirt = 0.15
	state.position.y += 1.0
	trails.sample(state,DriveFrame.new())
	check(trails.cursor == 4,"straight dirty driving leaves paired marks")
	check(trails.mark_colors[2].a < strong,"cleaner tires deposit fainter marks")
	check(trails.instances.visible_instance_count == 4,"paired trails share one bounded instance batch")
	var mark_transform: Transform3D = trails.mark_transforms[0]
	check(is_equal_approx(mark_transform.basis.z.length(),1.04),"batched mark retains driven length and seam overlap")
	if DisplayServer.get_name() != "headless":
		var uploaded: Color = trails.instances.get_instance_color(2)
		var expected: Color = trails.mark_colors[2]
		check(absf(uploaded.a-expected.a) <= 1.0/255.0 and absf(uploaded.r-expected.r) <= 1.0/255.0 and absf(uploaded.g-expected.g) <= 1.0/255.0 and absf(uploaded.b-expected.b) <= 1.0/255.0,"GPU receives faded per-mark color within 8-bit storage precision")
		check(trails.instances.get_instance_transform(0).is_equal_approx(mark_transform),"GPU receives the bridge-aware mark pose")
	state.roll_ticks = VehicleSimulation.ROLL_DURATION_TICKS
	trails.sample(state,DriveFrame.new())
	check(not trails.active,"tumbling tires leave no ground tracks")
	if "--capture" in OS.get_cmdline_user_args():
		root.size = Vector2i(1280,720)
		VisualGeometry.box(world,Vector3(80,0.1,80),Vector3(0,-0.08,0),VisualGeometry.material(Color("53585a")))
		var light := DirectionalLight3D.new()
		light.shadow_enabled = true
		world.add_child(light)
		light.rotation_degrees = Vector3(-55,-25,0)
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.position = Vector3(12,22,18)
		camera.look_at(Vector3.ZERO)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 28
		trails.clear()
		state.roll_ticks = 0
		for i: int in range(90):
			state.position = Vector2(-3,-10+i*0.22)
			state.tire_dirt = 1.0-i/95.0
			trails.sample(state,DriveFrame.new())
		var car := CarVisual.new()
		world.add_child(car)
		car.present(state.position,0,state,DriveFrame.new())
		for pose: String in ["dirty-trails","roll-right","roll-left","rollover"]:
			car.rotation = Vector3.ZERO
			car.present(state.position,0,state,DriveFrame.new())
			if pose in ["roll-right","roll-left"]:
				state.roll_ticks = VehicleSimulation.ROLL_DURATION_TICKS * 3 / 4
				state.roll_direction = -1.0 if pose == "roll-right" else 1.0
				car.present_roll(state)
			if pose == "rollover":
				state.roll_ticks = VehicleSimulation.ROLL_DURATION_TICKS / 2
				car.present_roll(state)
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://../docs/evidence/soil/"+pose+".png")
		# Fixed-tick moving evidence; assemble frames into a 0.6-second GIF outside Godot.
		camera.size = 12
		trails.clear()
		for tick: int in range(0,109,3):
			state.tick = tick
			state.roll_direction = -1.0
			state.roll_ticks = maxi(0,72-tick)
			car.rotation = Vector3.ZERO
			car.present(Vector2.ZERO,0.0,state,DriveFrame.new())
			car.present_suspension(state,0.0)
			car.present_roll(state)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://../docs/evidence/soil/realistic-%03d.png" % tick)
		var tumble := VehicleSimulation.new(config)
		tumble.state.velocity = Vector2(46,0)
		tumble.step(DriveFrame.new(),track)
		for tick: int in range(181):
			car.rotation = Vector3.ZERO
			car.present(tumble.state.position,tumble.state.heading,tumble.state,DriveFrame.new())
			car.present_suspension(tumble.state,0.0)
			car.present_roll(tumble.state)
			if tick % 3 == 0:
				var center: Vector3 = VisualGeometry.world(tumble.state.position)
				camera.position = center + Vector3(12,22,18)
				camera.look_at(center)
				await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://../docs/evidence/soil/multi-%03d.png" % tick)
			tumble.step(DriveFrame.new(),track)
	print("SOIL_CHECKS ",checks," failures=",failures)
	quit(1 if failures else 0)
