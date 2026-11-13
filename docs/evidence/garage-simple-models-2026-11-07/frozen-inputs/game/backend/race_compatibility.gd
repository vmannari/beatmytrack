extends RefCounted
## Explicit per-car equivalence; every other race-contract field stays exact.
## .75 and .76 change only Electric handling. Six unchanged cars retain .74 math.
const ELECTRIC_ONLY_PHYSICS: Array[String] = ["arcade-planar-0.74","arcade-planar-0.75","arcade-planar-0.76"]
const UNCHANGED_VEHICLES: Array[String] = ["compact","pickup","classic","formula","kart","forklift"]

static func physics_matches(version: String, vehicle_id: String) -> bool:
	if vehicle_id not in VehicleCatalog.IDS: return false
	if version == VehicleSimulation.PHYSICS_VERSION: return true
	return vehicle_id in UNCHANGED_VEHICLES and version in ELECTRIC_ONLY_PHYSICS and VehicleSimulation.PHYSICS_VERSION in ELECTRIC_ONLY_PHYSICS
