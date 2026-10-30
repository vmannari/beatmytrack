extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var cache=preload("res://ui/garage_car_cache.gd")
	cache.enabled=false
	for id: String in VehicleCatalog.IDS:
		var car:=CarVisual.new()
		car.vehicle_id=id
		car.editable_kits=id=="compact"
		root.add_child(car)
		var error: Error=cache.bake(car)
		print("GARAGE_CAR_BAKE ",id," ",error)
		car.free()
		if error!=OK: quit(1);return
	quit()
