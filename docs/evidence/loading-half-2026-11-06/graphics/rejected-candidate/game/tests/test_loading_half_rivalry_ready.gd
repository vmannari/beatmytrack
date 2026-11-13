extends "res://tests/test_rivalry_ready_entry.gd"
## The original native readiness gate still exercises real 3D render targets.
func run() -> void:
	preload("res://ui/rivalry_podium_pictures.gd").enabled = false
	OS.set_environment("BMT_RIVALRY_READY_CAPTURE_DIR",OS.get_environment("BMT_GRAPHICS_OUTPUT"))
	await super.run()
