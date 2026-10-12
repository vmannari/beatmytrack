extends SceneTree
## Owner-deferred wet rolling stays silent; quiet rain and other surfaces remain.
const OUT: String = "res://../docs/evidence/wet-tires-deferred-2026-10-09"
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
	for speed: float in [4.0,12.0,24.0,40.0]:
		audio.reset()
		state.velocity = Vector2(0,speed)
		var snapshot: Array = state.snapshot()
		for tick: int in range(30): audio.present(state,pedal,track,0.05,false)
		check(state.snapshot()==snapshot,"presentation preserves canonical state at "+str(speed))
		check(float(audio.levels.road)==0 and road.volume_linear==0,"deferred wet rolling silent at "+str(speed))
		check(not audio.streams.has("wet_road"),"rejected wet derivative is not loaded")
		check(road.stream==audio.streams.road,"muted road voice retains ordinary dry stream")
		check(float(audio.levels.water)==0.0,"no weather-wide spray")
	state.velocity = Vector2.ZERO
	audio.present(state,pedal,track,0.05,false)
	check(float(audio.levels.road)==0 and road.volume_linear==0,"stationary asphalt immediately silent despite throttle")
	state.velocity = Vector2(0,-24)
	audio.present(state,pedal,track,0.1,false)
	check(float(audio.levels.road)==0,"deferred wet rolling silent in reverse")
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
	check(road.stream==audio.streams.road and float(audio.levels.road)>0,"ordinary dry asphalt rolling still plays")
	track.metadata.theme = "storm"
	audio.present(state,pedal,track,0.1,false)
	check(float(audio.levels.road)==0 and road.volume_linear==0,"return to storm immediately suppresses dry rolling tail")
	check(audio.get_child_count()==23,"wet rolling adds no playback voices; one kerb loop is separately bounded")
	var weather := StormWeather.new()
	root.add_child(weather)
	var weather_voices: int = 0
	for child: Node in weather.get_children():
		if child is AudioStreamPlayer:
			weather_voices += 1
			check(child==weather.thunder_audio or child==weather.thunder_tail_audio or child==weather.rain_audio or child==weather.rumble_audio,"storm has rain, distant bed and two bounded strike voices")
	check(weather_voices==4,"one rain, one distant bed and two thunder crossfade voices")
	var rumble: AudioStreamWAV = weather.rumble_audio.stream
	check(rumble.loop_mode==AudioStreamWAV.LOOP_FORWARD and absf(rumble.get_length()-16.0)<.001,"distant rumble is a continuous sixteen-second PCM loop")
	check(weather.rumble_audio.bus=="Vehicle" and weather.rumble_audio.volume_linear==0.0,"distant thunder begins silent and follows Vehicle volume")
	check(weather.thunder_audio.bus=="Vehicle" and is_equal_approx(weather.thunder_audio.volume_linear,StormWeather.THUNDER_LEVEL),"thunder obeys Vehicle volume at its audible level")
	weather.advance(1.0,false)
	check(is_equal_approx(weather.rain_gain,StormWeather.RAIN_LEVEL) and weather.rain_audio.bus=="Vehicle","rain reaches restrained level through Vehicle volume")
	check(is_equal_approx(weather.rumble_audio.volume_linear,StormWeather.RUMBLE_LEVEL) and weather.thunder_count==0,"faint rumble reaches its level independently of lightning")
	# Headless presentation does not auto-start ambient loops. Start the fixture
	# voice explicitly so cursor suspension is checked on actual playback.
	weather.rumble_audio.play()
	check(weather.rumble_audio.playing,"distant loop is playing before suspension checks")
	var weather_elapsed: float = weather.elapsed
	weather._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	weather.advance(1.0,false)
	check(weather.suspended and weather.elapsed==weather_elapsed and is_equal_approx(weather.rain_gain,StormWeather.RAIN_LEVEL),"backgrounding freezes weather and rain fade")
	check(weather.rumble_audio.stream_paused,"backgrounding pauses distant thunder")
	weather._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	weather.advance(1.0,true)
	check(not weather.suspended and weather.elapsed==weather_elapsed,"focus return retains race pause")
	check(weather.rumble_audio.stream_paused,"race pause holds the distant thunder cursor")
	weather.advance(0.25,false,true)
	check(weather.rumble_audio.volume_linear>0.0 and weather.rumble_audio.volume_linear<StormWeather.RUMBLE_LEVEL,"distant thunder fades out with rain after finish")
	weather.advance(1.0,false,true)
	check(weather.rain_gain==0.0 and not weather.rain_audio.playing,"finished race fades and stops rain")
	check(weather.rumble_audio.volume_linear==0.0 and not weather.rumble_audio.playing,"finished race silences and stops distant thunder")
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
		var pcm: PackedByteArray = sample.data
		var peak: int = 0
		for offset: int in range(0,pcm.size(),2): peak = maxi(peak,absi(pcm.decode_s16(offset)))
		check(peak==0,"actual deferred wet rolling PCM is silent: "+scene)
		rows.append({"scene":scene,"speed_mps":state.velocity.length(),"gain":audio.levels.road,"pitch":(audio.layers.road as AudioStreamPlayer).pitch_scale,"rate":sample.mix_rate})
	var report := FileAccess.open(OUT.path_join("capture.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify(rows,"\t")+"\n")
	report.close()
	(audio.layers.road as AudioStreamPlayer).bus = "Tires"
	AudioServer.remove_bus(bus)
