extends "res://tests/test_hovercraft.gd"
## Retain the original persistence, presentation, weathering and sound checks.
func _run() -> void:
	OS.set_environment("BMT_API_URL","")
	DirAccess.make_dir_recursive_absolute("user://hovercraft-tests")
	_persistence()
	await _model(VehicleCatalog.config("hovercraft"))
	print("HOVERCRAFT_SPORT_INTEGRATION: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
