extends SceneTree
## Real bank geometry, physical crossings, independent mixer output and lifecycle.
var checks: int = 0
var failures: int = 0
var baseline: bool = false
var output: String = "res://../docs/evidence/snowbank-audio-2026-10-22"

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func make_track() -> NativeTrack:
	var track := NativeTrack.new()
	track.cell_size = .5
	track.grid_width = 80
	track.grid_height = 80
	track.half_extent = Vector2(20,20)
	track.cells.resize(6400)
	track.deck_cells.resize(6400)
	track.cells.fill(1)
	track.deck_cells.fill(-1)
	track.metadata = {"theme":"winter"}
	track.route = PackedVector2Array([Vector2(0,-18),Vector2(0,18)])
	for y: int in range(80):
		for x: int in range(30,50): track.cells[y*80+x] = 0
	track.snow_banks.build(track)
	return track

func make_audio() -> Node:
	var audio: Node
	if baseline:
		var script := GDScript.new()
		script.source_code = FileAccess.get_file_as_string(output.path_join("before/vehicle_audio.gd.txt")).replace("class_name VehicleAudio\n","").replace("class_name VehicleAudio\r\n","")
		check(script.reload()==OK,"preserved original compiles")
		audio = script.new()
	else: audio = VehicleAudio.new()
	audio.use_windows_impacts = false
	root.add_child(audio)
	return audio

