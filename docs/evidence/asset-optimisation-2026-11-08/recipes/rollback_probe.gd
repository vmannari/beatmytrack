extends "res://tests/test_modular_car_assets.gd"
func run()->void:
	VisualGeometry.batch_transformed_car_parts=false
	await test_last_module_rollback()
	print("ROLLBACK_CONTROL ",checks," checks, ",failures," failures Base=",Base.hits," Kits=",Kits.hits)
	quit(1 if failures else 0)
