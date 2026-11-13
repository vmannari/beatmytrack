extends "res://tests/test_modular_car_assets.gd"
## RBC04: compare each Rally body/aero module to the live source constructor.
func run() -> void:
	Garage.enabled = false
	for simple: bool in [false,true]:
		var stock: Dictionary = VehicleCustomisation.defaults()
		var control: CarVisual = await make_car("compact",simple,true,stock,false)
		var prepared: CarVisual = await make_car("compact",simple,true,stock,false)
		Rest._stable_names(control)
		Rest._stable_names(prepared)
		for category: String in ["body","aero"]:
			for option: Array in VehicleCustomisation.OPTIONS[category].slice(1):
				exercise_single_replacement(control,prepared,"compact",simple,category,str(option[0]))
				await process_frame
		control.free()
		prepared.free()
		await process_frame
	print("RALLY_KIT_MODULES: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
