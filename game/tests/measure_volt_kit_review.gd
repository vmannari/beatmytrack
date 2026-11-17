extends SceneTree
const Base = preload("res://vehicle/modular_car_base.gd")
const Kits = preload("res://vehicle/modular_car_kits.gd")
const OUT = "res://../docs/evidence/volt-kit-review-2026-11-17"

func _initialize() -> void: run.call_deferred()

func triangles(holder: Node) -> int:
	var total: int = 0
	for part: MeshInstance3D in holder.find_children("*","MeshInstance3D",true,false):
		if part.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			total += part.mesh.get_faces().size()/3
	return total

func run() -> void:
	var rows: Array = []
	for simple: bool in [false,true]:
		var car := CarVisual.new()
		car.vehicle_id = "electric"
		car.simple_model = simple
		car.editable_kits = true
		var base: Node3D = load(Base.path_for(car)).instantiate()
		var data: Dictionary = base.get_meta("modular_car_base")
		var stock: int = triangles(base)
		var fixed: int = stock
		var choices: Dictionary = {}
		var selected: Dictionary = VehicleCustomisation.defaults()
		for category: String in VehicleCustomisation.CATEGORIES:
			var original: int = 0
			for path: NodePath in data.kit_frames[category]: original += triangles(base.get_node(path))
			fixed -= original
			var options: Dictionary = {"stock":original}
			for option: Array in VehicleCustomisation.options(category,"electric").slice(1):
				var module: Node = load(Kits.path_for(car,category,str(option[0]))).instantiate()
				options[str(option[0])] = triangles(module)
				module.free()
			var maximum: int = original
			for option: String in options:
				if int(options[option]) > maximum:
					maximum = int(options[option])
					selected[category] = option
			choices[category] = {"triangles":options,"maximum":maximum}
		base.free()
		var expected: int = fixed
		for category: String in choices: expected += int(choices[category].maximum)
		car.customisation = selected
		car.cache_rest_pose = false
		root.add_child(car)
		while not car.model_ready: await process_frame
		var actual: int = triangles(car)
		assert(actual == expected,"Independent module maxima match actual combined assembly")
		assert(actual < 170000,"Every module combination retains the established 170k ceiling")
		rows.append({"simple":simple,"stock_triangles":stock,"maximum_combination_triangles":actual,"selection":selected,"categories":choices})
		car.free()
		await process_frame
	FileAccess.open(OUT.path_join("kit-counts.json"),FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	print("VKR_COUNTS ",rows.map(func(row: Dictionary)->Array:return [row.simple,row.stock_triangles,row.maximum_combination_triangles]))
	quit()
