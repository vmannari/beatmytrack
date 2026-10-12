extends SceneTree
var checks: int = 0
var failures: int = 0
const OUT: String = "res://../docs/evidence/grass-birds-2026-10-10"


func _initialize() -> void: call_deferred("run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", message)


func advance(birds: GrassBirds, seconds: float, paused: bool = false, finished: bool = false) -> void:
	for tick: int in range(ceili(seconds * 60.0)):
		birds.present(1.0 / 60.0, paused, finished)


func run() -> void:
	var birds := GrassBirds.new()
	root.add_child(birds)
	for theme: String in ["desert", "winter", "storm", "night_city"]:
		birds.configure(theme)
		advance(birds, 15.0)
		check(birds.player == null and birds.calls_started == 0, "other biome has no birds: " + theme)
	birds.rng.seed = 3941
	birds.configure("pine")
	var voice: AudioStreamPlayer = birds.player
	check(voice != null and voice.bus == "Vehicle" and birds.get_child_count() == 1, "one grass voice follows sound volume")
	for clip: AudioStreamWAV in GrassBirds.CLIPS:
		check(clip.loop_mode == AudioStreamWAV.LOOP_DISABLED, "bird phrases never loop")
		check(clip.format == AudioStreamWAV.FORMAT_16_BITS and clip.mix_rate == 44100 and not clip.stereo, "authored mono PCM import")
		check(clip.data.slice(0, 2) == PackedByteArray([0, 0]) and clip.data.slice(clip.data.size() - 2) == PackedByteArray([0, 0]), "click-free phrase edges")
	var orders: Array = []
	var gaps: Array[float] = []
	var pitches: Array[float] = []
	var levels: Array[float] = []
	for race: int in range(8):
		birds.reset()
		check(birds.wait_seconds >= 0.6 and birds.wait_seconds <= 2.8 and birds.gain == 0.0, "retry resets opening and active voice")
		var order: Array[int] = []
		var previous: int = birds.last_clip
		var count: int = birds.calls_started
		for tick: int in range(60 * 90):
			birds.present(1.0 / 60.0, false, false)
			if birds.calls_started == count: continue
			count = birds.calls_started
			order.append(birds.last_clip)
			check(previous != birds.last_clip, "no consecutive repeat, including bag/race boundaries")
			previous = birds.last_clip
			check(birds.wait_seconds >= GrassBirds.MIN_GAP * birds.gap_scale and birds.wait_seconds <= GrassBirds.MAX_GAP * birds.gap_scale, "bounded randomized silence after complete call")
			check(voice.pitch_scale >= 0.98 and voice.pitch_scale <= 1.02 and birds.call_level >= 0.216 and birds.call_level <= 0.304, "subtle pitch and softer background gain")
			gaps.append(birds.wait_seconds)
			pitches.append(voice.pitch_scale)
			levels.append(birds.call_level)
		check(order.size() >= 6, "grass race contains several calls")
		for index: int in range(0, order.size() - 2, 3):
			check(order[index] != order[index + 1] and order[index] != order[index + 2] and order[index + 1] != order[index + 2], "shuffle bag covers all three phrases")
		if order not in orders: orders.append(order)
	check(orders.size() > 1 and gaps.min() < gaps.max() and pitches.min() < pitches.max() and levels.min() < levels.max(), "race sequences, gaps, pitch and gain vary")
	birds.reset()
	birds.wait_seconds = 0.0
	advance(birds, 0.2)
	var remaining: float = birds.remaining
	var wait_time: float = birds.wait_seconds
	var gain: float = birds.gain
	advance(birds, 3.0, true)
	check(birds.remaining == remaining and birds.wait_seconds == wait_time and birds.gain == gain and (voice.stream_paused if DisplayServer.get_name() != "headless" else not voice.playing), "pause freezes call and schedule")
	birds.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	advance(birds, 3.0)
	check(birds.remaining == remaining and birds.wait_seconds == wait_time and (voice.stream_paused if DisplayServer.get_name() != "headless" else not voice.playing), "background freezes call and schedule")
	birds.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	advance(birds, 0.1)
	check(birds.remaining < remaining and not voice.stream_paused, "foreground resumes same phrase")
	var calls: int = birds.calls_started
	advance(birds, 20.0, false, true)
	check(birds.gain == 0.0 and birds.remaining == 0.0 and not voice.playing and birds.calls_started == calls, "finish fades and schedules no new calls")
	birds.reset()
	remaining = birds.wait_seconds
	birds.present(100.0, false, false)
	check(birds.calls_started == calls and is_equal_approx(birds.wait_seconds, remaining - 0.25), "long frame cannot burst missed calls")
	GameSoundtrack.instance().apply_settings({"vehicle_volume": 0.0})
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(voice.bus)), "sound mute includes birds")
	GameSoundtrack.instance().apply_settings({})
	birds.configure("storm")
	advance(birds, 20.0)
	check(birds.calls_started == calls and not voice.playing and voice.volume_linear == 0.0, "leaving grass stops voice immediately")
	birds.configure("pine")
	check(birds.player == voice and birds.get_child_count() == 1, "biome cycling reuses bounded voice")
	if "--capture" in OS.get_cmdline_user_args(): await capture(birds)
	birds.free()
	var doc: Dictionary = TrackDocument.create_default()
	doc.theme = "pine"
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = TrackCompiler.compile(doc)
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	check(game.grass_birds != null and game.grass_birds.enabled, "actual grass race owns ambience")
	var snapshot: Array = game.sim.state.snapshot()
	advance(game.grass_birds, 30.0)
	check(game.sim.state.snapshot() == snapshot, "ambience does not mutate canonical state")
	game.grass_birds.wait_seconds = 42.0
	game.restart()
	check(game.grass_birds.wait_seconds <= 2.8 and game.grass_birds.remaining == 0.0, "actual Retry resets race variation")
	var ref: WeakRef = weakref(game.grass_birds.player)
	game.queue_free()
	await process_frame
	await process_frame
	check(ref.get_ref() == null, "race exit frees bird voice")
	await create_timer(0.15).timeout
	print("GRASS_BIRDS: %d checks, %d failures; %d distinct race sequences" % [checks, failures, orders.size()])
	quit(1 if failures else 0)


