extends "res://tests/test_racing_car_models.gd"
## Counterfactual only: keep current assets with the exact task-start constructor.
func _run() -> void:
	var original: String = FileAccess.get_file_as_string("res://../docs/evidence/garage-icon-latency-2026-10-26/before/game/vehicle/car_visual.gd")
	var model: GDScript = load("res://vehicle/car_visual.gd")
	model.source_code = original
	check(not original.is_empty() and model.reload()==OK,"task-start car constructor reloads only in isolated memory")
	await super._run()
