extends SceneTree
var checks: int = 0
var failures: int = 0
const OUT: String = "res://../docs/evidence/desert-rattle-variation-2026-10-11"

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", message)

func advance(snake: DesertRattlesnake, seconds: float, paused: bool = false, finished: bool = false) -> void:
	for tick: int in range(ceili(seconds * 60.0)): snake.present(1.0 / 60.0, paused, finished)

func clocks(snake: DesertRattlesnake) -> Array:
	return [snake.wait_seconds, snake.remaining, snake.elapsed, snake.gain, snake.calls_started, snake.source_offset, snake.duration, snake.rhythm_times, snake.rhythm_levels]

func phrase(snake: DesertRattlesnake) -> Dictionary:
	return {"variant": snake.variant, "gap": snake.wait_seconds, "level": snake.level, "pitch": snake.player.pitch_scale, "offset": snake.source_offset, "duration": snake.duration, "rhythm_times": Array(snake.rhythm_times), "rhythm_levels": Array(snake.rhythm_levels)}

func run() -> void:
	var snake := DesertRattlesnake.new()
	snake.output_enabled = false
	root.add_child(snake)
	for theme: String in ["pine", "winter", "storm", "night_city"]:
		snake.configure(theme)
		advance(snake, 30.0)
		check(snake.player == null and snake.calls_started == 0, "Desert-only rattle: " + theme)
	snake.rng.seed = 4811
	snake.configure("desert")
	check(snake.get_child_count() == 1 and snake.player.bus == "Vehicle", "one bounded voice follows sound settings")
	for clip: AudioStreamWAV in DesertRattlesnake.CLIPS:
		check(clip.format == AudioStreamWAV.FORMAT_16_BITS and clip.mix_rate == 44100 and not clip.stereo, "lossless recorded PCM")
		check(clip.loop_mode == AudioStreamWAV.LOOP_DISABLED, "rattles never loop")
		check(clip.data.slice(0, 2) == PackedByteArray([0, 0]) and clip.data.slice(clip.data.size() - 2) == PackedByteArray([0, 0]), "quiet recorded-clip edges")
	var sequences: Array = []
	var phrases: Array = []
	for race: int in range(6):
		snake.reset()
		check(snake.remaining == 0 and snake.gain == 0 and snake.wait_seconds >= 4.0 and snake.wait_seconds <= 10.0, "Retry clears tails and varies opening delay")
		var previous: int = snake.calls_started
		var variant: int = snake.variant
		var events: Array = []
		for tick: int in range(90 * 60):
			snake.present(1.0 / 60.0, false, false)
			if previous == snake.calls_started: continue
			previous = snake.calls_started
			check(snake.variant != variant, "no immediate recorded-clip repeats")
			variant = snake.variant
			check(snake.wait_seconds >= 12.0 and snake.wait_seconds <= 24.0, "sparse randomized gaps after complete call")
			check(snake.level >= 0.28 and snake.level <= 0.38 and snake.player.pitch_scale >= 0.97 and snake.player.pitch_scale <= 1.03, "bounded background level and subtle pitch")
			check(snake.source_offset >= 0.05 and snake.source_offset + snake.duration * snake.player.pitch_scale <= snake.player.stream.get_length() - 0.049, "random excerpt stays inside recording")
			check(snake.duration * snake.player.pitch_scale >= 1.349 and snake.duration * snake.player.pitch_scale <= 3.251, "rattle length varies within safe bounds")
			check(snake.rhythm_times.size() >= 4 and snake.rhythm_times.size() < 32 and snake.rhythm_times.size() == snake.rhythm_levels.size(), "bounded individual pulse pattern")
			for pulse: int in range(1, snake.rhythm_times.size()):
				check(snake.rhythm_times[pulse] > snake.rhythm_times[pulse - 1] and snake.rhythm_levels[pulse] >= 0.379 and snake.rhythm_levels[pulse] <= 1.0, "ordered smooth pulse points with audible floor")
			var event: Dictionary = phrase(snake)
			event.tick = tick
			events.append(event)
			phrases.append(phrase(snake))
		check(events.size() >= 3 and events.size() <= 7, "occasional rattles throughout race")
		sequences.append(events)
	check(sequences[0] != sequences[1], "race timing and mix vary")
	check(phrases.size() > 15, "many independently varied rattles exercised")
	for index: int in range(2, phrases.size()):
		check(phrases[index].offset != phrases[index - 2].offset and phrases[index].duration != phrases[index - 2].duration and phrases[index].rhythm_times != phrases[index - 2].rhythm_times and phrases[index].rhythm_levels != phrases[index - 2].rhythm_levels, "same recording returns with new excerpt, length and pulse pattern")
	snake.reset()
	snake.wait_seconds = 0.0
	advance(snake, 0.3)
	var before: Array = clocks(snake)
	advance(snake, 3.0, true)
	check(clocks(snake) == before, "pause freezes sound and interval")
	snake.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	advance(snake, 3.0)
	check(clocks(snake) == before and snake.suspended, "OS suspension freezes sound and interval")
	snake.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	advance(snake, 0.1)
	check(clocks(snake) != before and not snake.player.stream_paused, "resume continues same recorded call")
	check(snake.rhythm_times == before[7] and snake.rhythm_levels == before[8] and snake.source_offset == before[5], "resume preserves chosen rattle shape")
	var count: int = snake.calls_started
	advance(snake, 10.0, false, true)
	check(snake.gain == 0 and not snake.player.playing and snake.calls_started == count, "finish fades out and schedules nothing")
	snake.reset()
	var waiting: float = snake.wait_seconds
	snake.present(100.0, false, false)
	check(is_equal_approx(snake.wait_seconds, waiting - 0.25), "long frame cannot burst missed calls")
	GameSoundtrack.instance().apply_settings({"vehicle_volume": 0.0})
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(snake.player.bus)), "existing mute includes rattle")
	GameSoundtrack.instance().apply_settings({})
	snake.configure("winter")
	check(not snake.player.playing and snake.player.volume_linear == 0, "leaving Desert stops immediately")
	snake.configure("desert")
	check(snake.get_child_count() == 1, "cycling reuses one voice")
	check(snake.rhythm_times.is_empty() and snake.duration == 0.0 and snake.source_offset == 0.0, "reset clears previous excerpt and rhythm")
	if "--capture" in OS.get_cmdline_user_args(): await capture(snake)
	snake.free()
	var doc: Dictionary = TrackDocument.create_default()
	doc.theme = "desert"
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = TrackCompiler.compile(doc)
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	check(game.desert_rattlesnake.enabled and game.desert_ambience.enabled and not game.winter_wind.enabled, "actual Desert race owns rattle plus continuous wind")
	game.desert_rattlesnake.output_enabled = false
	var snapshot: Array = game.sim.state.snapshot()
	advance(game.desert_rattlesnake, 30.0)
	check(game.sim.state.snapshot() == snapshot, "rattles never affect canonical driving")
	game.desert_rattlesnake.wait_seconds = 42.0
	game.restart()
	check(game.desert_rattlesnake.wait_seconds <= 10.0 and game.desert_rattlesnake.remaining == 0, "actual Retry resets rattle scheduling")
	var ref: WeakRef = weakref(game.desert_rattlesnake.player)
	game.queue_free()
	await process_frame
	await process_frame
	check(ref.get_ref() == null, "exit frees rattle voice")
	await create_timer(0.15).timeout
	print("DESERT_RATTLESNAKE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func capture(snake: DesertRattlesnake) -> void:
	check(DisplayServer.get_name() != "headless", "native mixer capture")
	if DisplayServer.get_name() == "headless": return
	snake.output_enabled = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var wind := DesertAmbience.new()
	root.add_child(wind)
	wind.configure("desert")
	var bus: int = AudioServer.get_bus_index("Master")
	var effect_index: int = AudioServer.get_bus_effect_count(bus)
	var effect := AudioEffectRecord.new()
	effect.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(bus, effect)
	for mode: String in ["rattle_a", "rattle_b", "rattle_a_alt", "rattle_b_alt", "desert0", "desert1", "paused", "muted", "finished", "driving"]:
		snake.rng.seed = 4811 + (1 if mode == "desert1" else 7 if mode.ends_with("alt") else 0)
		snake.reset()
		wind.reset()
		if mode.begins_with("rattle"):
			snake.variant = 1 if mode.begins_with("rattle_a") else 0
			snake.wait_seconds = 0.0
		var vehicle: VehicleAudio
		var state := VehicleState.new()
		var track: NativeTrack
		if mode == "driving":
			track = NativeTrack.read("res://resources/tracks/starter_circuit.json")
			track.metadata.theme = "desert"
			vehicle = VehicleAudio.new()
			root.add_child(vehicle)
			vehicle.configure("compact", VehicleCatalog.config("compact"))
			state.position = track.spawn
		await create_timer(0.2).timeout
		if mode in ["paused", "muted", "finished"]:
			snake.wait_seconds = 0.0
			advance(snake, 0.3)
			if mode == "paused": snake.present(0.1, true, false)
			elif mode == "muted": GameSoundtrack.instance().apply_settings({"vehicle_volume": 0.0})
			else: advance(snake, 1.0, false, true)
			await create_timer(0.25).timeout
		var duration: int = 40000 if mode.begins_with("desert") else 15000 if mode == "driving" else 5000 if mode.begins_with("rattle") else 400
		var began: int = Time.get_ticks_msec()
		var previous_time: int = began
		var previous_call: int = snake.calls_started
		var events: Array = []
		effect.set_recording_active(true)
		while Time.get_ticks_msec() - began < duration:
			await process_frame
			var now: int = Time.get_ticks_msec()
			var delta: float = (now - previous_time) / 1000.0
			previous_time = now
			if mode.begins_with("rattle") or mode.begins_with("desert") or mode == "driving":
				snake.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
				snake.present(delta, false, false)
			if mode.begins_with("desert") or mode == "driving":
				wind.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
				wind.present(delta, false, false)
			if vehicle != null:
				state.tick += 1
				state.velocity = Vector2(0.0, 25.0)
				vehicle.present(state, DriveFrame.sample(0.0, 0.7, 0.0), track, delta, false)
			if previous_call != snake.calls_started:
				previous_call = snake.calls_started
				var event: Dictionary = phrase(snake)
				event.seconds = (now - began) / 1000.0
				events.append(event)
		effect.set_recording_active(false)
		check(effect.get_recording().save_to_wav(OUT.path_join(mode + ".wav")) == OK, "native recording: " + mode)
		if mode.begins_with("desert") or mode.begins_with("rattle") or mode == "driving":
			check(events.size() >= (2 if mode.begins_with("desert") else 1), "rattles occur over uninterrupted wind")
			var file := FileAccess.open(OUT.path_join(mode + ".json"), FileAccess.WRITE)
			file.store_string(JSON.stringify(events, "\t"))
			file.close()
		if vehicle != null: vehicle.free()
		for tick: int in range(60): wind.present(1.0 / 60.0, false, true)
		GameSoundtrack.instance().apply_settings({})
	AudioServer.remove_bus_effect(bus, effect_index)
	wind.free()
