extends "res://tests/review_hovercraft_prepared.gd"
## Keep the original six-car prepared assertions with the current kit capability.
## The inherited adapter resolves only unset uniforms to their declared defaults.
func make(id: String,prepared: bool) -> CarVisual:
	var car := CarVisual.new()
	car.vehicle_id = id
	car.livery = VehicleLivery.defaults(id)
	car.editable_kits = VehicleCustomisation.supported(id)
	car.garage_template = prepared
	root.add_child(car)
	return car
