extends RefCounted
## Native renderer factory, loaded only for a missing authored picture.

class ProfilePreview extends "res://ui/rivalry_victory_car.gd":
	# The header cache owns its first draws. Inherited resize/radiance settles
	# must not submit the complete cold car ahead of its material queue.
	var deferred_render: bool = false
	var preparing_render: bool = false
	var camera: Camera3D:
		get: return viewport.get_camera_3d() if is_instance_valid(viewport) else null
	var showroom_viewport: SubViewport:
		get: return viewport
	func _refresh() -> void:
		# Staging hides geometry temporarily. Fitting against that partial car
		# would move the camera and invalidate both appearance and receipts.
		if preparing_render: return
		super._refresh()
		if deferred_render and is_instance_valid(viewport): viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

	func _fit_camera() -> void:
		var camera: Camera3D = viewport.get_camera_3d()
		if camera == null: return
		# Center the visible model rather than the podium's fixed world target.
		# Translate in the camera plane to retain the Rivalry viewing angle.
		var points := PackedVector3Array()
		var view: Transform3D = camera.global_transform.affine_inverse()
		var depth_range := Vector2(INF,-INF)
		for mesh: Node in car.find_children("*","MeshInstance3D",true,false):
			if not mesh.is_visible_in_tree() or mesh.mesh == null: continue
			var bounds: AABB = mesh.get_aabb()
			for x: float in [bounds.position.x,bounds.end.x]:
				for y: float in [bounds.position.y,bounds.end.y]:
					for z: float in [bounds.position.z,bounds.end.z]:
						var point: Vector3 = view*mesh.to_global(Vector3(x,y,z))
						points.append(point)
						depth_range.x = minf(depth_range.x,-point.z)
						depth_range.y = maxf(depth_range.y,-point.z)
		if points.is_empty(): return
		var shift := Vector2.ZERO
		for _pass: int in range(4):
			var low := Vector2(INF,INF)
			var high := Vector2(-INF,-INF)
			for point: Vector3 in points:
				var projected: Vector2 = (Vector2(point.x,point.y)-shift)/maxf(0.01,-point.z)
				low = low.min(projected)
				high = high.max(projected)
			shift += (low+high)*0.5*(depth_range.x+depth_range.y)*0.5
		camera.position += camera.basis*Vector3(shift.x,shift.y,0)
		super._fit_camera()

static func make_preview(vehicle: String, paint: Dictionary, parts: Dictionary) -> Control:
	var result := ProfilePreview.new()
	result.name = "ProfileCarRender"
	result.vehicle_id = vehicle
	result.livery = paint.duplicate(true)
	result.customisation = parts.duplicate(true)
	result.simple_model = true
	result.podium_presentation = true
	result.fit_to_frame = true
	return result

static func apply_presentation(view: Control) -> void:
	var environment: WorldEnvironment = view.viewport.find_child("PodiumReflectionEnvironment",true,false)
	environment.environment.ambient_light_energy = 0.7
	var fill := DirectionalLight3D.new()
	fill.name = "ProfileReadabilityFill"
	fill.light_energy = 0.65
	fill.rotation = view.viewport.get_camera_3d().rotation
	view.car.get_parent().add_child(fill)
	view._refresh()

static func repaint_preview(view: Control, paint: Dictionary) -> void:
	# Icon batches retain geometry, camera, lights and radiance. Only paint changes.
	view.livery = paint.duplicate(true)
	view.car.apply_livery(paint)
	if view.car.chassis_id!="compact":
		preload("res://ui/rivalry_podium_studio.gd")._garage_paint(view.car)
