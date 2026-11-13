extends SceneTree
func _initialize() -> void:
	for path: String in ["res://assets/vehicles/kart_refined_v1/tomkart_driver_v1/driver.res","res://assets/vehicles/kart_refined_v1/tomkart_driver_v1/helmet_static.res"]:
		var mesh: ArrayMesh = load(path)
		print("LAYOUT ",path," ",mesh.get_faces().size()/3," triangles ",mesh.get_surface_count()," surfaces ",mesh.get_blend_shape_count()," poses ",mesh.get_meta_list())
		for surface: int in range(mesh.get_surface_count()):
			var material: Material = mesh.surface_get_material(surface)
			print("SURFACE ",surface," ",material.resource_name)
			if material.resource_name != "RT_DriverSuit": continue
			var points: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			var offset: int = points.size()-2*21*17
			var center := Vector3.ZERO
			for vertex: int in range(16): center += points[offset+vertex]
			center /= 16
			print("ROOT ",center," radius ",center.distance_to(points[offset])," prefix ",offset)
			var arrays: Array = mesh.surface_get_arrays(surface)
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var signs: Dictionary = {"body_out":0,"body_in":0,"arm_out":0,"arm_in":0}
			for corner: int in range(0,indices.size(),3):
				var a: int = indices[corner]
				var b: int = indices[corner+1]
				var c: int = indices[corner+2]
				var dot: float = (points[b]-points[a]).cross(points[c]-points[a]).dot(normals[a]+normals[b]+normals[c])
				var key: String = ("body_" if a<offset and b<offset and c<offset else "arm_")+("out" if dot<0 else "in")
				signs[key] += 1
			print("WINDING ",signs)
	quit()
