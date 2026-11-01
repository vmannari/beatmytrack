extends "res://tests/bake_garage_cars.gd"
func _initialize() -> void:
	# The Garage baker needs a PreparedCarCache entry, which modular restore
	# bypasses. Keep this offline operation on the authored/prepared-mesh path.
	preload("res://vehicle/modular_car_base.gd").enabled = false
	super._initialize()
