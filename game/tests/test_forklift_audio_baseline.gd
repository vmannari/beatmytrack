extends "res://tests/test_vehicle_audio.gd"
## Reproduce the retained audio-pause diagnostic with the task-start audio implementation.
func _initialize() -> void:
	var audio_script: GDScript = load("res://vehicle/vehicle_audio.gd")
	audio_script.source_code = FileAccess.get_file_as_string("res://../docs/evidence/forklift-2026-10-25/before/game__vehicle__vehicle_audio.gd")
	if audio_script.reload() != OK:
		quit(2)
		return
	print("FORKLIFT_AUDIO_BASELINE: task-start VehicleAudio loaded only in this process")
	call_deferred("run")
