extends SceneTree
## Own-process PCM/control verification and sustained real driving mix.
var output: String = "res://../build/surface-audio-latency-2026-10-23/controls"
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func save_json(name: String, data: Variant) -> void:
	var file := FileAccess.open(output.path_join(name),FileAccess.WRITE)
	file.store_string(JSON.stringify(data,"\t"))
	file.close()

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="): output = argument.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var world: GameSoundtrack = GameSoundtrack.instance()
	world.begin_race(root,"pine",VehicleState.new())
	world.apply_settings({"music_volume":1.0,"interface_volume":1.0})
	var transfer: WindowsAudioOutput = world.windows_output
	check(transfer.backend!=null and bool(transfer.stats().ready),"native shared output ready")
	if transfer.backend==null:
		quit(1)
		return
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 48000
	stream.stereo = true
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = 48000
	var data := PackedByteArray()
	data.resize(48000*4)
	for frame: int in range(48000):
		var time: float = float(frame)/48000.0
		# Distinct channels and incommensurate sums expose pitch/phase/copy errors.
		var left: float = .12*sin(TAU*431*time)+.04*sin(TAU*719*time)
		var right: float = .09*sin(TAU*613*time)+.03*sin(TAU*997*time)
		data.encode_s16(frame*4,roundi(left*32767))
		data.encode_s16(frame*4+2,roundi(right*32767))
	stream.data = data
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = "Tires"
	root.add_child(player)
	var recorder := AudioEffectRecord.new()
	AudioServer.add_bus_effect(0,recorder)
	transfer.sync_output()
	save_json("ready.json",{"pid":OS.get_process_id(),"driver":AudioServer.get_driver_name(),"rate":AudioServer.get_mix_rate()})
	var deadline: int = Time.get_ticks_msec()+15000
	while not FileAccess.file_exists(output.path_join("armed")):
		await process_frame
		if Time.get_ticks_msec()>deadline:
			quit(1)
			return
	player.play()
	recorder.set_recording_active(true)
	var rows: Array[Dictionary] = []
	var stages: Array = [
		["full","Tires",1.0,"",1.0,false],
		["master_half","Tires",.5,"",1.0,false],
		["master_mute","Tires",1.0,"",1.0,true],
		["vehicle_half","Tires",1.0,"Vehicle",.5,false],
		["vehicle_mute","Tires",1.0,"Vehicle",0.0,false],
		["tires_half","Tires",1.0,"Tires",.5,false],
		["tires_mute","Tires",1.0,"Tires",0.0,false],
		["engine","Engine",1.0,"",1.0,false],
		["engine_mute","Engine",1.0,"Engine",0.0,false],
		["music","Music",1.0,"",1.0,false],
		["music_mute","Music",1.0,"Music",0.0,false],
		["interface","Interface",1.0,"",1.0,false],
		["interface_mute","Interface",1.0,"Interface",0.0,false],
		["solo_excludes","Tires",1.0,"Engine",1.0,false],
		["solo_includes","Tires",1.0,"Tires",1.0,false],
		["normal_reference","Tires",1.0,"",1.0,false],
		["normal_fallback","Tires",1.0,"",1.0,false],
		["restored","Tires",1.0,"",1.0,false]]
	for stage: Array in stages:
		for bus: int in range(AudioServer.bus_count):
			AudioServer.set_bus_volume_db(bus,0)
			AudioServer.set_bus_mute(bus,false)
			AudioServer.set_bus_solo(bus,false)
		player.bus = stage[1]
		AudioServer.set_bus_volume_db(0,linear_to_db(stage[2]))
		AudioServer.set_bus_mute(0,stage[5])
		if stage[3]!="":
			var bus: int = AudioServer.get_bus_index(stage[3])
			AudioServer.set_bus_volume_db(bus,linear_to_db(maxf(stage[4],.0001)))
			AudioServer.set_bus_mute(bus,stage[4]==0)
			if str(stage[0]).begins_with("solo_"): AudioServer.set_bus_solo(bus,true)
		# Explicitly solo the complete authored Tires -> Vehicle -> Master chain.
		if stage[0]=="solo_includes": AudioServer.set_bus_solo(AudioServer.get_bus_index("Vehicle"),true)
		transfer.sync_output()
		for index: int in range(AudioServer.get_bus_effect_count(0)):
			if AudioServer.get_bus_effect(0,index)==transfer.effect:
				AudioServer.set_bus_effect_enabled(0,index,stage[0]!="normal_reference")
		if stage[0]=="normal_fallback": transfer.backend.call("set_output",1.0,false,false)
		elif stage[0]=="restored": transfer.backend.call("set_output",1.0,false,true)
		rows.append({"stage":stage[0],"unix_us":int(Time.get_unix_time_from_system()*1000000.0)})
		await create_timer(.9).timeout
	player.stop()
	recorder.set_recording_active(false)
	var recording: AudioStreamWAV = recorder.get_recording()
	check(recording!=null and recording.save_to_wav(output.path_join("pre-fader.wav"))==OK,"upstream recorder retains the actual original PCM")
	for index: int in range(AudioServer.get_bus_effect_count(0)):
		if AudioServer.get_bus_effect(0,index)==recorder:
			AudioServer.remove_bus_effect(0,index)
			break
	player.free()
	for bus: int in range(AudioServer.bus_count): AudioServer.set_bus_solo(bus,false)
	var audio := VehicleAudio.new()
	root.add_child(audio)
	audio.configure("compact",VehicleCatalog.config("compact"))
	var track: NativeTrack = NativeTrack.read("res://resources/tracks/starter_circuit.json")
	var state := VehicleState.new()
	state.position = track.spawn
	state.velocity = Vector2(3,24)
	var frame := DriveFrame.sample(.1,1,0)
	var finish: int = Time.get_ticks_msec()+12000
	while Time.get_ticks_msec()<finish:
		audio.present(state,frame,track,1.0/60.0,false)
		audio._layer("kerb_roll",.25,1.0,.1,false)
		await process_frame
	audio.reset()
	await create_timer(.25).timeout
	var stats: Dictionary = transfer.stats()
	check(not bool(stats.failed) and int(stats.overflows)==0,"sustained engine/road/kerb mix never overflows or falls back")
	check(int(stats.peak_queued_frames)<=4096 and int(stats.rendered_frames)>48000*20,"sustained mixed playback remains in the fixed ring")
	save_json("output-stats.json",stats)
	save_json("controls.json",rows)
	# A closed backend passes through the unchanged effect; unsupported rate fails open.
	var backend: RefCounted = transfer.backend
	backend.call("close")
	check(not bool(backend.call("stats").ready),"closed worker is joined")
	transfer.close()
	var unavailable: RefCounted = ClassDB.instantiate("BmtWindowsMixSink")
	check(not bool(unavailable.call("open",44100 if AudioServer.get_mix_rate()!=44100 else 48000)),"unsupported source/device rate retains normal output")
	unavailable.call("close")
	audio.free()
	transfer.configure()
	save_json("test-report.json",{"checks":checks,"failures":failures})
	print("MIXED_AUDIO_OUTPUT: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
