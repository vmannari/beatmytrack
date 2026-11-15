extends SceneTree
const D=preload("res://vehicle/car_detail_reduction.gd")
var registry: Dictionary={}
func _initialize() -> void: run.call_deferred()
func scope(part: Node) -> bool:return str(part.name).begins_with("ReferenceDoorSeam") or str(part.name).begins_with("RefHandle")
func inspect(group: Dictionary) -> void:
	var others: Array=[];var changed: bool=false;var parts: Dictionary={}
	for entry: Dictionary in group.entries:
		parts[entry.code]={"name":str(entry.part.name),"contour":scope(entry.part)}
		if scope(entry.part):changed=true
		else:others.append(entry.code)
	if changed:
		others.sort();var key: String=var_to_bytes(others).hex_encode().sha256_text()
		var row: Dictionary={"context":group.code,"others":others,"parts":parts,"recipe":D.recipe("electric",group.code)}
		if registry.has(key):assert(registry[key].recipe==row.recipe)
		registry[key]=row
	D.apply_group(group)
func run() -> void:
	preload("res://vehicle/modular_car_base.gd").enabled=false;preload("res://vehicle/modular_car_kits.gd").enabled=false;preload("res://vehicle/prepared_car_cache.gd").enabled=false
	D.offline=inspect
	for editable: bool in [false,true]:
		var car:=CarVisual.new();car.vehicle_id="electric";car.editable_kits=editable;car.cache_rest_pose=false
		root.add_child(car)
		while not car.model_ready:await process_frame
		car.free();await process_frame
	FileAccess.open("res://../docs/evidence/car-step10-2026-11-15/volt-clearance-registry.json",FileAccess.WRITE).store_string(JSON.stringify(registry,"  "))
	print("VOLT_FRAME_REGISTRY ",registry.size());quit()
