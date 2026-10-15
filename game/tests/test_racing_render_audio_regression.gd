extends "res://tests/test_vehicle_audio.gd"
## Existing assertions; isolate generated recordings from earlier evidence.
func _initialize() -> void:
	evidence = "res://../build/racing-render-fixes-2026-10-14/audio"
	super._initialize()
