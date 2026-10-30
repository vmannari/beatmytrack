extends "res://ui/car_showroom.gd"
## The original live studio, warmed offscreen and transferred without rebuilding.
var permitted: Callable
var record_settings: Dictionary={}
var achievement_service: Node
var carousel_texture: Texture2D
var prepared: bool=false
var adopted: bool=false
var warming: bool=false
var warm_draws: int=0
var max_draw_ms: float=0.0
var _pending: Array[Dictionary]=[]
var _held: Array[Dictionary]=[]
var _phase: int=0
var _phase_draws: int=0
var _thumbnail_state: Dictionary={}
var _material_keys: Dictionary={}

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

func invalidate_render() -> void:
	if adopted: super.invalidate_render()
	else: _render_dirty=true

func _process(delta: float) -> void:
	if adopted: super._process(delta)

func _allowed() -> bool:
	return not adopted and is_inside_tree() and not is_queued_for_deletion() and permitted.is_valid() and permitted.call()

func warm() -> void:
	if warming or prepared or not showroom_ready or not _allowed(): return
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
		await _draw()
		for entry: Dictionary in group:
			var node: Object=entry.node.get_ref()
			if is_instance_valid(node): node.extra_cull_margin=entry.margin
	while _pending.is_empty() and _allowed() and not prepared:
		# Warm/capture the exact existing carousel pose in this same world. Its
		# 2x MSAA and shadowless key need different native pipelines from live 3D.
		if _phase==1 and _thumbnail_state.is_empty(): _begin_thumbnail()
		await _draw()
		if adopted or not is_inside_tree() or is_queued_for_deletion(): break
		_phase_draws+=1
		if _phase_draws<4: continue
		_phase_draws=0
		if _phase==1:
			if DisplayServer.get_name()!="headless": carousel_texture=ImageTexture.create_from_image(showroom_viewport.get_texture().get_image())
			_restore_thumbnail()
		_phase+=1
		if _phase==3: prepared=true
	warming=false
	if not adopted: _stop_draws()

func _draw() -> void:
	if not _allowed(): return
	var began: int=Time.get_ticks_usec()
	_submit_render()
	warm_draws+=1
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
	max_draw_ms=maxf(max_draw_ms,(Time.get_ticks_usec()-began)/1000.0)
	if is_inside_tree() and not is_queued_for_deletion(): await get_tree().process_frame

func adopt() -> void:
	adopted=true
	permitted=Callable()
	_restore_thumbnail()
	achievement_service=null
	release_geometry()
	mouse_filter=Control.MOUSE_FILTER_STOP
	invalidate_render()

func release_geometry() -> void:
	_restore_thumbnail()
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

func take_carousel_picture() -> Dictionary:
	if carousel_texture==null: return {}
	var result: Dictionary={"vehicle":vehicle_id,"paint":livery.duplicate(true),"condition":condition.duplicate(true),"parts":customisation.duplicate(true),"texture":carousel_texture}
	carousel_texture=null
	return result

func _begin_thumbnail() -> void:
	var key: DirectionalLight3D=camera.get_parent().get_node("GarageKey")
	var awards: Node3D=find_child("EarnedAchievements",true,false)
	_thumbnail_state={"size":size,"msaa":showroom_viewport.msaa_3d,"camera":camera.transform,"fov":camera.fov,"distance":garage_distance,"shadow":key.shadow_enabled,"awards":weakref(awards) if awards!=null else null,"awards_visible":awards.visible if awards!=null else false,"read_only":read_only,"roof":roof.visible}
	if awards!=null: awards.hide()
	super.update_records({})
	read_only=true
	garage_distance=0
	camera.fov=38.0
	showroom_viewport.msaa_3d=Viewport.MSAA_4X
	size=Vector2(2048,512)
	refresh_thumbnail()
	_orbit()

func _restore_thumbnail() -> void:
	if _thumbnail_state.is_empty(): return
	var state: Dictionary=_thumbnail_state
	_thumbnail_state={}
	read_only=state.read_only
	garage_distance=state.distance
	camera.transform=state.camera
	camera.fov=state.fov
	camera.get_parent().get_node("GarageKey").shadow_enabled=state.shadow
	showroom_viewport.msaa_3d=state.msaa
	size=state.size
	roof.visible=state.roof
	var awards: Object=state.awards.get_ref() if state.awards!=null else null
	if is_instance_valid(awards): awards.visible=state.awards_visible
	super.update_records(record_settings)
	refresh_thumbnail()

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
