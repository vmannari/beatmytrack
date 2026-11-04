extends "res://ui/car_showroom.gd"
## The original live studio, warmed offscreen and transferred without rebuilding.
var permitted: Callable
var record_settings: Dictionary={}
var achievement_service: Node
var prepared: bool=false
var adopted: bool=false
var warming: bool=false
var warm_draws: int=0
var max_draw_ms: float=0.0
var _pending: Array[Dictionary]=[]
var _held: Array[Dictionary]=[]
var _phase_draws: int=0
var _material_keys: Dictionary={}
var _warm_setup_ready: bool=false

func _ready() -> void:
	cooperative_build=true
	await super._ready()
	if not is_inside_tree() or is_queued_for_deletion(): return
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	super.update_records(record_settings)
	preload("res://ui/achievement_display.gd").update(self,achievement_service)
	for node: GeometryInstance3D in camera.get_parent().find_children("*","GeometryInstance3D",true,false):
		if not node.is_visible_in_tree(): continue
		var priority: int=0 if node.name=="GarageConcrete" or (reflections!=null and node is MeshInstance3D and node.material_override==reflections.deck_material) else 1 if car.is_ancestor_of(node) else 2
		var entry: Dictionary={"node":weakref(node),"margin":node.extra_cull_margin,"key":_geometry_key(node),"priority":priority,"order":_held.size()}
		_held.append(entry)
		_pending.append(entry)
		node.hide()
	_pending.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.priority<b.priority if a.priority!=b.priority else a.order<b.order)
	_stop_draws()
	_warm_setup_ready=true

func invalidate_render() -> void:
	if adopted: super.invalidate_render()
	else: _render_dirty=true

func _process(delta: float) -> void:
	if adopted: super._process(delta)

func _allowed() -> bool:
	return not adopted and is_inside_tree() and not is_queued_for_deletion() and permitted.is_valid() and permitted.call()

func warm() -> void:
	if warming or prepared or not _warm_setup_ready or not _allowed(): return
	warming=true
	while not _pending.is_empty() and _allowed():
		var key: String=_pending[0].key
		var shown: int=0
		var group: Array[Dictionary]=[]
		for index: int in range(_pending.size()-1,-1,-1):
			if _pending[index].key!=key or shown>=8: continue
			var entry: Dictionary=_pending[index]
			var node: Object=entry.node.get_ref()
			if is_instance_valid(node):
				if node is MeshInstance3D:
					var distance: Vector3=(node.to_local(camera.global_position)-node.get_aabb().get_center()).abs()
					node.extra_cull_margin=maxf(node.extra_cull_margin,maxf(distance.x,maxf(distance.y,distance.z))+camera.near+1.0)
				node.show()
				group.append(entry)
			_pending.remove_at(index)
			shown+=1
		# Visit another program before uploading more objects that use the same
		# one. An early handoff then inherits broader real pipeline preparation.
		var repeated: Array[Dictionary]=[]
		for index: int in range(_pending.size()-1,-1,-1):
			if _pending[index].key==key:
				repeated.push_front(_pending[index])
				_pending.remove_at(index)
		_pending.append_array(repeated)
		await _warm_frame()
		for entry: Dictionary in group:
			var node: Object=entry.node.get_ref()
			if is_instance_valid(node): node.extra_cull_margin=entry.margin
	while _pending.is_empty() and _allowed() and not prepared:
		# Carousel pictures have their own studio. Finish only this live view,
		# keeping its camera, awards and reflections intact throughout warming.
		await _warm_frame()
		if adopted or not is_inside_tree() or is_queued_for_deletion(): break
		_phase_draws+=1
		if _phase_draws>=4: prepared=true
	warming=false
	if not adopted: _stop_draws()

func _warm_frame() -> void:
	# This helper is deliberately separate from CanvasItem's _draw callback.
	if not warming or not _warm_setup_ready or not _allowed(): return
	var began: int=Time.get_ticks_usec()
	_submit_render()
	warm_draws+=1
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
	max_draw_ms=maxf(max_draw_ms,(Time.get_ticks_usec()-began)/1000.0)
	if is_inside_tree() and not is_queued_for_deletion(): await get_tree().process_frame

func adopt() -> void:
	adopted=true
	permitted=Callable()
	achievement_service=null
	release_geometry()
	mouse_filter=Control.MOUSE_FILTER_STOP
	invalidate_render()

func release_geometry() -> void:
	for entry: Dictionary in _held:
		var node: Object=entry.node.get_ref()
		if is_instance_valid(node):
			node.extra_cull_margin=entry.margin
			node.show()
	_held.clear()
	_pending.clear()
	_material_keys.clear()

func _geometry_key(node: GeometryInstance3D) -> String:
	var mesh: Mesh=node.mesh if node is MeshInstance3D else node.multimesh.mesh if node is MultiMeshInstance3D and node.multimesh!=null else null
	var key: Array=[node.get_class(),node.cast_shadow]
	if mesh!=null:
		for surface: int in range(mesh.get_surface_count()):
			var material: Material=node.get_active_material(surface) if node is MeshInstance3D else node.material_override if node.material_override!=null else mesh.surface_get_material(surface)
			key.append(_material_key(material))
			key.append(mesh.surface_get_format(surface) if mesh is ArrayMesh else mesh.get_class())
	return str(key)

func _material_key(material: Material) -> String:
	if material==null: return "none"
	var id: int=material.get_instance_id()
	if _material_keys.has(id): return _material_keys[id]
	var key: Array=[material.get_class()]
	if material is ShaderMaterial:
		key.append(material.shader.get_instance_id() if material.shader!=null else 0)
	elif material is BaseMaterial3D:
		# Shader features are modes, flags and texture presence. Colours and
		# scalar surface uniforms do not require another compiled program.
		for property: Dictionary in material.get_property_list():
			if not int(property.usage)&PROPERTY_USAGE_STORAGE: continue
			if property.name in ["resource_local_to_scene","resource_name","resource_path","next_pass"]: continue
			var value: Variant=material.get(property.name)
			if value is bool or value is int: key.append([property.name,value])
			elif property.hint==PROPERTY_HINT_RESOURCE_TYPE and "Texture" in str(property.hint_string): key.append([property.name,value!=null])
	else: key.append(id)
	key.append(_material_key(material.next_pass) if material.next_pass!=null else "none")
	var result: String=str(key)
	_material_keys[id]=result
	return result

func _stop_draws() -> void:
	_settle_draws=0
	_reflection_settle_draws=0
	if RenderingServer.frame_post_draw.is_connected(_finish_render): RenderingServer.frame_post_draw.disconnect(_finish_render)
	if is_instance_valid(showroom_viewport): showroom_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	if reflections!=null:
		for view: SubViewport in reflections.views: view.render_target_update_mode=SubViewport.UPDATE_DISABLED

func _notification(what: int) -> void:
	if what==NOTIFICATION_PREDELETE: release_geometry()
	super._notification(what)
