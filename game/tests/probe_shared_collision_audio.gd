extends SceneTree
var out: String = "res://../build/shared-collision-audio-2026-10-09/before"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--audio-probe-output="): out = argument.trim_prefix("--audio-probe-output=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var ready_file: FileAccess = FileAccess.open(out.path_join("ready.json"),FileAccess.WRITE)
	ready_file.store_string(JSON.stringify({"pid":OS.get_process_id(),"driver":AudioServer.get_driver_name(),"reported_latency_ms":AudioServer.get_output_latency()*1000.0}))
	ready_file.close()
	var timeout: int = Time.get_ticks_msec()+60000
	while not FileAccess.file_exists(out.path_join("armed")):
		await process_frame
		if Time.get_ticks_msec()>timeout:
			quit(1)
			return
	var audio := VehicleAudio.new()
	root.add_child(audio)
	audio.configure("compact",VehicleCatalog.config("compact"))
	for bus: int in range(1,AudioServer.bus_count):
		AudioServer.set_bus_mute(bus,AudioServer.get_bus_name(bus) not in ["Vehicle","Impacts"])
	var rows: Array[Dictionary] = []
	for trial: int in range(6):
		audio.reset()
		await create_timer(1.0).timeout
		var native_before: Dictionary = audio.windows_impacts.stats()
		var request: int = int(Time.get_unix_time_from_system()*1000000.0)
		var clip: String = "impact_2" if trial%2==0 else "chassis"
		if clip=="chassis": audio._event("chassis",.12,1.32)
		else:
			audio.begin_physics_feedback()
			audio.collision(Vector2(20,0))
		var native_after: Dictionary = audio.windows_impacts.stats()
		rows.append({"trial":trial,"unix_us":request,"clip":clip,"route":"windows_raw" if int(native_after.get("submitted",0))>int(native_before.get("submitted",0)) else "godot","native":native_after,"next_mix_ms":AudioServer.get_time_to_next_mix()*1000.0,"reported_latency_ms":AudioServer.get_output_latency()*1000.0})
		await create_timer(.5).timeout
	var file: FileAccess = FileAccess.open(out.path_join("events.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"\t"))
	file.close()
	audio.free()
	await create_timer(.2).timeout
	print("SHARED_COLLISION_AUDIO: ",JSON.stringify(rows))
	quit()
