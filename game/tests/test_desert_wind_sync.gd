extends "res://tests/test_desert_dune_edges.gd"
const SYNC_OUT: String = "res://../docs/evidence/desert-wind-sync-2026-10-24/"
const ENVELOPE = preload("res://track/desert_wind_envelope.gd")

func _initialize() -> void:
	super._initialize()
	capture_out = SYNC_OUT

func actual_app(track: NativeTrack) -> void:
	var ambience := DesertAmbience.new()
	ambience.output_enabled = false
	root.add_child(ambience)
	ambience.rng.seed = 231023
	ambience.configure("desert")
	for variant: int in range(3):
		var filename: String = ["desert_wind", "desert_wind_b", "desert_wind_c"][variant]
		check(FileAccess.get_sha256("res://assets/audio/ambience/" + filename + ".wav") == ENVELOPE.HASHES[variant][0] and FileAccess.get_sha256("res://assets/audio/ambience/" + filename + ".ogg") == ENVELOPE.HASHES[variant][1], "loudness guide belongs to the exact unchanged wind recording: " + filename)
		check(ENVELOPE.LEVELS[variant].size() == roundi(ambience.wind_loops[variant].get_length() * ENVELOPE.RATE), "guide covers one complete wind loop")
		check(absf(ENVELOPE.sample(variant, -0.001) - ENVELOPE.sample(variant, ambience.wind_loops[variant].get_length() - 0.001)) < 0.00001, "guide interpolation wraps across zero, including output latency")
	var original := GDScript.new()
	original.source_code = FileAccess.get_file_as_string(SYNC_OUT + "before/game/track/desert_ambience.gd").replace("class_name DesertAmbience\n", "").replace("class_name DesertAmbience\r\n", "")
	check(original.reload() == OK, "task-entry wind schedule compiles for seeded cadence comparison")
	var previous: Node = original.new()
	previous.output_enabled = false
	root.add_child(previous)
	var old_rises: int = 0
	var new_rises: int = 0
	for seed_value: int in range(12):
		for node: Node in [ambience, previous]:
			node.rng.seed = seed_value + 20261024
			node.configure("desert")
		for tick: int in range(90 * 30):
			for node: Node in [ambience, previous]:
				var before: int = node.gusts_started
				node.present(1.0 / 30.0, false, false)
				if node.gusts_started != before and node.gust_to >= 0.55:
					if node == ambience: new_rises += 1
					else: old_rises += 1
	check(new_rises >= old_rises * 1.20, "audible rising gusts recur at least 20 percent more often over twelve seeded 90-second drives")
	print("WIND_SYNC_CADENCE: old=", old_rises, " new=", new_rises)
	previous.free()
	var fx := DesertSandWind.new()
	root.add_child(fx); fx.configure(track)
	# A short sound pulse must enter at the newest births, then travel through
	# history rather than brighten old airborne particles in place.
	for tick: int in range(60): fx.present(1.0 / 60.0, Vector2(0, -18), 0.0, false, false, 0.0)
	for tick: int in range(15): fx.present(1.0 / 60.0, Vector2(0, -18), 1.0, false, false, 1.0)
	check(fx.lift_history[0] > 0.99 and fx.lift_history[12] == 0.0, "audible pulse lifts new roots without changing one-second-old births")
	for tick: int in range(60): fx.present(1.0 / 60.0, Vector2(0, -18), 0.0, false, false, 0.0)
	check(fx.lift_history[0] == 0.0 and fx.lift_history[12] > 0.99, "birth pulse travels with drifting particles after the sound falls")
	var frozen: Array = [fx.elapsed, fx.lift_elapsed, fx.previous_lift, fx.lift_history.duplicate()]
	fx.present(0.25, Vector2.ZERO, 1.0, true, false, 1.0)
	fx.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	fx.present(0.25, Vector2.ZERO, 1.0, false, false, 1.0)
	check(frozen == [fx.elapsed, fx.lift_elapsed, fx.previous_lift, fx.lift_history], "pause and background preserve complete birth history")
	fx.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	fx.present(0.1, Vector2.ZERO, 1.0, false, false, NAN)
	check(frozen == [fx.elapsed, fx.lift_elapsed, fx.previous_lift, fx.lift_history], "invalid audio envelope cannot corrupt history")
	fx.reset()
	check(fx.lift_history.count(0.0) == 48 and fx.lift_elapsed == 0.0 and fx.previous_lift == 0.0, "retry clears every old sound-triggered birth")
	fx.free(); ambience.free()
	await super.actual_app(track)

