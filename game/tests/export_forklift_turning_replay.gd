extends "res://backend/generate_fixture.gd"
## Offline five-lap recording for independent verification of forklift-4.
func initial_simulation(track: NativeTrack, _vehicle: String) -> VehicleSimulation:
	return super.initial_simulation(track,"forklift")

func respond(result: Dictionary, error: String = "") -> void:
	if result.has("replay"): result.vehicle_id = "forklift"
	super.respond(result,error)
