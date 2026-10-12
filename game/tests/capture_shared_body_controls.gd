extends SceneTree
const OUT: String = "res://../build/shared-collision-audio-2026-10-09/controls"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var ready_file: FileAccess = FileAccess.open(OUT.path_join("ready.json"),FileAccess.WRITE)
	ready_file.store_string(JSON.stringify({"pid":OS.get_process_id()}))
	ready_file.close()
	var timeout: int = Time.get_ticks_msec()+60000
	while not FileAccess.file_exists(OUT.path_join("armed")):
		await process_frame
		if Time.get_ticks_msec()>timeout:
			quit(1)
			return
	var audio := VehicleAudio.new()
	root.add_child(audio)
	audio.configure("compact",VehicleCatalog.config("compact"))
	var vehicle: int = AudioServer.get_bus_index("Vehicle")
	var impact: int = AudioServer.get_bus_index("Impacts")
	for bus: int in range(1,AudioServer.bus_count):
		AudioServer.set_bus_mute(bus,AudioServer.get_bus_name(bus) not in ["Vehicle","Impacts"])
	var modes: Array[String] = ["chassis-full","chassis-30","chassis-vehicle-mute","chassis-impact-mute","impact-vehicle-mute","chassis-master-mute","chassis-paused","overlap"]
	var rows: Array[Dictionary] = []
	for mode: String in modes:
		audio.reset()
		AudioServer.set_bus_volume_db(vehicle,linear_to_db(.3 if mode=="chassis-30" else 1.0))
		AudioServer.set_bus_mute(vehicle,mode in ["chassis-vehicle-mute","impact-vehicle-mute"])
		AudioServer.set_bus_mute(impact,mode=="chassis-impact-mute")
		AudioServer.set_bus_mute(0,mode=="chassis-master-mute")
		audio.windows_impacts.sync_output(mode=="chassis-paused")
		await create_timer(.5).timeout
		var request: int = int(Time.get_unix_time_from_system()*1000000.0)
		if mode=="impact-vehicle-mute": audio.windows_impacts.play(2,.8,1.0)
		elif mode=="overlap":
			for index: int in range(4): audio.windows_impacts.play(index,.8,1.0,index)
		elif mode=="chassis-paused": audio.windows_impacts.backend.call("play",3,.3,1.0)
		else: audio._event("chassis",.3,1.0)
		rows.append({"mode":mode,"unix_us":request})
		await create_timer(.65).timeout
	var file: FileAccess = FileAccess.open(OUT.path_join("events.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"\t"))
	file.close()
	audio.free()
	AudioServer.set_bus_mute(0,false)
	GameSoundtrack.instance().apply_settings({})
	await create_timer(.2).timeout
	print("SHARED_BODY_CONTROLS: ",JSON.stringify(rows))
	quit()
