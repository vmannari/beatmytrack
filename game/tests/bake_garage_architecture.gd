extends SceneTree
## Offline native geometry preparation; no changes to the authored workshop.
const SOURCES: Array[String]=[
	"ui/garage_environment.gd","ui/garage_details.gd","ui/garage_drain.gd",
	"ui/garage_record_station.gd","ui/garage_furnishings.gd","ui/garage_materials.gd",
	"ui/garage_workshop.gd","ui/garage_plant.gd",
	"ui/garage_plant_leaf.gdshader","ui/garage_plant_ceramic.gdshader",
	"ui/garage_timber.gdshader","ui/garage_audio_wood.gdshader","ui/garage_vinyl.gdshader",
	"ui/garage_audio_lid.gdshader","ui/garage_display_backing.gdshader",
	"ui/garage_display_stone.gdshader","ui/garage_surface_finish.gdshader",
	"soundtrack/record_library.gd",
	"tests/support/garage_mesh_lods.gd",
	"tests/support/car_refinement_lods.gd","vehicle/car_mesh_lods.gd",
]
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var car := CarVisual.new()
	world.add_child(car)
	GarageEnvironment.architecture_scene=null
	GarageEnvironment.build(world,car,false,false)
	var path: String="res://assets/garage/workshop_v1.scn"
	var error: Error=ResourceSaver.save(GarageEnvironment.architecture_scene,path,ResourceSaver.FLAG_COMPRESS)
	if error == OK: error = preload("res://tests/support/garage_mesh_lods.gd").new().bake(path)
	if error==OK:
		var hashes: Dictionary={}
		for source: String in SOURCES: hashes[source]=FileAccess.get_sha256("res://"+source)
		var provenance: Dictionary={"origin":"Original authored GarageEnvironment architecture; no generated art or external models.",
			"generator":"res://tests/bake_garage_architecture.gd","engine":Engine.get_version_info().string,
			"sources":hashes,"scene_sha256":FileAccess.get_sha256(path),
			"validation":"test_menu_responsiveness.gd compares every node transform, mesh array and finish with a fresh procedural build."}
		var file:=FileAccess.open("res://assets/garage/workshop_v1.provenance.json",FileAccess.WRITE)
		if file==null: error=FileAccess.get_open_error()
		else: file.store_string(JSON.stringify(provenance,"  ")+"\n")
	print("GARAGE_ARCHITECTURE_BAKE ",error)
	world.free()
	quit(0 if error==OK else 1)
