extends "res://tests/test_super_rally_design.gd"
## Every retained cosmetic ID is rebuilt on the coupe, including stock reset.
func run() -> void:
	preload("res://vehicle/modular_car_base.gd").enabled = false
	preload("res://vehicle/modular_car_kits.gd").enabled = false
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	preload("res://ui/garage_car_cache.gd").enabled = false
	for reduced: bool in [false,true]:
		var car: CarVisual = await make_car("super_rally",reduced)
		var positions: Array[Vector3] = car.wheel_rest_positions.duplicate()
		var factory: AABB = bounds(car)
		for category: String in VehicleCustomisation.CATEGORIES:
			for option: Array in VehicleCustomisation.options(category,"super_rally").slice(1):
				var parts: Dictionary = VehicleCustomisation.defaults()
				parts[category] = option[0]
				car.change_kit_parts(parts)
				check(car.customisation == parts and not car.kit_frames.get(category,[]).is_empty(),"coupe accepts "+category+"/"+str(option[0]))
				var box: AABB = bounds(car)
				check(box.position.is_finite() and box.size.is_finite() and box.size.x < 2.5 and box.size.y < 1.55 and box.size.z < 5.5,"bounded classic exterior "+str(option[0]))
				check(car.wheel_rest_positions == positions and car.brake_lights.size() == 4,"classic identity and physical wheel contacts survive "+str(option[0]))
				car.change_kit_parts(VehicleCustomisation.defaults())
				check(bounds(car).is_equal_approx(factory),"reset restores the full coupe after "+str(option[0]))
				await process_frame
		car.set_night_headlights(true)
		check(car.headlights != null and car.night_lights_enabled,"classic pop-up headlight assembly opens at night")
		car.set_night_headlights(false)
		check(not car.headlights.visible,"classic pop-up headlight assembly closes in daylight")
		car.free()
	print("SUPER_RALLY_C3_KITS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
