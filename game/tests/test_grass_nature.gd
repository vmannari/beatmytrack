extends SceneTree
var checks: int = 0
var failures: int = 0
const OUT: String = "res://../docs/evidence/grass-nature-2026-10-10"


func _initialize() -> void: call_deferred("run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", message)


func advance(nature: GrassNature, seconds: float, paused: bool = false, finished: bool = false) -> void:
	for tick: int in range(ceili(seconds * 60.0)): nature.present(1.0 / 60.0, paused, finished)


func clocks(nature: GrassNature) -> Array:
	return [nature.insect_gain, nature.insect_target, nature.drift_wait, nature.leaf_gain, nature.leaf_remaining, nature.leaf_wait, nature.rustles_started]


func run() -> void:
	var nature := GrassNature.new()
	# Fast schedule checks advance minutes without rendered frames. Reserve
	# real decoder starts/stops for the wall-time native capture below.
	nature.output_enabled = false
	root.add_child(nature)
	for theme: String in ["storm", "desert", "winter", "night_city"]:
		nature.configure(theme)
		advance(nature, 30.0)
		check(nature.get_child_count() == 0 and nature.rustles_started == 0, "grass-only nature: " + theme)
	nature.rng.seed = 4159
	nature.configure("pine")
	check(nature.get_child_count() == 2 and nature.insects.bus == "Vehicle" and nature.leaves.bus == "Vehicle", "two bounded nature voices follow sound volume")
	var loop: AudioStreamWAV = nature.insects.stream
	var leaf: AudioStreamWAV = nature.leaves.stream
	check(loop.loop_mode == AudioStreamWAV.LOOP_FORWARD and loop.loop_end == 40 * 44100, "insect loop retains long natural development")
	check(loop.data.slice(loop.data.size() - 2) == loop.data.slice(0, 2), "cyclic interpolation guard retained")
	check(leaf.loop_mode == AudioStreamWAV.LOOP_DISABLED and leaf.format == AudioStreamWAV.FORMAT_16_BITS and leaf.mix_rate == 44100, "leaf one-shot lossless import")
	check(leaf.data.slice(0, 2) == PackedByteArray([0, 0]) and leaf.data.slice(leaf.data.size() - 2) == PackedByteArray([0, 0]), "soft leaf endpoints")
	var offsets: Array[float] = []
	var targets: Array[float] = []
	var gaps: Array[float] = []
	var max_insects: float = 0.0
	var max_leaves: float = 0.0
	for race: int in range(6):
		nature.reset()
		check(nature.insect_gain == 0.0 and nature.leaf_gain == 0.0 and nature.leaf_remaining == 0.0, "retry resets both voices")
		check(nature.leaf_wait >= 4.0 and nature.leaf_wait <= 10.0, "opening rustle delay")
		offsets.append(nature.insect_offset)
		var previous: int = nature.rustles_started
		var target: float = nature.insect_target
		for tick: int in range(60 * 90):
			nature.present(1.0 / 60.0, false, false)
			max_insects = maxf(max_insects, nature.insect_gain)
			max_leaves = maxf(max_leaves, nature.leaf_gain)
			if nature.insect_target != target:
				targets.append(nature.insect_target)
				target = nature.insect_target
			if nature.rustles_started == previous: continue
			previous = nature.rustles_started
			gaps.append(nature.leaf_wait)
			check(nature.leaf_wait >= 8.0 and nature.leaf_wait <= 20.0, "sparse leaf intervals")
			check(nature.leaf_level >= 0.09 and nature.leaf_level <= 0.15 and nature.leaves.pitch_scale >= 0.90 and nature.leaves.pitch_scale <= 1.02, "restrained rustle gain/pitch")
	check(offsets.min() < offsets.max() and gaps.min() < gaps.max() and targets.min() < targets.max(), "race offsets, rustles and slow insect swells vary")
	check(max_insects > 0.03 and max_insects <= 0.075 and max_leaves > 0.05 and max_leaves <= 0.15, "nature remains below bird voice gain")
	nature.reset()
	nature.leaf_wait = 0.0
	advance(nature, 0.3)
	var before: Array = clocks(nature)
	advance(nature, 3.0, true)
	check(clocks(nature) == before, "pause freezes modulation and rustle schedule")
	nature.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	advance(nature, 3.0)
	check(clocks(nature) == before and nature.suspended, "OS suspension freezes nature")
	nature.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	advance(nature, 0.1)
	check(clocks(nature) != before and not nature.insects.stream_paused and not nature.leaves.stream_paused, "resume continues both layers")
	var count: int = nature.rustles_started
	advance(nature, 10.0, false, true)
	check(nature.insect_gain == 0.0 and nature.leaf_gain == 0.0 and nature.rustles_started == count and not nature.insects.playing and not nature.leaves.playing, "finish stops both layers without new rustles")
	nature.reset()
	var wait_time: float = nature.leaf_wait
	nature.present(100.0, false, false)
	check(nature.rustles_started == count and is_equal_approx(nature.leaf_wait, wait_time - 0.25), "long frame cannot catch up with bursts")
	GameSoundtrack.instance().apply_settings({"vehicle_volume": 0.0})
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(nature.insects.bus)) and AudioServer.is_bus_mute(AudioServer.get_bus_index(nature.leaves.bus)), "existing volume mute includes both layers")
	GameSoundtrack.instance().apply_settings({})
	nature.configure("night_city")
	check(nature.insect_gain == 0 and nature.leaf_gain == 0 and not nature.insects.playing and not nature.leaves.playing, "leaving grass stops nature")
	nature.configure("pine")
	check(nature.get_child_count() == 2 and nature.insects.stream == loop, "track cycling reuses voices and prepared loop")
	if "--capture" in OS.get_cmdline_user_args(): await capture(nature)
	nature.free()
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = TrackCompiler.compile(TrackDocument.create_default())
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	check(game.grass_nature != null and game.grass_nature.enabled and game.grass_birds.enabled, "actual grass race owns birds and subtle nature")
	var state: Array = game.sim.state.snapshot()
	game.grass_nature.output_enabled = false
	advance(game.grass_nature, 30.0)
	check(game.sim.state.snapshot() == state, "nature leaves canonical state unchanged")
	game.grass_nature.leaf_wait = 42.0
	game.restart()
	check(game.grass_nature.leaf_wait <= 10.0 and game.grass_nature.insect_gain == 0.0, "actual Retry resets nature")
	var voice_ref: WeakRef = weakref(game.grass_nature.insects)
	game.queue_free()
	await process_frame
	await process_frame
	check(voice_ref.get_ref() == null, "race exit releases nature")
	await create_timer(0.15).timeout
	print("GRASS_NATURE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func capture(nature: GrassNature) -> void:
	check(DisplayServer.get_name() != "headless", "native mixer capture")
	if DisplayServer.get_name() == "headless": return
	nature.output_enabled = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var birds := GrassBirds.new()
	root.add_child(birds)
	birds.configure("pine")
	var output_bus: int = AudioServer.get_bus_index("Master")
	var index: int = AudioServer.get_bus_effect_count(output_bus)
	var effect := AudioEffectRecord.new()
	effect.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(output_bus, effect)
	for mode: String in ["insects", "leaves", "birds", "mixed0", "mixed1", "paused", "muted", "finished"]:
		nature.rng.seed = 4159 + (1 if mode == "mixed1" else 0)
		nature.reset()
		birds.rng.seed = 3941
		birds.reset()
		nature.insect_offset = 38.0 if mode == "insects" else nature.insect_offset
		nature.leaf_wait = 0.0 if mode == "leaves" else nature.leaf_wait
		birds.wait_seconds = 0.0 if mode == "birds" else birds.wait_seconds
		await create_timer(0.2).timeout
		if mode in ["paused", "muted", "finished"]:
			advance(nature, 1.0)
			birds.present(0.25, false, false)
			if mode == "paused":
				nature.present(0.1, true, false)
				birds.present(0.1, true, false)
			elif mode == "muted": GameSoundtrack.instance().apply_settings({"vehicle_volume": 0.0})
			else:
				advance(nature, 1.0, false, true)
				for tick: int in range(60): birds.present(1.0 / 60.0, false, true)
			await create_timer(0.25).timeout
		var duration: int = 20000 if mode.begins_with("mixed") else 8000 if mode == "insects" else 6000 if mode == "birds" else 3000 if mode == "leaves" else 400
		var began: int = Time.get_ticks_msec()
		var previous_time: int = began
		var rustles: int = nature.rustles_started
		var leaf_events: Array = []
		var wraps: int = 0
		var previous_cursor: float = -1.0
		effect.set_recording_active(true)
		while Time.get_ticks_msec() - began < duration:
			await process_frame
			var now: int = Time.get_ticks_msec()
			var delta: float = (now - previous_time) / 1000.0
			previous_time = now
			if mode in ["insects", "leaves", "birds", "mixed0", "mixed1"]:
				nature.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
				birds.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
				if mode != "birds": nature.present(delta, false, false)
				if mode == "leaves": nature.insects.volume_linear = 0.0
				if mode == "insects": nature.leaves.volume_linear = 0.0
				if mode in ["birds", "mixed0", "mixed1"]: birds.present(delta, false, false)
			if nature.rustles_started != rustles:
				rustles = nature.rustles_started
				leaf_events.append({"seconds": (now - began) / 1000.0, "gap": nature.leaf_wait, "gain": nature.leaf_level, "pitch": nature.leaves.pitch_scale})
			if mode == "insects" and nature.insects.playing:
				var cursor: float = nature.insects.get_playback_position()
				if previous_cursor >= 0.0 and cursor + 0.2 < previous_cursor: wraps += 1
				previous_cursor = cursor
		effect.set_recording_active(false)
		check(effect.get_recording().save_to_wav(OUT.path_join(mode + ".wav")) == OK, "native recording: " + mode)
		if mode.begins_with("mixed"):
			check(not leaf_events.is_empty(), "mixed nature includes recorded leaf rustle")
			var file := FileAccess.open(OUT.path_join(mode + ".json"), FileAccess.WRITE)
			file.store_string(JSON.stringify({"insect_offset": nature.insect_offset, "insect_target": nature.insect_target, "rustles": leaf_events}, "\t"))
			file.close()
		if mode == "insects": check(wraps >= 1, "native insect playback crosses loop boundary")
		GameSoundtrack.instance().apply_settings({})
	AudioServer.remove_bus_effect(output_bus, index)
	birds.free()
