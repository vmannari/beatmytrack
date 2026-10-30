extends "res://ui/car_showroom.gd"
## Keep the ordinary Garage page usable while its real studio takes first draws.
signal studio_prepared
signal studio_interactive
const FirstDraw=preload("res://ui/garage_first_draw.gd")
var preparing: bool=true
var can_begin_studio: Callable
var _picture: TextureRect
var _pending: Dictionary={}
var _record_choice: Dictionary={}
var _facade: RefCounted
var _warm_view: SubViewport
var _warm_camera: Camera3D
var _last_input: int=0
var interaction_ready: bool=false
var opening_started: int=0
var live_ready_ms: float=0.0
var _loads: Array[String]=[]
var _resources: Array[Resource]=[]
var _lights: Array[Dictionary]=[]
var _tree_ref: WeakRef
var _first: Node
var _motion_was_running: bool=false
var _last_uploads: int=-1

func _ready() -> void:
	opening_started=Time.get_ticks_usec()
	_tree_ref=weakref(get_tree())
	set_process(false)
	mouse_filter=Control.MOUSE_FILTER_STOP
	_picture=TextureRect.new()
	_picture.name="GarageOpeningPicture"
	_picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_picture.texture=load("res://assets/garage/previews_v1/"+vehicle_id+".png")
	add_child(_picture)
	MenuStyle.fill(_picture)
	child_entered_tree.connect(func(_child: Node) -> void: _cover.call_deferred())
	weathering.restore(condition)
	set_process_input(true)
	RenderingServer.frame_pre_draw.connect(_sync_live_finish)
	# Resource decoding may run off the UI thread; nodes and renderer stay owned.
	for path: String in ["res://assets/garage/cars_v1/"+vehicle_id+".scn",GarageEnvironment.PREPARED_ARCHITECTURE]:
		if ResourceLoader.exists(path) and ResourceLoader.load_threaded_request(path)==OK: _loads.append(path)
	_begin_studio.call_deferred()

func _cover() -> void:
	if preparing and is_instance_valid(_picture) and _picture.get_index()!=get_child_count()-1:
		move_child(_picture,get_child_count()-1)

