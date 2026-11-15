extends SceneTree
const D=preload("res://vehicle/car_detail_reduction.gd")
const S=preload("res://vehicle/car_surface_reduction.gd")
var registry: Dictionary={}
func _initialize() -> void: run.call_deferred()
func inspect(group: Dictionary) -> void:
	var others: Array=[];var has_side: bool=false
	for entry: Dictionary in group.entries:
		if str(entry.part.name).begins_with("ReferenceSide"):has_side=true
		else:others.append(entry.code)
	if has_side:
		others.sort();var key: String=var_to_bytes(others).hex_encode().sha256_text()
		var path: String=S.ROOT.path_join("electric_"+group.code+".json")
		assert(FileAccess.file_exists(path))
		registry[key]={"context":group.code,"recipe":JSON.parse_string(FileAccess.get_file_as_string(path)),"other_members":others}
	S.apply_group(group,D)
func run() -> void:
	preload("res://vehicle/modular_car_base.gd").enabled=false;preload("res://vehicle/modular_car_kits.gd").enabled=false;preload("res://vehicle/prepared_car_cache.gd").enabled=false
	S.offline=inspect
	for editable: bool in [false,true]:
		var car:=CarVisual.new();car.vehicle_id="electric";car.editable_kits=editable;car.cache_rest_pose=false
		root.add_child(car)
		while not car.model_ready:await process_frame
		car.free();await process_frame
	FileAccess.open("res://../docs/evidence/volt-rear-corners-2026-11-15/frame-registry.json",FileAccess.WRITE).store_string(JSON.stringify(registry,"  "))
	print("VOLT_CORNER_REGISTRY ",registry.size());quit()
