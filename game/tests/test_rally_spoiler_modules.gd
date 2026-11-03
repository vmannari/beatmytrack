extends "res://tests/test_modular_car_assets.gd"
## Compare each live spoiler module with a procedural stock car. Stock base
## snapshots are deliberately not required for this focused module test.
func run() -> void:
	Garage.enabled = false
	for simple: bool in [false, true]:
		var stock: Dictionary = VehicleCustomisation.defaults()
		var control: CarVisual = await make_car("compact", simple, true, stock, false)
		var prepared: CarVisual = await make_car("compact", simple, true, stock, false)
		# The baker records parent paths after assigning the stock snapshot's
		# deterministic names. Both procedural comparison cars need those paths.
		Rest._stable_names(control)
		Rest._stable_names(prepared)
		for option: Array in VehicleCustomisation.OPTIONS.aero.slice(1):
			exercise_single_replacement(control, prepared, "compact", simple, "aero", str(option[0]))
			await process_frame
		control.free()
		prepared.free()
		await process_frame
	print("RALLY_SPOILER_MODULES: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
