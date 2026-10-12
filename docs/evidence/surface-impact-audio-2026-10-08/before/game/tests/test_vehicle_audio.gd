extends SceneTree
## Sound lifecycle, cleared bank integrity and canonical equivalence. Isolated local fixtures.
var checks: int = 0
var failures: int = 0
var capture_audio: bool = false
var evidence: String = "res://../docs/evidence/vehicle-audio-2026-10-06"

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+description)

func run() -> void:
	capture_audio = DisplayServer.get_name()!="headless"
	check(not ClassDB.class_exists("BMTMusicStream"),"retired native soundtrack is absent")
	check(not FileAccess.file_exists("res://music/bmt_music.gdextension"),"soundtrack is outside the export root")
	check(AudioServer.get_bus_index("Engine")>=0 and AudioServer.get_bus_index("Tires")>=0,"vehicle buses loaded")
	var vehicle_bus: int = AudioServer.get_bus_index("Vehicle")
	check(AudioServer.get_bus_effect(vehicle_bus,1) is AudioEffectHardLimiter,"vehicle peak ceiling installed")
	check(AudioServer.get_bus_effect(0,0) is AudioEffectHardLimiter,"final output peak ceiling installed")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(VehicleAudio.BANK+"manifest.json"))
	check(manifest.outputs.size()==44,"complete mastered bank including desert debris")
	for clip: Dictionary in manifest.outputs:
		var sample: AudioStreamWAV = load(VehicleAudio.BANK+str(clip.file))
		check(sample.mix_rate==44100 and not sample.stereo and sample.format==AudioStreamWAV.FORMAT_16_BITS,"portable mono PCM: "+str(clip.file))
		check(float(clip.peak_dbfs)<= -1.5,"asset has mastering headroom: "+str(clip.file))
		check(sample.data.size()>1000,"asset contains audio: "+str(clip.file))
		check(FileAccess.get_sha256(VehicleAudio.BANK+str(clip.file))==str(clip.sha256),"bank checksum: "+str(clip.file))
	var track: NativeTrack = NativeTrack.read("res://resources/tracks/starter_circuit.json")
	var config: HandlingConfig = VehicleCatalog.config("compact")
	var state := VehicleState.new()
	state.position = track.spawn
	var control := DriveFrame.sample(0,1,0)
	var neutral := DriveFrame.new()
	for id: String in VehicleCatalog.IDS:
		var model := VehicleAudioModel.new()
		model.configure(id,VehicleCatalog.config(id).maximum_speed)
		check(model.rpm==model.idle_rpm and model.gear==1,"clean drivetrain start: "+id)
		var state_before: Array = state.snapshot()
		var frame_before: Array = control.packed()
		for i: int in range(240):
			state.velocity = Vector2(0,float(i)/240*model.maximum_speed)
			model.advance(state,control,1.0/60)
			var weights: Vector3 = model.weights()
			check(absf(weights.length_squared()-1.0)<0.0001,"equal-power engine crossfade: "+id)
		check(model.shifts==0 if id=="kart" else model.shifts>=3,"authored transmission: "+id)
		check(model.rpm>=model.idle_rpm and model.rpm<=model.redline_rpm,"bounded RPM: "+id)
		state.velocity = Vector2.ZERO
		var final_before: Array = state.snapshot()
		model.advance(state,control,0.1)
		check(state.snapshot()==final_before and control.packed()==frame_before,"audio model does not modify state/input: "+id)
		model.reset()
		check(model.shifts==0 and model.rpm==model.idle_rpm,"retry clears drivetrain: "+id)
		state.velocity = Vector2(0,-5)
		model.advance(state,DriveFrame.sample(0,0,1),0.1)
		check(model.reverse and model.gear== -1 and model.load_amount>0,"reverse follows brake pedal: "+id)
		check(state_before.size()==state.snapshot().size(),"audio adds no canonical fields: "+id)
	var audio := VehicleAudio.new()
	root.add_child(audio)
	audio.configure("compact",config)
	check(audio.get_child_count()==18,"bounded race voice count including dedicated sand and scrape layers")
	state.velocity = Vector2(6,20)
	var snapshot: Array = state.snapshot()
	audio.present(state,control,track,0.1,false)
	check(state.snapshot()==snapshot,"whole mixer reads canonical state")
	check(float(audio.levels.tire)>0,"recorded asphalt squeal follows actual slip")
	state.jump_height = 1.0
	audio.present(state,control,track,0.1,false)
	check(float(audio.levels.tire)==0 and float(audio.levels.road)==0,"airborne wheels immediately silence tire/road layers")
	state.jump_height = 0
	audio.present(state,control,track,0.1,true)
	var frozen_rpm: float = audio.model.rpm
	audio.collision(Vector2(15,0))
	audio.present(state,control,track,0.1,true)
	check(audio.model.rpm==frozen_rpm and audio.event_count==0,"pause freezes drivetrain and suppresses events")
	check(audio.engine_load[0].stream_paused,"pause suspends loop playback")
	audio.present(state,control,track,0.1,false)
	audio.collision(Vector2(15,0))
	audio.present(state,control,track,0.016,false)
	check(audio.event_count==1,"actual impact triggers one body sound")
	for i: int in range(4):
		audio.collision(Vector2(15,0))
		audio.present(state,control,track,0.016,false)
	check(audio.event_count==1,"wall rubbing cannot machine-gun impacts")
	state.tick = 100
	audio.present(state,neutral,track,0.016,false)
	state.tick = 10
	audio.present(state,neutral,track,0.016,false)
	check(audio.event_count==0 and audio.pending_impact==0,"rewind resets stale events")
	track.metadata.theme = "desert"
	state.velocity = Vector2(6,20)
	for i: int in range(10): audio.present(state,control,track,0.05,false)
	check(float(audio.levels.sand)>0 and float(audio.levels.loose)==0 and float(audio.levels.tire)==0,"desert replaces tire/rolling noise with sand particles")
	track.metadata.theme = "storm"
	audio.present(state,control,track,0.1,false)
	check(float(audio.levels.water)>0,"wet road spray")
	var original_cells: PackedInt32Array = track.cells.duplicate()
	track.cells.fill(6)
	track.metadata.theme = "pine"
	audio.reset()
	audio.present(state,control,track,0.1,false)
	check(float(audio.levels.water)>0 and float(audio.levels.loose)==0,"puddles use spray from their first contact")
	track.cells = original_cells
	audio.reset()
	audio.present(state,control,track,0.1,false,true)
	check(float(audio.levels.tire)==0 and float(audio.levels.road)==0,"countdown has engine sound and no road noise")
	audio.free()
	# Simulate the same quantized controls with and without audio alongside every step.
	var plain := VehicleSimulation.new(config)
	var mixed := VehicleSimulation.new(config)
	plain.reset(Vector2.ZERO,0)
	mixed.reset(Vector2.ZERO,0)
	audio = VehicleAudio.new()
	root.add_child(audio)
	audio.configure("compact",config)
	for i: int in range(960):
		var input: DriveFrame = DriveFrame.sample(sin(float(i)*0.031)*0.8,1.0 if i%240<180 else 0.0,0.5 if i%240>=180 else 0.0)
		plain.step(input)
		mixed.step(input)
		audio.present(mixed.state,input,null,1.0/120,false)
	check(plain.state.snapshot()==mixed.state.snapshot(),"960 canonical ticks are byte-equivalent with the sound mix")
	audio.free()
	# Lifecycle regression: a real race creates only the replacement mixer.
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = NativeTrack.read("res://resources/tracks/starter_circuit.json")
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	check(game.vehicle_audio!=null and game.find_child("VehicleAudio",true,false)!=null,"race installs vehicle sound")
	check(game.find_child("DynamicMusicController",true,false)==null,"race has no soundtrack controller")
	game.vehicle_audio.present(game.sim.state,game.frame,game.native_track,0.1,false)
	game.restart()
	check(game.vehicle_audio.model.shifts==0 and game.vehicle_audio.event_count==0,"race retry resets audio")
	game.free()
	if capture_audio: await _record_previews()
	await process_frame
	print("VEHICLE_AUDIO: %d checks, %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)

func _record_previews() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	var record := AudioEffectRecord.new()
	record.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(0,record)
	for id: String in VehicleCatalog.IDS:
		var audio := VehicleAudio.new()
		root.add_child(audio)
		var config: HandlingConfig = VehicleCatalog.config(id)
		audio.configure(id,config)
		var state := VehicleState.new()
		var time: float = 0.0
		var previous_usec: int = Time.get_ticks_usec()
		record.set_recording_active(true)
		while time<8.0:
			await process_frame
			var now_usec: int = Time.get_ticks_usec()
			var dt: float = float(now_usec-previous_usec)/1000000.0
			previous_usec = now_usec
			time += dt
			state.tick += 1
			var speed: float = config.maximum_speed*clampf((time-.5)/3.0,0.0,1.0)
			if time>4.0: speed *= clampf(1.0-(time-4.0)/2.5,0,1)
			state.velocity = Vector2(speed*0.35 if time>5.0 and time<6.0 else 0.0,speed)
			var frame: DriveFrame = DriveFrame.sample(0,1 if time<4 else 0,0.5 if time>4.8 else 0)
			if time>6.2 and time<6.3: audio.collision(Vector2(14,0))
			audio.present(state,frame,null,dt,time>7.3)
		record.set_recording_active(false)
		var recording: AudioStreamWAV = record.get_recording()
		check(recording!=null and recording.data.size()>44100,"captured engine mix: "+id)
		if recording!=null:
			var pcm: PackedByteArray = recording.data
			var peak: int = 0
			for offset: int in range(0,pcm.size(),2): peak = maxi(peak,absi(pcm.decode_s16(offset)))
			check(peak>1000 and peak<32700,"captured mix is audible and unclipped: "+id)
			check(recording.save_to_wav(evidence.path_join(id+"-driving.wav"))==OK,"saved playable preview: "+id)
		audio.free()
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
