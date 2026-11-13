extends "res://tests/check_prepared_assets.gd"
## Scope the existing preflight to the assemblies affected by RW01/RW02.
var reported_source_difference: bool = false

func inspect(path: String, metadata: String, key: Array, sources: Dictionary) -> void:
	super.inspect(path, metadata, key, sources)
	if reported_source_difference or not ResourceLoader.exists(path): return
	var holder: Node = (load(path) as PackedScene).instantiate()
	var previous: Dictionary = holder.get_meta(metadata, {}).get("sources", {})
	if previous != sources:
		reported_source_difference = true
		for source: String in sources:
			if previous.get(source, "") != sources[source]: print("RALLY_SOURCE_DIFFERENCE ", source, " stored=", previous.get(source, ""), " current=", sources[source])
	holder.free()

func run() -> void:
	var sources: Dictionary = Base.source_hashes("compact")
	for simple: bool in [false, true]:
		for editable: bool in [false, true]:
			var car := CarVisual.new()
			car.vehicle_id = "compact"
			car.simple_model = simple
			car.editable_kits = editable
			inspect(Base.path_for(car), "modular_car_base", Base.key_for(car), sources)
			if editable:
				for category: String in VehicleCustomisation.CATEGORIES:
					for option: Array in VehicleCustomisation.options(category, "compact").slice(1):
						inspect(Kits.path_for(car, category, option[0]), "modular_kit", Kits.key_for(car, category, option[0]), Kits.geometry_sources("compact"))
			car.free()
	var car := CarVisual.new()
	car.simple_model = false
	car.editable_kits = true
	inspect(Garage.DIRECTORY + "compact.scn", "garage_rest", Garage.geometry_key(car), Garage.geometry_sources("compact"))
	car.free()
	car = CarVisual.new()
	car.simple_model = true
	inspect(Header.DIRECTORY + "compact.scn", "garage_rest", Header.geometry_key(car), Header.geometry_sources())
	car.free()
	print("RALLY_PREPARED: ", resources, " resources; ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
