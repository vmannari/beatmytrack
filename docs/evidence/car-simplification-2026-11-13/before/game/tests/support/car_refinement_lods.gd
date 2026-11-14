extends "res://vehicle/car_mesh_lods.gd"
## Preserve inherited LOD policy; isolate embedded identities when publishing.
func bake(path: String, vehicle: String = "", bias: float = 1.0) -> Error:
	if vehicle.is_empty() and path.get_file().get_basename() in VehicleCatalog.IDS: vehicle = path.get_file().get_basename()
	var scene: PackedScene = ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if scene==null: return ERR_CANT_OPEN
	var holder: Node = scene.instantiate()
	prepare_vehicle(holder,vehicle,bias)
	if vehicle in ["compact","forklift"]: preload("res://tests/support/car_model_buffers.gd").detach(holder)
	var packed := PackedScene.new()
	var error: Error = packed.pack(holder)
	if error==OK: error = ResourceSaver.save(packed,path,ResourceSaver.FLAG_COMPRESS)
	holder.free()
	return error
