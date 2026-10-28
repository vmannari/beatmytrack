extends "res://backend/generate_fixture.gd"
## Offline five-lap recording for independent verification of the kart-5 tune.
func initial_simulation(track: NativeTrack, _vehicle: String) -> VehicleSimulation:
	return super.initial_simulation(track,"kart")

func respond(result: Dictionary, error: String = "") -> void:
	if result.has("replay"): result.vehicle_id = "kart"
	super.respond(result,error)
