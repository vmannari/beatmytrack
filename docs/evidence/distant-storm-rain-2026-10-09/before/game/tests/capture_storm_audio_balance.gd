extends SceneTree
## Same-clock engine, wet tire, quiet rain and complete native mixer references.
const OUT: String = "res://../docs/evidence/storm-audio-balance-2026-10-09"
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func run() -> void:
	check(DisplayServer.get_name()!="headless","actual audio driver required")
	if DisplayServer.get_name()=="headless":
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var track: NativeTrack = NativeTrack.read("res://resources/tracks/starter_circuit.json")
	track.metadata.theme = "storm"
	track.cells.fill(0)
	var audio := VehicleAudio.new()
	audio.use_windows_impacts = false
	root.add_child(audio)
	var full_wet: AudioStreamWAV = audio._stream("wet_road",true)
	var baseline_wet: AudioStreamWAV = full_wet.duplicate()
	var baseline_pcm: PackedByteArray = baseline_wet.data
	for offset: int in range(0,baseline_pcm.size(),2):
		baseline_pcm.encode_s16(offset,roundi(float(baseline_pcm.decode_s16(offset))/3.0))
	baseline_wet.data = baseline_pcm
	var weather := StormWeather.new()
	root.add_child(weather)
	weather.until_lightning = 9999.0
	var buses: Array[int] = [0,AudioServer.get_bus_index("Engine")]
	for label: String in ["WetRoadReview","RainReview"]:
		var bus: int = AudioServer.get_bus_count()
		AudioServer.add_bus()
		AudioServer.set_bus_name(bus,label)
		AudioServer.set_bus_send(bus,"Tires" if label=="WetRoadReview" else "Vehicle")
		buses.append(bus)
	(audio.layers.road as AudioStreamPlayer).bus = "WetRoadReview"
	weather.rain_audio.bus = "RainReview"
	var records: Array[AudioEffectRecord] = []
	for bus: int in buses:
		var record := AudioEffectRecord.new()
		record.format = AudioStreamWAV.FORMAT_16_BITS
		AudioServer.add_bus_effect(bus,record)
		records.append(record)
	var names: Array[String] = ["mix","engine","wet","rain"]
	var rows: Array[Dictionary] = []
	for scene: String in ["cruise-before","cruise-after","fast-after","formula-after","stopped","paused","rain-loop"]:
		# The only old/new wet difference is a factor of three. Apply its inverse
		# to this private PCM copy for a stable old-level reference, avoiding
		# temporary volume writes racing the audio thread between present calls.
		audio.streams.wet_road = baseline_wet if scene=="cruise-before" else full_wet
		audio.configure("formula" if scene=="formula-after" else "compact",VehicleCatalog.config("formula" if scene=="formula-after" else "compact"))
		var state := VehicleState.new()
		state.position = track.spawn
		state.velocity = Vector2(0,32 if scene in ["fast-after","formula-after"] else 16)
		if scene in ["stopped","rain-loop"]: state.velocity = Vector2.ZERO
		var input := DriveFrame.sample(0,0.7,0)
		# This fixture models foreground driving; external test windows can
		# steal actual desktop focus. Focus suspension is checked separately.
		weather._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		for tick: int in range(30):
			audio.present(state,input,track,.05,scene=="paused")
			weather.advance(.05,scene=="paused")
		# Compare identical source regions; other phases may have left the player
		# at a different cursor despite the same held presentation state.
		(audio.layers.road as AudioStreamPlayer).play(0.0)
		await create_timer(.25).timeout
		for record: AudioEffectRecord in records: record.set_recording_active(true)
		var elapsed: float = 0.0
		var last_us: int = Time.get_ticks_usec()
		var previous_cursor: float = weather.rain_audio.get_playback_position()
		var wraps: int = 0
		while elapsed<(21.0 if scene=="rain-loop" else 7.0 if scene in ["cruise-before","cruise-after"] else 3.0):
			await process_frame
			var now: int = Time.get_ticks_usec()
			var dt: float = float(now-last_us)/1000000.0
			last_us = now
			elapsed += dt
			state.tick += 1
			weather._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
			audio.present(state,input,track,dt,scene=="paused")
			weather.advance(dt,scene=="paused")
			var cursor: float = weather.rain_audio.get_playback_position()
			if cursor+.5<previous_cursor: wraps += 1
			previous_cursor = cursor
		for i: int in range(records.size()):
			records[i].set_recording_active(false)
			check(records[i].get_recording().save_to_wav(OUT.path_join(scene+"-"+names[i]+".wav"))==OK,"native reference: "+scene+" "+names[i])
		if scene=="rain-loop": check(wraps>=1,"continuous recorded rain crosses a real playback wrap")
		rows.append({"scene":scene,"speed_mps":state.velocity.length(),"road_gain":audio.levels.road,"rain_gain":weather.rain_gain,"rain_wraps":wraps,"foreground_fixture":not weather.suspended})
	var report := FileAccess.open(OUT.path_join("capture.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify(rows,"\t")+"\n")
	report.close()
	audio.free()
	weather.free()
	await create_timer(.15).timeout
	for bus: int in buses: AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
	AudioServer.remove_bus(buses[3])
	AudioServer.remove_bus(buses[2])
	print("STORM_AUDIO_BALANCE_CAPTURE: %d checks, %d failures"%[checks,failures])
	quit(1 if failures>0 else 0)
