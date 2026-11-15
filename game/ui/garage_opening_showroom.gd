extends "res://ui/car_showroom.gd"
## Keep the ordinary Garage page usable while its real studio takes first draws.
signal studio_prepared
signal studio_interactive
const FirstDraw=preload("res://ui/garage_first_draw.gd")
const ENTRY_IDLE_MS: int=100
var reflection_msaa: int=Viewport.MSAA_4X
var preparing: bool=true
var can_begin_studio: Callable
var achievement_service: Node
var _picture: Control
var _pending: Dictionary={}
var _record_choice: Dictionary={}
var _last_input: int=0
var interaction_ready: bool=false
var opening_started: int=0
var live_ready_ms: float=0.0
var _loads: Array[String]=[]
var _resources: Array[Resource]=[]
var _tree_ref: WeakRef
var _first: Node

func _ready() -> void:
	opening_started=Time.get_ticks_usec()
	_tree_ref=weakref(get_tree())
	set_process(false)
	mouse_filter=Control.MOUSE_FILTER_STOP
	_picture=preload("res://ui/garage_loading_car.gd").new()
	_picture.name="GarageOpeningPicture"
	_picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_picture.vehicle_id=vehicle_id
	add_child(_picture)
	MenuStyle.fill(_picture)
	child_entered_tree.connect(func(_child: Node) -> void: _cover.call_deferred())
	weathering.restore(condition)
	set_process_input(true)
	_request_assets(vehicle_id,customisation)
	_begin_studio.call_deferred()

func _request_assets(id: String,parts: Dictionary) -> void:
	# Decode public resources on workers; create nodes/renderer state on main.
	for path: String in preload("res://ui/garage_studio_assets.gd").paths(id,simple_model,parts):
		if DisplayServer.get_name()!="headless" and not _loads.has(path) and ResourceLoader.exists(path) and ResourceLoader.load_threaded_request(path)==OK: _loads.append(path)

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
	while _current_studio():
		while _current_studio() and not _work_allowed(): await get_tree().process_frame
		if not _current_studio(): return
		while not _loads.is_empty():
			var path: String=_loads[0]
			while _current_studio() and ResourceLoader.load_threaded_get_status(path)==ResourceLoader.THREAD_LOAD_IN_PROGRESS: await get_tree().process_frame
			if not _current_studio(): return
			var status: int=ResourceLoader.load_threaded_get_status(path)
			if status==ResourceLoader.THREAD_LOAD_LOADED: _resources.append(ResourceLoader.load_threaded_get(path))
			elif status==ResourceLoader.THREAD_LOAD_FAILED: ResourceLoader.load_threaded_get(path)
			_loads.pop_front()
		if _work_allowed(): break
	if not _current_studio(): return
	# A choice made while the picture was visible becomes the first built car.
	if not _pending.is_empty():
		vehicle_id=_pending.vehicle
		livery=_pending.paint
		condition=_pending.wear
		customisation=_pending.parts
		_pending={}
	cooperative_build=true
	await super._ready()
	if not is_inside_tree() or is_queued_for_deletion(): return
	# The ordinary page applies its wall contents synchronously. Its deferred
	# counterpart must include them before holding/warming the actual scene.
	preload("res://ui/achievement_display.gd").update(self,achievement_service)
	# Render the actual receiving targets once input is idle. Proxy cameras,
	# cloned lights and offscreen meshes create additional pipeline variants.
	showroom_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	for view: SubViewport in reflections.views: view.render_target_update_mode=SubViewport.UPDATE_DISABLED
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
		move_child(_picture,get_child_count()-1)
		while _current_preparation() and not _current_warm_batch(): await get_tree().process_frame
		if not _current_studio(): return
		if not _record_choice.is_empty(): super.update_records(_record_choice)
		var graphics: Script=preload("res://rendering/graphics_preparation.gd")
		var capture: Dictionary=graphics.begin_capture(camera.get_parent(),showroom_viewport,camera)
		# The original main image, both planar reflections and their resized
		# targets must settle under the picture before the first live reveal.
		for _settle: int in range(4):
			if not _current_preparation(): break
			while _current_preparation() and not _current_warm_batch(): await get_tree().process_frame
			if not _current_preparation(): break
			super._process(0.0)
			showroom_viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
			reflections.request_draw()
			if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
			else: await get_tree().process_frame
			if _settle==0: await get_tree().process_frame
		if not _current_studio(): return
		first.release()
		first.queue_free()
		_first=null
		if _pending.is_empty():
			graphics.finish_capture(capture,camera.get_parent(),showroom_viewport,camera)
			break
	_resources.clear()
	preparing=false
	interaction_ready=true
	live_ready_ms=(Time.get_ticks_usec()-opening_started)/1000.0
	print("GARAGE_LIVE_READY_MS ",live_ready_ms)
	_picture.queue_free()
	_picture=null
	set_process(true)
	studio_interactive.emit()
	studio_prepared.emit()
	invalidate_render()

