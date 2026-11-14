extends SceneTree
## Storm sand contacts emit compact ballistic dirt without suspended clouds.
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func quiet_clouds(effect: SandDust) -> bool:
	return effect.cloud_emitters().all(func(e: GPUParticles3D) -> bool: return not e.emitting and e.amount_ratio == 0.0)

func run() -> void:
	var track := NativeTrack.new()
	track.cell_size = 1.0
	track.grid_width = 40
	track.grid_height = 40
	track.half_extent = Vector2(20,20)
	track.cells.resize(1600)
	track.cells.fill(2)
	track.deck_cells.resize(1600)
	track.deck_cells.fill(2)
	track.metadata = {"theme":"storm"}
	var effect := SandDust.new()
	root.add_child(effect)
	effect.prepare_track(track)
	var state := VehicleState.new()
	state.velocity = Vector2(0,18)
	var frame := DriveFrame.new()
	var before: Array = state.snapshot()
	effect.sample(state,frame,track)
	check(quiet_clouds(effect),"straight Storm sand driving emits no dust clouds")
	check(effect.spray_emitters.all(func(e: GPUParticles3D) -> bool: return e.emitting),"normal driving throws a little dirt from both rear tires")
	check(state.snapshot() == before,"cosmetic spray leaves canonical state exact")
	var rolling: float = effect.spray_emitters[0].amount_ratio
	state.velocity = Vector2(9,18)
	frame.brake = 255
	effect.sample(state,frame,track)
	check(quiet_clouds(effect),"sliding and braking on wet sand never creates clouds")
	check(effect.spray_emitters[0].amount_ratio > rolling and effect.spray_emitters[0].amount_ratio <= 0.32,"sliding adds a bounded amount of dirt")
	for emitter: GPUParticles3D in effect.spray_emitters:
		var process: ParticleProcessMaterial = emitter.process_material
		var grain: SphereMesh = emitter.draw_pass_1
		check(emitter.lifetime <= 0.35 and process.gravity.y < 0.0 and process.initial_velocity_max <= 3.0,"dirt settles quickly in a low ballistic spray")
		check(grain.radius <= 0.03 and grain.height <= 0.08,"wet dirt uses small solid grains")
	state.track_elevated = true
	effect.sample(state,frame,track)
	check(not effect.deck_dust_emitters.is_empty() and quiet_clouds(effect),"elevated sand cannot bypass the Storm cloud suppression")
	state.track_elevated = false
	state.velocity = Vector2(0,18)
	frame.brake = 0
	for row: int in range(40):
		for column: int in range(20,40): track.cells[row*40+column] = 0
	effect.sample(state,frame,track)
	check(effect.spray_emitters[0].emitting and not effect.spray_emitters[1].emitting,"mixed contacts spray only from the tire on sand")
	check(not effect.water_drops[0].emitting and effect.water_drops[1].emitting,"wet asphalt retains its independent water spray")
	track.cells.fill(2)
	state.velocity = Vector2(0,-18)
	effect.sample(state,frame,track)
	check((-effect.spray_emitters[0].basis.z).dot(VisualGeometry.world(-state.velocity.normalized())) > 0.99,"reverse dirt follows actual tire travel")
	for mode: String in ["stopped","airborne","rolled"]:
		state.velocity = Vector2.ZERO if mode == "stopped" else Vector2(0,18)
		state.jump_height = 1.0 if mode == "airborne" else 0.0
		state.roll_ticks = 10 if mode == "rolled" else 0
		effect.sample(state,frame,track)
		check(quiet_clouds(effect) and effect.spray_emitters.all(func(e: GPUParticles3D) -> bool: return not e.emitting),mode+" stops sand effects")
	state.jump_height = 0.0
	state.roll_ticks = 0
	track.metadata.theme = "desert"
	effect.sample(state,frame,track)
	check(effect.dust_emitters[0].emitting and effect.tyre_emitters[0].emitting and effect.dust_emitters[0].lifetime == 9.0,"Desert retains its approved long-lived billowing clouds")
	track.metadata.theme = "storm"
	effect.prepare_track(track)
	check(quiet_clouds(effect),"entering Storm clears lingering dry-biome clouds before driving")
	effect.sample(state,frame,track)
	check(quiet_clouds(effect) and effect.spray_emitters[0].emitting,"reused Storm effects restore small dirt without dust")
	track.metadata.theme = "pine"
	effect.sample(state,frame,track)
	check(effect.dust_emitters[0].emitting and effect.spray_emitters[0].lifetime == 0.65,"dry sand restores its original effect profile")
	effect.clear()
	check(effect.get_children().all(func(e: Node) -> bool: return not e.emitting),"restart/rewind clears every particle emitter")
	effect.free()
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless": await capture_driving()
	print("STORM_SAND_SPRAY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func capture_driving() -> void:
	var output: String = "res://../docs/evidence/storm-sand-spray-2026-11-14/"+RenderingServer.get_current_rendering_method()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size = Vector2i(1280,720)
	var race: Node = load("res://core/game.tscn").instantiate()
	race.initial_track = NativeTrack.read("res://resources/tracks/storm_quarry.json")
	race.production_mode = true
	root.add_child(race)
	race.set_physics_process(false)
	race.set_process(false)
	race.paused = false
	race.countdown_ticks = 0
	race.race_cues.reset()
	race.hud.hide()
	race.storm_weather.set_process(false)
	race.camera.speed_zoom_enabled = false
	var state := VehicleState.new()
	state.velocity = Vector2(0,18)
	race.sim.state = state
	for tick: int in range(72):
		state.position = Vector2(-30,-28)+state.forward()*18.0*float(tick-71)/120.0
		race.previous_position = state.position
		race.previous_heading = state.heading
		race.call("_process",1.0/120.0)
		race.sand_dust.sample(state,DriveFrame.new(),race.native_track,race.bridge_presentation)
		await create_timer(1.0/120.0).timeout
		await RenderingServer.frame_post_draw
	race.sand_dust.set_water_paused(true)
	check(quiet_clouds(race.sand_dust) and race.sand_dust.spray_emitters[0].emitting,"actual Quarry race presents dirt without clouds")
	var with_spray: Image = await capture_frame()
	with_spray.save_png(output.path_join("driving.png"))
	for emitter: GPUParticles3D in race.sand_dust.spray_emitters: emitter.hide()
	var without_spray: Image = await capture_frame()
	without_spray.save_png(output.path_join("without-spray.png"))
	var changed: int = 0
	for y: int in range(with_spray.get_height()):
		for x: int in range(with_spray.get_width()):
			var a: Color = with_spray.get_pixel(x,y)
			var b: Color = without_spray.get_pixel(x,y)
			if maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b))) > 0.008: changed += 1
	print("STORM_SAND_PIXELS: ",changed)
	check(changed > 0 and changed < 500,"rendered dirt remains visible and compact")
	race.queue_free()
	await process_frame
	await process_frame

func capture_frame() -> Image:
	for frame: int in range(4): await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
