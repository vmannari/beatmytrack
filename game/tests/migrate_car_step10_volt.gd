extends SceneTree
const D=preload("res://vehicle/car_detail_reduction.gd")
const OUT: String="res://../docs/evidence/car-step10-2026-11-15"
var registry: Dictionary={};var saved: Dictionary={}
func _initialize() -> void: run.call_deferred()
func scope(part: Node) -> bool:return str(part.name).begins_with("ReferenceDoorSeam") or str(part.name).begins_with("RefHandle")
func inspect(group: Dictionary) -> void:
	var others: Array=[];var changed: bool=false
	for entry: Dictionary in group.entries:
		if scope(entry.part):changed=true
		else:others.append(entry.code)
	if not changed:D.apply_group(group);return
	others.sort();var key: String=var_to_bytes(others).hex_encode().sha256_text()
	assert(registry.has(key),"Non-contour members retain exact source/frame identities")
	var old: Dictionary=registry[key];var parts: Dictionary={}
	for code: String in old.recipe.get("parts",{}):
		if not old.parts[code].contour:parts[code]=old.recipe.parts[code]
	var result: Dictionary={"schema":D.SCHEMA,"context":group.code,"parts":parts}
	var path: String=D.ROOT.path_join("electric_"+group.code+".json")
	if not saved.has(path):
		assert(not FileAccess.file_exists(path))
		FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
		saved[path]={"old_context":old.context,"non_contour_rows":parts.size(),"key":key}
	D.recipes["electric_"+group.code]=result;D.apply_group(group)
func run() -> void:
	registry=JSON.parse_string(FileAccess.get_file_as_string(OUT.path_join("volt-frame-registry.json")))
	preload("res://vehicle/modular_car_base.gd").enabled=false;preload("res://vehicle/modular_car_kits.gd").enabled=false;preload("res://vehicle/prepared_car_cache.gd").enabled=false
	D.offline=inspect
	for editable: bool in [false,true]:
		var car:=CarVisual.new();car.vehicle_id="electric";car.editable_kits=editable;car.cache_rest_pose=false
		root.add_child(car)
		while not car.model_ready:await process_frame
		car.free();await process_frame
	FileAccess.open(OUT.path_join("volt-recipe-migration.json"),FileAccess.WRITE).store_string(JSON.stringify(saved,"  "))
	print("VOLT_RECIPE_MIGRATION ",saved.size()," exact non-contour frames");quit()
