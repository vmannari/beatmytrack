extends SceneTree
## Actual race presentation, held speed, default music, raw rain and engine references.
const OUT: String = "res://../docs/evidence/rain-presence-2026-10-09"
var evidence_dir: String = OUT
var verify_loop: bool = false
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func run() -> void:
	check(DisplayServer.get_name()!="headless","native output required")
	if DisplayServer.get_name()=="headless":
		quit(1)
		return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-dir="): evidence_dir = argument.trim_prefix("--evidence-dir=")
		if argument=="--capture-loop": verify_loop = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence_dir))
	var game: Node = load("res://core/game.tscn").instantiate()
	game.initial_track = NativeTrack.read("res://resources/tracks/starter_circuit.json")
	game.initial_track.metadata.theme = "storm"
	root.add_child(game)
	game.set_physics_process(false) # Held presentation, no race completion or record writes.
	game.set_process(false) # Drive actual presentation explicitly as a foreground fixture.
	game.countdown_ticks = 0
	game.sim.state.velocity = game.sim.state.forward()*24.0
	game.frame = DriveFrame.sample(0,0.7,0)
	var weather: StormWeather = game.storm_weather
	weather.until_lightning = 9999.0
	check(weather!=null and weather.visible,"actual storm race installs visible weather")
	var bus: int = AudioServer.get_bus_count()
	AudioServer.add_bus()
	AudioServer.set_bus_name(bus,"RainPresenceReview")
	AudioServer.set_bus_send(bus,"Vehicle")
	var source_bus: int = AudioServer.get_bus_count()
	AudioServer.add_bus()
	AudioServer.set_bus_name(source_bus,"RainPresenceSource")
	AudioServer.set_bus_send(source_bus,"RainPresenceReview")
	weather.rain_audio.bus = "RainPresenceSource"
	var buses: Array[int] = [0,AudioServer.get_bus_index("Engine"),AudioServer.get_bus_index("Music"),bus]
	var names: Array[String] = ["mix","engine","music","rain"]
	var records: Array[AudioEffectRecord] = []
	for index: int in buses:
		var record := AudioEffectRecord.new()
		record.format = AudioStreamWAV.FORMAT_16_BITS
		AudioServer.add_bus_effect(index,record)
		records.append(record)
	var rows: Array[Dictionary] = []
	var scenes: Array[String] = ["before","after","paused","muted"]
	if verify_loop: scenes.append("loop")
	for scene: String in scenes:
		game.paused = scene=="paused"
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Vehicle"),scene=="muted")
		# A separate parent gain reproduces .13 without racing the player's
		# instantaneous volume; use the same unchanged rain PCM in both mixes.
		AudioServer.set_bus_volume_linear(source_bus,0.13/StormWeather.RAIN_LEVEL if scene=="before" else 1.0)
		weather.rain_audio.play(0.0)
		var elapsed: float = 0.0
		while elapsed<1.0:
			await process_frame
			game.paused = scene=="paused"
			game.frame = DriveFrame.sample(0,0.7,0)
			weather._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
			GameSoundtrack.instance()._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
			game._process(root.get_process_delta_time())
			elapsed += root.get_process_delta_time()
		check(weather.rain_audio.stream_paused if scene=="paused" else weather.rain_audio.playing,"race rain obeys foreground/pause playback: "+scene)
		check(float(game.vehicle_audio.levels.road)==0 and not game.vehicle_audio.streams.has("wet_road"),"wet rolling stays deferred: "+scene)
		for record: AudioEffectRecord in records: record.set_recording_active(true)
		elapsed = 0.0
		var duration: float = weather.rain_audio.stream.get_length()+2.0 if scene=="loop" else 3.0 if scene in ["before","after"] else 1.0
		var previous_cursor: float = weather.rain_audio.get_playback_position()
		var wraps: int = 0
		while elapsed<duration:
			await process_frame
			game.paused = scene=="paused"
			game.frame = DriveFrame.sample(0,0.7,0)
			weather._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
			GameSoundtrack.instance()._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
			game._process(root.get_process_delta_time())
			elapsed += root.get_process_delta_time()
			var cursor: float = weather.rain_audio.get_playback_position()
			if cursor+.5<previous_cursor: wraps += 1
			previous_cursor = cursor
		for i: int in range(records.size()):
			records[i].set_recording_active(false)
			check(records[i].get_recording().save_to_wav(evidence_dir.path_join(scene+"-"+names[i]+".wav"))==OK,"native race audio: "+scene+" "+names[i])
		if scene=="loop": check(wraps>=1,"actual owner rain crosses a native loop boundary")
		rows.append({"scene":scene,"rain_gain":weather.rain_gain,"rain_review_gain":AudioServer.get_bus_volume_linear(source_bus),"paused":game.paused,"music_mode":GameSoundtrack.instance().mode,"music_bus_gain":AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("Music")),"rain_wraps":wraps})
	var file := FileAccess.open(evidence_dir.path_join("capture.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"\t")+"\n")
	file.close()
	game.paused = true
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Vehicle"),false)
	weather.rain_audio.bus = "Vehicle"
	game.free()
	GameSoundtrack.instance().show_menu()
	await create_timer(.15).timeout
	for index: int in buses: AudioServer.remove_bus_effect(index,AudioServer.get_bus_effect_count(index)-1)
	AudioServer.remove_bus(source_bus)
	AudioServer.remove_bus(bus)
	print("RAIN_PRESENCE_CAPTURE: %d checks, %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)
