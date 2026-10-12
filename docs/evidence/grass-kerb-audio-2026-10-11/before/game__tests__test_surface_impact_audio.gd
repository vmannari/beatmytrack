extends SceneTree
## Owner's material/underbody correction: real wheel edges, speed/load, safety and actual PCM.
var checks: int = 0
var failures: int = 0
const OUTPUT: String = "res://../docs/evidence/surface-impact-audio-2026-10-08"

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func settle(audio: VehicleAudio, state: VehicleState, frame: DriveFrame, track: NativeTrack, frames: int = 120) -> void:
	for i: int in range(frames):
		state.tick += 1
		audio.present(state,frame,track,1.0/60.0,false)

func run() -> void:
	var track: NativeTrack = NativeTrack.read("res://resources/tracks/starter_circuit.json")
	track.metadata.theme = "pine"
	var state := VehicleState.new()
	state.position = Vector2.ZERO
	state.velocity = Vector2(0,14)
	var coast := DriveFrame.new()
	var power: DriveFrame = DriveFrame.sample(0,1.0,0)
	var config: HandlingConfig = VehicleCatalog.config("compact")
	var audio := VehicleAudio.new()
	root.add_child(audio)
	audio.configure("compact",config)
	for cell: int in [0,1,2,3,5,6,7]:
		track.cells.fill(cell)
		audio.reset()
		settle(audio,state,coast,track)
		check(float(audio.levels.grass)>0.0 if cell==1 else float(audio.levels.grass)==0.0,"grass only comes from grass wheels: %d"%cell)
		check(float(audio.levels.sand)>0.0 and float(audio.levels.sand_roll)>0.0 if cell==2 else float(audio.levels.sand)==0.0 and float(audio.levels.sand_roll)==0.0,"sand/dirt outside desert uses sand bed: %d"%cell)
		check(float(audio.levels.loose)>0.0 if cell==7 else float(audio.levels.loose)==0.0,"coarse loose material remains distinct: %d"%cell)
		check(float(audio.levels.road)>0.0 if cell in [0,5] else float(audio.levels.road)==0.0,"road/kerb contact excludes off-road rolling: %d"%cell)
		check(audio.grit_count>0 if cell in [2,7] else audio.grit_count==0,"underbody taps follow particle-bearing ground: %d"%cell)
	# Straight road edge through the car centre: exactly two wheels on grass.
	track.cells.fill(0)
	for y: int in range(track.grid_height):
		for x: int in range(track.grid_width):
			if (float(x)+0.5)*track.cell_size-track.half_extent.x>=0.0:
				track.cells[y*track.grid_width+x] = 1
	audio.reset()
	settle(audio,state,coast,track)
	check(audio.surface_model.grass==0.5 and audio.surface_model.pavement==0.5,"two wheels off track mix grass and road while centre stays at boundary")
	check(float(audio.levels.grass)>0.0 and float(audio.levels.road)>0.0,"partial contact is audible on both materials")
	for id: String in VehicleCatalog.IDS:
		var car_config: HandlingConfig = VehicleCatalog.config(id)
		var contacts := SurfaceAudioModel.new()
		contacts.configure(car_config)
		var probe := VehicleState.new()
		probe.velocity = Vector2(0,14)
		probe.position.x = car_config.track_width*.5-.05
		contacts.sample(probe,coast,track,.1,true)
		check(contacts.grass==0.5 and contacts.pavement==0.5,"actual selected wheel span reaches the road edge: "+id)
		probe.position.x += .1
		contacts.sample(probe,coast,track,.1,true)
		check(contacts.grass==1.0,"selected wheel span has fully left the road: "+id)
	state.position.x = -4.0
	audio.present(state,coast,track,.1,false)
	check(float(audio.levels.grass)==0.0,"grass stops immediately after all wheels return to pavement")
	# Speed and tractive effort are tested independently at identical contact.
	state.position = Vector2.ZERO
	track.metadata.theme = "desert"
	track.cells.fill(0)
	audio.reset()
	state.velocity = Vector2(0,7)
	settle(audio,state,coast,track)
	var slow_gain: float = float(audio.levels.sand)
	var slow_debris: float = float(audio.levels.sand_debris)
	var slow_pitch: float = (audio.layers.sand_roll as AudioStreamPlayer).pitch_scale
	audio.reset()
	state.velocity = Vector2(0,25)
	settle(audio,state,coast,track)
	check(float(audio.levels.sand)>slow_gain and float(audio.levels.sand_debris)>slow_debris and (audio.layers.sand_roll as AudioStreamPlayer).pitch_scale>slow_pitch,"higher speed increases sand energy, rolling rate and continuous debris")
	audio.reset()
	state.velocity = Vector2(0,14)
	settle(audio,state,coast,track)
	var coast_gain: float = float(audio.levels.sand)
	var coast_debris: float = float(audio.levels.sand_debris)
	audio.reset()
	settle(audio,state,power,track)
	var powered_gain: float = float(audio.levels.sand)
	check(powered_gain>coast_gain*1.3 and float(audio.levels.sand_debris)>coast_debris,"acceleration demand strengthens sand spray and continuous stones at the same speed")
	# Actual rising speed supplies extra demand beyond the same held pedal.
	var held_drive: float = audio.surface_model.drive
	for i: int in range(60):
		state.velocity = Vector2(0,14.0+float(i)/60.0*8.0)
		audio.present(state,power,track,1.0/60.0,false)
	check(audio.surface_model.acceleration>6.0 and audio.surface_model.drive>held_drive+.10,"measured acceleration further raises spray without changing physics")
	audio.reset()
	state.velocity = Vector2(0,-14)
	settle(audio,state,DriveFrame.sample(0,0,1),track)
	check(absf(float(audio.levels.sand)-powered_gain)<.002,"reverse acceleration follows reverse pedal with matching energy")
	# Short underbody hits have their own pool and never replace crash playback.
	audio.reset()
	state.velocity = Vector2(0,25)
	settle(audio,state,power,track,30)
	audio.collision(Vector2(20,0))
	audio.present(state,power,track,.016,false)
	var collision_voice: AudioStreamPlayer = audio.events[(audio.event_index+audio.events.size()-1)%audio.events.size()]
	var collision_stream: AudioStream = collision_voice.stream
	var debris_stream: AudioStream = (audio.layers.sand_debris as AudioStreamPlayer).stream
	settle(audio,state,power,track,120)
	check(float(audio.levels.sand_debris)>0 and (audio.layers.sand_debris as AudioStreamPlayer).stream==debris_stream and collision_voice.stream==collision_stream,"continuous stones preserve their playback and cannot steal a collision slot")
	check(audio.grit_count==0 and audio.get_child_count()==22,"desert stream uses a single loop voice and no scheduled impacts")
	# Different normal impulse magnitudes produce different impact character.
	track.metadata.theme = "pine"
	track.cells.fill(0)
	var impact_streams: Array[AudioStream] = []
	var gains: Array[float] = []
	for impulse: float in [2.5,9.0,20.0]:
		audio.reset()
		audio.present(state,coast,track,.1,false)
		audio.collision(Vector2(impulse,0))
		audio.present(state,coast,track,.016,false)
		impact_streams.append(audio.events[0].stream)
		gains.append(audio.events[0].volume_linear)
	check(impact_streams[0]!=impact_streams[1] and impact_streams[1]!=impact_streams[2],"light, medium and heavy contacts select different mastered bodies")
	check(gains[0]<gains[1] and gains[1]<gains[2],"impact energy is proportional to severity")
	track.metadata.theme = "desert"
	settle(audio,state,power,track)
	state.velocity = Vector2.ZERO
	audio.present(state,power,track,.016,false)
	check(float(audio.levels.sand)==0.0 and float(audio.levels.sand_roll)==0.0 and float(audio.levels.sand_debris)==0.0,"stationary revving stops granular beds immediately")
	for condition: String in ["airborne","rolled","countdown","pause"]:
		audio.reset()
		state.velocity = Vector2(0,25)
		state.jump_height = 0.0
		state.roll_ticks = 0
		settle(audio,state,power,track,30)
		var old_count: int = audio.grit_count
		state.jump_height = 1.0 if condition=="airborne" else 0.0
		state.roll_ticks = 10 if condition=="rolled" else 0
		audio.present(state,power,track,.1,condition=="pause",condition=="countdown")
		check(audio.grit_count==old_count,"no new underbody taps during "+condition)
		check((audio.layers.sand as AudioStreamPlayer).stream_paused and (audio.layers.sand_debris as AudioStreamPlayer).stream_paused if condition=="pause" else float(audio.levels.sand)==0.0 and float(audio.levels.sand_roll)==0.0 and float(audio.levels.sand_debris)==0.0,"surface playback suspends during "+condition)
	state.jump_height = 0.0
	state.roll_ticks = 0
	audio.reset()
	settle(audio,state,power,track)
	state.tick = 1
	audio.present(state,power,track,.016,false)
	check(audio.grit_count==0 and audio.impact_count==0 and audio.surface_model.acceleration==0.0,"rewind clears debris, incidents and acceleration history")
	# Canonical verification through actual four-wheel off-road sampling.
	var plain := VehicleSimulation.new(config)
	var mixed := VehicleSimulation.new(config)
	plain.reset(Vector2.ZERO,0)
	mixed.reset(Vector2.ZERO,0)
	audio.reset()
	for tick: int in range(960):
		var input: DriveFrame = DriveFrame.sample(sin(float(tick)*.031)*.8,1.0,.1 if tick%240>200 else 0.0)
		plain.step(input)
		mixed.step(input)
		audio.present(mixed.state,input,track,1.0/120.0,false)
	check(plain.state.snapshot()==mixed.state.snapshot(),"new surface/acceleration audio leaves 960 canonical ticks byte-equivalent")
	audio.free()
	print("SURFACE_IMPACT_AUDIO: %d checks, %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)

func capture(track: NativeTrack, config: HandlingConfig) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var record := AudioEffectRecord.new()
	record.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(0,record)
	var tires := AudioEffectRecord.new()
	tires.format = AudioStreamWAV.FORMAT_16_BITS
	var tire_bus: int = AudioServer.get_bus_index("Tires")
	AudioServer.add_bus_effect(tire_bus,tires)
	for scenario: String in ["desert-full","desert-surfaces","offtrack-surfaces","collision-hits"]:
		var audio := VehicleAudio.new()
		root.add_child(audio)
		audio.configure("compact",config)
		var state := VehicleState.new()
		var elapsed: float = 0.0
		var previous_usec: int = Time.get_ticks_usec()
		var incidents: int = 0
		var engine_bus: int = AudioServer.get_bus_index("Engine")
		AudioServer.set_bus_mute(engine_bus,scenario in ["desert-surfaces","offtrack-surfaces"])
		var duration: float = 8.0 if scenario=="collision-hits" else 12.0
		var last_cell: int = -1
		await create_timer(.25).timeout
		previous_usec = Time.get_ticks_usec()
		record.set_recording_active(true)
		if scenario=="desert-full": tires.set_recording_active(true)
		while elapsed<duration:
			await process_frame
			var now_usec: int = Time.get_ticks_usec()
			var delta: float = float(now_usec-previous_usec)/1000000.0
			previous_usec = now_usec
			elapsed += delta
			state.tick += 1
			track.metadata.theme = "pine" if scenario in ["collision-hits","offtrack-surfaces"] else "desert"
			var cell: int = 0
			if scenario=="offtrack-surfaces": cell = 1 if elapsed<4.0 else (2 if elapsed<8.0 else 0)
			if cell!=last_cell:
				track.cells.fill(cell)
				last_cell = cell
			var speed: float = 25.0*clampf((elapsed-.5)/2.5,0.0,1.0)
			var pedal: float = 0.0 if elapsed>4.0 and elapsed<6.0 else .9
			if scenario=="collision-hits": speed = 5.0
			state.velocity = Vector2(speed*.30 if elapsed>8.0 and elapsed<10.2 else 0.0,speed)
			if scenario=="collision-hits" and incidents<3 and elapsed>float(incidents)*2.0+1.0:
				audio.collision(Vector2([2.5,9.0,20.0][incidents],0))
				incidents += 1
			audio.present(state,DriveFrame.sample(0,pedal,0),track,delta,elapsed>duration-1.0)
		record.set_recording_active(false)
		if scenario=="desert-full":
			tires.set_recording_active(false)
			var tire_recording: AudioStreamWAV = tires.get_recording()
			check(tire_recording.save_to_wav(OUTPUT.path_join("desert-tire-bus.wav"))==OK,"saved dry desert tire-bus proof")
			var tire_peak: int = 0
			var tire_pcm: PackedByteArray = tire_recording.data
			for offset: int in range(0,tire_pcm.size(),2): tire_peak = maxi(tire_peak,absi(tire_pcm.decode_s16(offset)))
			check(tire_peak==0,"actual dry desert tire bus is exactly silent")
		var recording: AudioStreamWAV = record.get_recording()
		check(recording.save_to_wav(OUTPUT.path_join(scenario+".wav"))==OK,"saved actual game PCM: "+scenario)
		var pcm: PackedByteArray = recording.data
		var peak: int = 0
		var pause_peak: int = 0
		for offset: int in range(0,pcm.size(),2):
			var value: int = absi(pcm.decode_s16(offset))
			peak = maxi(peak,value)
			if offset>=pcm.size()-int(recording.mix_rate)*2: pause_peak = maxi(pause_peak,value)
		check(peak>100 and peak<31130,"actual capture is audible and unclipped: "+scenario)
		check(pause_peak==0,"actual final half-second is silent: "+scenario)
		audio.free()
		AudioServer.set_bus_mute(engine_bus,false)
		await create_timer(.15).timeout
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	AudioServer.remove_bus_effect(tire_bus,AudioServer.get_bus_effect_count(tire_bus)-1)
