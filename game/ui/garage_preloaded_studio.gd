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
var _pending: Dictionary={}
var _held: Array[Dictionary]=[]
var _phase_draws: int=0
var _material_keys: Dictionary={}
var _warm_setup_ready: bool=false
var _graphics: Node
var _capture_ticket: Dictionary={}

func _ready() -> void:
	cooperative_build=true
	await super._ready()
	if not is_inside_tree() or is_queued_for_deletion(): return
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	super.update_records(record_settings)
	preload("res://ui/achievement_display.gd").update(self,achievement_service)
	_graphics=preload("res://race/world_render_preparation.gd").new()
	add_child(_graphics)
	for node: GeometryInstance3D in camera.get_parent().find_children("*","GeometryInstance3D",true,false):
		if not node.is_visible_in_tree(): continue
		var priority: int=0 if node.name=="GarageConcrete" or (reflections!=null and node is MeshInstance3D and node.material_override==reflections.deck_material) else 1 if car.is_ancestor_of(node) else 2
		var entry: Dictionary={"node":weakref(node),"margin":node.extra_cull_margin,"key":_geometry_key(node),"priority":priority,"order":_held.size()}
		_held.append(entry)
	_held.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.priority<b.priority if a.priority!=b.priority else a.order<b.order)
	# Preserve floor/car/room ordering while sharing the race queue and ledger.
	_graphics._world=weakref(camera.get_parent())
	for entry: Dictionary in _held: _graphics.hold_geometry(entry.node.get_ref())
	_pending=_graphics.pending
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
	var instance: WeakRef=weakref(self)
	warming=true
	if not _pending.is_empty() and _allowed(): await _graphics.prepare(_warm_frame,_allowed)
	if not is_instance_valid(instance.get_ref()): return
	# Entry or eviction can retire this studio while the draw is yielding.
	# Its emptied queue is not evidence that a detached world finished warming.
	if not _allowed():
		warming=false
		if not adopted: _stop_draws()
		return
	if _pending.is_empty() and _capture_ticket.is_empty():
		_capture_ticket=preload("res://rendering/graphics_preparation.gd").begin_capture(camera.get_parent(),showroom_viewport,camera)
	while _pending.is_empty() and _allowed() and not prepared:
		# Carousel pictures have their own studio. Finish only this live view,
		# keeping its camera, awards and reflections intact throughout warming.
		var drawn: bool=await _warm_frame()
		if not is_instance_valid(instance.get_ref()): return
		if not drawn or not _allowed(): break
		_phase_draws+=1
		if _phase_draws>=4: prepared=true
	if prepared: preload("res://rendering/graphics_preparation.gd").finish_capture(_capture_ticket,camera.get_parent(),showroom_viewport,camera)
	warming=false
	if not adopted: _stop_draws()

func _warm_frame() -> bool:
	# This helper is deliberately separate from CanvasItem's _draw callback.
	if not warming or not _warm_setup_ready or not _allowed(): return false
	var began: int=Time.get_ticks_usec()
	_submit_render()
	warm_draws+=1
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
	max_draw_ms=maxf(max_draw_ms,(Time.get_ticks_usec()-began)/1000.0)
	if is_inside_tree() and not is_queued_for_deletion(): await get_tree().process_frame
	return is_inside_tree() and not is_queued_for_deletion()

func adopt() -> void:
	adopted=true
	permitted=Callable()
	achievement_service=null
	release_geometry()
	mouse_filter=Control.MOUSE_FILTER_STOP
	invalidate_render()

func release_geometry() -> void:
	if is_instance_valid(_graphics): _graphics.release()
	for entry: Dictionary in _held:
		var node: Object=entry.node.get_ref()
		if is_instance_valid(node):
			node.extra_cull_margin=entry.margin
			node.show()
	_held.clear()
	_pending.clear()
	_material_keys.clear()
	_capture_ticket.clear()

func _geometry_key(node: GeometryInstance3D) -> String:
	return preload("res://rendering/graphics_preparation.gd").geometry_key(node,_material_keys)

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
