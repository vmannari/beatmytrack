extends SceneTree
func _initialize() -> void:run.call_deferred()
func triangles(car: CarVisual) -> int:
	var count: int = 0
	for part: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		if part.mesh!=null and part.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:count+=part.mesh.get_faces().size()/3
	return count
func make_car(id: String) -> CarVisual:
	var car := CarVisual.new();car.vehicle_id=id;car.simple_model=true;car.editable_kits=true;car.batch_parts=false;car.livery=VehicleLivery.defaults(id);root.add_child(car)
	while not car.model_ready:await process_frame
	return car
func run() -> void:
	preload("res://vehicle/modular_car_base.gd").enabled=false
	preload("res://vehicle/modular_car_kits.gd").enabled=false
	preload("res://vehicle/prepared_car_cache.gd").enabled=false
	preload("res://ui/garage_car_cache.gd").enabled=false
	var rally: CarVisual = await make_car("compact");var rally_count: int=triangles(rally);rally.free()
	var baseline: String="res://../docs/evidence/challenger-reference-body-2026-11-13/before/"
	var manifest: Dictionary = (load(SuperRallyModel.ROOT+"manifest.json") as JSON).data
	for tier: String in ["simple","full"]:
		for item: Dictionary in manifest.tiers[tier]:
			var path: String = baseline+str(item.mesh)
			assert(FileAccess.file_exists(path),path)
			SuperRallyModel.assets[SuperRallyModel.ROOT+str(item.mesh)] = ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_IGNORE)
	var old: CarVisual = await make_car("super_rally");var old_count: int=triangles(old);old.free()
	var receipt: Dictionary={"current_rally_triangles":rally_count,"task_start_challenger_triangles":old_count,"legacy_relative_limit":rally_count+10000,"baseline_already_exceeds_relative_limit":old_count>rally_count+10000,"current_absolute_allocation":50000}
	var file:=FileAccess.open("res://../docs/evidence/challenger-reference-body-2026-11-13/legacy-budget-control.json",FileAccess.WRITE);file.store_string(JSON.stringify(receipt,"\t"));file.close()
	print("LEGACY_BUDGET_CONTROL: ",JSON.stringify(receipt))
	quit(0 if old_count>rally_count+10000 else 1)
