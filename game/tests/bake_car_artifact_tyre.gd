extends SceneTree
## CMA03: bake the regular 24-section racing slick; full tyres remain 64 sections.
func _initialize() -> void: call_deferred("run")
func collect(car: CarVisual,parts: Array) -> void:
	for part: MeshInstance3D in parts:
		if part.mesh!=null and preload("res://vehicle/car_budget_reduction.gd").is_protected(part): print(part.name," triangles=",part.mesh.get_faces().size()/3)
func run() -> void:
	for path: String in ["modular_car_base","modular_car_kits","prepared_car_cache"]: load("res://vehicle/"+path+".gd").enabled=false
	preload("res://ui/garage_car_cache.gd").enabled=false
	preload("res://vehicle/car_budget_reduction.gd").offline=collect
	var car:=CarVisual.new();car.vehicle_id="kart";car.cache_rest_pose=false;root.add_child(car)
	while not car.model_ready: await process_frame
	var geometry=preload("res://vehicle/kart_geometry.gd")
	var written: int=0
	for key: String in geometry.meshes:
		if key.ends_with("|round24-v1"):
			var path: String=geometry.ROOT.path_join(key.sha256_text().left(24)+".res")
			assert(geometry.meshes[key].get_faces().size()/3==432)
			written+=1
			assert(ResourceSaver.save(geometry.meshes[key],path,ResourceSaver.FLAG_COMPRESS)==OK)
			print("ROUND_TYRE_SAVED ",path," triangles=",geometry.meshes[key].get_faces().size()/3)
	assert(written==1)
	car.free();quit()
