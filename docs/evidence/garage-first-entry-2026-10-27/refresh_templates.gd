extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var cache=preload("res://ui/garage_car_cache.gd")
	cache.enabled=false
	# The current Electric template is already valid. Rebuild only the six stale
	# templates from their unchanged native authors, retaining the strict guard.
	for id: String in ["compact","pickup","classic","formula","kart","forklift"]:
		var car:=CarVisual.new()
		car.vehicle_id=id;car.livery=VehicleLivery.defaults(id)
		car.editable_kits=id=="compact"
		root.add_child(car)
		while not car.model_ready: await process_frame
		var error: Error=cache.bake(car)
		print("REFRESH_TEMPLATE ",id," ",error)
		car.free()
		if error!=OK: quit(1);return
	quit()
