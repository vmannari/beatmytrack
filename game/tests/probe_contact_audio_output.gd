extends SceneTree
## Emits only this test process's event cues for timestamped process loopback.
var output: String = "res://../build/snow-audio-response-2026-10-22/before"

func _initialize() -> void: run.call_deferred()

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="): output = argument.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for label: String in ["Engine","Tires","Music","Interface"]:
		AudioServer.set_bus_mute(AudioServer.get_bus_index(label),true)
	var audio := VehicleAudio.new()
	root.add_child(audio)
	audio.configure("compact",VehicleCatalog.config("compact"))
	audio._stream("snow_hit",false)
	var ready := FileAccess.open(output.path_join("ready.json"),FileAccess.WRITE)
	ready.store_string(JSON.stringify({"pid":OS.get_process_id(),"driver":AudioServer.get_driver_name(),"device":AudioServer.output_device,"reported_latency_ms":AudioServer.get_output_latency()*1000.0,"native":audio.windows_impacts.stats()}))
	ready.close()
	var deadline: int = Time.get_ticks_msec()+15000
	while not FileAccess.file_exists(output.path_join("armed")):
		await process_frame
		if Time.get_ticks_msec()>deadline:
			print("CONTACT_OUTPUT_PROBE: capture was not armed")
			quit(1)
			return
	var rows: Array[Dictionary] = []
	for trial: int in range(3):
		for clip: String in ["snow_hit","impact_0","impact_1","impact_2","chassis"]:
			audio.reset()
			await create_timer(.45).timeout
			var before: int = int(audio.windows_impacts.stats().get("submitted",0))
			var requested: int = int(Time.get_unix_time_from_system()*1000000.0)
			audio._event(clip,.65,1.0)
			var native: bool = int(audio.windows_impacts.stats().get("submitted",0))>before
			rows.append({"trial":rows.size(),"repeat":trial,"clip":clip,"unix_us":requested,"reported_latency_ms":AudioServer.get_output_latency()*1000.0,"next_mix_ms":AudioServer.get_time_to_next_mix()*1000.0,"route":"windows_raw" if native else "godot","native":audio.windows_impacts.stats()})
			await create_timer(.45).timeout
	audio.reset()
	var report := FileAccess.open(output.path_join("events.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify(rows,"\t"))
	report.close()
	audio.free()
	await create_timer(.2).timeout
	print("CONTACT_OUTPUT_PROBE: %d events"%rows.size())
	quit()
