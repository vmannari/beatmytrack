extends "res://ui/rivalry_simple_car.gd"
## Offline portraits retain native vehicle finishes and Garage studio lighting.

func _init() -> void:
	render_scale = 1.0
	cache_rest_pose = false

func _prepare_materials() -> void:
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.mesh_lod_threshold = 0.5
	var world := Node3D.new()
	viewport.add_child(world)
	var environment: WorldEnvironment = GarageEnvironment.build_lighting(world,true,true)
	environment.environment.ambient_light_energy = 0.60
	world.get_node("GarageKey").light_energy = 1.15
	world.get_node("GarageFill").light_energy = 0.50
	world.get_node("GarageRim").light_energy = 1.45
	var inverse: Transform3D = car.global_transform.affine_inverse()
	for part: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
		if part.mesh == null: continue
		if part.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			part.hide()
			continue
		if not part.is_visible_in_tree(): continue
		var local: Transform3D = inverse*part.global_transform
		for corner: int in range(8): _bounds.append(local*part.get_aabb().get_endpoint(corner))

func _refresh() -> void:
	if camera == null or not is_inside_tree() or _bounds.is_empty(): return
	var bounds := AABB(_bounds[0],Vector3.ZERO)
	for point: Vector3 in _bounds: bounds = bounds.expand(point)
	var target: Vector3 = car.transform*bounds.get_center()
	camera.transform = Transform3D(Basis.IDENTITY,Vector3(5,2.8,6.5)).looking_at(target)
	super._refresh()
