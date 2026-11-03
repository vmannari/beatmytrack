extends "res://tests/test_compact_aero_variety.gd"
## Run the retained silhouette and roll checks against source-built parts.
func _initialize() -> void:
	CompactKits.use_baked = false
	preload("res://vehicle/modular_car_kits.gd").enabled = false
	preload("res://vehicle/modular_car_base.gd").enabled = false
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	preload("res://ui/garage_car_cache.gd").enabled = false
	_run.call_deferred()
