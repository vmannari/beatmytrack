extends SceneTree
## Matched native-mixer audition; synthetic driving states, no player records.
var OUTPUT: String = "res://../docs/evidence/compact-audio-2026-10-10"
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Use TestScript -Graphical for the real audio mixer")
		quit(1)
		return
	var variant: String = "after"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--variant="): variant = argument.trim_prefix("--variant=")
		if argument.begins_with("--evidence-dir="): OUTPUT = argument.trim_prefix("--evidence-dir=")
	if variant not in ["before","after"]:
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var bus: int = AudioServer.get_bus_index("Engine")
	var recorder := AudioEffectRecord.new()
	recorder.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(bus,recorder)
	var mixed := AudioEffectRecord.new()
	mixed.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(0,mixed)
	var audio := VehicleAudio.new()
	root.add_child(audio)
	audio.configure("compact",VehicleCatalog.config("compact"))
	var state := VehicleState.new()
	var elapsed: float = 0.0
	var previous_us: int = Time.get_ticks_usec()
	var wraps: Array[int] = [0,0,0,0,0,0]
	var positions: Array[float] = [0,0,0,0,0,0]
	var telemetry: Array[Dictionary] = []
	recorder.set_recording_active(true)
	mixed.set_recording_active(true)
	while elapsed<37.0:
		await process_frame
		var now: int = Time.get_ticks_usec()
		var dt: float = float(now-previous_us)/1000000.0
		previous_us = now
		elapsed += dt
		state.tick += 1
		# Idle 0-2; acceleration 2-8; cruise 8-12; coast 12-16;
		# stationary rev 16-18; sustained high revs18-36 to exercise the
		# current eight-second banks repeatedly; exact pause36-37.
		var speed: float = 0.0
		if elapsed>=2.0 and elapsed<8.0: speed = 43.0*(elapsed-2.0)/6.0
		elif elapsed>=8.0 and elapsed<12.0: speed = 43.0
		elif elapsed>=12.0 and elapsed<16.0: speed = 43.0*(16.0-elapsed)/4.0
		elif elapsed>=18.0: speed = 43.0
		state.velocity = Vector2(0,speed)
		var pedal: float = 0.0
		if elapsed>=2.0 and elapsed<8.0: pedal = 1.0
		elif elapsed>=8.0 and elapsed<12.0: pedal = 0.65
		elif elapsed>=16.0 and elapsed<18.0: pedal = 0.55
		elif elapsed>=18.0: pedal = .65
		var canonical: Array = state.snapshot()
		audio.present(state,DriveFrame.sample(0,pedal,0),null,dt,elapsed>=36.0)
		if state.snapshot()!=canonical:
			failures += 1
		var players: Array[AudioStreamPlayer] = audio.engine_load+audio.engine_coast
		for index: int in range(players.size()):
			var position: float = players[index].get_playback_position()
			if position+0.1<positions[index]: wraps[index] += 1
			positions[index] = position
		if telemetry.is_empty() or elapsed-float(telemetry[-1].seconds)>=0.1:
			telemetry.append({"seconds":elapsed,"speed":speed,"rpm":audio.model.rpm,"gear":audio.model.gear,"load":audio.model.load_amount})
	recorder.set_recording_active(false)
	mixed.set_recording_active(false)
	var recording: AudioStreamWAV = recorder.get_recording()
	if recording==null or recording.get_length()<36.5:
		failures += 1
	elif recording.save_to_wav(OUTPUT.path_join("compact-"+variant+".wav"))!=OK:
		failures += 1
	if mixed.get_recording().save_to_wav(OUTPUT.path_join("compact-"+variant+"-mix.wav"))!=OK: failures += 1
	for count: int in wraps:
		if count<2: failures += 1
	var file := FileAccess.open(OUTPUT.path_join(variant+"-telemetry.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"samples":telemetry,"wraps":wraps,"failures":failures},"\t"))
	file.close()
	audio.free()
	AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	print("COMPACT_AUDIO_CAPTURE: ",variant," wraps=",wraps," failures=",failures)
	quit(1 if failures>0 else 0)
