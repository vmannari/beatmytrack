extends "res://tests/check_prepared_assets.gd"
## RBC04: full existing metadata/dependency checks scoped to the rebuilt Rally.
func run() -> void:
	var sources: Dictionary = Base.source_hashes("compact")
	for simple: bool in [false,true]:
		for editable: bool in [false,true]:
			var car := CarVisual.new()
			car.simple_model = simple
			car.editable_kits = editable
			inspect(Base.path_for(car),"modular_car_base",Base.key_for(car),sources)
			if editable:
				for category: String in VehicleCustomisation.CATEGORIES:
					for option: Array in VehicleCustomisation.options(category,"compact").slice(1):
						inspect(Kits.path_for(car,category,option[0]),"modular_kit",Kits.key_for(car,category,option[0]),Kits.geometry_sources("compact"))
			car.free()
	var car := CarVisual.new()
	car.editable_kits = true
	inspect(Garage.DIRECTORY+"compact.scn","garage_rest",Garage.geometry_key(car),Garage.geometry_sources("compact"))
	car.free()
	car = CarVisual.new()
	car.simple_model = true
	inspect(Header.DIRECTORY+"compact.scn","garage_rest",Header.geometry_key(car),Header.geometry_sources())
	car.free()
	print("RALLY_PREPARED_ASSETS: ",resources," resources; ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