func _begin_studio() -> void:
	await get_tree().process_frame
	if not is_inside_tree() or is_queued_for_deletion(): return
	while _current_studio():
		while _current_studio() and not _entry_presented(): await get_tree().process_frame
		if not _current_studio(): return
		# Finish the incoming page's actual draw before submitting a native world.
		if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
		await get_tree().process_frame
		if _entry_presented(): break
	if not _current_studio(): return
	for path: String in _loads:
		while _current_studio() and ResourceLoader.load_threaded_get_status(path)==ResourceLoader.THREAD_LOAD_IN_PROGRESS: await get_tree().process_frame
		if not _current_studio(): return
		if ResourceLoader.load_threaded_get_status(path)==ResourceLoader.THREAD_LOAD_LOADED: _resources.append(ResourceLoader.load_threaded_get(path))
	_loads.clear()
	cooperative_build=true
	await super._ready()
	if not is_inside_tree() or is_queued_for_deletion(): return
	# One MSAA level prevents renderer precompilation switching back and forth
	# between the live view and its two reflection captures.
	for view: SubViewport in reflections.views: view.msaa_3d=showroom_viewport.msaa_3d
	_warm_view=SubViewport.new()
	_warm_view.world_3d=showroom_viewport.find_world_3d()
	_warm_view.size=Vector2i(64,64)
	_warm_view.msaa_3d=showroom_viewport.msaa_3d
	_warm_view.render_target_update_mode=SubViewport.UPDATE_DISABLED
	add_child(_warm_view)
	_warm_camera=Camera3D.new()
	_warm_camera.cull_mask=8
	_warm_view.add_child(_warm_camera)
	_warm_camera.current=true
	for light: Node in camera.get_parent().find_children("*","Light3D",true,false):
		var copy: Node=light.duplicate()
		copy.layers=8
		copy.light_cull_mask=8
		light.get_parent().add_child(copy)
		_lights.append({"source":weakref(light),"mask":light.light_cull_mask,"copy":copy})
		light.light_cull_mask&=7
	while _current_studio():
		if not _pending.is_empty():
			var target: Dictionary=_pending
			_pending={}
			var previous: Node3D=turntable
			super.replace_car(target.vehicle,target.paint,target.wear,target.parts)
			super.finish_car_transition()
			if is_instance_valid(previous) and previous!=turntable and previous.get_parent()!=null:
				previous.get_parent().remove_child(previous)
				previous.queue_free()
		var first: Node=FirstDraw.new()
		_first=first
		add_child(first)
		first.hold(car)
		first.hold(camera.get_parent())
		_facade=preload("res://ui/garage_opening_facade.gd").new()
		_facade.build(first.pending)
		move_child(_picture,get_child_count()-1)
		showroom_viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
		reflections.request_draw()
		if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
		if not _current_studio(): return
		if _pending.is_empty(): _picture.hide()
		# Present the viewport texture once too: its first canvas resolve can be
		# a different program from rendering the world behind the picture.
		showroom_viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
		if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
		if not _current_studio(): return
		# Settle native render targets before accepting the first drag. The first
		# world draw and its canvas presentation may submit work on separate frames.
		for _settle: int in range(3):
			await get_tree().process_frame
			if not _current_studio(): return
			super._process(0.0)
			showroom_viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
			reflections.request_draw()
			if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
		interaction_ready=true
		_last_input=Time.get_ticks_msec()
		if live_ready_ms==0.0:
			live_ready_ms=(Time.get_ticks_usec()-opening_started)/1000.0
			print("GARAGE_LIVE_READY_MS ",live_ready_ms)
		set_process(true)
		studio_interactive.emit()
		while not first.pending.is_empty() and _current_preparation():
			# Do not even reveal a cold native material into the shadow pass while
			# input is active. Wait before prepare() exposes its next group.
			while _current_preparation() and (not is_visible_in_tree() or Time.get_ticks_msec()-_last_input<750): await get_tree().process_frame
			if not _current_preparation(): break
			await first.prepare(_draw_studio,_current_warm_batch)
		if not _current_studio(): return
		interaction_ready=false
		_facade.restore()
		_facade=null
		# Release held visibility synchronously before the next generation holds it.
		for job: Dictionary in first.pending:
			var held: Object=job.node.get_ref()
			if is_instance_valid(held): held.show()
		first.pending.clear()
		first.queue_free()
		_first=null
		if _pending.is_empty(): break
	_warm_view.queue_free()
	_warm_view=null
	_restore_lights()
	_resources.clear()
	preparing=false

	if not _record_choice.is_empty(): super.update_records(_record_choice)
	_picture.queue_free()
	_picture=null
	set_process(true)
	studio_prepared.emit()
	invalidate_render()

func _current_preparation() -> bool:
	return _current_studio() and _pending.is_empty()

func _entry_presented() -> bool:
	return is_visible_in_tree() and (not can_begin_studio.is_valid() or can_begin_studio.call())

func _current_warm_batch() -> bool:
	return _current_preparation() and is_visible_in_tree() and Time.get_ticks_msec()-_last_input>=750

func _current_studio() -> bool:
	return is_inside_tree() and not is_queued_for_deletion()

func _draw_studio() -> bool:
	while _current_studio() and not is_visible_in_tree(): await get_tree().process_frame
	# Compile full finishes only after the player pauses their interaction.
	while _current_preparation() and Time.get_ticks_msec()-_last_input<750: await get_tree().process_frame
	if not _current_preparation(): return false
	_warm_camera.transform=camera.transform
	_warm_camera.fov=camera.fov
	_warm_camera.keep_aspect=camera.keep_aspect
	_warm_view.render_target_update_mode=SubViewport.UPDATE_ONCE
	showroom_viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	reflections.request_draw()
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
	await get_tree().process_frame
	return _current_studio()

func replace_car(id: String,paint: Dictionary,wear: Dictionary,parts: Dictionary={}) -> void:
	if preparing:
		_pending={"vehicle":id,"paint":paint.duplicate(true),"wear":wear.duplicate(true),"parts":parts.duplicate(true)}
		if _picture!=null:
			_picture.texture=load("res://assets/garage/previews_v1/"+id+".png")
			_picture.show()
		return
	super.replace_car(id,paint,wear,parts)

