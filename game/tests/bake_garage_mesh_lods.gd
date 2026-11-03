extends SceneTree
## Refresh only LOD indices; ordinary car/workshop bake tools also prepare them.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var lods = preload("res://tests/support/garage_mesh_lods.gd").new()
	var paths: Array[String] = [GarageEnvironment.PREPARED_ARCHITECTURE]
	for id: String in VehicleCatalog.IDS: paths.append("res://assets/garage/cars_v1/"+id+".scn")
	for path: String in paths:
		assert(lods.bake(path) == OK)
		print("GARAGE_LOD_BAKE ",path," ",JSON.stringify(lods.totals))
	var output: String = ProjectSettings.globalize_path("res://../docs/evidence/garage-performance-2026-11-01/lod-bake.json")
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(lods.totals,"\t"))
	quit()
