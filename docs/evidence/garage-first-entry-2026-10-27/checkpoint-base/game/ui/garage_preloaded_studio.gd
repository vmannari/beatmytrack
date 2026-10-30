extends "res://ui/car_showroom.gd"
## The original live studio, warmed offscreen and transferred without rebuilding.
const Keys=preload("res://race/world_render_preparation.gd")
var permitted: Callable
var record_settings: Dictionary={}
var prepared: bool=false
var adopted: bool=false
var warming: bool=false
var warm_draws: int=0
var max_draw_ms: float=0.0
var _pending: Array[Dictionary]=[]
var _held: Array[Dictionary]=[]

func _ready() -> void:
	cooperative_build=true
	await super._ready()
	if not is_inside_tree() or is_queued_for_deletion(): return
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	super.update_records(record_settings)
	for node: GeometryInstance3D in camera.get_parent().find_children("*","GeometryInstance3D",true,false):
		if not node.is_visible_in_tree(): continue
		var entry: Dictionary={"node":weakref(node),"margin":node.extra_cull_margin,"key":Keys._key(node)}
		_held.append(entry)
		_pending.append(entry)
		node.hide()
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
		await _draw()
		for entry: Dictionary in group:
			var node: Object=entry.node.get_ref()
			if is_instance_valid(node): node.extra_cull_margin=entry.margin
	if _pending.is_empty() and _allowed():
		for _settle: int in range(4):
			if not _allowed(): break
			await _draw()
		if _allowed(): prepared=true
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
