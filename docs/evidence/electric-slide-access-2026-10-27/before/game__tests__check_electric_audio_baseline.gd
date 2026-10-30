extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var baseline := GDScript.new()
	baseline.source_code = FileAccess.get_file_as_string("res://../docs/evidence/electric-car-2026-10-25/before/vehicle_audio.gd.txt").trim_prefix("\ufeff").replace("class_name VehicleAudio","")
	assert(baseline.reload() == OK)
	for source: GDScript in [baseline,load("res://vehicle/vehicle_audio.gd")]:
		var audio: Node = source.new()
		root.add_child(audio)
		audio.configure("compact",VehicleCatalog.config("compact"))
		audio.present(VehicleState.new(),DriveFrame.new(),null,0.1,true)
		print("AUDIO_PAUSE_BASELINE current=",source != baseline," output_enabled=",audio.output_enabled," paused=",audio.engine_load[0].stream_paused)
		audio.free()
	quit()
