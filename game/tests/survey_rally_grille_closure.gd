extends SceneTree
const D=preload("res://vehicle/car_detail_reduction.gd")
const S=preload("res://vehicle/car_surface_reduction.gd")
func _initialize() -> void:run.call_deferred()
func inspect(group: Dictionary,stage: String) -> void:
	for entry: Dictionary in group.entries:
		if "FrontCoachwork" not in str(entry.part.name):continue
		print("RGC_SURVEY ",stage," ",group.code," ",entry.part.name," ",entry.source," ",entry.part.mesh.resource_path," tri=",entry.part.mesh.get_faces().size()/3)
		var path: String=(D.ROOT if stage=="detail" else S.ROOT).path_join("compact_"+group.code+".json")
		if FileAccess.file_exists(path):print("RGC_ROW ",stage," ",JSON.parse_string(FileAccess.get_file_as_string(path)).parts.get(entry.code,{}))
	if stage=="detail":D.apply_group(group)
	else:S.apply_group(group,D)
func run() -> void:
	preload("res://vehicle/modular_car_base.gd").enabled=false;preload("res://vehicle/modular_car_kits.gd").enabled=false;preload("res://vehicle/prepared_car_cache.gd").enabled=false
	D.offline=func(group: Dictionary) -> void:inspect(group,"detail")
	S.offline=func(group: Dictionary) -> void:inspect(group,"surface")
	var car:=CarVisual.new();car.vehicle_id="compact";car.cache_rest_pose=false;root.add_child(car)
	while not car.model_ready:await process_frame
	car.free();quit()
