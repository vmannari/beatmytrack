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
	for contacts: Vector4 in [Vector4(0.1,0,0,0),Vector4(0,0.1,0,0.1),Vector4(0.1,0.1,0.1,0),Vector4.ZERO]:
		state.kerb_offset = Vector3((contacts.x+contacts.y+contacts.z+contacts.w)*0.25,atan2((contacts.x+contacts.y-contacts.z-contacts.w)*0.5,2.26),atan2((contacts.y+contacts.w-contacts.x-contacts.z)*0.5,1.46))
		var before: Array = state.snapshot()
		car.present_suspension(state,0.0,true,0.0,contacts)
		var support := Basis.from_euler(Vector3(state.kerb_offset.y,0,state.kerb_offset.z))
		for index: int in range(car.rolling_wheels.size()):
			var pivot: Node3D = car.rolling_wheels[index].get_parent() as Node3D
			var rest: Vector3 = car.wheel_rest_positions[index]
			var slot: int = (0 if rest.z < 0 else 2)+(0 if rest.x < 0 else 1)
			var tyre_height: float = ((support*pivot.position).y-rest.y)*HandlingConfig.BODY_SCALE+state.kerb_offset.x
			check(absf(tyre_height-contacts[slot]) < 0.00001,"each tyre follows its own kerb contact")
		check(is_equal_approx(car.body.rotation.z,state.kerb_offset.z*0.7) and is_equal_approx(car.body.rotation.x,state.kerb_offset.y*0.7),"body accentuates the correct kerb axle and side")
		check(state.snapshot() == before,"kerb articulation preserves canonical state")
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
	state.tick += 1
	car.present_suspension(state, 0.0, true, 1.0)
	var rough_pose := Vector2(car.body.position.y,car.body.rotation.z)
	check(rough_pose.length() > 0.001, "off-track contact visibly agitates the sprung body")
	check(absf(car.body.position.y) <= CarVisual.MAX_SURFACE_HEAVE*1.35 and absf(car.body.rotation.z) <= CarVisual.MAX_SURFACE_ROLL*1.30, "off-track body shake stays subtle and bounded")
	var canonical_before_rumble: Array = state.snapshot()
	car.present_suspension(state, 0.0, true, 1.0)
	check(Vector2(car.body.position.y,car.body.rotation.z) == rough_pose and state.snapshot() == canonical_before_rumble, "off-track body shake is deterministic and presentation-only")
	car.present_suspension(state, 0.0, true, 0.0)
	check(absf(car.body.position.y) < 0.0001 and absf(car.body.rotation.z) < 0.0001, "road contact removes the surface shake")
	state.heading = 0.0
	car.add_collision_impact(state,Vector2(12.0,0.0))
	check(car.suspension_speed.z > 0.1 and car.suspension_speed.length() <= CarVisual.MAX_COLLISION_SUSPENSION_SPEED, "side collision adds a bounded suspension roll impulse")
	var side_kick: float = car.suspension_speed.z
	car.suspension_speed = Vector3.ZERO
	car.add_collision_impact(state,Vector2(0.0,12.0))
	check(car.suspension_speed.y > 0.1 and absf(car.suspension_speed.z) < 0.001, "longitudinal collision adds pitch instead of side roll")
	car.suspension_speed = Vector3.ZERO
	car.add_collision_impact(state,Vector2(1.0,0.0))
	check(car.suspension_speed == Vector3.ZERO and side_kick > 0.1, "minor contact does not disturb suspension")
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
	for speed: float in [3.0,24.0]:
		var peak: float = 0.0
		var span: Dictionary = RoadPieces.create("bridge",Vector2.ZERO,0,10)
		span.length = 32.0
		state.tick = 0
		state.velocity = Vector2(speed,0)
		car.present_ramp(state,0,0,false)
		for i: int in range(ceili(40.0/speed*120.0)):
			var u: float = -4.0+i*speed/120.0
			var front: float = CreatorBridges.height(span,Vector2(u+1.13,0))
			var rear: float = CreatorBridges.height(span,Vector2(u-1.13,0))
			state.tick += 1
			car.position.y = (front+rear)*0.5
			car.rotation.x = atan2(front-rear,2.26)
			car.present_ramp(state,car.position.y,car.rotation.x,true)
			peak = maxf(peak,car.ramp_lift)
		check(peak < 0.01 if speed < 5 else peak > 0.05 and peak <= 0.55,"slow ramp stays planted; fast ramp visibly unloads within bounds")
		check(car.ramp_lift == 0.0,"car lands after descending ramp")
		print("RAMP speed=",speed," peak_lift=",peak)
	var ramp_pose: float = car.ramp_lift
	car.present_ramp(state,0,0,true)
	check(car.ramp_lift == ramp_pose,"duplicate snapshots cannot advance crest motion")
	car.present_ramp(state,0,0,false)
	check(car.ramp_lift == 0.0 and car.ramp_velocity == 0.0,"jump/roll/reset clears visual ramp motion")
	for stride: int in [1,2,4]:
		state.tick = 0
		state.velocity = Vector2(0,12)
		car.present_ramp(state,0,0.25,false)
		var response: Array[float] = []
		for tick: int in range(stride,241,stride):
			state.tick = tick
			car.present_ramp(state,0,0,true)
			if tick in [48,96,240]: response.append(car.ramp_pitch)
		check(response[0] < -0.01 and response[1] > 0.001,"pitch rebounds on both sides after ramp exit at %d Hz" % (120/stride))
		check(absf(response[1]) < absf(response[0])*0.3 and absf(response[2]) < 0.0001,"successive ramp rebounds decay and settle at %d Hz" % (120/stride))
		var frozen: Vector2 = Vector2(car.ramp_pitch,car.ramp_pitch_speed)
		var canonical: Array = state.snapshot()
		car.present_ramp(state,0,0,true)
		check(frozen == Vector2(car.ramp_pitch,car.ramp_pitch_speed) and canonical == state.snapshot(),"paused ramp spring preserves pose and canonical state")
		print("RAMP_SETTLE rate=",120/stride," pitch_at_0.4_0.8_2s=",response)
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
	if "--capture" in OS.get_cmdline_user_args(): await _capture_ramp()
	print("SUSPENSION_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _capture_ramp() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var span: Dictionary = RoadPieces.create("bridge",Vector2(-16,0),0,10)
	span.length = 32.0
	CreatorBridgeVisual.build(world,[span])
	VisualGeometry.box(world,Vector3(200,0.1,60),Vector3(0,-0.1,0),VisualGeometry.material(Color("627157")))
	var car := CarVisual.new()
	world.add_child(car)
	var light := DirectionalLight3D.new()
	world.add_child(light)
	light.rotation_degrees = Vector3(-50,-25,0)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 13.0
	var state := VehicleState.new()
	state.velocity = Vector2(24,0)
	state.heading = PI*0.5
	var frame := DriveFrame.new()
	var captured: int = 0
	var targets: Array[float] = [4.0,10.0,26.0,35.0]
	var names: Array[String] = ["climb","crest","descent","settled"]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../build/ramp-motion"))
	for i: int in range(420):
		var u: float = -4.0+i*0.2
		state.tick = i
		state.position = Vector2(-16+u,0)
		car.present(state.position,state.heading,state,frame)
		var front: float = CreatorBridges.height(span,state.position+Vector2(1.13,0))
		var rear: float = CreatorBridges.height(span,state.position-Vector2(1.13,0))
		car.position.y = (front+rear)*0.5
		car.rotation.x = atan2(front-rear,2.26)
		car.present_ramp(state,car.position.y,car.rotation.x,true)
		car.present_suspension(state,car.rotation.x,car.ramp_lift <= 0.005)
		camera.position = car.position+Vector3(6,9,10)
		camera.look_at(car.position+Vector3(0,0.6,0))
		if i % 4 == 0:
			await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png("res://../build/ramp-motion/frame-%03d.png" % (i/4)) == OK,"capture ramp motion frame")
		if captured < targets.size() and u >= targets[captured]:
			await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png("res://../build/ramp-"+names[captured]+".png") == OK,"capture ramp "+names[captured])
			captured += 1
	world.queue_free()
	await process_frame
