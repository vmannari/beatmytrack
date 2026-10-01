extends SceneTree

var checks: int = 0
var failures: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280,720)
	_test_tire_spray()
	_test_flash_profiles()
	var track := NativeTrack.new()
	track.cell_size = 10.0
	track.grid_width = 100
	track.grid_height = 100
	track.half_extent = Vector2(500,500)
	track.cells.resize(10000)
	track.deck_cells.resize(10000)
	track.deck_cells.fill(-1)
	track.route = PackedVector2Array([Vector2(0,-400),Vector2(0,400)])
	var state := VehicleState.new()
	for surface: int in range(8):
		track.cells.fill(surface)
		track.metadata = {"theme":"pine"}
		var dry: Vector2 = track.surface_factors(state)
		track.metadata.theme = "winter"
		var ice: Vector2 = track.surface_factors(state)
		track.metadata.theme = "storm"
		var wet: Vector2 = track.surface_factors(state)
		check(wet.x < dry.x and wet.x > ice.x+0.2 if surface == 0 else wet == dry,"wet grip is intermediate and changes asphalt only "+str(surface))
	track.cells.fill(0)
	track.deck_cells.fill(0)
	state.track_elevated = true
	check(is_equal_approx(track.surface_factors(state).x,NativeTrack.STORM_ROAD_GRIP),"wet bridge deck")
	track.deck_cells.fill(-1)
	for car: String in VehicleCatalog.IDS:
		var config: HandlingConfig = VehicleCatalog.config(car)
		var slides: Array[float] = []
		for theme: String in ["pine","storm","winter"]:
			track.metadata.theme = theme
			var sim := VehicleSimulation.new(config)
			sim.state.velocity = Vector2(10,15)
			for tick: int in range(60): sim.step(DriveFrame.new(),track)
			slides.append(sim.state.position.x)
		print("STORM_SLIDE ",car," dry/wet/ice=",slides)
		check(slides[1] > slides[0]+0.04 and slides[1] < slides[2]*0.9,car+" wet slide is mild compared with ice")
		track.metadata.theme = "storm"
		var sim := VehicleSimulation.new(config)
		var frames: Array = []
		for tick: int in range(600):
			var input: DriveFrame = DriveFrame.sample(0.5 if tick > 120 else 0.0,1.0 if tick < 400 else 0.0,1.0 if tick >= 480 else 0.0)
			frames.append(input.packed())
			sim.step(input,track)
		var decoded: Array = JSON.parse_string(JSON.stringify(frames))
		for batch: int in [1,2,4,8]:
			var replay := VehicleSimulation.new(config)
			for offset: int in range(0,decoded.size(),batch):
				for index: int in range(offset,mini(offset+batch,decoded.size())):
					var input := DriveFrame.new()
					input.steer = int(decoded[index][0])
					input.throttle = int(decoded[index][1])
					input.brake = int(decoded[index][2])
					replay.step(input,track)
			check(replay.state.snapshot() == sim.state.snapshot(),car+" exact wet replay batch "+str(batch))
	var document: Dictionary = TrackDocument.create_default()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--track="):
			var fixture: String = argument.trim_prefix("--track=")
			if fixture == "fixture:knit_bridge_regression":
				document = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/knit_bridge_regression.json"))
			else:
				document = TrackLibrary.new().load_document(fixture)
			check(not document.is_empty(),"requested road-piece fixture exists")
			if document.is_empty(): quit(1); return
	document.theme = "storm"
	var race: Node = load("res://core/game.tscn").instantiate()
	race.initial_track = TrackCompiler.compile(document)
	race.production_mode = true
	root.add_child(race)
	await process_frame
	if "--video" in OS.get_cmdline_user_args():
		for frame: int in range(540):
			race.paused = false
			await RenderingServer.frame_post_draw
		print("STORM_VIDEO strikes=",race.storm_weather.strikes," thunder=",race.storm_weather.thunder_count)
		race.queue_free()
		await process_frame
		await process_frame
		quit()
		return
	race.paused = true
	(race.race_cues as Control).hide()
	var wet_materials: int = 0
	var wet_paint: int = 0
	for mesh: MeshInstance3D in race.track_ground.find_children("*","MeshInstance3D",true,false):
		var material: ShaderMaterial = mesh.material_override as ShaderMaterial
		if material != null and material.get_shader_parameter("wet_road") == true:
			wet_materials += 1
			if material.get_shader_parameter("road_marking") == true or material.get_shader_parameter("kerb") == true:
				wet_paint += 1
	check(wet_materials > 0,"wet road materials bound in race")
	if not document.get("pieces",[]).is_empty(): check(wet_paint > 0,"Storm paint and kerbs receive wet materials")
	var finish: MeshInstance3D = race.track_ground.get_node_or_null("FinishLight")
	check(finish != null and (finish.material_override as StandardMaterial3D).specular_mode == BaseMaterial3D.SPECULAR_SCHLICK_GGX,"start line receives specular lighting")
	check(race.biome_environment.sky != null and race.biome_environment.reflected_light_source == Environment.REFLECTION_SOURCE_SKY,"Storm supplies filtered sky reflections")
	var dry_environment := Environment.new()
	var test_light := DirectionalLight3D.new()
	TrackTheme.apply_lighting("storm",dry_environment,test_light)
	TrackTheme.apply_lighting("pine",dry_environment,test_light)
	check(dry_environment.sky == null and dry_environment.reflected_light_source == Environment.REFLECTION_SOURCE_BG,"changing biome clears Storm reflections")
	test_light.free()
	var weather: StormWeather = race.storm_weather
	check(weather != null and weather.mouse_filter == Control.MOUSE_FILTER_IGNORE,"storm never captures driving input")
	check(race.weather_layer.layer < race.hud.layer,"HUD and pedals remain above weather")
	check(weather.DROP_COUNT <= 6,"bounded unobtrusive lens droplets")
	var cached_ok: bool = true
	for sample_time: float in [0.0,0.035,1.55,14.1,3599.9,0.03]:
		weather.elapsed = sample_time
		weather._update_trail_history()
		for i: int in range(weather.DROP_COUNT):
			for offset: int in range(mini(weather.trail_tick+1,weather.TRAIL_SLOTS)):
				var tick: int = weather.trail_tick-offset
				cached_ok = cached_ok and weather.trail_samples[i][tick%weather.TRAIL_SLOTS].is_equal_approx(weather.lens_sample(i,float(tick)*weather.TRAIL_STEP))
	check(cached_ok,"bounded trail cache matches analytic paths through skipped frames, respawn and clock wrap")
	weather.elapsed = 0.0
	weather._update_trail_history()
	var bench_started: int = Time.get_ticks_usec()
	for frame: int in range(120):
		var sample_time: float = 5.0+float(frame)/60.0
		for i: int in range(weather.DROP_COUNT):
			for step: int in range(71): weather.lens_sample(i,sample_time-float(step)*0.02)
	var legacy_usec: int = Time.get_ticks_usec()-bench_started
	weather.elapsed = 5.0
	weather._update_trail_history()
	bench_started = Time.get_ticks_usec()
	for frame: int in range(120):
		weather.elapsed = 5.0+float(frame)/60.0
		weather._update_trail_history()
	print("STORM_TRAIL_CPU_120_FRAMES legacy_us=",legacy_usec," cached_us=",Time.get_ticks_usec()-bench_started)
	weather.elapsed = 0.0
	weather._update_trail_history()
	var resting := weather.lens_sample(0,0.5)
	var growing := weather.lens_sample(0,0.9)
	check(Vector2(resting.x,resting.y) == Vector2(growing.x,growing.y) and growing.z > resting.z,"lens drop clings while accumulating water")
	var saw_slip: bool = false
	var saw_turn: bool = false
	var stopped_again: bool = false
	var previous := weather.lens_sample(0,0.9)
	for frame: int in range(1,500):
		var sample := weather.lens_sample(0,0.9+float(frame)/100.0)
		var motion := Vector2(sample.x-previous.x,sample.y-previous.y)
		if motion.y > 0.001: saw_slip = true
		if saw_slip and absf(motion.x) > 0.0001: saw_turn = true
		if saw_slip and motion.length_squared() < 0.00000001: stopped_again = true
		previous = sample
	check(saw_slip and saw_turn and stopped_again,"lens drop slips sideways/down then settles again")
	check(race.initial_track.snow_banks.triangles.is_empty(),"Storm does not acquire winter snowbanks")
	var state_before: Array = race.sim.state.snapshot()
	var light: DirectionalLight3D = race.biome_light
	check(light.light_energy > 0.025 and light.light_energy < 1.0,"overcast light between daytime and night")
	weather.rng.seed = 317
	weather.until_lightning = 0.01
	weather.advance(0.02,false)
	check(weather.strikes == 1 and weather.thunder_count == 0 and weather.until_thunder >= 1.2,"lightning precedes delayed thunder")
	check(weather.until_lightning >= 9.0 and weather.until_lightning <= 16.0,"occasional lightning spacing")
	weather.advance(0.16,false)
	check(light.light_energy > weather.base_light_energy and weather.flash_strength() <= 0.32,"restrained irregular lightning intensity")
	var elapsed: float = weather.elapsed
	var frozen_flash: float = weather.flash_strength()
	weather.advance(10.0,true)
	check(weather.elapsed == elapsed and weather.rain_audio.stream_paused and not weather.thunder_audio.playing,"pause freezes weather and pending thunder")
	check(weather.flash_strength() == frozen_flash,"pause freezes the current lightning intensity")
	if "--capture" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../docs/evidence/storm"))
		await _capture("flash")
		var saved_age: float = weather.flash_age
		for knot: int in range(1,mini(5,weather.flash_profile.size())):
			weather.flash_age = weather.flash_profile[knot].x
			weather.advance(0.0,false)
			await _capture("strike-phase-"+str(knot))
		weather.flash_age = saved_age
		weather.advance(0.0,true)
	weather.advance(3.0,false)
	check(weather.thunder_count == 1 and weather.thunder_audio.playing,"thunder actually starts after delay")
	weather.advance(0.0,true)
	check(weather.rain_audio.stream_paused and weather.thunder_audio.stream_paused,"pause silences active rain and thunder")
	check(is_equal_approx(light.light_energy,weather.base_light_energy),"lightning restores overcast light")
	check(race.sim.state.snapshot() == state_before,"weather never changes canonical car state")
	if "--capture" in OS.get_cmdline_user_args():
		await _capture("rain")
		# Freeze every other effect and advance only the ripple clock.
		var ripple_first: Image = root.get_texture().get_image()
		RenderingServer.global_shader_parameter_set("storm_ripple_time",weather.elapsed+0.27)
		await _capture("ripples-later")
		var ripple_later: Image = root.get_texture().get_image()
		var ripple_delta: float = 0.0
		for y: int in range(240,440,2):
			for x: int in range(300,980,2):
				ripple_delta += absf(ripple_first.get_pixel(x,y).r-ripple_later.get_pixel(x,y).r)
		print("STORM_RIPPLE_DELTA: ",ripple_delta)
		check(ripple_delta > 10.0,"ripple animation changes the reflected road with other weather frozen")
		RenderingServer.global_shader_parameter_set("storm_ripple_time",weather.elapsed)
		await _capture("rain")
		var reflected: Image = root.get_texture().get_image()
		race.biome_environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
		await _capture("reflection-disabled")
		var unreflected: Image = root.get_texture().get_image()
		var reflection_delta: float = 0.0
		for y: int in range(240,440,4):
			for x: int in range(300,980,4):
				reflection_delta += absf(reflected.get_pixel(x,y).r-unreflected.get_pixel(x,y).r)
		print("STORM_REFLECTION_DELTA: ",reflection_delta)
		check(reflection_delta > 1.0,"reflected sky changes the rendered road view, not only material properties")
		race.biome_environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		# Consecutive stills verify progression of rain and fading/drifting droplets.
		weather.advance(1.2,false)
		await _capture("rain-later")
	var intervals_ok: bool = true
	for tick: int in range(3200):
		var previous_strikes: int = weather.strikes
		weather.advance(0.1,false)
		if weather.strikes != previous_strikes:
			intervals_ok = intervals_ok and weather.until_lightning >= 9.0 and weather.until_lightning <= 16.0
	check(intervals_ok and weather.strikes >= 20 and weather.strikes <= 37,"five-minute storm retains occasional separate strikes")
	check(weather.thunder_count >= weather.strikes-1,"each lightning event receives thunder")
	# Changing the active biome removes visual/audio nodes and resets the light rig.
	race.native_track.metadata.theme = "pine"
	race.call("_update_weather")
	await process_frame
	check(race.storm_weather == null and race.weather_layer == null and is_equal_approx(light.light_energy,1.2),"leaving Storm cleans up weather and restores daytime")
	race.native_track.metadata.theme = "storm"
	race.call("_update_weather")
	check(is_equal_approx(race.storm_weather.base_light_energy,0.5),"entering Storm from day uses overcast baseline")
	if "--capture" in OS.get_cmdline_user_args(): await _capture_tire_spray(race)
	race.queue_free()
	await process_frame
	await process_frame
	# Let the audio mixer retire its playback references before headless exit.
	await create_timer(0.15).timeout
	print("STORM_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _test_flash_profiles() -> void:
	var weather := StormWeather.new()
	var bounded: bool = true
	var gradual: bool = true
	var varied: bool = false
	var first := PackedVector2Array()
	for seed_value: int in range(64):
		weather.rng.seed = seed_value
		weather._build_flash_profile()
		if seed_value == 0: first = weather.flash_profile.duplicate()
		else: varied = varied or first != weather.flash_profile
		var peaks: int = 0
		for index: int in range(1,weather.flash_profile.size()-1):
			var knot: Vector2 = weather.flash_profile[index]
			weather.flash_age = knot.x
			bounded = bounded and is_equal_approx(weather.flash_strength(),knot.y)
			if knot.y > weather.flash_profile[index-1].y and knot.y > weather.flash_profile[index+1].y: peaks += 1
		bounded = bounded and peaks >= 2 and peaks <= 3 and weather.flash_profile[-1].x >= 0.98 and weather.flash_profile[-1].x < weather.FLASH_DURATION
		var rng_state: int = weather.rng.state
		var previous_strength: float = 0.0
		for sample: int in range(ceili(weather.FLASH_DURATION*120.0)+1):
			weather.flash_age = float(sample)/120.0
			var strength: float = weather.flash_strength()
			bounded = bounded and strength >= 0.0 and strength <= 0.32
			gradual = gradual and absf(strength-previous_strength) <= 0.03
			previous_strength = strength
		bounded = bounded and weather.rng.state == rng_state and weather.flash_strength() == 0.0
	check(bounded,"64 seeded strikes have 2-3 softer peaks, at least 0.98s duration and no random sampling during rendering")
	check(gradual,"lightning intensity changes gradually instead of fast high-contrast flicker")
	check(varied,"strike shape varies with the random seed")
	weather.rng.seed = 0
	weather._build_flash_profile()
	check(weather.flash_profile == first,"same seed reproduces the complete strike envelope")
	weather.free()

func _capture(label: String) -> void:
	for i: int in range(3): await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../docs/evidence/storm/"+label+".png"))


func _test_tire_spray() -> void:
	var track := NativeTrack.new()
	track.cell_size = 1.0
	track.grid_width = 40
	track.grid_height = 40
	track.half_extent = Vector2(20,20)
	track.cells.resize(1600)
	track.deck_cells.resize(1600)
	track.deck_cells.fill(0)
	track.metadata = {"theme":"pine"}
	var effect := SandDust.new()
	root.add_child(effect)
	var state := VehicleState.new()
	state.velocity = Vector2(0,18)
	var frame := DriveFrame.new()
	effect.sample(state,frame,track)
	check(effect.water_drops.is_empty(),"dry theme allocates no water spray")
	track.metadata.theme = "storm"
	var before: Array = state.snapshot()
	effect.sample(state,frame,track)
	check(effect.water_drops.size() == 4,"four droplet-only tire emitters")
	check(state.snapshot() == before,"spray does not mutate simulation")
	var fast: float = effect.water_drops[0].amount_ratio
	check(effect.water_drops.all(func(e: GPUParticles3D) -> bool: return e.emitting),"straight driving sprays without drift or throttle")
	state.velocity = Vector2(0,5)
	effect.sample(state,frame,track)
	check(effect.water_drops[0].amount_ratio < fast,"spray increases with speed")
	for kind: int in [1,2,3,4,5,6,7]:
		track.cells.fill(kind)
		effect.sample(state,frame,track)
		check(effect.water_drops.all(func(e: GPUParticles3D) -> bool: return not e.emitting),"non-road surface stops water spray "+str(kind))
	track.cells.fill(0)
	state.track_elevated = true
	effect.sample(state,frame,track)
	check(effect.water_drops[0].emitting,"wet bridge deck emits water spray")
	state.track_elevated = false
	state.velocity = Vector2(0,-18)
	effect.sample(state,frame,track)
	check((-effect.water_drops[0].global_basis.z).dot(VisualGeometry.world(-state.velocity.normalized())) > 0.99,"reverse spray follows actual contact travel")
	var left_process: ParticleProcessMaterial = effect.water_drops[0].process_material
	check((effect.water_drops[0].basis*left_process.direction).x < 0.0,"reverse fan still points outward from left tire")
	for car: String in VehicleCatalog.IDS:
		var config: HandlingConfig = VehicleCatalog.config(car)
		effect.wheelbase = config.wheelbase
		effect.track_width = config.track_width
		effect.sample(state,frame,track)
		check(is_equal_approx(effect.water_drops[0].position.distance_to(effect.water_drops[1].position),config.track_width),car+" spray uses actual tire spacing")
	# Put just the left tires onto grass: right tires must keep spraying.
	for row: int in range(40):
		for column: int in range(20): track.cells[row*40+column] = 1
	effect.sample(state,frame,track)
	check(not effect.water_drops[0].emitting and effect.water_drops[1].emitting,"independent wheel surface gating at road edge")
	track.cells.fill(0)
	for mode: String in ["stopped","airborne","rolled"]:
		state.velocity = Vector2.ZERO if mode == "stopped" else Vector2(0,18)
		state.jump_height = 1.0 if mode == "airborne" else 0.0
		state.roll_ticks = 10 if mode == "rolled" else 0
		effect.sample(state,frame,track)
		check(effect.water_drops.all(func(e: GPUParticles3D) -> bool: return not e.emitting),mode+" stops spray")
	state.roll_ticks = 0
	effect.sample(state,frame,track)
	effect.set_water_paused(true)
	check(effect.water_drops[0].speed_scale == 0.0,"pause freezes water particles")
	effect.set_water_paused(false)
	check(effect.water_drops[0].speed_scale == 1.0,"resume unfreezes water particles")
	track.metadata.theme = "pine"
	effect.sample(state,frame,track)
	check(not effect.water_drops[0].emitting,"leaving Storm stops spray")
	effect.clear()
	check(effect.water_drops.all(func(e: GPUParticles3D) -> bool: return not e.emitting),"restart/rewind clears spray")
	effect.free()


func _capture_tire_spray(race: Node) -> void:
	race.set_process(false)
	var state := VehicleState.new()
	state.heading = race.sim.state.heading
	state.velocity = state.forward()*18.0
	var origin: Vector2 = race.sim.state.position
	race.sim.state = state
	for index: int in range(60):
		state.position = origin+state.forward()*(float(index)*0.3-9.0)
		race.previous_position = state.position
		race.previous_heading = state.heading
		race.call("_process",0.0)
		race.sand_dust.set_water_paused(false)
		race.sand_dust.sample(state,DriveFrame.new(),race.native_track,race.bridge_presentation)
		await create_timer(1.0/60.0).timeout
		await RenderingServer.frame_post_draw
		if index == 30:
			check(race.sand_dust.water_drops[0].emitting,"capture car on wet asphalt")
			race.sand_dust.set_water_paused(true)
			await _capture("tire-spray")
	race.sand_dust.set_water_paused(true)
	await _capture("tire-spray-later")
