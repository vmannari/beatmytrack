extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var rows: Array = []
	for id: String in VehicleCatalog.IDS:
		var car := CarVisual.new()
		car.vehicle_id = id
		root.add_child(car)
		while not car.model_ready: await process_frame
		var effect := VehicleWeathering.new()
		effect.configure(car,"pine",VehicleCatalog.config(id))
		var groups: Dictionary = {}
		for binding: Dictionary in effect.bindings:
			var material: ShaderMaterial = binding.finish
			var family: String = "toon" if material.shader.code.contains("diffuse_toon") else "burley"
			var role: String = "wheel" if binding.wheel else ("paint" if binding.graphics else ("rear" if material.get_shader_parameter("rear_only") == 1.0 else "front"))
			var key: String = family+"/"+role
			groups[key] = int(groups.get(key,0))+1
		rows.append({"car":id,"groups":groups,"materials":effect.materials.size()})
		print("WEATHERING_ROLES ",JSON.stringify(rows[-1]))
		effect.reset(); car.free()
		await process_frame
	FileAccess.open(OS.get_environment("BMT_GRAPHICS_OUTPUT").path_join("roles.json"),FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	quit()
