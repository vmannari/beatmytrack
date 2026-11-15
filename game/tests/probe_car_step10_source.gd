extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	preload("res://vehicle/modular_car_base.gd").enabled=false
	preload("res://vehicle/modular_car_kits.gd").enabled=false
	preload("res://vehicle/prepared_car_cache.gd").enabled=false
	var car:=CarVisual.new();car.vehicle_id="compact";car.simple_model=true;car.cache_rest_pose=false
	print("PROBE_ADD");root.add_child(car);print("PROBE_ADDED ",car.model_ready)
	for n: int in range(100):
		await process_frame
		if n%20==0: print("PROBE ",n," ",car.model_ready," ",car.get("_model_stage"))
	print("PROBE_END");car.free();quit()
