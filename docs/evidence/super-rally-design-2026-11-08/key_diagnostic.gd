extends SceneTree
func _initialize() -> void:
	var kits = preload("res://vehicle/modular_car_kits.gd")
	for item: Array in [[false,"body","volt_sweep"],[true,"hood","volt_centre"]]:
		var car := CarVisual.new(); car.vehicle_id = "electric"; car.simple_model = item[0]; car.editable_kits = true
		var holder: Node3D = (load(kits.path_for(car,item[1],item[2])) as PackedScene).instantiate()
		var key: Array = holder.get_meta("modular_kit").key
		var expected: Array = kits.key_for(car,item[1],item[2])
		print("KEY_EQUAL ",key==expected)
		for index: int in range(key.size()):
			if key[index] != expected[index]: print("ELEMENT_DIFF ",index," ",typeof(key[index]),"/",typeof(expected[index])," ","%.17f" % float(key[index]) if key[index] is float else str(key[index])," expected ","%.17f" % float(expected[index]) if expected[index] is float else str(expected[index]))
		print("KEY_DIFF ",item," stored=",JSON.stringify(key)," expected=",JSON.stringify(expected))
		holder.free(); car.free()
	quit()
