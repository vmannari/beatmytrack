extends SceneTree
## Wet rolling follows speed/material, with lifecycle guards and optional native PCM.
const OUT: String = "res://../docs/evidence/wet-road-audio-2026-10-09"
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
	var track: NativeTrack = NativeTrack.read("res://resources/tracks/starter_circuit.json")
	track.metadata.theme = "storm"
	track.cells.fill(0)
	var audio := VehicleAudio.new()
	audio.use_windows_impacts = false
	root.add_child(audio)
	audio.configure("compact",VehicleCatalog.config("compact"))
	var state := VehicleState.new()
	state.position = track.spawn
	var pedal := DriveFrame.sample(0,1,0)
	var road: AudioStreamPlayer = audio.layers.road
	var previous_gain: float = 0.0
	var previous_pitch: float = 0.0
	for speed: float in [4.0,12.0,24.0,40.0]:
		audio.reset()
		state.velocity = Vector2(0,speed)
		var snapshot: Array = state.snapshot()
		for tick: int in range(30): audio.present(state,pedal,track,0.05,false)
		check(state.snapshot()==snapshot,"presentation preserves canonical state at "+str(speed))
		check(float(audio.levels.road)>previous_gain,"rolling gain increases at "+str(speed))
		check(road.pitch_scale>previous_pitch and road.pitch_scale<=1.14,"bounded speed texture at "+str(speed))
		check(road.stream==audio.streams.wet_road,"wet derivative uses existing road voice")
		check(float(audio.levels.water)==0.0,"no weather-wide spray")
		previous_gain = float(audio.levels.road)
		previous_pitch = road.pitch_scale
	state.velocity = Vector2.ZERO
	audio.present(state,pedal,track,0.05,false)
	check(float(audio.levels.road)==0 and road.volume_linear==0,"stationary asphalt immediately silent despite throttle")
	state.velocity = Vector2(0,-24)
	audio.present(state,pedal,track,0.1,false)
	check(float(audio.levels.road)>0,"reverse rolls on wet asphalt")
	state.jump_height = 1
	audio.present(state,pedal,track,0.05,false)
	check(float(audio.levels.road)==0 and float(audio.levels.water)==0,"airborne tire contact immediately silent")
	state.jump_height = 0
	state.roll_ticks = 10
	audio.present(state,pedal,track,0.05,false)
	check(float(audio.levels.road)==0,"rolling car has no grounded tire bed")
	state.roll_ticks = 0
	track.cells.fill(1)
	audio.present(state,pedal,track,0.05,false)
	check(float(audio.levels.road)==0 and float(audio.levels.water)==0 and float(audio.levels.grass)>0,"storm grass has grass contact, no asphalt or blanket spray")
	track.cells.fill(6)
	audio.present(state,pedal,track,0.05,false)
	check(float(audio.levels.road)==0 and float(audio.levels.water)>0,"puddles retain actual water contact")
	track.cells.fill(0)
	audio.present(state,pedal,track,0.05,false,true)
	check(float(audio.levels.road)==0 and float(audio.levels.water)==0,"countdown suppresses road and puddle motion")
	audio.present(state,pedal,track,0.05,false)
	var cursor: AudioStream = road.stream
	audio.present(state,pedal,track,0.05,true)
	check(road.stream_paused and road.stream==cursor,"pause suspends rolling playback")
	audio.reset()
	check(float(audio.levels.road)==0 and not road.stream_paused,"retry clears levels and unpauses")
	track.metadata.theme = "pine"
	audio.present(state,pedal,track,0.1,false)
	check(road.stream==audio.streams.road,"dry asphalt restores dry recording")
	track.metadata.theme = "storm"
	audio.present(state,pedal,track,0.1,false)
	check(audio.get_child_count()==22,"wet rolling adds no playback voices")
	var weather := StormWeather.new()
	root.add_child(weather)
	var weather_voices: int = 0
	for child: Node in weather.get_children():
		if child is AudioStreamPlayer:
			weather_voices += 1
			check(child==weather.thunder_audio,"weather contains only the requested thunder voice")
	check(weather_voices==1,"storm has no ambient rain player")
	weather.free()
	if "--capture" in OS.get_cmdline_user_args():
		check(DisplayServer.get_name()!="headless","native capture uses audio driver")
		if DisplayServer.get_name()!="headless": await capture(audio,state,pedal,track)
	audio.free()
	await create_timer(0.15).timeout
	print("WET_ROAD_AUDIO: %d checks, %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)

func capture(audio: VehicleAudio, state: VehicleState, pedal: DriveFrame, track: NativeTrack) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var bus: int = AudioServer.get_bus_count()
	AudioServer.add_bus()
	AudioServer.set_bus_name(bus,"WetRoadReview")
	AudioServer.set_bus_send(bus,"Tires")
	var record := AudioEffectRecord.new()
	record.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(bus,record)
	(audio.layers.road as AudioStreamPlayer).bus = "WetRoadReview"
	var rows: Array[Dictionary] = []
	for scene: String in ["slow","medium","fast","stopped","airborne","paused"]:
		state.velocity = Vector2(0,4 if scene=="slow" else 16 if scene=="medium" else 40)
		if scene=="stopped": state.velocity = Vector2.ZERO
		state.jump_height = 1 if scene=="airborne" else 0
		for tick: int in range(30): audio.present(state,pedal,track,0.05,scene=="paused")
		await create_timer(0.20).timeout
		record.set_recording_active(true)
		await create_timer(2.5).timeout
		record.set_recording_active(false)
		var sample: AudioStreamWAV = record.get_recording()
		check(sample.save_to_wav(OUT.path_join(scene+".wav"))==OK,"native rolling PCM: "+scene)
		rows.append({"scene":scene,"speed_mps":state.velocity.length(),"gain":audio.levels.road,"pitch":(audio.layers.road as AudioStreamPlayer).pitch_scale,"rate":sample.mix_rate})
	var report := FileAccess.open(OUT.path_join("capture.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify(rows,"\t")+"\n")
	report.close()
	(audio.layers.road as AudioStreamPlayer).bus = "Tires"
	AudioServer.remove_bus(bus)