func apply_livery(value: Dictionary,animate_paint: bool=false) -> void:
	if preparing and interaction_ready:
		super.apply_livery(value,animate_paint)
		_refresh_facade()
		return
	if preparing:
		if _pending.is_empty(): _pending={"vehicle":vehicle_id,"paint":livery.duplicate(true),"wear":condition.duplicate(true),"parts":customisation.duplicate(true)}
		_pending.paint=value.duplicate(true)
		return
	super.apply_livery(value,animate_paint)

func apply_customisation(value: Dictionary,animate_kit: bool=false) -> void:
	if preparing and interaction_ready:
		super.apply_customisation(value,animate_kit)
		_refresh_facade()
		return
	if preparing:
		if _pending.is_empty(): _pending={"vehicle":vehicle_id,"paint":livery.duplicate(true),"wear":condition.duplicate(true),"parts":customisation.duplicate(true)}
		_pending.parts=value.duplicate(true)
		return
	super.apply_customisation(value,animate_kit)

func update_records(settings: Dictionary) -> void:
	if preparing:
		_record_choice=settings.duplicate(true)
		if interaction_ready:
			super.update_records(settings)
			_refresh_facade()
	else: super.update_records(settings)

func _drag(event: InputEvent) -> void:
	if not preparing or interaction_ready: super._drag(event)

func _input(event: InputEvent) -> void:
	if preparing and is_visible_in_tree() and (event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventKey): _last_input=Time.get_ticks_msec()

func _process(delta: float) -> void:
	if not preparing or interaction_ready: super._process(delta)
	if DisplayServer.get_name()=="headless": _sync_live_finish()

func _sync_live_finish() -> void:
	# Tweens advance after node processing. Copy their current uniforms just
	# before drawing so the live sweep uses the same progress as its source.
	if interaction_ready and _facade!=null:
		var motion: bool=(paint_motion!=null and paint_motion.is_running()) or (kit_motion!=null and kit_motion.is_running())
		if motion or _motion_was_running: _refresh_facade()
		elif weathering.parameter_uploads!=_last_uploads: _facade.sync_parameters()
		else: _facade.sync_poses()
		_motion_was_running=motion
		_last_uploads=weathering.parameter_uploads

func _refresh_facade() -> void:
	if _facade!=null and is_instance_valid(_first):
		_facade.refresh(camera.get_parent(),_first)

func _exit_tree() -> void:
	super._exit_tree()

func _notification(what: int) -> void:
	super._notification(what)
	if what==NOTIFICATION_PREDELETE and RenderingServer.frame_pre_draw.is_connected(_sync_live_finish): RenderingServer.frame_pre_draw.disconnect(_sync_live_finish)
	if what==NOTIFICATION_PREDELETE:
		if _facade!=null:
			_facade.restore()
			_facade=null
		_restore_lights()
	if what==NOTIFICATION_PREDELETE and not _loads.is_empty():
		_retire_loads(_loads.duplicate(),_tree_ref)
		_loads.clear()

func _restore_lights() -> void:
	for item: Dictionary in _lights:
		var light: Object=item.source.get_ref()
		if is_instance_valid(light): light.light_cull_mask=item.mask
		if is_instance_valid(item.copy):
			if item.copy.get_parent()!=null: item.copy.get_parent().remove_child(item.copy)
			item.copy.queue_free()
	_lights.clear()

static func _retire_loads(paths: Array[String],tree_ref: WeakRef) -> void:
	var pending: Array[String]=[]
	for path: String in paths:
		var status: int=ResourceLoader.load_threaded_get_status(path)
		if status==ResourceLoader.THREAD_LOAD_IN_PROGRESS: pending.append(path)
		elif status==ResourceLoader.THREAD_LOAD_LOADED: ResourceLoader.load_threaded_get(path)
	var tree: Object=tree_ref.get_ref()
	if not pending.is_empty() and is_instance_valid(tree): tree.process_frame.connect(_retire_loads.bind(pending,tree_ref),CONNECT_ONE_SHOT)
