extends "res://tests/test_modular_car_assets.gd"

func run() -> void:
	only_vehicle = "forklift"
	all_kits = true
	await super.run()
