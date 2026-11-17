extends SceneTree
func _initialize() -> void:
	var catalog: Dictionary=load("res://../build/car-mechanics-2026-11-17/survey.res").get_meta("catalog")
	var plan: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../docs/evidence/car-mechanics-2026-11-17/selected-plan.json"))
	var checks: int=0
	for key: String in plan.parts:
		if plan.parts[key].has("required_bindings"):continue
		var source: Mesh=catalog[key].source
		var mesh: Mesh=load("res://../build/car-mechanics-2026-11-17/candidates/"+plan.parts[key].file)
		print("PIN_BOUNDS ",source.get_aabb()," candidate=",mesh.get_aabb())
		for p: Vector3 in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			assert(source.get_aabb().grow(0.000001).has_point(p),"New pin remains inside the preserved culling bounds");checks+=1
	var before: ArrayMesh=load("res://../build/car-mechanics-2026-11-17/before/game/assets/vehicles/kart_refined_v1/tomkart_driver_v1/driver_steering.res")
	var after: ArrayMesh=load("res://assets/vehicles/kart_refined_v1/tomkart_driver_v1/driver_steering.res")
	assert(before.get_aabb()==after.get_aabb() and before.blend_shape_mode==after.blend_shape_mode);checks+=1
	var helper=load("res://tests/bake_car_mechanics_candidates.gd").new()
	for pose: int in range(after.get_blend_shape_count()):
		assert(before.get_blend_shape_name(pose)==after.get_blend_shape_name(pose));checks+=1
	for sf: int in range(before.get_surface_count()):
		assert(before.surface_get_material(sf).resource_name==after.surface_get_material(sf).resource_name);checks+=1
		for pose: int in range(-1,after.get_blend_shape_count()):
			assert(helper.corner(before,sf,pose)==helper.corner(after,sf,pose),"Published driver retains exact used encoded corners and every morph");checks+=1
	helper.free()
	print("MECHANICS_NATIVE_PROOF ",checks," checks 0 failures");quit()
