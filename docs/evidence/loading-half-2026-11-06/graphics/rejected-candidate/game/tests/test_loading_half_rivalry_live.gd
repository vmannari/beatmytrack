extends "res://tests/test_rivalry_custom_cars.gd"
## Retain the authored native geometry assertions independently of image hits.
func run() -> void:
	preload("res://ui/rivalry_podium_pictures.gd").enabled = false
	OS.set_environment("BMT_RIVALRY_CARS_EVIDENCE_DIR",OS.get_environment("BMT_GRAPHICS_OUTPUT"))
	await super.run()
