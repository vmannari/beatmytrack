extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1440,900)
	preload("res://vehicle/modular_car_base.gd").enabled = false
	preload("res://vehicle/modular_car_kits.gd").enabled = false
	preload("res://ui/garage_car_cache.gd").enabled = false
	var view := CarShowroom.new(); view.vehicle_id = "super_rally"; view.read_only = true; view.size = Vector2(1440,900)
	root.add_child(view)
	while not view.showroom_ready or not view.car.model_ready: await process_frame
	view.finish_car_transition(); view.finish_paint_transition(); view.finish_kit_transition()
	view.yaw = -0.70; view.elevation = 0.32; view.zoom = 0.75; view._orbit()
	print("PICK_COORDINATES ",view.size," ",view.showroom_viewport.size," ",view.get_global_transform_with_canvas()," ",root.get_stretch_transform())
	for pixel: Vector2 in [Vector2(525,711),Vector2(532,713),Vector2(526,701),Vector2(526,721),Vector2(137,476)]:
		var local: Vector2 = (root.get_stretch_transform()*view.get_global_transform_with_canvas()).affine_inverse()*pixel
		var screen: Vector2 = local*Vector2(view.showroom_viewport.size)/view.size
		var origin: Vector3 = view.camera.project_ray_origin(screen); var direction: Vector3 = view.camera.project_ray_normal(screen)
		var closest: float = INF; var answer: Dictionary = {}
		for part: MeshInstance3D in view.car.find_children("*","MeshInstance3D",true,false):
			if part.mesh == null or part.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
			var faces: PackedVector3Array = part.mesh.get_faces()
			var inverse: Transform3D = part.global_transform.affine_inverse()
			var ray: Vector3 = inverse*origin; var delta: Vector3 = inverse.basis*direction
			for i: int in range(0,faces.size(),3):
				var hit: Variant = Geometry3D.ray_intersects_triangle(ray,delta,faces[i],faces[i+1],faces[i+2])
				if hit == null: continue
				var distance: float = origin.distance_to(part.global_transform*hit)
				if distance < closest:
					closest = distance
					answer = {"node":str(view.car.get_path_to(part)),"position":str(view.car.global_transform.affine_inverse()*part.global_transform*hit),"material":str(part.get_active_material(0).albedo_color),"triangle":[str(faces[i]),str(faces[i+1]),str(faces[i+2])]}
		print("PICK_SURFACE ",pixel," ",JSON.stringify(answer))
	view.free();quit()