func run() -> void:
	baseline = "--baseline" in OS.get_cmdline_user_args() or "--baseline-pause" in OS.get_cmdline_user_args()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="): output = argument.trim_prefix("--output-dir=")
	var track: NativeTrack = make_track()
	var audio: Node = make_audio()
	if "--baseline-pause" in OS.get_cmdline_user_args():
		audio.configure("compact",VehicleCatalog.config("compact"))
		audio.present(VehicleState.new(),DriveFrame.new(),track,.1,true)
		check(audio.engine_load[0].stream_paused,"preserved original pause suspends loop playback")
		audio.free()
		print("SNOW_AUDIO_ORIGINAL_PAUSE: %d checks, %d failures"%[checks,failures])
		quit(1 if failures else 0)
		return
	for id: String in VehicleCatalog.IDS:
		var config: HandlingConfig = VehicleCatalog.config(id)
		audio.configure(id,config)
		var state := VehicleState.new()
		state.heading = PI*.5
		state.position = Vector2(5.25-audio.surface_model.bumper_length,0)
		state.velocity = Vector2(18,0)
		var saved: Array = state.snapshot()
		audio.begin_physics_feedback()
		audio.resolved_contact(state,track,state.velocity)
		audio.present(state,DriveFrame.sample(0,.7,0),track,1.0/60,false)
		check(float(audio.levels.get("snow",0))>.02,"front bumper starts snow sound before tyres enter: "+id)
		check(audio.surface_model.snow==0 and audio.surface_model.snow_bank>.08,"fixture is body-only physical snow contact: "+id)
		check(state.snapshot()==saved,"snow observer preserves canonical state: "+id)
		if baseline: continue
		check(audio.snow_count==1 and audio.impact_count==0 and audio.kerb_count==0,"snow entry dispatches crunch without wall/concrete voice: "+id)
		check(audio.layers.snow.bus=="Vehicle" and audio.get_child_count()==24,"one bounded Winter loop and existing event pool: "+id)
		for i: int in range(60):
			state.tick += 1
			audio.begin_physics_feedback()
			audio.resolved_contact(state,track,state.velocity)
			audio.present(state,DriveFrame.new(),track,1.0/60,false)
		check(audio.snow_count==1 and audio.levels.snow>.10,"sustained push has no repeated entry events: "+id)
		state.position.x = 5.6
		state.heading = 0
		var levels: Array[float] = []
		for speed: float in [.8,6,22]:
			state.velocity = Vector2(0,speed)
			for i: int in range(15): audio.present(state,DriveFrame.new(),track,1.0/60,false)
			levels.append(float(audio.levels.snow))
		check(levels[0]>0 and levels[0]<levels[1] and levels[1]<levels[2],"plough texture follows crawl/driving/fast speed: "+id)
		check(audio.levels.grass==0 and audio.levels.sand==0 and audio.grit_count==0,"snow wheels never play grass/sand/stone foley: "+id)
		state.heading = -PI*.5
		state.velocity = Vector2(6,0)
		audio.present(state,DriveFrame.new(),track,.016,false)
		check(audio.levels.snow>.05,"reverse snow travel stays audible: "+id)
		await physical_crossing(audio,track,config,id)
		await process_frame
	if not baseline:
		lifecycle(audio,track)
		entry_rearm(audio,track)
		verify_streams(audio)
	audio.free()
	await process_frame
	print("SNOW_BANK_AUDIO: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)

func physical_crossing(audio: Node, track: NativeTrack, config: HandlingConfig, id: String) -> void:
	audio.reset()
	var sim := VehicleSimulation.new(config)
	var control := VehicleSimulation.new(config)
	sim.reset(Vector2(3.2,0),PI*.5)
	control.reset(sim.state.position,sim.state.heading)
	sim.state.velocity = Vector2(20,0)
	control.state.velocity = sim.state.velocity
	var exact: bool = true
	var peak: float = 0
	for i: int in range(140):
		var previous: Vector2 = sim.state.position
		var heading: float = sim.state.heading
		var incoming: Vector2 = sim.state.velocity
		var frame := DriveFrame.sample(0,.7,0)
		sim.step(frame,track)
		control.step(frame,track)
		audio.begin_physics_feedback()
		audio.resolved_contact(sim.state,track,incoming,previous,heading)
		if i%4==0: audio.present(sim.state,frame,track,VehicleSimulation.STEP*4,false)
		peak = maxf(peak,float(audio.levels.snow))
		exact = exact and sim.state.snapshot()==control.state.snapshot()
	check(exact,"actual bank crossing with sound remains byte-exact")
	check(peak>.10 and audio.snow_count==1 and audio.impact_count==0,"coarse rendering retains physical snow entry and continuous plough: %s peak=%.3f entries=%d impacts=%d"%[id,peak,audio.snow_count,audio.impact_count])

func lifecycle(audio: Node, track: NativeTrack) -> void:
	audio.configure("compact",VehicleCatalog.config("compact"))
	var state := VehicleState.new()
	state.position = Vector2(5.6,0)
	state.velocity = Vector2(0,12)
	var frame := DriveFrame.sample(0,1,0)
	for mode: String in ["stationary","air","roll","deck","pause","countdown","asphalt","other_biome"]:
		audio.reset()
		audio.present(state,frame,track,.016,false)
		state.velocity = Vector2.ZERO if mode=="stationary" else Vector2(0,12)
		state.jump_height = 1.0 if mode=="air" else 0.0
		state.roll_ticks = 1 if mode=="roll" else 0
		state.track_elevated = mode=="deck"
		state.position.x = 0 if mode=="asphalt" else 5.6
		track.metadata.theme = "pine" if mode=="other_biome" else "winter"
		audio.present(state,frame,track,.016,mode=="pause",mode=="countdown")
		check(audio.levels.snow==0 and audio.layers.snow.volume_linear==0,"no stale snow sound during "+mode)
		check(audio.snow_count==0,"no snow entry from presentation alone: "+mode)
		state.velocity = Vector2(0,12)
		state.jump_height = 0
		state.roll_ticks = 0
		state.track_elevated = false
		state.position.x = 5.6
		track.metadata.theme = "winter"
	var shared := SurfaceAudioModel.new()
	shared.configure(VehicleCatalog.config("compact"))
	shared.sample_contacts(state,track,true)
	audio.present(state,frame,track,.016,false,false,shared)
	check(audio.surface_model.snow_bank==shared.snow_bank and audio.surface_model.snow==shared.snow,"same-frame shared contacts retain exact snow amounts")
	state.tick = 200
	audio.present(state,frame,track,.016,false)
	state.tick = 10
	audio.present(state,frame,track,.016,false)
	check(audio.snow_count==0 and not audio.snow_touching,"rewind does not replay old entry events")
	audio.reset()
	check(audio.levels.snow==0 and audio.snow_count==0,"restart clears snow state and gain")
	audio.begin_physics_feedback()
	audio.collision(Vector2(20,0))
	check(audio.impact_count==1,"real solid crashes retain their own immediate impact")

func verify_streams(audio: Node) -> void:
	var source: AudioStreamWAV = load(VehicleAudio.BANK+"snow.wav")
	var prepared: AudioStreamWAV = audio.layers.snow.stream
	check(prepared.loop_mode==AudioStreamWAV.LOOP_FORWARD and prepared.loop_end==source.data.size()/2,"six-second snow loop retains exact cyclic PCM extent")
	check(prepared.data.slice(0,source.data.size())==source.data and prepared.data.slice(source.data.size())==source.data.slice(0,2),"snow loop uses original PCM plus exact interpolation guard")
	var hit: AudioStreamWAV = audio._stream("snow_hit",false)
	check(hit.loop_mode==AudioStreamWAV.LOOP_DISABLED and hit.get_length()<.6,"entry crunch stays a short non-looping event")

func entry_rearm(audio: Node, track: NativeTrack) -> void:
	audio.reset()
	var state := VehicleState.new()
	state.position = Vector2(5.6,0)
	state.velocity = Vector2(0,12)
	for mode: String in ["pause","countdown","air","roll","deck","asphalt","near_pass"]:
		audio.reset()
		state.position.x = 0 if mode=="asphalt" else (3.0 if mode=="near_pass" else 5.6)
		state.jump_height = 1.0 if mode=="air" else 0.0
		state.roll_ticks = 1 if mode=="roll" else 0
		state.track_elevated = mode=="deck"
		audio.present(state,DriveFrame.new(),track,.016,mode=="pause",mode=="countdown")
		audio.resolved_contact(state,track,state.velocity)
		check(audio.snow_count==0 and audio.levels.snow==0,"resolved feedback stays silent for "+mode)
	state.jump_height = 0
	state.roll_ticks = 0
	state.track_elevated = false
	audio.reset()
	for pass_index: int in range(2):
		state.position.x = 5.6
		audio.begin_physics_feedback()
		audio.resolved_contact(state,track,state.velocity)
		check(audio.snow_count==pass_index+1,"a separate real bank entry rearms once")
		state.position.x = 0
		for i: int in range(60): audio.resolved_contact(state,track,state.velocity)
		check(audio.levels.snow==0,"leaving bank clears continuous snow without a tail")
