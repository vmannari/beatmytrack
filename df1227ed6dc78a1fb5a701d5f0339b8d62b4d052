extends "res://../build/asset-optimisation-2026-11-08/native.gd"
func car(id: String,fitted: bool,prepared: bool)->CarVisual:
	VisualGeometry.batch_transformed_car_parts=true
	var base=preload("res://vehicle/modular_car_base.gd");var kits=preload("res://vehicle/modular_car_kits.gd");var rest=preload("res://vehicle/prepared_car_cache.gd")
	base.enabled=prepared;kits.enabled=prepared;rest.enabled=prepared;rest.entries.clear()
	var hits: int=base.hits;var kit_hits: int=kits.hits
	var result:=CarVisual.new();result.vehicle_id=id;result.simple_model=true;result.cache_rest_pose=false;result.customisation=VehicleCustomisation.defaults()
	if fitted:
		for category: String in VehicleCustomisation.CATEGORIES:result.customisation[category]=VehicleCustomisation.options(category,id)[-1][0]
	stage.add_child(result)
	while not result.model_ready:await process_frame
	if prepared:
		check(base.hits==hits+1,"actual prepared base restored "+id)
		if fitted:check(kits.hits>=kit_hits+4,"every fitted module restored "+id)
	for node: Node in result.front_wheels+result.rear_wheels+result.rolling_wheels+result.brake_lights:check(is_instance_valid(node) and node.is_inside_tree(),"prepared live handle retained "+id)
	return result
