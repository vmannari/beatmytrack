extends SceneTree
## Desert material feedback: tire silence, airborne/stationary bounds, foley and exact state.
var checks: int = 0
var failures: int = 0
const OUTPUT: String = "res://../docs/evidence/desert-audio-2026-10-06"

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func run() -> void:
	var track: NativeTrack = NativeTrack.read("res://resources/tracks/starter_circuit.json")
	track.metadata.theme = "desert"
	track.cells.fill(0)
	var state := VehicleState.new()
	state.position = track.spawn
	var input: DriveFrame = DriveFrame.sample(0,0.7,0)
	var config: HandlingConfig = VehicleCatalog.config("compact")
	var audio := VehicleAudio.new()
	# This fixture explicitly tests output-player pause state, including dummy output.
	audio.output_enabled = true
	root.add_child(audio)
	audio.configure("compact",config)
	state.velocity = Vector2(7,25)
	# Start with a real paved-road envelope, then change the presentation theme.
	track.metadata.theme = "pine"
	audio.present(state,input,track,.1,false)
	check(float(audio.levels.tire)>0,"paved slide remains audible")
	track.metadata.theme = "desert"
	var before: Array = state.snapshot()
	audio.present(state,input,track,.016,false)
	for key: String in ["tire","road","loose","grass"]:
		check(float(audio.levels[key])==0 and (audio.layers[key] as AudioStreamPlayer).volume_linear==0,"desert immediately silences "+key)
	check(float(audio.levels.sand)>0 and float(audio.levels.sand_debris)>0,"continuous desert spray replaces tires")
	check(before==state.snapshot(),"desert feedback is read-only")
	for cell: int in [0,1,2,5]:
		track.cells.fill(cell)
		audio.present(state,input,track,.1,false)
		check(float(audio.levels.sand)>0 and float(audio.levels.sand_debris)>0 and float(audio.levels.tire)==0,"road/apron/shoulder follow continuous desert material: %d"%cell)
	track.cells.fill(0)
	audio.reset()
	state.velocity = Vector2.ZERO
	for i: int in range(120): audio.present(state,input,track,1.0/60,false)
	check(float(audio.levels.sand)==0 and float(audio.levels.sand_debris)==0 and audio.grit_count==0,"stationary revving cannot emit gravel")
	state.velocity = Vector2(0,25)
	for i: int in range(120): audio.present(state,input,track,1.0/60,false)
	var straight_level: float = float(audio.levels.sand_debris)
	check(straight_level>0 and audio.grit_count==0,"ordinary desert driving produces a steady layer without pebble one-shots")
	audio.reset()
	state.velocity = Vector2(10,25)
	for i: int in range(120): audio.present(state,input,track,1.0/60,false)
	check(float(audio.levels.sand_debris)>straight_level,"sliding strengthens the continuous sand/stone stream")
	check(audio.grit_count==0 and not audio.debris_events[0].playing and not audio.debris_events[1].playing,"desert cannot punctuate the stream with the old regular hits")
	var active_grit: int = audio.grit_count
	state.jump_height = 1.0
	for i: int in range(30): audio.present(state,input,track,1.0/60,false)
	check(float(audio.levels.sand)==0 and float(audio.levels.sand_debris)==0 and audio.grit_count==active_grit,"airborne wheels stop all dry ground layers")
	state.jump_height = 0.0
	state.roll_ticks = 20
	for i: int in range(30): audio.present(state,input,track,1.0/60,false)
	check(float(audio.levels.sand)==0 and float(audio.levels.sand_debris)==0 and audio.grit_count==active_grit,"rolled car cannot spray gravel")
	state.roll_ticks = 0
	for i: int in range(30): audio.present(state,input,track,1.0/60,true)
	check(audio.grit_count==active_grit and (audio.layers.sand_debris as AudioStreamPlayer).stream_paused,"pause freezes the continuous debris playback")
	audio.reset()
	for i: int in range(30): audio.present(state,input,track,1.0/60,false,true)
	check(float(audio.levels.sand)==0 and float(audio.levels.sand_debris)==0 and audio.grit_count==0,"countdown has no particle sound")
	for cell: int in [3,6]:
		track.cells.fill(cell)
		audio.present(state,input,track,.1,false)
		check(float(audio.levels.sand)==0 and float(audio.levels.sand_debris)==0 and float(audio.levels.water)>0,"water replaces dry sand on cell %d"%cell)
	track.metadata.theme = "pine"
	track.cells.fill(0)
	audio.reset()
	for i: int in range(120): audio.present(state,input,track,1.0/60,false)
	check(audio.grit_count==0 and float(audio.levels.sand)==0 and float(audio.levels.sand_debris)==0 and float(audio.levels.tire)>0,"other biomes retain tire audio")
	track.metadata.theme = "desert"
	audio.reset()
	state.tick = 100
	for i: int in range(30): audio.present(state,input,track,1.0/60,false)
	check(float(audio.levels.sand_debris)>0 and audio.grit_count==0,"pre-rewind continuous grains are audible")
	state.tick = 5
	audio.present(state,input,track,1.0/60,false)
	check(audio.grit_count==0 and audio.grit_distance==0,"rewind resets particle history")
	var plain := VehicleSimulation.new(config)
	var mixed := VehicleSimulation.new(config)
	plain.reset(Vector2.ZERO,0)
	mixed.reset(Vector2.ZERO,0)
	audio.reset()
	for tick: int in range(960):
		var control: DriveFrame = DriveFrame.sample(sin(float(tick)*.031)*.8,1.0,.1 if tick%240>200 else 0.0)
		plain.step(control)
		mixed.step(control)
		audio.present(mixed.state,control,track,1.0/120,false)
	check(plain.state.snapshot()==mixed.state.snapshot() and audio.grit_count==0,"continuous desert debris leaves 960 canonical ticks exactly equivalent")
	audio.free()
	if DisplayServer.get_name()!="headless": await capture(track,config)
	# Allow queued mixer playback removals to finish before engine shutdown.
	await create_timer(.05).timeout
	print("DESERT_AUDIO: %d checks, %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)

func capture(track: NativeTrack, config: HandlingConfig) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var master := AudioEffectRecord.new()
	var tires := AudioEffectRecord.new()
	master.format = AudioStreamWAV.FORMAT_16_BITS
	tires.format = AudioStreamWAV.FORMAT_16_BITS
	var tire_bus: int = AudioServer.get_bus_index("Tires")
	AudioServer.add_bus_effect(0,master)
	AudioServer.add_bus_effect(tire_bus,tires)
	var audio := VehicleAudio.new()
	# This fixture explicitly tests output-player pause state, including dummy output.
	audio.output_enabled = true
	root.add_child(audio)
	audio.configure("compact",config)
	var state := VehicleState.new()
	state.position = track.spawn
	var elapsed: float = 0.0
	var previous_usec: int = Time.get_ticks_usec()
	master.set_recording_active(true)
	tires.set_recording_active(true)
	while elapsed<12.0:
		await process_frame
		var now_usec: int = Time.get_ticks_usec()
		var delta: float = float(now_usec-previous_usec)/1000000.0
		previous_usec = now_usec
		elapsed += delta
		state.tick += 1
		var speed: float = 25.0*clampf((elapsed-1.0)/2.0,0,1)
		state.velocity = Vector2(speed*.4 if elapsed>5.0 and elapsed<8.8 else 0.0,speed)
		audio.present(state,DriveFrame.sample(0,0.65,0),track,delta,elapsed>11.0)
	master.set_recording_active(false)
	tires.set_recording_active(false)
	check(master.get_recording().save_to_wav(OUTPUT.path_join("desert-driving.wav"))==OK,"saved full desert sound mix")
	var tire_recording: AudioStreamWAV = tires.get_recording()
	check(tire_recording.save_to_wav(OUTPUT.path_join("desert-tire-bus.wav"))==OK,"saved tire-silence proof")
	var peak: int = 0
	var pcm: PackedByteArray = tire_recording.data
	for offset: int in range(0,pcm.size(),2): peak = maxi(peak,absi(pcm.decode_s16(offset)))
	check(peak==0,"actual desert tire bus is digitally silent")
	check(audio.grit_count==0,"actual desert capture has no discrete pebble bursts")
	audio.free()
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	AudioServer.remove_bus_effect(tire_bus,AudioServer.get_bus_effect_count(tire_bus)-1)
