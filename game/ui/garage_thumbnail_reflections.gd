extends GarageReflections
## One bounded car-only capture sharing the thumbnail's existing world/model.
func build(source: CarShowroom, world: Node3D, stage: Node3D) -> void:
	owner = source
	owner.camera.cull_mask = 1
	mark_stage(stage)
	holder = Node.new()
	holder.name = "ThumbnailReflectionViews"
	owner.add_child(holder)
	var view := SubViewport.new()
	view.name = "ThumbnailTurntableReflection"
	view.world_3d = owner.showroom_viewport.find_world_3d()
	view.size = Vector2i(768,192)
	view.msaa_3d = Viewport.MSAA_2X
	view.mesh_lod_threshold = 0.5
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	holder.add_child(view)
	_restore_parent(view)
	view.tree_entered.connect(_restore_parent.bind(view))
	var capture := Camera3D.new()
	capture.cull_mask = CAR_LAYER
	view.add_child(capture)
	capture.current = true
	views.append(view)
	cameras.append(capture)
	var receiver: MeshInstance3D = world.get_node("ThumbnailDeck")
	deck_material = receiver.material_override
	deck_material.set_shader_parameter("reflection_image",view.get_texture())
	deck_material.set_shader_parameter("reflection_enabled",true)
	sync()

func mark_stage(stage: Node3D) -> void:
	# Contact shadows and the receiver stay out of the reflected car image.
	for node: GeometryInstance3D in stage.find_children("*","GeometryInstance3D",true,false):
		if owner.car.is_ancestor_of(node): node.layers = 1 | CAR_LAYER

func sync() -> void:
	if views.is_empty() or owner.camera == null: return
	var state: Array = [owner.camera.transform,owner.camera.fov,owner.camera.keep_aspect]
	if state == _synced: return
	_synced = state
	var reflected: Transform3D = owner.camera.transform
	reflected.origin.y = GarageEnvironment.DECK_HEIGHT*2.0-reflected.origin.y
	# Mirror the viewpoint while retaining right-handed face winding. The
	# material restores the horizontal direction when sampling the image.
	reflected.basis.x = -Vector3(reflected.basis.x.x,-reflected.basis.x.y,reflected.basis.x.z)
	reflected.basis.y = Vector3(reflected.basis.y.x,-reflected.basis.y.y,reflected.basis.y.z)
	reflected.basis.z = Vector3(reflected.basis.z.x,-reflected.basis.z.y,reflected.basis.z.z)
	cameras[0].transform = reflected
	cameras[0].fov = owner.camera.fov
	cameras[0].keep_aspect = owner.camera.keep_aspect
	set_visible(owner.is_visible_in_tree())

func request_draw(_room: bool = true, car: bool = true) -> void:
	if not enabled or not car or not owner.is_visible_in_tree(): return
	for view: SubViewport in views: view.render_target_update_mode = SubViewport.UPDATE_ONCE
	draw_requests[1] += 1

func set_enabled(active: bool) -> void:
	if active == enabled: return
	enabled = active
	if deck_material != null: deck_material.set_shader_parameter("reflection_enabled",active)
	if not active:
		for view: SubViewport in views: view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	owner.invalidate_render()
