extends SceneTree

const SandDustEffect = preload("res://vehicle/sand_dust.gd")
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
	for kind: int in [1,2]:
		track.cells.fill(kind)
		var rough_state := VehicleState.new()
		check(track.off_road_rumble(rough_state) == 1.0,"grass and sand receive equal off-road camera shake, surface %d" % kind)
	track.cells.fill(0)
	check(track.off_road_rumble(VehicleState.new()) == 0.0,"asphalt does not receive off-road camera shake")
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
	# Every car reacts before its centre leaves asphalt. Unequal wheel drag pulls
	# toward the escaped side, and four-wheel soil sheds speed substantially faster.
	track.cells.fill(0)
	for row: int in range(50,100):
		for col: int in range(50,100): track.cells[row*100+col] = 2
	var one_tire := VehicleSimulation.new(config)
	one_tire.reset(Vector2(-0.2,0.2))
	one_tire.state.velocity = Vector2(0,24)
	var one_contacts: Vector4 = one_tire._wheel_soil_contacts(track)
	check(one_contacts.x+one_contacts.y+one_contacts.z+one_contacts.w == 1.0,"fixture catches exactly one tyre in soil")
	var clean_tire := VehicleSimulation.new(config)
	clean_tire.reset(Vector2(-2.0,0.2))
	clean_tire.state.velocity = one_tire.state.velocity
	one_tire.step(DriveFrame.new(),track)
	clean_tire.step(DriveFrame.new(),track)
	print("SOIL_ONE_TIRE_IMMEDIATE yaw_rate=%.3f clean_yaw_rate=%.3f" % [one_tire.state.yaw_rate,clean_tire.state.yaw_rate])
	check(absf(one_tire.state.yaw_rate) > absf(clean_tire.state.yaw_rate)+0.05,"one off-track tyre immediately creates strong differential-drag torque")
	var corner := VehicleSimulation.new(config)
	corner.reset(Vector2(-0.2,0.2))
	corner.state.velocity = Vector2(0,24)
	corner.state.steering = 1.0
	corner.state.yaw_rate = 0.8
	var clean_corner := VehicleSimulation.new(config)
	clean_corner.reset(Vector2(-2.0,0.2))
	clean_corner.state.velocity = corner.state.velocity
	clean_corner.state.steering = corner.state.steering
	clean_corner.state.yaw_rate = corner.state.yaw_rate
	corner.step(DriveFrame.sample(1,0,0),track)
	clean_corner.step(DriveFrame.sample(1,0,0),track)
	var caught_side: float = (one_contacts.y+one_contacts.w)-(one_contacts.x+one_contacts.z)
	check((corner.state.yaw_rate-clean_corner.state.yaw_rate)*signf(caught_side) > 0.02,"one off-track tyre adds physical torque during an established corner")
	for i: int in range(59): one_tire.step(DriveFrame.new(),track)
	print("SOIL_ONE_TIRE speed_mps=%.3f heading_deg=%.3f yaw_rate=%.3f" % [one_tire.state.velocity.length(),rad_to_deg(one_tire.state.heading),one_tire.state.yaw_rate])
	check(absf(one_tire.state.heading) < deg_to_rad(10.0),"brief one-tyre contact has no scripted residual spin")
	var edge := VehicleSimulation.new(config)
	edge.reset(Vector2(-0.2,-100.0))
	edge.state.velocity = Vector2(0,24)
	var clean := VehicleSimulation.new(config)
	clean.reset(Vector2(-2.0,-100.0))
	clean.state.velocity = edge.state.velocity
	edge.step(DriveFrame.new(),track)
	clean.step(DriveFrame.new(),track)
	check(track.tire_pickup(edge.state) == 0.0 and edge.state.velocity.length() < clean.state.velocity.length(),"partial wheel excursion slows every vehicle before its centre leaves asphalt")
	for i: int in range(59):
		edge.step(DriveFrame.new(),track)
		clean.step(DriveFrame.new(),track)
	print("SOIL_EDGE clean_mps=%.3f partial_mps=%.3f partial_heading_deg=%.3f" % [clean.state.velocity.length(),edge.state.velocity.length(),rad_to_deg(edge.state.heading)])
	check(edge.state.heading > deg_to_rad(20.0),"sustained right-side soil gives a strong physical pull toward the escaped wheels")
	var full_soil := VehicleSimulation.new(config)
	full_soil.reset(Vector2(100,-100))
	full_soil.state.velocity = Vector2(0,24)
	for i: int in range(60): full_soil.step(DriveFrame.new(),track)
	print("SOIL_FULL speed_after_0_5s_mps=%.3f" % full_soil.state.velocity.length())
	check(full_soil.state.velocity.length() < 15.5,"full off-track excursion rapidly sheds speed")
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
	state.position.y += 1.0
	trails.sample(state,DriveFrame.new())
	check(trails.cursor == 12,"straight dirty driving leaves four wheel-contact marks per segment")
	check(trails.mark_colors[8].a < strong,"cleaner tires deposit fainter marks after the natural fade distance")
	check(trails.instances.visible_instance_count == 12,"four wheel trails share one bounded instance batch")
	var mark_transform: Transform3D = trails.mark_transforms[0]
	check(is_equal_approx(mark_transform.basis.z.length(),1.0),"batched mark retains exact driven length without double-blended seam overlap")
	check(trails.CAPACITY == 16384 and trails.instances.instance_count == trails.CAPACITY,"one fixed batch retains a race-scale four-wheel mark budget")
	check(trails.instances.use_custom_data,"single trail batch carries per-segment physics and loose-surface tread data")
	var asphalt_style: Vector4 = trails._surface_style(0,0.0)
	var grass_style: Vector4 = trails._surface_style(1,0.0)
	var dirt_style: Vector4 = trails._surface_style(2,0.0)
	var water_style: Vector4 = trails._surface_style(3,0.0)
	check(asphalt_style != grass_style and grass_style != dirt_style and dirt_style != water_style,"asphalt, grass, dirt and wet surfaces have distinct trail treatments")
	check(grass_style.x > grass_style.z and grass_style.y > grass_style.x and grass_style.w >= 0.59,"grass tracks use a dark opaque brown-green crushed-vegetation treatment")
	check(trails._surface_width(1) > trails._surface_width(0) and trails._surface_width(2) > trails._surface_width(0),"soft-ground tracks are wider than asphalt rubber")
	check(trails._surface_relief(1) >= 0.07 and trails._surface_relief(2) >= 0.055,"grass and dirt tracks have deep faceted rut relief")
	check(trails._surface_relief(1) > trails._surface_relief(0) * 20.0 and trails._surface_relief(2) > trails._surface_relief(0) * 16.0,"loose-surface relief remains visually distinct from nearly-flat asphalt")
	var quiet_state := VehicleState.new()
	quiet_state.velocity = Vector2(0,12)
	var sliding_state := VehicleState.new()
	sliding_state.velocity = Vector2(6,18)
	sliding_state.yaw_rate = 0.9
	var braking_frame := DriveFrame.new()
	braking_frame.brake = 230
	var quiet_strength: float = SkidTrails.physics_intensity(quiet_state,DriveFrame.new(),0,-1.0)
	var slide_left: float = SkidTrails.physics_intensity(sliding_state,DriveFrame.new(),0,-1.0)
	var slide_right: float = SkidTrails.physics_intensity(sliding_state,DriveFrame.new(),0,1.0)
	var slide_front: float = SkidTrails.physics_intensity(sliding_state,DriveFrame.new(),0,-1.0,1.0)
	var brake_strength: float = SkidTrails.physics_intensity(quiet_state,braking_frame,0,-1.0)
	check(quiet_strength < slide_left and quiet_strength < brake_strength,"sliding and braking make stronger tracks than clean rolling")
	check(not is_equal_approx(slide_left,slide_right),"cornering load varies left and right rear-track intensity")
	check(slide_front < slide_left,"front contact marks stay lighter than rear marks during oversteer")
	check(trails._surface_style(0,0.0,0.25).w < trails._surface_style(0,0.0,0.9).w and trails._surface_width(0,0.25) < trails._surface_width(0,0.9),"physics strength continuously changes mark opacity and width")
	check(trails._surface_width(0,1.0) > 0.21 and trails._surface_style(0,0.0,0.2).w < 0.05 and trails._surface_style(0,0.0,1.0).w <= 0.461,"asphalt marks are tire-width, subtle at mild slip and bounded under heavy slip")
	track.metadata.theme = "winter"
	track.cells.fill(0)
	check(SkidTrails.surface_at(track,Vector3.ZERO,false) == 8,"winter asphalt uses the frosty trail treatment")
	track.metadata.theme = "storm"
	check(SkidTrails.surface_at(track,Vector3.ZERO,false) == 9,"storm asphalt uses the damp trail treatment")
	track.metadata.theme = "desert"
	track.cells.fill(2)
	var rough_probe := VehicleSimulation.new(config)
	var rough_contacts := Vector4.ONE
	var rough_left: float = 0.0
	var rough_right: float = 0.0
	for x: float in [-2.0,-1.0,0.0,1.0,2.0]:
		rough_probe.state.position = Vector2(x,0.37)
		var disturbance: float = rough_probe._soil_rough_yaw_acceleration(rough_contacts,20.0)
		rough_left = minf(rough_left,disturbance)
		rough_right = maxf(rough_right,disturbance)
	print("SOIL_ROUGH_YAW_ACCEL range=[%.3f,%.3f]" % [rough_left,rough_right])
	check(rough_left < -0.1 and rough_right > 0.1,"loose-ground steering disturbance varies irregularly in both directions")
	check(maxf(absf(rough_left),absf(rough_right)) <= VehicleSimulation.SOIL_ROUGH_YAW_ACCELERATION,"loose-ground steering disturbance stays within its small bounded tyre-deflection limit")
	rough_probe.state.position = Vector2(0.25,-0.7)
	check(rough_probe._soil_rough_yaw_acceleration(rough_contacts,20.0) == rough_probe._soil_rough_yaw_acceleration(rough_contacts,20.0),"loose-ground steering disturbance is deterministic")
	check(rough_probe._soil_rough_yaw_acceleration(Vector4.ZERO,20.0) == 0.0,"asphalt receives no terrain steering disturbance")
	var one_rough_wheel: float = absf(rough_probe._soil_rough_yaw_acceleration(Vector4(1,0,0,0),20.0))
	var four_rough_wheels: float = absf(rough_probe._soil_rough_yaw_acceleration(rough_contacts,20.0))
	check(one_rough_wheel > 0.0 and is_equal_approx(four_rough_wheels,one_rough_wheel*4.0),"terrain steering variation scales with the number of off-road tyres")
	# Generic loose-sand/asphalt contract; desert roads now deliberately emit dust.
	track.metadata.theme = "pine"
	var dust := SandDustEffect.new()
	world.add_child(dust)
	check(dust.dust_emitters.size() == 4 and dust.spray_emitters.size() == 2,"sand effect has four wheel clouds and two rear-wheel spray emitters")
	check(dust.clipping_emitters.size() == 4 and dust.mud_emitters.size() == 2 and dust.smoke_emitters.size() == 4,"grass and asphalt effects follow four wheel contacts with rear-biased heavy debris")
	var blade: Mesh = dust.clipping_emitters[0].draw_pass_1
	check(blade is ArrayMesh and blade.get_aabb().size.y > 0.005 and blade.get_faces().size() == 15 and dust.mud_emitters[0].draw_pass_1 is SphereMesh,"folded grass blades and mud are real bounded 3D fragments rather than camera-facing pasted cards")
	check(dust.smoke_emitters[0].amount >= 900 and dust.smoke_emitters[0].lifetime >= 1.5,"asphalt smoke uses many faint overlapping particles for a continuous restrained haze")
	check(dust.smoke_emitters[0].fixed_fps == VehicleSimulation.TICK_RATE and dust.dust_emitters[0].fixed_fps == 30,"smoke samples fast wheel motion at 120 Hz without raising every effect's simulation rate")
	var smoke_quad: QuadMesh = dust.smoke_emitters[0].draw_pass_1 as QuadMesh
	var smoke_material: ShaderMaterial = smoke_quad.material as ShaderMaterial
	check(smoke_material != null and "float haze" in smoke_material.shader.code and not "dust_texture" in smoke_material.shader.code,"asphalt smoke uses a uniform soft haze rather than individual dust-puff silhouettes")
	check(dust.dust_emitters[0].lifetime >= 5.0 and dust.spray_emitters[0].lifetime >= 0.6,"sand clouds linger beyond five seconds while fast spray stays short lived")
	var dust_quad: QuadMesh = dust.dust_emitters[0].draw_pass_1 as QuadMesh
	check(dust_quad != null and dust_quad.size.x >= 2.0 and dust_quad.size.y >= 2.0,"dust particles start with a broad footprint before expanding")
	var dust_material: ShaderMaterial = dust_quad.material as ShaderMaterial
	check(dust_material != null and dust_material.render_priority >= 4 and not "depth_test_disabled" in dust_material.shader.code,"young ground-level dust respects car depth until it physically rises")
	check(dust_material != null and "dust_texture" in dust_material.shader.code and dust_material.get_shader_parameter("dust_texture") != null,"dust uses the authored irregular puff texture instead of procedural cross-hatching")
	var dust_process: ParticleProcessMaterial = dust.dust_emitters[0].process_material as ParticleProcessMaterial
	check(dust_process != null and dust_process.direction.y > 0.4 and dust_process.gravity.y > 0.0,"dust launches upward from wheel contact and continues rising slowly")
	var dust_state := VehicleState.new()
	dust_state.velocity = Vector2(0,12)
	dust.sample(dust_state,DriveFrame.new(),track)
	check(dust.last_strengths[0] > 0.0 and dust.dust_emitters[0].emitting,"normal sand driving produces a restrained wheel dust trail")
	check(dust.dust_emitters[0].position.y < 0.04,"dust begins at exact tire-ground height rather than appearing already suspended")
	check(dust.spray_emitters[0].amount_ratio < dust.dust_emitters[0].amount_ratio,"normal driving keeps fast sand spray below the dust cloud")
	dust_state.velocity = Vector2(9,16)
	dust_state.yaw_rate = 1.0
	dust.sample(dust_state,DriveFrame.new(),track)
	check(dust.spray_emitters[0].amount_ratio > 0.35 and dust.dust_emitters[0].amount_ratio > 0.75,"heavy sand slip produces strong rear spray and dust")
	check(dust.last_strengths[2] < dust.last_strengths[0],"front wheel dust remains weaker than the loaded rear plume during a slide")
	track.cells.fill(0)
	dust.sample(dust_state,DriveFrame.new(),track)
	check(not dust.dust_emitters[0].emitting and not dust.spray_emitters[0].emitting,"dust emission stops when wheel contact returns to asphalt")
	var quiet_asphalt := VehicleState.new()
	quiet_asphalt.velocity = Vector2(0,12)
	check(SandDustEffect.asphalt_smoke_strength(quiet_asphalt,DriveFrame.new(),-1.0) == 0.0,"normal asphalt grip produces no smoke")
	var heavy_asphalt := VehicleState.new()
	heavy_asphalt.velocity = Vector2(8,18)
	heavy_asphalt.yaw_rate = 0.9
	var smoke_rear: float = SandDustEffect.asphalt_smoke_strength(heavy_asphalt,DriveFrame.new(),-1.0)
	var smoke_front: float = SandDustEffect.asphalt_smoke_strength(heavy_asphalt,DriveFrame.new(),1.0)
	check(smoke_rear > 0.35 and smoke_rear <= 0.48 and smoke_front < smoke_rear,"heavy asphalt cornering creates faint bounded rear-biased smoke")
	var grass_normal: Vector2 = SandDustEffect.grass_emission_strengths(quiet_asphalt,DriveFrame.new(),-1.0,-1.0)
	var grass_heavy: Vector2 = SandDustEffect.grass_emission_strengths(heavy_asphalt,DriveFrame.new(),-1.0,-1.0)
	check(grass_normal.x > 0.0 and grass_normal.y == 0.0,"normal grass crossing throws a few clippings without mud")
	check(grass_heavy.x > grass_normal.x and grass_heavy.y > 0.5,"heavy grass slip throws more clippings and strong mud flecks")
	if DisplayServer.get_name() != "headless":
		var uploaded: Color = trails.instances.get_instance_color(8)
		var expected: Color = trails.mark_colors[8]
		check(absf(uploaded.a-expected.a) <= 1.0/255.0 and absf(uploaded.r-expected.r) <= 1.0/255.0 and absf(uploaded.g-expected.g) <= 1.0/255.0 and absf(uploaded.b-expected.b) <= 1.0/255.0,"GPU receives faded per-mark color within 8-bit storage precision")
		check(trails.instances.get_instance_transform(0).is_equal_approx(mark_transform),"GPU receives the bridge-aware mark pose")
		trails._mark(Vector3.ZERO,Vector3(0,0,1),0.0,2,0.73)
		var uploaded_custom: Color = trails.instances.get_instance_custom_data(12)
		check(absf(uploaded_custom.g-0.73) <= 1.0/255.0 and uploaded_custom.b > 0.99,"GPU receives loose-surface physics strength for procedural tread breakup")
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
		# Dedicated loose-surface relief proof under the same cel-shaded light.
		trails.clear()
		car.visible = false
		var grass_panel: MeshInstance3D = VisualGeometry.box(world,Vector3(6,0.1,18),Vector3(-4,-0.015,0),VisualGeometry.material(Color("597343")))
		var sand_panel: MeshInstance3D = VisualGeometry.box(world,Vector3(6,0.1,18),Vector3(4,-0.015,0),VisualGeometry.material(Color("b18d58")))
		for i: int in range(16):
			var start_z: float = -7.5+i
			trails._mark(Vector3(-4.55,0.04,start_z),Vector3(-4.55,0.04,start_z+1.06),0.0,1,0.9)
			trails._mark(Vector3(-3.45,0.04,start_z),Vector3(-3.45,0.04,start_z+1.06),0.0,1,0.62)
			trails._mark(Vector3(3.45,0.04,start_z),Vector3(3.45,0.04,start_z+1.06),0.0,2,0.9)
			trails._mark(Vector3(4.55,0.04,start_z),Vector3(4.55,0.04,start_z+1.06),0.0,2,0.62)
		camera.size = 23
		camera.position = Vector3(11,18,16)
		camera.look_at(Vector3.ZERO)
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://../docs/evidence/soil/deep-off-track-ruts.png") == OK,"grass and sand relief evidence saved")
		# Moving high-slip sand proof: wheel spray remains compact while clouds
		# detach in world space, expand and linger behind the car.
		grass_panel.visible = false
		sand_panel.visible = true
		car.visible = true
		trails.clear()
		track.cells.fill(2)
		dust.clear()
		dust_state.velocity = Vector2(6,15)
		dust_state.yaw_rate = 0.85
		for i: int in range(70):
			dust_state.position = Vector2(4.0,-6.0+i*0.11)
			dust.sample(dust_state,DriveFrame.new(),track)
			car.present(dust_state.position,dust_state.heading,dust_state,DriveFrame.new())
			car.position.y = 0.10
			await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://../docs/evidence/soil/sand-dust-clouds.png") == OK,"two-layer sand dust evidence saved")
		dust._stop()
		for i: int in range(90): await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://../docs/evidence/soil/sand-dust-risen.png") == OK,"mature raised sand cloud evidence saved")
		# Grass clippings and mud remain low, ballistic and short-lived.
		dust.clear()
		grass_panel.visible = true
		sand_panel.visible = false
		track.cells.fill(1)
		dust_state.velocity = Vector2(7,15)
		dust_state.yaw_rate = 0.9
		for i: int in range(55):
			dust_state.position = Vector2(-4.0,-5.0+i*0.10)
			dust.sample(dust_state,DriveFrame.new(),track)
			car.present(dust_state.position,dust_state.heading,dust_state,DriveFrame.new())
			await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://../docs/evidence/soil/grass-clippings-mud.png") == OK,"grass clippings and mud evidence saved")
		# Dry asphalt stays clean under normal grip and smokes only in this
		# deliberately heavy lateral-slip fixture.
		dust.clear()
		grass_panel.visible = false
		track.cells.fill(0)
		dust_state.velocity = Vector2(8,18)
		for i: int in range(55):
			dust_state.position = Vector2(0.0,-5.0+i*0.10)
			dust.sample(dust_state,DriveFrame.new(),track)
			car.present(dust_state.position,dust_state.heading,dust_state,DriveFrame.new())
			await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://../docs/evidence/soil/asphalt-tire-smoke.png") == OK,"heavy-slip asphalt smoke evidence saved")
		dust.clear()
		dust.queue_free()
		car.position.y = 0.0
		track.cells.fill(0)
		track.metadata.theme = "pine"
		await process_frame
		# Asphalt progression: faint onset, moderate slip, heavy slide, then an
		# accumulated repeated line. All remain in the same MultiMesh draw.
		grass_panel.visible = false
		sand_panel.visible = false
		trails.clear()
		for column: int in range(4):
			var strength: float = [0.10,0.35,0.78,0.48][column]
			var x: float = -6.0+column*4.0
			for i: int in range(16):
				var z: float = -7.5+i
				trails._mark(Vector3(x,0.04,z),Vector3(x,0.04,z+1.06),0.0,0,strength)
				if column == 3:
					trails._mark(Vector3(x+0.025,0.041,z),Vector3(x+0.025,0.041,z+1.06),0.0,0,0.42)
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://../docs/evidence/soil/asphalt-skid-progression.png") == OK,"asphalt intensity and accumulation evidence saved")
		car.visible = true
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
