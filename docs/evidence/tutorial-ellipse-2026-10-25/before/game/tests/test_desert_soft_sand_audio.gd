extends SceneTree
## Raised sand must never dispatch concrete kerb voices, including physics crossings.
var checks: int = 0
var failures: int = 0
var baseline: bool = false
var capture: bool = false
var output: String = "res://../build/desert-soft-sand-audio"

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func make_track() -> NativeTrack:
	var track: NativeTrack = NativeTrack.read("res://resources/tracks/starter_circuit.json")
	track.metadata.theme = "desert"
	track.metadata.erase("creator_document")
	track.cells.fill(0)
	track.hazard_objects.clear()
	track.creator_bridges.clear()
	track.kerbs = RoadKerbs.new()
	track.kerbs.extent = track.half_extent
	track.kerbs.grid = Vector2i(track.grid_width,track.grid_height)
	track.kerbs.cell_size = track.cell_size
	track.kerbs.blocked.resize(track.cells.size())
	track.kerbs._strip(Vector2(-40,0),Vector2(40,0),Vector2(-40,.75),Vector2(40,.75),40,120,160)
	return track

func settle(audio: VehicleAudio, state: VehicleState, track: NativeTrack) -> void:
	for i: int in range(90):
		state.tick += 1
		audio.present(state,DriveFrame.sample(0,.7,0),track,1.0/60,false)

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--baseline": baseline = true
		if argument == "--capture": capture = true
		if argument.begins_with("--evidence-dir="): output = argument.trim_prefix("--evidence-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var track: NativeTrack = make_track()
	var audio := VehicleAudio.new()
	audio.use_windows_impacts = false
	root.add_child(audio)
	var rows: Array[Dictionary] = []
	for id: String in VehicleCatalog.IDS:
		var config: HandlingConfig = VehicleCatalog.config(id)
		audio.configure(id,config)
		var state := VehicleState.new()
		state.heading = PI*.5
		state.velocity = Vector2(18,0)
		state.position = Vector2(0,4)
		settle(audio,state,track)
		var road: float = audio.levels.sand
		var road_pitch: float = (audio.layers.sand as AudioStreamPlayer).pitch_scale
		state.position.y = .4+config.track_width*.5
		var snapshot: Array = state.snapshot()
		audio.begin_physics_feedback()
		audio.resolved_contact(state,track,state.velocity,Vector2(0,4),state.heading)
		settle(audio,state,track)
		check(audio.surface_model.kerb>0,"fixture touches actual raised bank: "+id)
		state.tick = int(snapshot[9])
		check(snapshot==state.snapshot(),"sound leaves canonical state unchanged apart from fixture tick: "+id)
		rows.append({"car":id,"road_sand":road,"bank_sand":audio.levels.sand,"bank_kerb":audio.levels.kerb_roll,"bank_thuds":audio.kerb_count})
		if baseline:
			check(audio.levels.kerb_roll>0 and audio.kerb_count>0,"baseline reproduces concrete bank thuds: "+id)
		else:
			check(audio.levels.kerb_roll==0 and audio.kerb_count==0,"raised desert sand has no hard rumble or entry thud: "+id)
			check(audio.levels.sand>road*1.25,"deeper bank builds a soft sand rush: "+id)
			check((audio.layers.sand as AudioStreamPlayer).pitch_scale<road_pitch,"bank sand has a slightly fuller tone: "+id)
			check(audio.get_child_count()==23,"reuses bounded original players: "+id)
		state.position.y = 4
		track.cells.fill(2)
		settle(audio,state,track)
		if not baseline: check(audio.levels.sand>road*1.5,"loose terrain also carries deeper sand: "+id)
		track.cells.fill(0)
		audio.reset()
		var sim := VehicleSimulation.new(config)
		var control := VehicleSimulation.new(config)
		sim.reset(Vector2(0,-4),0)
		control.reset(Vector2(0,-4),0)
		sim.state.velocity = Vector2(0,24)
		control.state.velocity = sim.state.velocity
		var equivalent: bool = true
		var peak: float = 0
		for tick: int in range(100):
			var previous: Vector2 = sim.state.position
			var heading: float = sim.state.heading
			var incoming: Vector2 = sim.state.velocity
			sim.step(DriveFrame.new(),track)
			control.step(DriveFrame.new(),track)
			audio.begin_physics_feedback()
			audio.resolved_contact(sim.state,track,incoming,previous,heading)
			if tick%4==0:
				audio.present(sim.state,DriveFrame.new(),track,VehicleSimulation.STEP*4,false)
				peak = maxf(peak,audio.levels.kerb_roll)
			equivalent = equivalent and sim.state.snapshot()==control.state.snapshot()
		check(equivalent,"actual bank-crossing physics stays exact: "+id)
		if not baseline: check(audio.kerb_count==0 and peak==0,"coarse-render axle crossings never dispatch hard voices: "+id)
		await process_frame
	if not baseline: lifecycle(audio,track)
	var report := FileAccess.open(output.path_join("contacts.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify(rows,"\t"))
	report.close()
	if capture: await record_mix(audio,track)
	audio.free()
	await process_frame
	await create_timer(.15).timeout
	print("DESERT_SOFT_SAND_AUDIO: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)

func lifecycle(audio: VehicleAudio, track: NativeTrack) -> void:
	audio.configure("compact",VehicleCatalog.config("compact"))
	var state := VehicleState.new()
	state.position = Vector2(0,.4+audio.surface_model.track_width*.5)
	state.heading = PI*.5
	state.velocity = Vector2(18,0)
	track.metadata.theme = "pine"
	audio.begin_physics_feedback()
	audio.resolved_contact(state,track,state.velocity)
	settle(audio,state,track)
	check(audio.kerb_count>0 and audio.levels.kerb_roll>0,"grass retains real concrete entry/rumble")
	var events: int = audio.kerb_count
	track.metadata.theme = "desert"
	audio.begin_physics_feedback()
	audio.resolved_contact(state,track,state.velocity)
	audio.present(state,DriveFrame.new(),track,.016,false)
	check(audio.levels.kerb_roll==0 and audio.pending_kerb==0 and audio.kerb_hold==0,"theme switch immediately clears hard bank history")
	check(audio.kerb_count==events,"theme switch never queues another chassis thud")
	var shared := SurfaceAudioModel.new()
	shared.configure(VehicleCatalog.config("compact"))
	shared.sample_contacts(state,track,true)
	audio.present(state,DriveFrame.new(),track,.016,false,false,shared)
	check(audio.surface_model.get("sand_depth")==shared.get("sand_depth") and float(shared.get("sand_depth"))>0,"shared weathering contacts preserve sand depth")
	for mode: String in ["stationary","air","roll","countdown","pause","water","blocked","deck"]:
		audio.reset()
		state.velocity = Vector2.ZERO if mode=="stationary" else Vector2(18,0)
		state.jump_height = 1.0 if mode=="air" else 0.0
		state.roll_ticks = 1 if mode=="roll" else 0
		state.track_elevated = mode=="deck"
		track.cells.fill(3 if mode=="water" else (4 if mode=="blocked" else 0))
		audio.present(state,DriveFrame.new(),track,.016,mode=="pause",mode=="countdown")
		check(audio.levels.kerb_roll==0 and audio.kerb_count==0,"no hard bank voice during "+mode)
		if mode!="deck": check(audio.levels.sand==0,"deep dry sand respects "+mode)
		else: check(audio.surface_model.get("sand_depth")==0,"deck cannot inherit ground bank depth")
	state.jump_height = 0
	state.roll_ticks = 0
	state.track_elevated = false
	track.cells.fill(2)
	state.velocity = Vector2(18,0)
	settle(audio,state,track)
	state.tick = 0
	audio.present(state,DriveFrame.new(),track,.016,false)
	check(audio.kerb_count==0 and audio.pending_kerb==0,"rewind clears old hard contact history")
	audio.begin_physics_feedback()
	audio.collision(Vector2(20,0))
	check(audio.impact_count==1,"real crash keeps immediate impact dispatch on deeper sand")
	track.cells.fill(0)

func record_mix(audio: VehicleAudio, track: NativeTrack) -> void:
	check(DisplayServer.get_name()!="headless","native capture requires desktop output")
	var buses: Array[int] = [0]
	for label: String in ["SandAudition","KerbAudition","EngineAudition"]:
		var bus: int = AudioServer.get_bus_count()
		AudioServer.add_bus()
		AudioServer.set_bus_name(bus,label)
		AudioServer.set_bus_send(bus,"Engine" if label=="EngineAudition" else "Vehicle")
		buses.append(bus)
	for key: String in ["sand","sand_roll","sand_debris"]: (audio.layers[key] as AudioStreamPlayer).bus = "SandAudition"
	(audio.layers.kerb_roll as AudioStreamPlayer).bus = "KerbAudition"
	for player: AudioStreamPlayer in audio.engine_load+audio.engine_coast: player.bus = "EngineAudition"
	var records: Array[AudioEffectRecord] = []
	for bus: int in buses:
		var recorder := AudioEffectRecord.new()
		recorder.format = AudioStreamWAV.FORMAT_16_BITS
		AudioServer.add_bus_effect(bus,recorder)
		records.append(recorder)
	audio.configure("compact",VehicleCatalog.config("compact"))
	var state := VehicleState.new()
	state.heading = PI*.5
	state.velocity = Vector2(18,0)
	state.position = Vector2(0,4)
	settle(audio,state,track)
	await create_timer(.3).timeout
	for recorder: AudioEffectRecord in records: recorder.set_recording_active(true)
	var elapsed: float = 0
	var last_us: int = Time.get_ticks_usec()
	while elapsed<11:
		await process_frame
		var now_us: int = Time.get_ticks_usec()
		var delta: float = minf(float(now_us-last_us)/1000000,.1)
		last_us = now_us
		elapsed += delta
		state.tick += 1
		var previous: Vector2 = state.position
		state.position = Vector2(0,.4+audio.surface_model.track_width*.5 if elapsed>=2 and elapsed<5 else 4)
		track.cells.fill(2 if elapsed>=6 and elapsed<9 else 0)
		state.velocity = Vector2(18,0) if elapsed<9 else Vector2.ZERO
		audio.begin_physics_feedback()
		audio.resolved_contact(state,track,state.velocity,previous,state.heading)
		audio.present(state,DriveFrame.sample(0,.7,0),track,delta,elapsed>=10)
	for i: int in range(records.size()):
		records[i].set_recording_active(false)
		check(records[i].get_recording().save_to_wav(output.path_join(["driving","sand","kerb","engine"][i]+".wav"))==OK,"native audio saved")
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	for i: int in range(buses.size()-1,0,-1): AudioServer.remove_bus(buses[i])
