extends RefCounted
## Online races require the current physics contract and a playable vehicle.

static func physics_matches(version: String, vehicle_id: String) -> bool:
	if vehicle_id not in VehicleCatalog.IDS: return false
	return version == VehicleSimulation.PHYSICS_VERSION
