extends "res://tests/bake_electric_design_shadows.gd"
func _initialize() -> void:
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	preload("res://ui/garage_car_cache.gd").enabled = false
	super._initialize()
