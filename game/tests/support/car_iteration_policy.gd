extends RefCounted
## CI01: offline source identities for the first reviewed Forklift iteration.
const IDS: Array[String]=["forklift"]
static func code(mesh: Mesh, id: String) -> String:
	return id+"_"+preload("res://vehicle/car_detail_reduction.gd").mesh_key(mesh)
