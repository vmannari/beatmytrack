extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var base = preload("res://vehicle/modular_car_base.gd")
	var sources: Dictionary = base.source_hashes("electric")
	for simple: bool in [false,true]:
		var car := CarVisual.new()
		car.vehicle_id = "electric"
		car.simple_model = simple
		var scene: PackedScene = load(base.path_for(car))
		var holder: Node3D = scene.instantiate()
		var data: Dictionary = holder.get_meta("modular_car_base")
		var different: Array = []
		for name_value: String in sources:
			if data.sources.get(name_value,"") != sources[name_value]: different.append(name_value)
		print("MODULAR_PROBE simple=",simple," key_equal=",data.key==base.key_for(car)," source_differences=",different," eligible=",base._eligible(car)," holder_valid=",base._valid_holder(holder,data))
		if data.key != base.key_for(car): print("STORED_KEY ",data.key," CURRENT_KEY ",base.key_for(car))
		holder.free()
		car.free()
	quit()
