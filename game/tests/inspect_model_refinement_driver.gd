extends SceneTree
func _initialize() -> void:
	var current: ArrayMesh = load("res://assets/vehicles/kart_refined_v1/tomkart_driver_v1/driver.res")
	var original: ArrayMesh = load("res://../docs/evidence/car-model-refinement-2026-11-12/before/game/assets/vehicles/kart_refined_v1/tomkart_driver_v1/driver.res")
	var rows: Array = []
	for surface: int in range(current.get_surface_count()):
		var original_slot: int = -1
		for index: int in range(original.get_surface_count()):
			if current.surface_get_material(surface).resource_name==original.surface_get_material(index).resource_name: original_slot = index
		rows.append({"material":current.surface_get_material(surface).resource_name,"vertices":current.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX].size(),"positions_exact":original_slot>=0 and current.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]==original.surface_get_arrays(original_slot)[Mesh.ARRAY_VERTEX]})
	print("CURRENT_DRIVER ",current.get_surface_count()," surfaces, ",current.get_blend_shape_count()," poses ",JSON.stringify(rows))
	quit()
