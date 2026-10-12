extends SceneTree
var checks: int = 0
var failures: int = 0
const OUT: String = "res://../docs/evidence/night-cicadas-2026-10-09"

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",message)

func run() -> void:
	var ambience := NightAmbience.new()
	root.add_child(ambience)
	for theme: String in ["pine","coast","desert","winter","storm"]:
		ambience.configure(theme)
		check(ambience.player == null,"no voice allocated for " + theme)
	ambience.configure("night_city")
	check(ambience.get_child_count() == 1,"night allocates one bounded voice")
	var player: AudioStreamPlayer = ambience.player
	var stream: AudioStreamWAV = player.stream
	check(player.bus == "Vehicle","ambience follows existing sound volume")
	check(stream.format == AudioStreamWAV.FORMAT_16_BITS and not stream.stereo and stream.mix_rate == 44100,"import retains authored PCM")
	check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and stream.loop_end == 18 * 44100,"full 18-second loop")
	check(stream.data.slice(stream.data.size()-2) == stream.data.slice(0,2),"inclusive cyclic endpoint supplied")
	ambience.present(0.1,false,false)
	check(ambience.gain > 0 and ambience.gain < NightAmbience.LEVEL,"gradual initial fade")
	ambience.present(1,false,false)
	check(is_equal_approx(ambience.gain,NightAmbience.LEVEL),"bounded background level")
	ambience.present(1,true,false)
	check((player.stream_paused if DisplayServer.get_name() != "headless" else not player.playing) and is_equal_approx(ambience.gain,NightAmbience.LEVEL),"pause retains gain and suspends output")
	ambience.present(0.1,false,false)
	check(not player.stream_paused and player.stream == stream,"resume retains recording")
	ambience.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	ambience.present(1,false,false)
	check((player.stream_paused if DisplayServer.get_name() != "headless" else not player.playing) and ambience.suspended,"application background suspends playback")
	ambience.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	ambience.present(0.1,false,false)
	check(not player.stream_paused,"foreground resumes playback")
	ambience.present(0.1,false,true)
	check(ambience.gain > 0 and ambience.gain < NightAmbience.LEVEL,"finish fades out")
	ambience.present(1,false,true)
	check(ambience.gain == 0 and not player.playing,"finish stops playback")
	ambience.present(1,false,false)
	check(is_equal_approx(ambience.gain,NightAmbience.LEVEL),"retry restarts ambience")
	ambience.configure("pine")
	check(not player.playing and player.volume_linear == 0,"leaving night stops immediately")
	ambience.configure("night_city")
	check(ambience.player == player and ambience.get_child_count() == 1,"track cycling reuses one voice")
	GameSoundtrack.instance().apply_settings({"vehicle_volume":0.0})
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(player.bus)),"Vehicle mute includes cicadas")
	GameSoundtrack.instance().apply_settings({})
	if "--capture" in OS.get_cmdline_user_args(): await capture(ambience)
	ambience.free()
	# Exercise the actual race weather setup and exit ownership.
	var doc: Dictionary = TrackDocument.create_default()
	doc.theme = "night_city"
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = TrackCompiler.compile(doc)
	root.add_child(game)
	await process_frame
	await process_frame
	check(game.night_ambience != null and game.night_ambience.enabled,"night race owns enabled ambience")
	game.set_process(false)
	game.set_physics_process(false)
	var state_before: Array = game.sim.state.snapshot()
	game.night_ambience.present(1,false,false)
	check(game.sim.state.snapshot() == state_before,"ambience leaves canonical state unchanged")
	var voice_ref: WeakRef = weakref(game.night_ambience.player)
	game.queue_free()
	await process_frame
	await process_frame
	check(voice_ref.get_ref() == null,"race exit frees the ambience voice")
	await create_timer(0.15).timeout
	print("NIGHT_AMBIENCE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func capture(ambience: NightAmbience) -> void:
	check(DisplayServer.get_name() != "headless","native mixer capture")
	if DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var bus: int = AudioServer.get_bus_count()
	AudioServer.add_bus()
	AudioServer.set_bus_name(bus,"NightReview")
	AudioServer.set_bus_send(bus,"Vehicle")
	ambience.player.bus = "NightReview"
	var record := AudioEffectRecord.new()
	record.format = AudioStreamWAV.FORMAT_16_BITS
	var output_bus: int = AudioServer.get_bus_index("Vehicle")
	AudioServer.add_bus_effect(output_bus,record)
	ambience.configure("pine")
	ambience.configure("night_city")
	ambience.present(1,false,false)
	await create_timer(0.2).timeout
	var previous: float = 0.0
	var wraps: int = 0
	var began: int = Time.get_ticks_msec()
	record.set_recording_active(true)
	while Time.get_ticks_msec() - began < 37000:
		await process_frame
		var cursor: float = ambience.player.get_playback_position()
		if cursor + 0.1 < previous: wraps += 1
		previous = cursor
	record.set_recording_active(false)
	check(record.get_recording().save_to_wav(OUT.path_join("cicadas-two-wraps.wav")) == OK,"native loop recording saved")
	check(wraps >= 2,"actual playback crosses two loop boundaries")
	for mode: String in ["paused","muted","finished"]:
		if mode == "paused": ambience.present(1,true,false)
		elif mode == "muted":
			ambience.present(1,false,false)
			AudioServer.set_bus_mute(bus,true)
		else:
			AudioServer.set_bus_mute(bus,false)
			ambience.present(1,false,true)
		await create_timer(0.2).timeout
		record.set_recording_active(true)
		await create_timer(0.3).timeout
		record.set_recording_active(false)
		check(record.get_recording().save_to_wav(OUT.path_join(mode+".wav")) == OK,"native silence recording: "+mode)
	ambience.player.bus = "Vehicle"
	AudioServer.remove_bus_effect(output_bus,AudioServer.get_bus_effect_count(output_bus)-1)
	AudioServer.remove_bus(bus)
	print("NIGHT_AMBIENCE_WRAPS: ",wraps)
