extends "res://backend/generate_fixture.gd"
## Reuse the canonical offline oval generator with the electric-3 car.
func initial_simulation(track: NativeTrack, _vehicle: String) -> VehicleSimulation:
	return super.initial_simulation(track,"electric")

func respond(result: Dictionary, error: String = "") -> void:
	if result.has("replay"): result.vehicle_id = "electric"
	super.respond(result,error)
