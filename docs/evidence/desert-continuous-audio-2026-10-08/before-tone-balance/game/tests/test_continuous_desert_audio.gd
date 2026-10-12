extends SceneTree
## Continuous-grain identity, transitions, reverse/load and collision timing coexistence.
var checks: int = 0
var failures: int = 0

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
	track.cells.fill(0)
	track.metadata.theme = "desert"
	var state := VehicleState.new()
	state.position = track.spawn
	state.velocity = Vector2(0,25)
	var audio := VehicleAudio.new()
	root.add_child(audio)
	audio.configure("compact",VehicleCatalog.config("compact"))
	var layer: AudioStreamPlayer = audio.layers.sand_debris
	var source: AudioStream = layer.stream
	for material: int in [0,1,2,5]:
		track.cells.fill(material)
		settle(audio,state,DriveFrame.sample(0,.7,0),track)
		check(float(audio.levels.sand_debris)>0 and layer.playing,"continuous stream on desert material %d"%material)
		check(audio.grit_count==0,"no scheduled grain hits on desert material %d"%material)
	check(source==layer.stream,"ordinary driving retains one playback source")
	var count: int = audio.event_count
	settle(audio,state,DriveFrame.sample(0,.7,0),track,600)
	check(audio.event_count==count and audio.grit_count==0,"ten seconds of steady sand have no recurring impact events")
	check(audio.get_child_count()==22,"continuous detail adds one bounded loop, not grain voices")
	track.cells.fill(0)
	audio.reset()
	state.velocity = Vector2(0,8)
	settle(audio,state,DriveFrame.new(),track)
	var slow: float = float(audio.levels.sand_debris)
	var slow_pitch: float = layer.pitch_scale
	state.velocity = Vector2(0,25)
	settle(audio,state,DriveFrame.new(),track)
	var coasting: float = float(audio.levels.sand_debris)
	check(coasting>slow and layer.pitch_scale>slow_pitch,"speed increases continuous spray energy and spectral movement")
	settle(audio,state,DriveFrame.sample(0,1,0),track)
	var powered: float = float(audio.levels.sand_debris)
	check(powered>coasting,"power increases the steady stream at the same speed")
	audio.reset()
	state.velocity = Vector2(0,-25)
	settle(audio,state,DriveFrame.sample(0,0,1),track)
	check(absf(float(audio.levels.sand_debris)-powered)<.002,"reverse drive gives matching continuous texture")
	var before: Array = state.snapshot()
	audio.collision(Vector2(20,0))
	check(audio.impact_count==1 and audio.events[0].playing,"real collision still starts immediately over the continuous bed")
	check(before==state.snapshot(),"continuous mix and contact feedback are read-only")
	track.metadata.theme = "pine"
	track.cells.fill(2)
	audio.present(state,DriveFrame.new(),track,.1,false)
	check(float(audio.levels.sand_debris)==0,"new stream immediately leaves non-desert material audio alone")
	settle(audio,state,DriveFrame.new(),track)
	check(audio.grit_count>0,"other-biome loose-ground event behavior is retained")
	track.metadata.theme = "desert"
	audio.present(state,DriveFrame.new(),track,.016,false)
	check(not audio.debris_events[0].playing and not audio.debris_events[1].playing,"old gravel event tails cannot punctuate a desert transition")
	for material: int in [3,6,4]:
		track.cells.fill(material)
		audio.present(state,DriveFrame.new(),track,.1,false)
		check(float(audio.levels.sand_debris)==0,"water/blocked material cannot emit dry grains: %d"%material)
	track.cells.fill(0)
	for mode: String in ["stationary","airborne","rolled","countdown"]:
		audio.reset()
		state.velocity = Vector2.ZERO if mode=="stationary" else Vector2(0,25)
		state.jump_height = 1.0 if mode=="airborne" else 0.0
		state.roll_ticks = 10 if mode=="rolled" else 0
		audio.present(state,DriveFrame.sample(0,1,0),track,.1,false,mode=="countdown")
		check(float(audio.levels.sand_debris)==0 and audio.grit_count==0,"continuous layer respects "+mode)
	state.jump_height = 0.0
	state.roll_ticks = 0
	audio.free()
	await process_frame
	await process_frame
	print("CONTINUOUS_DESERT_AUDIO: %d checks, %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)
