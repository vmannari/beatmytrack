extends "res://tests/bake_kart_model.gd"
func _initialize() -> void:
	preload("res://vehicle/modular_car_base.gd").enabled = false
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	preload("res://ui/garage_car_cache.gd").enabled = false
	super._initialize()
