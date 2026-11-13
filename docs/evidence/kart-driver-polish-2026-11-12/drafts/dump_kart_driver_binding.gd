extends SceneTree
func _initialize() -> void:
	var old: ArrayMesh = load("res://../docs/evidence/kart-driver-polish-2026-11-12/before/game/assets/vehicles/kart_refined_v1/tomkart_driver_v1/driver.res")
	var result: Array = []
	var current: ArrayMesh = load("res://assets/vehicles/kart_refined_v1/tomkart_driver_v1/driver.res")
	var shape: Array = current.surface_get_blend_shape_arrays(1)[0]
	var posed: Array = []
	for point: Vector3 in shape[Mesh.ARRAY_VERTEX]: posed.append([point.x,point.y,point.z])
	for surface: int in range(old.get_surface_count()):
		if old.surface_get_material(surface).resource_name != "RT_DriverSuit": continue
		var arrays: Array = old.surface_get_arrays(surface)
		for point: Vector3 in arrays[Mesh.ARRAY_VERTEX]: result.append([point.x,point.y,point.z])
		FileAccess.open("res://../build/kart-driver-polish-2026-11-12/neutral-cloth.json",FileAccess.WRITE).store_string(JSON.stringify({"vertices":result,"posed":posed,"indices":Array(arrays[Mesh.ARRAY_INDEX])}))
	quit()