func capture(game: Node, track: NativeTrack, pass_index: int) -> void:
	# The inherited actual-App driving comparison uses deterministic presentation
	# time, so turn off live audio cursor reads for that accelerated fixture.
	game.desert_ambience.output_enabled = false
	await super.capture(game, track, pass_index)
	if pass_index != 1: return
	await synchronized_capture(game)

func synchronized_capture(game: Node) -> void:
	var folder: String = capture_out + RenderingServer.get_current_rendering_method() + "/"
	var ambience: DesertAmbience = game.desert_ambience
	var fx: DesertSandWind = game.desert_sand_wind
	ambience.rng.seed = 231023; ambience.reset(); fx.reset()
	ambience.output_enabled = true
	var bus: int = AudioServer.get_bus_count()
	AudioServer.add_bus(); AudioServer.set_bus_name(bus, "WindSyncReview")
	AudioServer.set_bus_send(bus, "Vehicle")
	var recording := AudioEffectRecord.new()
	recording.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(bus, recording)
	ambience.wind.bus = "WindSyncReview"; ambience.sand.bus = "WindSyncReview"
	var focus := Vector2(0, -18)
	game.sim.state.position = focus; game.previous_position = focus
	game.sim.state.velocity = Vector2.ZERO
	game.camera.follow(focus, Vector2.ZERO, 0.0, 0.0, true)
	var snapshot: Array = game.sim.state.snapshot().duplicate(true)
	var rows: Array[Dictionary] = []
	var previous_cursor: float = -1.0
	var wraps: int = 0
	var linked: bool = true
	var frame_index: int = 0
	var began: int = Time.get_ticks_usec()
	var previous_time: int = began
	var next_frame: float = 0.0
	recording.set_recording_active(true)
	while Time.get_ticks_usec() - began < 16000000:
		await draw(game)
		var now: int = Time.get_ticks_usec()
		var seconds: float = (now - began) / 1000000.0
		game.call("_process", (now - previous_time) / 1000000.0)
		previous_time = now
		linked = linked and is_equal_approx(fx.previous_lift, ambience.sand_lift)
		if previous_cursor >= 0.0 and ambience.wind_cursor < previous_cursor - 0.5: wraps += 1
		previous_cursor = ambience.wind_cursor
		if seconds < next_frame: continue
		next_frame = seconds + 1.0 / 12.0
		await draw(game)
		var name: String = "sync-%04d.jpg" % frame_index
		root.get_texture().get_image().save_jpg(folder + name, 0.92)
		rows.append({"seconds":(Time.get_ticks_usec()-began)/1000000.0,"frame":name,"cursor":ambience.wind_cursor,"wind_gain":ambience.wind_gain,"lift":ambience.sand_lift,"birth":fx.lift_history[0],"strength":ambience.strength})
		frame_index += 1
	recording.set_recording_active(false)
	check(recording.get_recording().save_to_wav(folder + "wind-sync.wav") == OK, "actual wind/sand mixer recording saved alongside native frames")
	check(linked and wraps >= 1, "actual Game connects the selected audible wind cursor to sand through a loop wrap")
	check(game.sim.state.snapshot() == snapshot, "recorded weather presentation leaves driving state exact")
	var receipt := FileAccess.open(folder + "sync.json", FileAccess.WRITE)
	receipt.store_string(JSON.stringify({"variant":ambience.wind_variant,"offset":ambience.wind_offset,"output_latency":AudioServer.get_output_latency(),"wraps":wraps,"samples":rows}, "\t")); receipt.close()
	print("WIND_SYNC_NATIVE: frames=", rows.size(), " wraps=", wraps, " linked=", linked)
	ambience.wind.bus = "Vehicle"; ambience.sand.bus = "Vehicle"
	AudioServer.remove_bus(bus)
