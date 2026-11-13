extends SceneTree
const OUT = "res://../docs/evidence/car-model-review-2026-11-12"
func _initialize() -> void:
	var driver: ArrayMesh = load("res://assets/vehicles/kart_refined_v1/tomkart_driver_v1/driver.res")
	var result: Array = []
	for surface: int in range(driver.get_surface_count()):
		var arrays: Array = driver.surface_get_arrays(surface)
		var rest: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var shapes: Array[Array] = driver.surface_get_blend_shape_arrays(surface)
		var moving: int = 0
		var static_attributes: bool = true
		for shape: Array in shapes:
			for attribute: int in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TANGENT]:
				if shape[attribute] != arrays[attribute]: static_attributes = false
		for vertex: int in range(rest.size()):
			var changed: bool = false
			for shape: Array in shapes:
				if shape[Mesh.ARRAY_VERTEX][vertex] != rest[vertex]: changed = true
			if changed: moving += 1
		var packet: Dictionary = driver.get("_surfaces")[surface]
		result.append({"surface":surface,"name":driver.surface_get_name(surface),"material":driver.surface_get_material(surface).resource_name,"vertices":rest.size(),"moving_position_vertices":moving,"static_vertex_normal_tangent_arrays":static_attributes,"blend_bytes":packet.get("blend_shapes",PackedByteArray()).size()})
	var file := FileAccess.open(OUT.path_join("driver-components.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	print("CMR_DRIVER_COMPONENTS ",JSON.stringify(result))
	quit()
