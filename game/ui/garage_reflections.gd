class_name GarageReflections
extends RefCounted
## Two bounded planar captures of the same menu world; no cloned car/simulation.
const ROOM_LAYER: int = 2
const CAR_LAYER: int = 4
var owner: CarShowroom
var holder: Node
var views: Array[SubViewport] = []
var cameras: Array[Camera3D] = []
var floor_material: ShaderMaterial
var deck_material: ShaderMaterial
var enabled: bool = true
var _visible: bool = false
var _synced: Array = []

func build(source: CarShowroom, world: Node3D, stage: Node3D) -> void:
	owner = source
	owner.camera.cull_mask = 1
	_mark_room(world)
	var floor: MeshInstance3D = world.find_child("GarageConcrete",true,false)
	floor.layers = 1
	floor_material = floor.material_override
	holder = Node.new()
	holder.name = "GarageReflectionViews"
	owner.add_child(holder)
	for index: int in range(2):
		var view := SubViewport.new()
		view.name = "FloorReflection" if index == 0 else "PedestalReflection"
		view.world_3d = owner.showroom_viewport.find_world_3d()
		view.msaa_3d = Viewport.MSAA_2X
		view.scaling_3d_scale = 1.0
		view.transparent_bg = true
		view.render_target_update_mode = SubViewport.UPDATE_ONCE
		holder.add_child(view)
		# The receiving showroom must draw after its freshly resized captures.
		RenderingServer.viewport_set_parent_viewport(view.get_viewport_rid(),owner.showroom_viewport.get_viewport_rid())
		# Native viewport entry restores its inferred parent. A retained Garage
		# can move between menu slots, so reinstate the same explicit draw order.
		view.tree_entered.connect(_restore_parent.bind(view))
		var camera := Camera3D.new()
		camera.cull_mask = ROOM_LAYER if index == 0 else CAR_LAYER
		view.add_child(camera)
		camera.current = true
		views.append(view)
		cameras.append(camera)
	floor_material.set_shader_parameter("reflection_image",views[0].get_texture())
	floor_material.set_shader_parameter("reflection_enabled",true)
	mark_stage(stage)
	sync()

func _restore_parent(view: SubViewport) -> void:
	if is_instance_valid(owner) and is_instance_valid(owner.showroom_viewport):
		RenderingServer.viewport_set_parent_viewport(view.get_viewport_rid(),owner.showroom_viewport.get_viewport_rid())
		_synced.clear()

func _mark_room(node: Node) -> void:
	if node is MeshInstance3D: node.layers = 1 | ROOM_LAYER
	for child: Node in node.get_children(): _mark_room(child)

func mark_stage(stage: Node3D) -> void:
	_mark_stage(stage,false)

func _mark_stage(node: Node, car_part: bool) -> void:
	car_part = car_part or node is CarVisual
	if node is MeshInstance3D:
		node.layers = 1 | ROOM_LAYER | (CAR_LAYER if car_part else 0)
		if node.material_override is ShaderMaterial:
			if node.material_override.shader == preload("res://ui/garage_deck.gdshader"):
				node.layers = 1
				deck_material = node.material_override
				deck_material.set_shader_parameter("reflection_image",views[1].get_texture())
				deck_material.set_shader_parameter("reflection_enabled",enabled)
			elif node.material_override.shader == preload("res://ui/studio_contact.gdshader"):
				node.layers = 1
	for child: Node in node.get_children(): _mark_stage(child,car_part)

func sync() -> void:
	if views.is_empty() or owner.camera == null: return
	var state: Array = [owner.showroom_viewport.size,owner.camera.transform,owner.camera.fov,owner.camera.keep_aspect]
	if state == _synced: return
	_synced = state
	var source_size: Vector2i = owner.showroom_viewport.size
	var width: int = mini(768,maxi(1,ceili(source_size.x*0.5)))
	var pixels := Vector2i(width,maxi(1,roundi(float(width)*source_size.y/maxi(1,source_size.x))))
	for index: int in range(2):
		if views[index].size != pixels: views[index].size = pixels
		var transform: Transform3D = owner.camera.transform
		var plane: float = -0.025 if index == 0 else GarageEnvironment.DECK_HEIGHT
		transform.origin.y = plane*2.0-transform.origin.y
		# Keep a right-handed camera; shader sampling flips X back.
		transform.basis.x = -Vector3(transform.basis.x.x,-transform.basis.x.y,transform.basis.x.z)
		transform.basis.y = Vector3(transform.basis.y.x,-transform.basis.y.y,transform.basis.y.z)
		transform.basis.z = Vector3(transform.basis.z.x,-transform.basis.z.y,transform.basis.z.z)
		cameras[index].transform = transform
		cameras[index].fov = owner.camera.fov
		cameras[index].keep_aspect = owner.camera.keep_aspect
	set_visible(owner.is_visible_in_tree())
	request_draw()

func request_draw() -> void:
	if not enabled or not owner.is_visible_in_tree(): return
	for view: SubViewport in views: view.render_target_update_mode = SubViewport.UPDATE_ONCE

func set_visible(active: bool) -> void:
	if active == _visible: return
	_visible = active
	if active: request_draw()
	else:
		for view: SubViewport in views: view.render_target_update_mode = SubViewport.UPDATE_DISABLED

func set_enabled(active: bool) -> void:
	if active == enabled: return
	enabled = active
	floor_material.set_shader_parameter("reflection_enabled",active)
	if deck_material != null: deck_material.set_shader_parameter("reflection_enabled",active)
	if not active:
		for view: SubViewport in views: view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	owner.invalidate_render()

func dispose() -> void:
	if floor_material != null: floor_material.set_shader_parameter("reflection_image",null)
	if deck_material != null: deck_material.set_shader_parameter("reflection_image",null)
	if is_instance_valid(holder): holder.queue_free()
	views.clear()
	cameras.clear()
