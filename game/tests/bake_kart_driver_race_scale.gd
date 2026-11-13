extends SceneTree
const OUT = "res://../docs/evidence/kart-driver-race-scale-2026-11-12"
func _initialize() -> void:
	var base: String = OUT+"/before/game/assets/vehicles/kart_refined_v1/tomkart_driver_v1/"
	var moving: ArrayMesh = load(base+"driver.res")
	var helmet: ArrayMesh = load(base+"helmet_static.res")
	var combined := ArrayMesh.new()
	combined.blend_shape_mode = moving.blend_shape_mode
	for shape: int in range(6): combined.add_blend_shape(moving.get_blend_shape_name(shape))
	var packets: Array = moving.get("_surfaces").duplicate(true)
	for surface: int in range(4):
		var arrays: Array = helmet.surface_get_arrays(surface)
		var shapes: Array[Array] = []
		for pose: int in range(6):
			var shape: Array = []
			shape.resize(Mesh.ARRAY_MAX)
			for attribute: int in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TANGENT]: shape[attribute] = arrays[attribute]
			shapes.append(shape)
		var temporary := ArrayMesh.new()
		for pose: int in range(6): temporary.add_blend_shape(moving.get_blend_shape_name(pose))
		temporary.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,shapes)
		var packet: Dictionary = temporary.get("_surfaces")[0]
		packet.material = helmet.surface_get_material(surface)
		packets.append(packet)
	combined.set("_surfaces",packets)
	for key: StringName in moving.get_meta_list(): combined.set_meta(key,moving.get_meta(key))
	var resized: ArrayMesh = preload("res://tests/support/kart_driver_anatomy.gd").resize(combined)
	preload("res://tests/support/kart_driver_finish.gd").save(resized)
	print("RACE_DRIVER_SCALE: ",resized.get_faces().size()/3," triangles; ",resized.get_aabb())
	quit()