func capture(birds: GrassBirds) -> void:
	check(DisplayServer.get_name() != "headless", "native output required for capture")
	if DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var bus: int = AudioServer.get_bus_count()
	AudioServer.add_bus()
	AudioServer.set_bus_name(bus, "BirdReview")
	AudioServer.set_bus_send(bus, "Vehicle")
	var effect := AudioEffectRecord.new()
	effect.format = AudioStreamWAV.FORMAT_16_BITS
	var output_bus: int = AudioServer.get_bus_index("Master")
	var effect_index: int = AudioServer.get_bus_effect_count(output_bus)
	AudioServer.add_bus_effect(output_bus, effect)
	birds.player.bus = "BirdReview"
	for race: int in range(2):
		birds.rng.seed = 3941 + race
		birds.reset()
		birds.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
		await create_timer(0.2).timeout
		effect.set_recording_active(true)
		var start: int = Time.get_ticks_msec()
		var previous: int = birds.calls_started
		var previous_time: int = Time.get_ticks_msec()
		var events: Array = []
		while Time.get_ticks_msec() - start < 22000:
			await process_frame
			birds.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
			var current_time: int = Time.get_ticks_msec()
			birds.present((current_time - previous_time) / 1000.0, false, false)
			previous_time = current_time
			if previous != birds.calls_started:
				previous = birds.calls_started
				events.append({"seconds": (Time.get_ticks_msec() - start) / 1000.0, "clip": birds.last_clip, "gap": birds.wait_seconds, "pitch": birds.player.pitch_scale, "gain": birds.call_level})
		effect.set_recording_active(false)
		check(effect.get_recording().save_to_wav(OUT.path_join("race%d.wav" % race)) == OK, "native bird review recording")
		var file := FileAccess.open(OUT.path_join("race%d.json" % race), FileAccess.WRITE)
		file.store_string(JSON.stringify(events, "\t"))
		file.close()
		check(events.size() >= 2, "native recording contains varied bird phrases")
	for mode: String in ["paused", "muted", "finished"]:
		birds.reset()
		birds.wait_seconds = 0.0
		birds.present(0.1, false, false)
		birds.present(0.1, false, false)
		if mode == "paused": birds.present(0.1, true, false)
		elif mode == "muted": GameSoundtrack.instance().apply_settings({"vehicle_volume": 0.0})
		else: advance(birds, 1.0, false, true)
		await create_timer(0.25).timeout
		effect.set_recording_active(true)
		await create_timer(0.4).timeout
		effect.set_recording_active(false)
		check(effect.get_recording().save_to_wav(OUT.path_join(mode + ".wav")) == OK, "native silence recording: " + mode)
		GameSoundtrack.instance().apply_settings({})
	birds.player.bus = "Vehicle"
	AudioServer.remove_bus_effect(output_bus, effect_index)
	AudioServer.remove_bus(bus)
