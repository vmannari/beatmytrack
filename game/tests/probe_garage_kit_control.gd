extends "res://tests/test_garage_kit_transition.gd"
## Reproduce retained fixture findings using task-start runtime and assets.
func _initialize() -> void:
	var before: String = "res://../docs/evidence/garage-performance-2026-11-01/before/game/"
	var showroom_script: Script = load("res://ui/car_showroom.gd")
	showroom_script.source_code = FileAccess.get_file_as_string(before+"ui/car_showroom.gd")
	assert(showroom_script.reload(true) == OK)
	GarageEnvironment.architecture_scene = load(before+"assets/garage/workshop_v1.scn")
	var cache_script: Script = load("res://ui/garage_car_cache.gd")
	cache_script.source_code = cache_script.source_code.replace("res://assets/garage/cars_v1/",before+"assets/garage/cars_v1/")
	assert(cache_script.reload(true) == OK)
	super._initialize()
