extends SceneTree
## Explicit offline bake. Regenerate after model, kit or helper source changes.
const Kits = preload("res://vehicle/modular_car_kits.gd")
const Cache = preload("res://vehicle/prepared_car_cache.gd")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var vehicle_filter: String = ""
	var quality_filter: String = ""
	var category_filter: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--vehicle="): vehicle_filter = argument.trim_prefix("--vehicle=")
		if argument.begins_with("--quality="): quality_filter = argument.trim_prefix("--quality=")
		if argument.begins_with("--category="): category_filter = argument.trim_prefix("--category=")
	if (not vehicle_filter.is_empty() and vehicle_filter not in VehicleCustomisation.KIT_CARS) or (not quality_filter.is_empty() and quality_filter not in ["full","simple"]) or (not category_filter.is_empty() and category_filter not in VehicleCustomisation.CATEGORIES):
		push_error("Invalid modular kit bake filter")
		quit(1)
		return
	Kits.enabled = false
	preload("res://ui/garage_car_cache.gd").enabled = false
	# Avoid the production base when rebaking from the actual source builders.
	if ResourceLoader.exists("res://vehicle/modular_car_base.gd"):
		var base: Script = load("res://vehicle/modular_car_base.gd")
		base.set("enabled",false)
	var count: int = 0
	for id: String in VehicleCustomisation.KIT_CARS:
		if not vehicle_filter.is_empty() and id != vehicle_filter: continue
		for simple: bool in [false,true]:
			if not quality_filter.is_empty() and quality_filter != ("simple" if simple else "full"): continue
			Cache.entries.clear()
			var car := CarVisual.new()
			car.vehicle_id = id
			car.simple_model = simple
			car.editable_kits = true
			car.livery = VehicleLivery.defaults(id)
			root.add_child(car)
			while not car.model_ready: await process_frame
			# Stable attachment paths match the offline base snapshot.
			Cache._stable_names(car)
			for category: String in VehicleCustomisation.CATEGORIES:
				if not category_filter.is_empty() and category != category_filter: continue
				for item: Array in VehicleCustomisation.options(category,id):
					var option: String = item[0]
					if option == "stock": continue
					var parts: Dictionary = car.customisation.duplicate(true)
					parts[category] = option
					car.change_kit_parts(parts)
					var error: Error = Kits.bake(car,category,option)
					if error != OK:
						push_error("Kit bake failed: %s/%s/%s/%s: %s" % [id,"simple" if simple else "full",category,option,error])
						car.free()
						quit(1)
						return
					count += 1
					print("MODULAR_KIT_BAKE ",id," ","simple" if simple else "full"," ",category," ",option)
					await process_frame
				var stock: Dictionary = car.customisation.duplicate(true)
				stock[category] = "stock"
				car.change_kit_parts(stock)
				await process_frame
			car.free()
			await process_frame
	print("MODULAR_KIT_BAKE_COUNT ",count)
	quit()
