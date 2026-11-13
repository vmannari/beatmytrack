extends SceneTree
func _initialize()->void:run.call_deferred()
func run()->void:
	preload("res://vehicle/prepared_car_cache.gd").enabled=false
	preload("res://vehicle/modular_car_base.gd").enabled=false
	var failures: int=0;var checks: int=0
	for id: String in VehicleCatalog.IDS:
		for simple: bool in [false,true]:
			var car:=CarVisual.new();car.vehicle_id=id;car.simple_model=simple;root.add_child(car)
			while not car.model_ready:await process_frame
			await process_frame
			for node: Node3D in car.brake_lights+car.front_wheels+car.rear_wheels+car.rolling_wheels:
				checks+=1
				if not is_instance_valid(node) or not node.is_inside_tree():failures+=1;printerr("HANDLE_FAIL ",id," ",simple)
			car.free()
	print("LIVE_HANDLES ",checks," checks, ",failures," failures");quit(1 if failures else 0)
