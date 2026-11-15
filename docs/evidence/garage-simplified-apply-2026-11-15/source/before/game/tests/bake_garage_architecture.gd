extends SceneTree
## Offline native geometry preparation; no changes to the authored workshop.
const Transaction = preload("res://tests/support/asset_bake_transaction.gd")
var bake_errors := preload("res://tests/support/asset_bake_errors.gd").new()
const SOURCES: Array[String]=[
	"tests/bake_garage_architecture.gd","tests/support/asset_bake_transaction.gd",
	"tests/support/asset_bake_errors.gd",
	"tests/support/garage_architecture_car.gd",
	"ui/garage_environment.gd","ui/garage_details.gd","ui/garage_drain.gd",
	"ui/garage_record_station.gd","ui/garage_furnishings.gd","ui/garage_materials.gd",
	"ui/garage_workshop.gd","ui/garage_plant.gd",
	"ui/garage_mesh_cleanup.gd","rendering/mesh_vertex_packing.gd",
	"ui/garage_plant_leaf.gdshader","ui/garage_plant_ceramic.gdshader",
	"ui/garage_pegboard.gdshader",
	"ui/garage_timber.gdshader","ui/garage_audio_wood.gdshader","ui/garage_vinyl.gdshader",
	"ui/garage_audio_lid.gdshader","ui/garage_display_backing.gdshader",
	"ui/garage_display_stone.gdshader","ui/garage_surface_finish.gdshader",
	"soundtrack/record_library.gd",
	"tests/support/garage_mesh_lods.gd",
	"tests/support/car_refinement_lods.gd","vehicle/car_mesh_lods.gd",
]
func _sources() -> Dictionary:
	var hashes: Dictionary = {}
	for source: String in SOURCES: hashes[source] = FileAccess.get_sha256("res://"+source)
	return hashes

func _initialize() -> void: run.call_deferred()
func run() -> void:
	OS.add_logger(bake_errors)
	var transaction := Transaction.new()
	var folder: String = "res://assets/garage"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): folder = arg.trim_prefix("--output=")
	var error: Error = transaction.begin(folder, ["workshop_v1.scn", "workshop_v1.provenance.json"])
	if error != OK:
		push_error("Workshop bake is locked or cannot create candidates")
		quit(1); return
	var hashes: Dictionary = _sources()
	var world := Node3D.new()
	root.add_child(world)
	var car := preload("res://tests/support/garage_architecture_car.gd").new()
	world.add_child(car)
	GarageEnvironment.architecture_scene=null
	GarageEnvironment.build(world,car,false,false)
	var path: String=transaction.candidate("workshop_v1.scn")
	error=ResourceSaver.save(GarageEnvironment.architecture_scene,path,ResourceSaver.FLAG_COMPRESS)
	if error == OK: error = preload("res://tests/support/garage_mesh_lods.gd").new().bake(path)
	if error==OK:
		var provenance: Dictionary={"origin":"Original authored GarageEnvironment architecture; no generated art or external models.",
			"generator":"res://tests/bake_garage_architecture.gd","engine":Engine.get_version_info().string,
			"sources":hashes,"scene_sha256":FileAccess.get_sha256(path),
			"validation":"test_menu_responsiveness.gd compares every node transform, mesh array and finish with a fresh procedural build."}
		var file:=FileAccess.open(transaction.candidate("workshop_v1.provenance.json"),FileAccess.WRITE)
		if file==null: error=FileAccess.get_open_error()
		else:
			file.store_string(JSON.stringify(provenance,"  ")+"\n")
			file.flush()
			error = file.get_error()
			file.close()
	if error == OK and bake_errors.failed(): error = ERR_INVALID_DATA
	if error == OK and hashes != _sources(): error = ERR_BUSY
	if error == OK: error = transaction.publish(["workshop_v1.scn", "workshop_v1.provenance.json"])
	transaction.close()
	print("GARAGE_ARCHITECTURE_BAKE ",error)
	world.free()
	quit(0 if error==OK else 1)
