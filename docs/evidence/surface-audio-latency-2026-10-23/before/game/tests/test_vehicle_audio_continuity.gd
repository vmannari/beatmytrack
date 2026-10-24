extends SceneTree
## Actual engine-bus recordings through repeated loops, sustained revs, coast and pause.
var checks: int = 0
var failures: int = 0
var OUTPUT: String = "res://../docs/evidence/vehicle-audio-continuity-2026-10-06"

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-dir="): OUTPUT = argument.trim_prefix("--evidence-dir=")
	check(DisplayServer.get_name()!="headless","continuity capture uses the actual desktop audio mixer")
	if failures>0:
		quit(1)
		return
	check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))==OK,"capture folder available")
	var engine_bus: int = AudioServer.get_bus_index("Engine")
	check(engine_bus>=0,"isolated engine bus available")
	var recorder := AudioEffectRecord.new()
	recorder.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(engine_bus,recorder)
	for id: String in VehicleCatalog.IDS:
		var audio := VehicleAudio.new()
		root.add_child(audio)
		var config: HandlingConfig = VehicleCatalog.config(id)
		audio.configure(id,config)
		var state := VehicleState.new()
		var before: Array = state.snapshot()
		var elapsed: float = 0.0
		var clock_usec: int = Time.get_ticks_usec()
		var resume: bool = true
		var previous_positions: Array[float] = [0,0,0,0,0,0]
		var observed_wraps: Array[int] = [0,0,0,0,0,0]
		recorder.set_recording_active(true)
		while elapsed<24.0:
			await process_frame
			var now_usec: int = Time.get_ticks_usec()
			var dt: float = float(now_usec-clock_usec)/1000000.0
			clock_usec = now_usec
			elapsed += dt
			state.tick += 1
			# High steady revs cover two wraps of even the eight-second high
			# bank; short low-RPM runs cannot prove those muted banks wrap.
			state.velocity = Vector2(0,config.maximum_speed*.85*clampf(elapsed-3.0,0,1))
			var frame: DriveFrame = DriveFrame.sample(0,0.65 if elapsed>3.0 and elapsed<21.0 else 0.0,0)
			# WAV's get_loop_count returns a placeholder zero in Godot. Observe
			# actual cursor wraparound while keeping the same playback instance.
			var engines: Array[AudioStreamPlayer] = audio.engine_load+audio.engine_coast
			for index: int in range(engines.size()):
				var position: float = engines[index].get_playback_position()
				if position+0.1<previous_positions[index]: observed_wraps[index] += 1
				previous_positions[index] = position
			if elapsed>=22.0 and resume:
				for index: int in range(engines.size()):
					check(observed_wraps[index]>1,"engine crossed multiple loop boundaries: "+id+"/"+engines[index].name)
				print("OBSERVED_ENGINE_WRAPS: ",id," ",observed_wraps)
				resume = false
			audio.present(state,frame,null,dt,elapsed>=22.0)
		recorder.set_recording_active(false)
		var recording: AudioStreamWAV = recorder.get_recording()
		check(recording!=null and recording.get_length()>23.5,"complete continuous engine recording: "+id)
		if recording!=null:
			check(recording.save_to_wav(OUTPUT.path_join(id+"-continuous.wav"))==OK,"saved continuous engine recording: "+id)
		check(state.snapshot().size()==before.size(),"audio retains canonical state schema: "+id)
		audio.free()
		print("CONTINUOUS_CAPTURE: "+id)
	AudioServer.remove_bus_effect(engine_bus,AudioServer.get_bus_effect_count(engine_bus)-1)
	print("VEHICLE_AUDIO_CONTINUITY: %d checks, %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)
