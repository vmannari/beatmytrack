extends SceneTree
## Clean native PCM: a long constant sand stream, then driving/load/slide/stop.
const OUT: String = "res://../docs/evidence/desert-continuous-audio-2026-10-08"
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func run() -> void:
	if DisplayServer.get_name()=="headless":
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var track: NativeTrack = NativeTrack.read("res://resources/tracks/starter_circuit.json")
	track.metadata.theme = "desert"
	track.cells.fill(0)
	var record := AudioEffectRecord.new()
	var tires := AudioEffectRecord.new()
	var engine := AudioEffectRecord.new()
	var sand := AudioEffectRecord.new()
	record.format = AudioStreamWAV.FORMAT_16_BITS
	tires.format = AudioStreamWAV.FORMAT_16_BITS
	engine.format = AudioStreamWAV.FORMAT_16_BITS
	sand.format = AudioStreamWAV.FORMAT_16_BITS
	var engine_bus: int = AudioServer.get_bus_index("Engine")
	var sand_bus: int = AudioServer.get_bus_count()
	AudioServer.add_bus()
	AudioServer.set_bus_name(sand_bus,"SandReview")
	AudioServer.set_bus_send(sand_bus,"Vehicle")
	AudioServer.add_bus_effect(engine_bus,engine)
	AudioServer.add_bus_effect(sand_bus,sand)
	var tire_bus: int = AudioServer.get_bus_index("Tires")
	AudioServer.add_bus_effect(0,record)
	AudioServer.add_bus_effect(tire_bus,tires)
	for scenario: String in ["steady-sand","desert-driving"]:
		var audio := VehicleAudio.new()
		root.add_child(audio)
		audio.configure("compact",VehicleCatalog.config("compact"))
		var state := VehicleState.new()
		state.position = track.spawn
		for key: String in ["sand","sand_roll","sand_debris"]: (audio.layers[key] as AudioStreamPlayer).bus = "SandReview"
		AudioServer.set_bus_mute(engine_bus,scenario=="steady-sand")
		# Let startup transmission cues finish before steady-texture recording.
		var warm_until: int = Time.get_ticks_usec()+1500000
		while Time.get_ticks_usec()<warm_until:
			await process_frame
			state.velocity = Vector2(0,25) if scenario=="steady-sand" else Vector2.ZERO
			audio.present(state,DriveFrame.sample(0,.7,0),track,1.0/60.0,false)
		var elapsed: float = 0.0
		var last_us: int = Time.get_ticks_usec()
		var previous_cursor: float = (audio.layers.sand_debris as AudioStreamPlayer).get_playback_position()
		var wraps: int = 0
		record.set_recording_active(true)
		tires.set_recording_active(true)
		engine.set_recording_active(true)
		sand.set_recording_active(true)
		while elapsed<18.0:
			await process_frame
			var now_us: int = Time.get_ticks_usec()
			var delta: float = float(now_us-last_us)/1000000.0
			last_us = now_us
			elapsed += delta
			state.tick += 1
			var speed: float = 25.0 if scenario=="steady-sand" else 25.0*clampf((elapsed-.5)/3.0,0.0,1.0)
			var pedal: float = .7 if scenario=="steady-sand" else (0.0 if elapsed>5.0 and elapsed<7.0 else .9)
			state.velocity = Vector2(speed*.35 if scenario=="desert-driving" and elapsed>11.0 and elapsed<13.0 else 0.0,speed)
			if elapsed>16.0: state.velocity = Vector2.ZERO
			audio.present(state,DriveFrame.sample(0,pedal,0),track,delta,elapsed>17.0)
			var cursor: float = (audio.layers.sand_debris as AudioStreamPlayer).get_playback_position()
			if cursor+.5<previous_cursor: wraps += 1
			previous_cursor = cursor
		record.set_recording_active(false)
		tires.set_recording_active(false)
		engine.set_recording_active(false)
		sand.set_recording_active(false)
		check(engine.get_recording().save_to_wav(OUT.path_join(scenario+"-engine.wav"))==OK,"saved same-clock engine reference: "+scenario)
		check(sand.get_recording().save_to_wav(OUT.path_join(scenario+"-sand.wav"))==OK,"saved same-clock sand reference: "+scenario)
		var sample: AudioStreamWAV = record.get_recording()
		check(sample.save_to_wav(OUT.path_join(scenario+".wav"))==OK,"saved native PCM: "+scenario)
		var pcm: PackedByteArray = sample.data
		var peak: int = 0
		var pause_peak: int = 0
		for offset: int in range(0,pcm.size(),2):
			var value: int = absi(pcm.decode_s16(offset))
			peak = maxi(peak,value)
			if offset>=pcm.size()-int(sample.mix_rate)*2: pause_peak = maxi(pause_peak,value)
		check(peak>100 and peak<31130,"native capture is audible/unclipped: "+scenario)
		check(pause_peak==0,"final pause is exactly silent: "+scenario)
		check(audio.grit_count==0 and not audio.debris_events[0].playing and not audio.debris_events[1].playing,"capture contains no separate stone hits: "+scenario)
		check(wraps>=1,"actual continuous playback crosses a loop boundary: "+scenario)
		var tire_pcm: PackedByteArray = tires.get_recording().data
		var tire_peak: int = 0
		for offset: int in range(0,tire_pcm.size(),2): tire_peak = maxi(tire_peak,absi(tire_pcm.decode_s16(offset)))
		check(tire_peak==0,"dry desert tire bus remains silent: "+scenario)
		audio.free()
		AudioServer.set_bus_mute(engine_bus,false)
		await create_timer(.15).timeout
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	AudioServer.remove_bus_effect(tire_bus,AudioServer.get_bus_effect_count(tire_bus)-1)
	AudioServer.remove_bus_effect(engine_bus,AudioServer.get_bus_effect_count(engine_bus)-1)
	AudioServer.remove_bus(sand_bus)
	print("CONTINUOUS_DESERT_CAPTURE: %d checks, %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)
