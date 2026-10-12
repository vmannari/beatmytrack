extends SceneTree
## Real race presentation: lightning/delayed recorded thunder, pause and mute.
const OUT: String = "res://../docs/evidence/rain-thunder-2026-10-10"
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")
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
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = NativeTrack.read("res://resources/tracks/starter_circuit.json")
	game.initial_track.metadata.theme = "storm"
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.countdown_ticks = 0
	game.sim.state.velocity = game.sim.state.forward()*24
	var weather: StormWeather = game.storm_weather
	weather.rng.seed = 317
	weather.until_lightning = 9999
	var buses: Array[int] = [0,AudioServer.get_bus_index("Music"),AudioServer.get_bus_index("Engine")]
	for label: String in ["RainReview","ThunderReview"]:
		var bus: int = AudioServer.get_bus_count()
		AudioServer.add_bus()
		AudioServer.set_bus_name(bus,label)
		AudioServer.set_bus_send(bus,"Vehicle")
		buses.append(bus)
	weather.rain_audio.bus = "RainReview"
	weather.thunder_audio.bus = "ThunderReview"
	var records: Array[AudioEffectRecord] = []
	var names: Array[String] = ["mix","music","engine","rain","thunder"]
	for bus: int in buses:
		var record := AudioEffectRecord.new()
		record.format = AudioStreamWAV.FORMAT_16_BITS
		AudioServer.add_bus_effect(bus,record)
		records.append(record)
	var rows: Array[Dictionary] = []
	for scene: String in ["strike","paused","muted"]:
		var paused: bool = scene=="paused"
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Vehicle"),scene=="muted")
		var elapsed: float = 0
		while elapsed<1:
			await process_frame
			present(game,weather,paused)
			elapsed += root.get_process_delta_time()
		var strikes_before: int = weather.strikes
		var thunder_before: int = weather.thunder_count
		if scene=="strike": weather.until_lightning = .02
		else: weather.until_thunder = .2
		for record: AudioEffectRecord in records: record.set_recording_active(true)
		elapsed = 0
		var lightning_at: float = -1
		var thunder_at: float = -1
		while elapsed<(12.0 if scene=="strike" else 2.0):
			await process_frame
			present(game,weather,paused)
			elapsed += root.get_process_delta_time()
			if weather.strikes>strikes_before and lightning_at<0:
				lightning_at = elapsed
				weather.until_lightning = 9999 # Exactly one scheduled fixture strike.
			if weather.thunder_count>thunder_before and thunder_at<0: thunder_at = elapsed
		for i: int in range(records.size()):
			records[i].set_recording_active(false)
			check(records[i].get_recording().save_to_wav(OUT.path_join(scene+"-"+names[i]+".wav"))==OK,"native thunder reference: "+scene+" "+names[i])
		check(weather.thunder_count==thunder_before+(0 if paused else 1),"one delayed cue or frozen pending thunder: "+scene)
		if scene=="strike": check(lightning_at>=0 and thunder_at-lightning_at>=1.2 and thunder_at-lightning_at<=2.9,"thunder follows lightning within configured delay")
		rows.append({"scene":scene,"lightning_at":lightning_at,"thunder_at":thunder_at,"music_gain":AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("Music")),"rain_gain":weather.rain_gain,"thunder_gain":weather.thunder_audio.volume_linear})
	var file := FileAccess.open(OUT.path_join("capture.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"\t")+"\n")
	file.close()
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Vehicle"),false)
	weather.rain_audio.bus = "Vehicle"
	weather.thunder_audio.bus = "Vehicle"
	game.free()
	GameSoundtrack.instance().show_menu()
	await create_timer(.15).timeout
	for bus: int in buses: AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
	AudioServer.remove_bus(buses[4])
	AudioServer.remove_bus(buses[3])
	print("THUNDER_AUDIO_CAPTURE: %d checks, %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)

func present(game: Node,weather: StormWeather,paused: bool) -> void:
	game.paused = paused
	game.frame = DriveFrame.sample(0,.7,0)
	weather._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	GameSoundtrack.instance()._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	game._process(root.get_process_delta_time())
