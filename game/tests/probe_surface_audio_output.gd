extends SceneTree
## Own-process output measurement; existing streams, gains and buses remain intact.
var output: String = "res://../build/surface-audio-latency-2026-10-23/before"

func _initialize() -> void: run.call_deferred()

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="): output = argument.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for label: String in ["Music","Interface"]: AudioServer.set_bus_mute(AudioServer.get_bus_index(label),true)
	var audio := VehicleAudio.new()
	root.add_child(audio)
	audio.configure("compact",VehicleCatalog.config("compact"))
	var file := FileAccess.open(output.path_join("ready.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"pid":OS.get_process_id(),"driver":AudioServer.get_driver_name(),"device":AudioServer.output_device,"reported_latency_ms":AudioServer.get_output_latency()*1000.0,"rate":AudioServer.get_mix_rate()}))
	file.close()
	var deadline: int = Time.get_ticks_msec()+15000
	while not FileAccess.file_exists(output.path_join("armed")):
		await process_frame
		if Time.get_ticks_msec()>deadline:
			quit(1)
			return
	var rows: Array[Dictionary] = []
	for repeat: int in range(3):
		for clip: String in ["kerb_roll","grass","scrape","water","grit_0","engine"]:
			audio.reset()
			await create_timer(.45).timeout
			var requested: int = int(Time.get_unix_time_from_system()*1000000.0)
			if clip=="engine": audio.engine_load[0].volume_linear = .6
			elif clip=="grit_0": audio._event(clip,.6,1.0,true)
			else: audio._layer(clip,.6,1.0,.1,false)
			rows.append({"trial":rows.size(),"repeat":repeat,"clip":clip,"unix_us":requested,"next_mix_ms":AudioServer.get_time_to_next_mix()*1000.0,"reported_latency_ms":AudioServer.get_output_latency()*1000.0})
			await create_timer(.45).timeout
	audio.reset()
	file = FileAccess.open(output.path_join("events.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"\t"))
	file.close()
	file = FileAccess.open(output.path_join("output-stats.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(GameSoundtrack.instance().windows_output.stats(),"\t"))
	file.close()
	audio.free()
	await create_timer(.2).timeout
	print("SURFACE_OUTPUT_PROBE: %d events"%rows.size())
	quit()
