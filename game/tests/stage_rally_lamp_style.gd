extends SceneTree
## Preserve every other member of the two original complete-body recipes.
const Detail=preload("res://vehicle/car_detail_reduction.gd")
const OUT: String="res://../docs/evidence/rally-lamp-style-2026-11-15"
var registry: Dictionary={}
var staged: Dictionary={}
func _initialize() -> void: run.call_deferred()
func scope(part: Node) -> bool:
	return str(part.name).begins_with("FrontLamp")
func inspect(group: Dictionary) -> void:
	var others: Array=[];var has_front: bool=false
	for entry: Dictionary in group.entries:
		if scope(entry.part):has_front=true
		else:others.append(entry.code)
	if not has_front:Detail.apply_group(group);return
	others.sort()
	var key: String=var_to_bytes(others).hex_encode().sha256_text()
	assert(registry.has(key),"Only grille/lamp members may change the original frame")
	var prior: Dictionary=registry[key]
	var parts: Dictionary={}
	for code: String in prior.recipe.get("parts",{}):
		if not prior.parts[code].front:parts[code]=prior.recipe.parts[code]
	var result: Dictionary={"schema":Detail.SCHEMA,"context":group.code,"parts":parts}
	var path: String="res://assets/vehicles/car_detail_v1/compact_"+group.code+".json"
	if not staged.has(path):
		assert(not FileAccess.file_exists(path),"Preserve an existing authored recipe")
		FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
		staged[path]={"old_context":prior.context,"retained_members":others.size(),"retained_rows":parts.size(),"key":key}
	Detail.recipes["compact_"+group.code]=result
	Detail.apply_group(group)
func run() -> void:
	registry=JSON.parse_string(FileAccess.get_file_as_string(OUT.path_join("frame-registry.json")))
	preload("res://vehicle/modular_car_base.gd").enabled=false
	preload("res://vehicle/modular_car_kits.gd").enabled=false
	preload("res://vehicle/prepared_car_cache.gd").enabled=false
	Detail.offline=inspect
	for editable: bool in [false,true]:
		var car:=CarVisual.new();car.vehicle_id="compact";car.simple_model=true;car.editable_kits=editable;car.cache_rest_pose=false
		root.add_child(car)
		while not car.model_ready:await process_frame
		if editable:
			for category: String in VehicleCustomisation.CATEGORIES:
				for option: Array in VehicleCustomisation.options(category,"compact").slice(1):
					var choice: Dictionary=car.customisation.duplicate();choice[category]=option[0];car.change_kit_parts(choice)
					choice=car.customisation.duplicate();choice[category]="stock";car.change_kit_parts(choice)
		car.free();await process_frame
	FileAccess.open(OUT.path_join("recipe-migration.json"),FileAccess.WRITE).store_string(JSON.stringify(staged,"  "))
	print("RALLY_FRONT_RECIPES ",staged.size()," exact retained-member migrations");quit()
