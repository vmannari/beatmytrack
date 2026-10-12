extends SceneTree
const OUT: String = "res://../build/audio-output-2026-10-09/controls"

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
	var world: GameSoundtrack = GameSoundtrack.instance()
	var state := VehicleState.new()
	var frame := DriveFrame.new()
	var rows: Array[Dictionary] = []
	var names: Array[String] = ["full","volume-30","vehicle-mute","master-mute","paused","countdown","overlap","engine-mix"]
	for mode: String in names:
		audio.reset()
		world.apply_settings({"vehicle_volume":.3 if mode=="volume-30" else (0.0 if mode=="vehicle-mute" else 1.0)})
		AudioServer.set_bus_mute(0,mode=="master-mute")
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Engine"),mode!="engine-mix")
		if mode=="engine-mix":
			state.velocity = Vector2(30,0)
			frame.throttle = 1.0
			for i: int in range(20):
				audio.present(state,frame,null,.016,false)
				await process_frame
		else:
			state.velocity = Vector2.ZERO
			frame.throttle = 0.0
		await create_timer(.5).timeout
		if mode in ["paused","countdown"]: audio.present(state,frame,null,.016,mode=="paused",mode=="countdown")
		else: audio.begin_physics_feedback()
		var event_us: int = int(Time.get_unix_time_from_system()*1000000.0)
		if mode=="overlap":
			for clip: int in range(3): audio.windows_impacts.play(clip,.9,1.0)
		else: audio.collision(Vector2(20,0))
		rows.append({"trial":rows.size(),"mode":mode,"unix_us":event_us,"native":audio.windows_impacts.stats()})
		await create_timer(.65).timeout
	var file: FileAccess = FileAccess.open(OUT.path_join("events.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"\t"))
	file.close()
	world.apply_settings({})
	AudioServer.set_bus_mute(0,false)
	audio.free()
	await create_timer(.2).timeout
	print("WINDOWS_IMPACT_CONTROLS: ",JSON.stringify(rows))
	quit()
