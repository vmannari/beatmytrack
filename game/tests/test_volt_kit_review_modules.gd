extends "res://tests/test_modular_car_assets.gd"

func run() -> void:
	Garage.enabled = false
	for simple: bool in [false,true]:
		var stock: Dictionary = VehicleCustomisation.defaults()
		await exercise("electric",simple,false,stock,"Volt final fixed stock")
		await exercise("electric",simple,true,stock,"Volt final editable stock")
		var control: CarVisual = await make_car("electric",simple,true,stock,false)
		var hits: int = Base.hits
		var prepared: CarVisual = await make_car("electric",simple,true,stock,true)
		check(Base.hits > hits,"Final body review starts from an actual prepared base")
		for option: Array in VehicleCustomisation.options("body","electric").slice(1):
			exercise_single_replacement(control,prepared,"electric",simple,"body",str(option[0]))
			print("VKR_BODY_MODULE ",simple," ",option[0])
			await process_frame
		control.free()
		prepared.free()
		await process_frame
		await exercise_replacement("electric",simple)
	print("VKR_FINAL_MODULES ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
