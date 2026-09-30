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
			document = TrackLibrary.new().load_document(argument.trim_prefix("--track="))
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
	check(light.light_energy > weather.base_light_energy and weather.flash_strength() < 0.7,"restrained single lightning pulse")
	var elapsed: float = weather.elapsed
	weather.advance(10.0,true)
	check(weather.elapsed == elapsed and weather.rain_audio.stream_paused and not weather.thunder_audio.playing,"pause freezes weather and pending thunder")
	if "--capture" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../docs/evidence/storm"))
		await _capture("flash")
	weather.advance(3.0,false)
	check(weather.thunder_count == 1 and weather.thunder_audio.playing,"thunder actually starts after delay")
	weather.advance(0.0,true)
	check(weather.rain_audio.stream_paused and weather.thunder_audio.stream_paused,"pause silences active rain and thunder")
	check(is_equal_approx(light.light_energy,weather.base_light_energy),"lightning restores overcast light")
	check(race.sim.state.snapshot() == state_before,"weather never changes canonical car state")
	if "--capture" in OS.get_cmdline_user_args():
		await _capture("rain")
		# Consecutive stills verify progression of rain and fading/drifting droplets.
		weather.advance(1.2,false)
		await _capture("rain-later")
	var intervals_ok: bool = true
	for tick: int in range(3200):
		var previous_strikes: int = weather.strikes
		weather.advance(0.1,false)
		if weather.strikes != previous_strikes:
			intervals_ok = intervals_ok and weather.until_lightning >= 9.0 and weather.until_lightning <= 16.0
	check(intervals_ok and weather.strikes >= 20 and weather.strikes <= 37,"five-minute storm stays intermittent, no flash bursts")
	check(weather.thunder_count >= weather.strikes-1,"each lightning event receives thunder")
	# Changing the active biome removes visual/audio nodes and resets the light rig.
	race.native_track.metadata.theme = "pine"
	race.call("_update_weather")
	await process_frame
	check(race.storm_weather == null and race.weather_layer == null and is_equal_approx(light.light_energy,1.2),"leaving Storm cleans up weather and restores daytime")
	race.native_track.metadata.theme = "storm"
	race.call("_update_weather")
	check(is_equal_approx(race.storm_weather.base_light_energy,0.5),"entering Storm from day uses overcast baseline")
	race.queue_free()
	await process_frame
	await process_frame
	# Let the audio mixer retire its playback references before headless exit.
	await create_timer(0.15).timeout
	print("STORM_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _capture(label: String) -> void:
	for i: int in range(3): await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../docs/evidence/storm/"+label+".png"))
