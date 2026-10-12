extends SceneTree
## Stable native-mixer loops with no changing RPM, shifting or contact events.
const OUTPUT: String = "res://../docs/evidence/compact-loop-2026-10-10"
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Native loop capture requires -Graphical")
		quit(1)
		return
	var variant: String = "after"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--variant="): variant = argument.trim_prefix("--variant=")
	if variant not in ["before","after"]:
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var bus: int = AudioServer.get_bus_index("Engine")
	var recorder := AudioEffectRecord.new()
	recorder.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(bus,recorder)
	var audio := VehicleAudio.new()
	root.add_child(audio)
	audio.configure("compact",VehicleCatalog.config("compact"))
	# Isolate the loaded bank from all drivetrain/surface scheduling.
	for player: AudioStreamPlayer in audio.engine_load+audio.engine_coast:
		player.stop()
	for layer: String in audio.layers:
		(audio.layers[layer] as AudioStreamPlayer).stop()
	var reports: Array[Dictionary] = []
	for clip: String in ["compact_0_load","compact_1_load","compact_2_load","wind","road"]:
		var player := AudioStreamPlayer.new()
		player.bus = "Engine" # One diagnostic recorder; ordinary bus routing unchanged.
		player.stream = audio._stream(clip,true)
		player.volume_linear = 0.65
		root.add_child(player)
		player.play()
		var elapsed: float = 0.0
		var clock_us: int = Time.get_ticks_usec()
		var previous_position: float = 0.0
		var wraps: int = 0
		recorder.set_recording_active(true)
		while elapsed<9.0:
			await process_frame
			var now: int = Time.get_ticks_usec()
			elapsed += float(now-clock_us)/1000000.0
			clock_us = now
			var position: float = player.get_playback_position()
			if position+0.1<previous_position: wraps += 1
			previous_position = position
			if elapsed>=8.0: player.stream_paused = true
		recorder.set_recording_active(false)
		var recording: AudioStreamWAV = recorder.get_recording()
		if recording==null or recording.get_length()<8.5: failures += 1
		elif recording.save_to_wav(OUTPUT.path_join(variant+"-"+clip+".wav"))!=OK: failures += 1
		if wraps<2: failures += 1
		reports.append({"clip":clip,"wraps":wraps,"length":player.stream.get_length()})
		player.free()
		print("LOOP_CAPTURE: ",variant," ",clip," wraps=",wraps)
	audio.free()
	AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
	var file := FileAccess.open(OUTPUT.path_join(variant+"-capture.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"reports":reports,"failures":failures},"\t"))
	file.close()
	print("COMPACT_LOOP_CAPTURE: ",variant," failures=",failures)
	quit(1 if failures>0 else 0)