func _current_preparation() -> bool:
	return _current_studio() and _pending.is_empty()

func _entry_presented() -> bool:
	return is_visible_in_tree() and (not can_begin_studio.is_valid() or can_begin_studio.call())

func _current_warm_batch() -> bool:
	return _current_preparation() and _work_allowed()

func _work_allowed() -> bool:
	if not _current_studio() or not _entry_presented() or Input.is_anything_pressed() or Time.get_ticks_msec()-_last_input<ENTRY_IDLE_MS: return false
	var focus: Control=get_viewport().gui_get_focus_owner()
	return not focus is LineEdit and not focus is TextEdit

func _current_studio() -> bool:
	return is_inside_tree() and not is_queued_for_deletion()

func replace_car(id: String,paint: Dictionary,wear: Dictionary,parts: Dictionary={}) -> void:
	if preparing:
		_pending={"vehicle":id,"paint":paint.duplicate(true),"wear":wear.duplicate(true),"parts":parts.duplicate(true)}
		if car==null: _request_assets(id,parts)
		if _picture!=null:
			_picture.vehicle_id=id
			_picture.show()
		return
	super.replace_car(id,paint,wear,parts)

func apply_livery(value: Dictionary,animate_paint: bool=false) -> void:
	if preparing:
		if _pending.is_empty(): _pending={"vehicle":vehicle_id,"paint":livery.duplicate(true),"wear":condition.duplicate(true),"parts":customisation.duplicate(true)}
		_pending.paint=value.duplicate(true)
		return
	super.apply_livery(value,animate_paint)

func apply_customisation(value: Dictionary,animate_kit: bool=false) -> void:
	if preparing:
		if _pending.is_empty(): _pending={"vehicle":vehicle_id,"paint":livery.duplicate(true),"wear":condition.duplicate(true),"parts":customisation.duplicate(true)}
		_pending.parts=value.duplicate(true)
		if car==null: _request_assets(_pending.vehicle,value)
		return
	super.apply_customisation(value,animate_kit)

func update_records(settings: Dictionary) -> void:
	if preparing:
		_record_choice=settings.duplicate(true)
	else: super.update_records(settings)

func _drag(event: InputEvent) -> void:
	if not preparing or interaction_ready: super._drag(event)

func _input(event: InputEvent) -> void:
	var active: bool=event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventKey or (event is InputEventMouseMotion and event.button_mask!=0)
	if preparing and is_visible_in_tree() and active: _last_input=Time.get_ticks_msec()

func _process(delta: float) -> void:
	if not preparing or interaction_ready: super._process(delta)

func _exit_tree() -> void:
	super._exit_tree()

func _notification(what: int) -> void:
	super._notification(what)
	if what==NOTIFICATION_PREDELETE and not _loads.is_empty():
		_retire_loads(_loads.duplicate(),_tree_ref)
		_loads.clear()

static func _retire_loads(paths: Array[String],tree_ref: WeakRef) -> void:
	var pending: Array[String]=[]
	for path: String in paths:
		var status: int=ResourceLoader.load_threaded_get_status(path)
		if status==ResourceLoader.THREAD_LOAD_IN_PROGRESS: pending.append(path)
		elif status in [ResourceLoader.THREAD_LOAD_LOADED,ResourceLoader.THREAD_LOAD_FAILED]: ResourceLoader.load_threaded_get(path)
	var tree: Object=tree_ref.get_ref()
	if not pending.is_empty() and is_instance_valid(tree): tree.process_frame.connect(_retire_loads.bind(pending,tree_ref),CONNECT_ONE_SHOT)
