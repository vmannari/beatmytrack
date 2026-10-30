extends SceneTree
var checks: int = 0
var failures: int = 0
const OUT: String = "res://../docs/evidence/winter-owner-wind-2026-10-11"

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", message)

func advance(wind: WinterWind, seconds: float, paused: bool = false, finished: bool = false) -> void:
	for tick: int in range(ceili(seconds * 60.0)): wind.present(1.0 / 60.0, paused, finished)

func clocks(wind: WinterWind) -> Array:
	return [wind.gain, wind.opening, wind.strength, wind.gust_elapsed, wind.gust_wait, wind.gusts_started]

func run() -> void:
	var wind := WinterWind.new()
	wind.output_enabled = false
	root.add_child(wind)
	for theme: String in ["pine", "desert", "storm", "night_city"]:
		wind.configure(theme)
		advance(wind, 15.0)
		check(wind.player == null and wind.gusts_started == 0, "winter-only voice: " + theme)
	wind.rng.seed = 4611
	wind.configure("winter")
	check(wind.get_child_count() == 1 and wind.player.bus == "Vehicle", "one voice uses existing sound volume")
	for stream: AudioStreamOggVorbis in wind.loops:
		check(stream.packet_sequence.sampling_rate == 44100, "compressed original sample rate")
		check(stream.loop and stream.loop_offset == 0.0, "native cyclic Vorbis loop")
	check(absf(wind.loops[0].get_length() - 15.5) < 1.0 / 44100.0 and absf(wind.loops[1].get_length() - 13.5) < 1.0 / 44100.0, "complete owner-recorded blizzard variations")
	var phases: Array = []
	var sequences: Array = []
	var previous_variant: int = wind.variant
	var largest_step: float = 0.0
	for race: int in range(6):
		wind.reset()
		check(wind.variant != previous_variant and wind.gain == 0 and wind.opening == 0, "Retry changes gale and resets fade")
		previous_variant = wind.variant
		phases.append(wind.offset)
		var events: Array = []
		var previous_gust: int = wind.gusts_started
		var previous_gain: float = 0.0
		var bounded: bool = true
		for tick: int in range(60 * 60):
			wind.present(1.0 / 60.0, false, false)
			bounded = bounded and wind.gain >= 0 and wind.gain <= WinterWind.MAX_GAIN
			if tick >= 90: bounded = bounded and wind.gain >= WinterWind.BASE * 0.90
			largest_step = maxf(largest_step, absf(wind.gain - previous_gain))
			previous_gain = wind.gain
			if previous_gust == wind.gusts_started: continue
			previous_gust = wind.gusts_started
			events.append([tick, wind.gust_to, wind.gust_duration, wind.gust_wait])
			check(wind.gust_duration >= 2.5 and wind.gust_duration <= 5.0 and wind.gust_to >= 0 and wind.gust_to <= 1.0, "bounded winter gust")
		check(bounded and events.size() >= 6, "continuous steady floor with varying gusts")
		sequences.append(events)
	check(phases[0] != phases[1] and sequences[0] != sequences[1], "phase and gust sequence vary across races")
	check(largest_step < 0.012, "smooth opening and gusts")
	wind.reset()
	advance(wind, 2.0)
	var before: Array = clocks(wind)
	advance(wind, 3.0, true)
	check(clocks(wind) == before, "pause freezes wind and timing")
	wind.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	advance(wind, 3.0)
	check(clocks(wind) == before and wind.suspended, "background suspends wind")
	wind.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	advance(wind, 0.1)
	check(clocks(wind) != before and not wind.player.stream_paused, "foreground resumes same gale")
	var count: int = wind.gusts_started
	advance(wind, 5.0, false, true)
	check(wind.gain == 0 and not wind.player.playing and wind.gusts_started == count, "finish fades to silence without new gusts")
	wind.reset()
	var wait_time: float = wind.gust_wait
	wind.present(100.0, false, false)
	check(is_equal_approx(wind.gust_wait, wait_time - 0.25), "stalled frame cannot burst missed gusts")
	GameSoundtrack.instance().apply_settings({"vehicle_volume": 0.0})
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(wind.player.bus)), "sound mute includes winter wind")
	GameSoundtrack.instance().apply_settings({})
	wind.configure("desert")
	check(not wind.player.playing and wind.player.volume_linear == 0, "leaving winter stops immediately")
	wind.configure("winter")
	check(wind.get_child_count() == 1 and wind.loops.has(wind.player.stream), "cycling reuses prepared loops and one voice")
	if "--capture" in OS.get_cmdline_user_args(): await capture(wind)
	wind.free()
	var doc: Dictionary = TrackDocument.create_default()
	doc.theme = "winter"
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = TrackCompiler.compile(doc)
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	check(game.winter_wind != null and game.winter_wind.enabled and not game.desert_ambience.enabled and not game.grass_birds.enabled and not game.grass_nature.enabled, "actual Winter race owns only its matching ambience")
	game.winter_wind.output_enabled = false
	var snapshot: Array = game.sim.state.snapshot()
	advance(game.winter_wind, 30.0)
	check(game.sim.state.snapshot() == snapshot, "wind never changes canonical driving")
	game.winter_wind.gust_wait = 42.0
	game.restart()
	check(game.winter_wind.gust_wait <= 4.5 and game.winter_wind.opening == 0, "actual Retry refreshes Winter wind")
	var ref: WeakRef = weakref(game.winter_wind.player)
	game.queue_free()
	await process_frame
	await process_frame
	check(ref.get_ref() == null, "race exit frees the voice")
	await create_timer(0.15).timeout
	print("WINTER_WIND: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func capture(wind: WinterWind) -> void:
	check(DisplayServer.get_name() != "headless", "native mixer capture")
	if DisplayServer.get_name() == "headless": return
	wind.output_enabled = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var master_bus: int = AudioServer.get_bus_index("Master")
	var effect_index: int = AudioServer.get_bus_effect_count(master_bus)
	var effect := AudioEffectRecord.new()
	effect.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(master_bus, effect)
	for mode: String in ["gale_a", "gale_b", "race0", "race1", "paused", "muted", "finished", "driving"]:
		wind.rng.seed = 4611 + (1 if mode == "race1" else 0)
		wind.reset()
		if mode.begins_with("gale"):
			wind.variant = 0 if mode == "gale_a" else 1
			wind.player.stream = wind.loops[wind.variant]
			wind.offset = wind.player.stream.get_length() - 2.0
		var vehicle: VehicleAudio
		var state := VehicleState.new()
		var track: NativeTrack
		if mode == "driving":
			track = NativeTrack.read("res://resources/tracks/starter_circuit.json")
			track.metadata.theme = "winter"
			vehicle = VehicleAudio.new()
			root.add_child(vehicle)
			vehicle.configure("compact", VehicleCatalog.config("compact"))
			state.position = track.spawn
		await create_timer(0.2).timeout
		if mode in ["paused", "muted", "finished"]:
			advance(wind, 2.0)
			if mode == "paused": wind.present(0.1, true, false)
			elif mode == "muted": GameSoundtrack.instance().apply_settings({"vehicle_volume": 0.0})
			else: advance(wind, 1.0, false, true)
			await create_timer(0.25).timeout
		var duration: int = 20000 if mode.begins_with("race") else 8000 if mode == "driving" else 6000 if mode.begins_with("gale") else 400
		var began: int = Time.get_ticks_msec()
		var previous: int = began
		var last_cursor: float = -1.0
		var wraps: int = 0
		var last_gust: int = wind.gusts_started
		var events: Array = []
		effect.set_recording_active(true)
		while Time.get_ticks_msec() - began < duration:
			await process_frame
			var now: int = Time.get_ticks_msec()
			var delta: float = (now - previous) / 1000.0
			previous = now
			if mode.begins_with("gale") or mode.begins_with("race") or mode == "driving":
				wind.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
				wind.present(delta, false, false)
			if vehicle != null:
				state.tick += 1
				state.velocity = Vector2(0.0, 25.0)
				vehicle.present(state, DriveFrame.sample(0.0, 0.7, 0.0), track, delta, false)
			if last_gust != wind.gusts_started:
				last_gust = wind.gusts_started
				events.append({"seconds": (now - began) / 1000.0, "target": wind.gust_to, "duration": wind.gust_duration, "hold": wind.gust_wait})
			if mode.begins_with("gale") and wind.player.playing:
				var cursor: float = wind.player.get_playback_position()
				if last_cursor >= 0 and cursor + 0.2 < last_cursor: wraps += 1
				last_cursor = cursor
		effect.set_recording_active(false)
		check(effect.get_recording().save_to_wav(OUT.path_join(mode + ".wav")) == OK, "native recording: " + mode)
		if mode.begins_with("gale"): check(wraps >= 1, "actual gale loop crossing: " + mode)
		if mode.begins_with("race"):
			check(events.size() >= 2, "varied gusts in Winter race")
			var file := FileAccess.open(OUT.path_join(mode + ".json"), FileAccess.WRITE)
			file.store_string(JSON.stringify({"variant": wind.variant, "offset": wind.offset, "scale": wind.scale, "gusts": events}, "\t"))
			file.close()
		if vehicle != null: vehicle.free()
		GameSoundtrack.instance().apply_settings({})
	AudioServer.remove_bus_effect(master_bus, effect_index)
