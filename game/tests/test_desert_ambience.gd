extends SceneTree
var checks: int = 0
var failures: int = 0
const OUT: String = "res://../docs/evidence/desert-wind-presence-2026-10-11"


func _initialize() -> void: call_deferred("run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", message)


func advance(ambience: DesertAmbience, seconds: float, paused: bool = false, finished: bool = false) -> void:
	for tick: int in range(ceili(seconds * 60.0)): ambience.present(1.0 / 60.0, paused, finished)


func clocks(ambience: DesertAmbience) -> Array:
	return [ambience.wind_gain, ambience.sand_gain, ambience.opening, ambience.strength, ambience.gust_elapsed, ambience.gust_wait, ambience.gusts_started]


func run() -> void:
	var ambience := DesertAmbience.new()
	ambience.output_enabled = false
	root.add_child(ambience)
	for theme: String in ["pine", "storm", "winter", "night_city"]:
		ambience.configure(theme)
		advance(ambience, 20.0)
		check(ambience.get_child_count() == 0 and ambience.gusts_started == 0, "no desert voices in " + theme)
	ambience.rng.seed = 4201
	ambience.configure("desert")
	check(ambience.get_child_count() == 2 and ambience.wind.bus == "Vehicle" and ambience.sand.bus == "Vehicle", "two bounded voices use existing sound settings")
	var wind_stream: AudioStream = ambience.wind_loops[0]
	var streams: Array[AudioStreamOggVorbis] = []
	streams.assign(ambience.wind_loops)
	streams.append(ambience.sand.stream)
	for stream: AudioStreamOggVorbis in streams:
		check(stream.packet_sequence.sampling_rate == 44100, "compressed original sample rate")
		check(stream.loop and stream.loop_offset == 0.0, "full-file loop")
		check(stream.get_length() > 10.0, "complete long loop retained")
	check(ambience.wind_loops.size() == 3 and absf(ambience.wind_loops[0].get_length() - 12.0) < 1.0 / 44100.0 and absf(ambience.wind_loops[1].get_length() - 14.0) < 1.0 / 44100.0 and absf(ambience.wind_loops[2].get_length() - 12.0) < 1.0 / 44100.0 and absf(ambience.sand.stream.get_length() - 29.0) < 1.0 / 44100.0, "three complete owner-wind variants and retained sand")
	var variants: Array[int] = [ambience.wind_variant]
	var phases: Array = []
	var sequences: Array = []
	var max_wind_step: float = 0.0
	var max_sand_step: float = 0.0
	for race: int in range(6):
		ambience.reset()
		check(ambience.wind_variant != variants.back(), "wind section never immediately repeats on Retry")
		variants.append(ambience.wind_variant)
		check(ambience.wind_gain == 0 and ambience.sand_gain == 0 and ambience.strength == 0, "retry resets fade and gust")
		phases.append([ambience.wind_offset, ambience.sand_offset, ambience.wind_scale, ambience.sand_scale])
		var previous: int = ambience.gusts_started
		var sequence: Array = []
		var previous_wind: float = 0.0
		var previous_sand: float = 0.0
		var bounded: bool = true
		for tick: int in range(60 * 90):
			ambience.present(1.0 / 60.0, false, false)
			bounded = bounded and ambience.wind_gain >= 0 and ambience.wind_gain <= DesertAmbience.WIND_MAX and ambience.sand_gain >= 0 and ambience.sand_gain <= DesertAmbience.SAND_MAX and ambience.sand_gain < ambience.wind_gain
			max_wind_step = maxf(max_wind_step, absf(ambience.wind_gain - previous_wind))
			max_sand_step = maxf(max_sand_step, absf(ambience.sand_gain - previous_sand))
			previous_wind = ambience.wind_gain
			previous_sand = ambience.sand_gain
			if previous == ambience.gusts_started: continue
			previous = ambience.gusts_started
			sequence.append([tick, ambience.gust_to, ambience.gust_duration, ambience.gust_wait])
			check(ambience.gust_duration >= 3.5 and ambience.gust_duration <= 7.0 and ambience.gust_to >= 0 and ambience.gust_to <= 1.0, "broad bounded gust envelope")
		check(bounded and sequence.size() >= 6, "steady background with quieter sand and varied gusts")
		sequences.append(sequence)
	check(phases[0] != phases[1] and sequences[0] != sequences[1], "retries vary loop phase, balance and gust timing")
	for index: int in [0, 3]:
		check(variants[index] != variants[index + 1] and variants[index] != variants[index + 2] and variants[index + 1] != variants[index + 2], "each shuffled bag uses all three wind sections")
	check(max_wind_step / DesertAmbience.WIND_MAX < (0.004 / 0.297) and max_sand_step < 0.002, "same proportional transition bound at increased wind volume")
	ambience.reset()
	advance(ambience, 3.0)
	check(ambience.wind_gain >= 0.38 * 0.90, "wind remains audible between gusts after opening")
	check(ambience.wind_gain > 0 and ambience.sand_gain > 0, "ambient sound needs no movement or wheel contact")
	var before: Array = clocks(ambience)
	advance(ambience, 5.0, true)
	check(clocks(ambience) == before, "pause freezes fades and gust timing")
	ambience.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	advance(ambience, 5.0)
	check(clocks(ambience) == before and ambience.suspended, "OS background freezes sound")
	ambience.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	advance(ambience, 0.1)
	check(clocks(ambience) != before and not ambience.wind.stream_paused and not ambience.sand.stream_paused, "resume continues same ambience")
	var count: int = ambience.gusts_started
	advance(ambience, 10.0, false, true)
	check(ambience.wind_gain == 0 and ambience.sand_gain == 0 and ambience.gusts_started == count and not ambience.wind.playing and not ambience.sand.playing, "finish fades out and stops scheduling")
	ambience.reset()
	var waiting: float = ambience.gust_wait
	ambience.present(100.0, false, false)
	check(is_equal_approx(ambience.gust_wait, waiting - 0.25), "stalled frame cannot burst through gusts")
	GameSoundtrack.instance().apply_settings({"vehicle_volume": 0.0})
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(ambience.wind.bus)), "existing mute covers desert ambience")
	GameSoundtrack.instance().apply_settings({})
	ambience.configure("pine")
	check(ambience.wind.volume_linear == 0 and ambience.sand.volume_linear == 0 and not ambience.wind.playing and not ambience.sand.playing, "biome switch stops both layers")
	ambience.configure("desert")
	check(ambience.get_child_count() == 2 and ambience.wind_loops[0] == wind_stream and ambience.wind_loops.has(ambience.wind.stream), "cycling reuses prepared variant streams without new voices")
	if "--capture" in OS.get_cmdline_user_args(): await capture(ambience)
	ambience.free()
	var document: Dictionary = TrackDocument.create_default()
	document.theme = "desert"
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = TrackCompiler.compile(document)
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	check(game.desert_ambience != null and game.desert_ambience.enabled and not game.grass_nature.enabled and not game.grass_birds.enabled, "actual desert race has correct ambience isolation")
	game.desert_ambience.output_enabled = false
	var snapshot: Array = game.sim.state.snapshot()
	advance(game.desert_ambience, 30.0)
	check(game.sim.state.snapshot() == snapshot, "gusts leave canonical state unchanged")
	game.desert_ambience.gust_wait = 42.0
	game.restart()
	check(game.desert_ambience.gust_wait <= 6.0 and game.desert_ambience.opening == 0, "actual Retry resets ambience")
	var ref: WeakRef = weakref(game.desert_ambience.wind)
	game.queue_free()
	await process_frame
	await process_frame
	check(ref.get_ref() == null, "exit releases voices")
	await create_timer(0.15).timeout
	print("DESERT_AMBIENCE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func capture(ambience: DesertAmbience) -> void:
	check(DisplayServer.get_name() != "headless", "native mixer capture")
	if DisplayServer.get_name() == "headless": return
	ambience.output_enabled = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var bus: int = AudioServer.get_bus_index("Master")
	var index: int = AudioServer.get_bus_effect_count(bus)
	var effect := AudioEffectRecord.new()
	effect.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(bus, effect)
	var wind_bus: int = AudioServer.get_bus_count()
	AudioServer.add_bus()
	AudioServer.set_bus_name(wind_bus, "WindComponentReview")
	AudioServer.set_bus_send(wind_bus, "Vehicle")
	var sand_bus: int = AudioServer.get_bus_count()
	AudioServer.add_bus()
	AudioServer.set_bus_name(sand_bus, "SandComponentReview")
	AudioServer.set_bus_send(sand_bus, "Vehicle")
	ambience.wind.bus = "WindComponentReview"
	ambience.sand.bus = "SandComponentReview"
	var components_only: bool = "--components-only" in OS.get_cmdline_user_args()
	var modes: Array[String] = ["wind", "wind_b", "wind_c", "sand", "mixed0", "mixed1", "paused", "muted", "finished"]
	if components_only: modes.assign(["wind", "wind_b", "wind_c", "sand"])
	for mode: String in modes:
		# Bus muting prevents the audio thread seeing transient gain writes from
		# the other component between present() and an immediate volume override.
		AudioServer.set_bus_mute(wind_bus, mode == "sand")
		AudioServer.set_bus_mute(sand_bus, mode.begins_with("wind"))
		ambience.rng.seed = 4201 + (1 if mode == "mixed1" else 0)
		ambience.reset()
		if mode.begins_with("wind"):
			var variant: int = 1 if mode == "wind_b" else 2 if mode == "wind_c" else 0
			ambience.wind_variant = variant
			ambience.wind.stream = ambience.wind_loops[variant]
			ambience.wind_offset = ambience.wind.stream.get_length() - 2.0
		if mode == "sand": ambience.sand_offset = 27.0
		await create_timer(0.2).timeout
		if mode in ["paused", "muted", "finished"]:
			advance(ambience, 2.0)
			if mode == "paused": ambience.present(0.1, true, false)
			elif mode == "muted": GameSoundtrack.instance().apply_settings({"vehicle_volume": 0.0})
			else: advance(ambience, 1.0, false, true)
			await create_timer(0.25).timeout
		var duration: int = 20000 if mode.begins_with("mixed") else 6000 if mode.begins_with("wind") else 8000 if mode == "sand" else 400
		var began: int = Time.get_ticks_msec()
		var previous_time: int = began
		var previous_cursor: float = -1.0
		var wraps: int = 0
		var previous_gust: int = ambience.gusts_started
		var events: Array = []
		effect.set_recording_active(true)
		while Time.get_ticks_msec() - began < duration:
			await process_frame
			var now: int = Time.get_ticks_msec()
			var delta: float = (now - previous_time) / 1000.0
			previous_time = now
			if mode.begins_with("wind") or mode in ["sand", "mixed0", "mixed1"]:
				ambience.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
				ambience.present(delta, false, false)
			if previous_gust != ambience.gusts_started:
				previous_gust = ambience.gusts_started
				events.append({"seconds": (now - began) / 1000.0, "target": ambience.gust_to, "duration": ambience.gust_duration, "hold": ambience.gust_wait})
			if mode.begins_with("wind") or mode == "sand":
				var voice: AudioStreamPlayer = ambience.wind if mode.begins_with("wind") else ambience.sand
				if voice.playing:
					var cursor: float = voice.get_playback_position()
					if previous_cursor >= 0 and cursor + 0.2 < previous_cursor: wraps += 1
					previous_cursor = cursor
		effect.set_recording_active(false)
		check(effect.get_recording().save_to_wav(OUT.path_join(mode + ".wav")) == OK, "native recording: " + mode)
		if mode.begins_with("wind") or mode == "sand": check(wraps >= 1, "actual loop crossing: " + mode)
		if mode.begins_with("mixed"):
			check(events.size() >= 2, "combined mix has rising/falling gusts")
			var file := FileAccess.open(OUT.path_join(mode + ".json"), FileAccess.WRITE)
			file.store_string(JSON.stringify({"wind_variant": ambience.wind_variant, "wind_offset": ambience.wind_offset, "sand_offset": ambience.sand_offset, "wind_scale": ambience.wind_scale, "sand_scale": ambience.sand_scale, "gusts": events}, "\t"))
			file.close()
		GameSoundtrack.instance().apply_settings({})
	AudioServer.set_bus_mute(wind_bus, false)
	AudioServer.set_bus_mute(sand_bus, false)
	if not components_only: await capture_vehicle_mix(ambience, effect)
	ambience.wind.bus = "Vehicle"
	ambience.sand.bus = "Vehicle"
	AudioServer.remove_bus(sand_bus)
	AudioServer.remove_bus(wind_bus)
	AudioServer.remove_bus_effect(bus, index)


func capture_vehicle_mix(ambience: DesertAmbience, master_record: AudioEffectRecord) -> void:
	# Controlled real mixer at fixed speeds; no race submission or player persistence.
	var track: NativeTrack = NativeTrack.read("res://resources/tracks/starter_circuit.json")
	track.metadata.theme = "desert"
	track.cells.fill(0)
	var vehicle := VehicleAudio.new()
	root.add_child(vehicle)
	vehicle.configure("compact", VehicleCatalog.config("compact"))
	var state := VehicleState.new()
	state.position = track.spawn
	var presence_bus: int = AudioServer.get_bus_count()
	AudioServer.add_bus()
	AudioServer.set_bus_name(presence_bus, "DesertPresenceReview")
	AudioServer.set_bus_send(presence_bus, "Vehicle")
	var presence_record := AudioEffectRecord.new()
	presence_record.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(presence_bus, presence_record)
	var engine_bus: int = AudioServer.get_bus_index("Engine")
	var engine_index: int = AudioServer.get_bus_effect_count(engine_bus)
	var engine_record := AudioEffectRecord.new()
	engine_record.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(engine_bus, engine_record)
	ambience.wind.bus = "DesertPresenceReview"
	ambience.sand.bus = "DesertPresenceReview"
	for mode: String in ["stationary", "driving"]:
		ambience.rng.seed = 4511
		ambience.reset()
		vehicle.reset()
		var began: int = Time.get_ticks_msec()
		var previous: int = began
		while Time.get_ticks_msec() - began < 9500:
			await process_frame
			var now: int = Time.get_ticks_msec()
			var delta: float = (now - previous) / 1000.0
			previous = now
			ambience.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
			ambience.present(delta, false, false)
			state.tick += 1
			state.velocity = Vector2(0.0, 25.0) if mode == "driving" else Vector2.ZERO
			vehicle.present(state, DriveFrame.sample(0.0, 0.7 if mode == "driving" else 0.0, 0.0), track, delta, false)
			if now - began >= 1500 and not master_record.is_recording_active():
				master_record.set_recording_active(true)
				presence_record.set_recording_active(true)
				engine_record.set_recording_active(true)
		master_record.set_recording_active(false)
		presence_record.set_recording_active(false)
		engine_record.set_recording_active(false)
		for item: Array in [[master_record, mode], [presence_record, mode + "-ambience"], [engine_record, mode + "-engine"]]:
			check((item[0] as AudioEffectRecord).get_recording().save_to_wav(OUT.path_join(str(item[1]) + ".wav")) == OK, "controlled full-mixer recording: " + str(item[1]))
		vehicle.present(state, DriveFrame.new(), track, 0.1, true)
		advance(ambience, 1.0, false, true)
		await create_timer(0.2).timeout
	ambience.wind.bus = "Vehicle"
	ambience.sand.bus = "Vehicle"
	AudioServer.remove_bus_effect(engine_bus, engine_index)
	AudioServer.remove_bus(presence_bus)
	vehicle.free()
