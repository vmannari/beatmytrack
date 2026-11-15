extends RefCounted
## Decode the same prepared geometry that CarVisual will actually restore.
const Base = preload("res://vehicle/modular_car_base.gd")
const Kits = preload("res://vehicle/modular_car_kits.gd")
const Rest = preload("res://ui/garage_car_cache.gd")

static func paths(id: String, simple: bool, parts: Dictionary) -> Array[String]:
	var model: String = VehicleCatalog.model_id(id)
	var quality: String = "simple" if simple else "full"
	var fitted: bool = VehicleCustomisation.valid(parts,id) and parts != VehicleCustomisation.defaults()
	var result: Array[String] = []
	if not simple and not fitted:
		result.append(Rest.DIRECTORY+model+".scn")
	else:
		var editable: String = "editable" if VehicleCustomisation.supported(id) else "fixed"
		result.append(Base.DIRECTORY.path_join("%s_%s_%s.scn" % [model,quality,editable]))
		if fitted:
			for category: String in VehicleCustomisation.CATEGORIES:
				if parts[category] != "stock":
					result.append(Kits.DIRECTORY.path_join(model).path_join(quality).path_join(category).path_join(parts[category]+".scn"))
	result.append(GarageEnvironment.PREPARED_ARCHITECTURE)
	return result
