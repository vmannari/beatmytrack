extends "res://tests/test_snow_bank_audio.gd"
## Fresh-process captures of the actual runtime mixer, without test command floods.
class CaptureAudio extends VehicleAudio:
	func _event(clip: String, amplitude: float, pitch: float = 1.0, debris: bool = false) -> void:
		super._event(clip,amplitude,pitch,debris)
		if clip=="snow_hit": events[(event_index+events.size()-1)%events.size()].bus = "SnowAudition"

func run() -> void:
	check(DisplayServer.get_name()!="headless","capture uses native desktop audio")
	if failures:
		quit(1)
		return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="): output = argument.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var track: NativeTrack = make_track()
	var audio := CaptureAudio.new()
	audio.use_windows_impacts = false
	root.add_child(audio)
	audio.configure("compact",VehicleCatalog.config("compact"))
	audio._ensure_snow()
	var bus_indices: Array[int] = [0]
	for label: String in ["SnowAudition","UnwantedAudition"]:
		var index: int = AudioServer.get_bus_count()
		AudioServer.add_bus()
		AudioServer.set_bus_name(index,label)
		AudioServer.set_bus_send(index,"Vehicle")
		bus_indices.append(index)
	(audio.layers.snow as AudioStreamPlayer).bus = "SnowAudition"
	for key: String in ["grass","sand","sand_roll","sand_debris","loose","kerb_roll"]:
		(audio.layers[key] as AudioStreamPlayer).bus = "UnwantedAudition"
	var records: Array[AudioEffectRecord] = []
	for index: int in bus_indices:
		var recorder := AudioEffectRecord.new()
		recorder.format = AudioStreamWAV.FORMAT_16_BITS
		AudioServer.add_bus_effect(index,recorder)
		records.append(recorder)
	var state := VehicleState.new()
	state.heading = PI*.5
	state.velocity = Vector2(18,0)
	state.position = Vector2.ZERO
	audio.present(state,DriveFrame.new(),track,.016,false)
	await create_timer(.3).timeout
	for record: AudioEffectRecord in records: record.set_recording_active(true)
	var elapsed: float = 0
	var last_us: int = Time.get_ticks_usec()
	var bank_gain: float = 0
	while elapsed<14:
		await process_frame
		var now_us: int = Time.get_ticks_usec()
		var delta: float = minf(float(now_us-last_us)/1000000.0,.1)
		last_us = now_us
		elapsed += delta
		state.tick += 1
		var previous: Vector2 = state.position
		# Clear ice 0-2s, nose entry 2-3s, continuous sideways push 3-10s,
		# reverse contact 10-11s, clear ice 11-12s, stop then pause 12-14s.
		state.position.x = 0 if elapsed<2 or elapsed>=11 else (5.25-audio.surface_model.bumper_length if elapsed<3 else 5.6)
		state.heading = PI*.5 if elapsed<3 else (PI if elapsed>=10 and elapsed<11 else 0.0)
		state.velocity = Vector2(0,0) if elapsed>=12 else (Vector2(18,0) if elapsed<3 else Vector2(0,6))
		audio.begin_physics_feedback()
		audio.resolved_contact(state,track,state.velocity,previous,state.heading)
		audio.present(state,DriveFrame.sample(0,.65,0),track,delta,elapsed>=13)
		if elapsed>4 and elapsed<9: bank_gain = maxf(bank_gain,audio.levels.snow)
	for index: int in range(records.size()):
		records[index].set_recording_active(false)
		var path: String = output.path_join(["driving","snow","unwanted"][index]+".wav")
		check(records[index].get_recording().save_to_wav(path)==OK,"native mix saved: "+path)
	check(bank_gain>.1 and audio.snow_count==1,"runtime mix contains one entry and sustained snow")
	check(audio.impact_count==0 and audio.kerb_count==0,"snow audition contains no false crash or concrete hit")
	audio.free()
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	for index: int in range(bus_indices.size()-1,0,-1): AudioServer.remove_bus(bus_indices[index])
	await process_frame
	print("SNOW_BANK_AUDIO_CAPTURE: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
