extends SceneTree
func _initialize() -> void:
	var base = preload("res://vehicle/modular_car_base.gd")
	var sources = preload("res://vehicle/prepared_asset_sources.gd")
	for reduced: bool in [false,true]:
		for editable: bool in [false,true]:
			var car := CarVisual.new()
			car.vehicle_id = "super_rally"; car.simple_model = reduced; car.editable_kits = editable
			var holder: Node3D = (load(base.path_for(car)) as PackedScene).instantiate()
			var data: Dictionary = holder.get_meta("modular_car_base")
			var actual: Dictionary = sources.runtime_projection(data.sources)
			var expected: Dictionary = sources.runtime_hashes(car.model_id)
			var changed: Array = []
			for path: String in expected:
				if actual.get(path) != expected[path]: changed.append(path)
			print("CACHE_DIAG ",reduced," ",editable," key=",data.key==base.key_for(car)," holder=",base._valid_holder(holder,data)," source=",actual==expected," diff=",changed," eligible=",base._eligible(car))
			holder.free(); car.free()
	quit()
