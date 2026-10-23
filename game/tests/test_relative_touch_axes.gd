extends SceneTree
## REL01-REL05: first-contact origin, dead zone, quick independent axes and lifecycle.
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func press(control: TouchControls, finger: int, point: Vector2, down: bool = true) -> void:
	var event := InputEventScreenTouch.new()
	event.index = finger
	event.position = control.get_global_transform_with_canvas()*point
	event.pressed = down
	control._input(event)

func drag(control: TouchControls, finger: int, point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = finger
	event.position = control.get_global_transform_with_canvas()*point
	control._input(event)

func run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	var control := TouchControls.new()
	control.driver = DriverInput.new()
	control.haptic_strength = 0.0
	root.add_child(control)
	await process_frame
	for method: String in ["horizontal","joystick"]:
		for mirrored: bool in [false,true]:
			for dimensions: Vector2 in [Vector2(960,540),Vector2(1280,720),Vector2(1600,720)]:
				for scale_value: float in [0.65,1.0,1.6]:
					control.size = dimensions
					control.layout = ControlLayout.preset(mirrored,scale_value)
					control.layout.steering_type = method
					_test_axes(control)
	# Same screen coordinates must work under a translated/scaled CanvasItem.
	control.position = Vector2(22,31)
	control.scale = Vector2(0.8,0.8)
	_test_axes(control)
	control.position = Vector2.ZERO
	control.scale = Vector2.ONE
	_test_lifecycle(control)
	control.queue_free()
	await process_frame
	if DisplayServer.get_name() != "headless": await _capture_gameplay()
	print("RELATIVE_TOUCH_AXES: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _test_axes(control: TouchControls) -> void:
	var groups: Dictionary = control.group_rects()
	var steering: Rect2 = groups[control.layout.steering_type]
	var pedal: Rect2 = groups.accelerator
	check(groups.size() == 3 and not groups.has("brake"),"analog mode has steer, gas/brake and separate handbrake")
	var saved_brake: Dictionary = control.layout.brake.duplicate(true)
	for fraction: Vector2 in [Vector2(0.04,0.08),Vector2(0.5,0.5),Vector2(0.96,0.92)]:
		var origin: Vector2 = steering.position+steering.size*fraction
		var pedal_origin: Vector2 = pedal.position+pedal.size*fraction
		var travel: float = steering.size.x*0.25
		var pedal_travel: float = pedal.size.y*0.25
		press(control,1,origin)
		press(control,2,pedal_origin)
		check(control.driver.sample().steer == 0 and control.driver.sample().throttle == 0 and control.driver.sample().brake == 0,"first contact is zero even near edges")
		for direction: float in [-1.0,1.0]:
			drag(control,1,origin+Vector2(direction*travel*0.11,0))
			drag(control,2,pedal_origin+Vector2(0,direction*pedal_travel*0.11))
			check(control.driver.sample().steer == 0 and control.driver.sample().throttle == 0 and control.driver.sample().brake == 0,"small dead zone on both sides of both origins")
			drag(control,1,origin+Vector2(direction*travel*0.56,0))
			drag(control,2,pedal_origin-Vector2(0,direction*pedal_travel*0.56))
			var frame: DriveFrame = control.driver.sample()
			check(absi(frame.steer) >= 62 and absi(frame.steer) <= 65 and signi(frame.steer) == int(direction),"quick continuous steering ramp in both directions")
			var pedal_strength: int = frame.throttle if direction > 0 else frame.brake
			check(pedal_strength >= 126 and pedal_strength <= 129 and (frame.brake if direction > 0 else frame.throttle) == 0,"quick vertical gas/brake ramp excludes opposite pedal")
			drag(control,1,origin+Vector2(direction*travel*1.01,500))
			drag(control,2,pedal_origin+Vector2(500,-direction*pedal_travel*1.01))
			frame = control.driver.sample()
			check(frame.steer == int(direction)*127,"vertical drift cannot reduce or reverse horizontal steering")
			check((frame.throttle if direction > 0 else frame.brake) == 255 and (frame.brake if direction > 0 else frame.throttle) == 0,"horizontal drift cannot reduce vertical gas/brake")
			drag(control,1,origin)
			drag(control,2,pedal_origin)
			check(control.driver.sample().steer == 0 and control.driver.sample().throttle == 0 and control.driver.sample().brake == 0,"returning to original contact is neutral")
		press(control,1,Vector2.ZERO,false)
		press(control,2,Vector2.ZERO,false)
		check(control.touch_origins.is_empty() and control.owners.is_empty(),"release removes both origins")
	check(control.layout.brake == saved_brake,"analog driving preserves separate button preferences")

func _test_lifecycle(control: TouchControls) -> void:
	control.size = Vector2(1280,720)
	control.layout = ControlLayout.preset()
	control.layout.steering_type = "horizontal"
	var steer: Rect2 = control.group_rects().horizontal
	var pedal: Rect2 = control.group_rects().accelerator
	var hb: Rect2 = control.group_rects().handbrake
	press(control,1,steer.get_center())
	drag(control,1,steer.get_center()+Vector2(100,0))
	press(control,2,pedal.get_center())
	drag(control,2,pedal.get_center()-Vector2(0,100))
	press(control,3,hb.get_center())
	check(control.driver.sample().steer == 127 and control.driver.sample().throttle == 255 and control.driver.sample().handbrake == 255,"three independent fingers steer, accelerate and handbrake")
	press(control,4,steer.position+Vector2(2,2))
	check(control.driver.sample().steer == 0 and control.driver.sample().throttle == 255,"steering handoff resets only its own origin")
	press(control,1,Vector2.ZERO,false)
	drag(control,1,steer.position-Vector2(100,0))
	drag(control,4,steer.position+Vector2(102,2))
	check(control.driver.sample().steer == 127,"old steering release and drag cannot affect new owner")
	press(control,5,pedal.position+Vector2(2,2))
	press(control,2,Vector2.ZERO,false)
	drag(control,2,pedal.position-Vector2(0,100))
	check(control.driver.sample().throttle == 0 and control.driver.sample().brake == 0 and control.driver.sample().steer == 127,"pedal handoff stays neutral after old owner events")
	drag(control,5,pedal.position+Vector2(2,102))
	check(control.driver.sample().brake == 255 and control.driver.sample().throttle == 0 and control.driver.sample().handbrake == 255,"new pedal finger brakes with independent handbrake")
	press(control,3,Vector2.ZERO,false)
	check(control.driver.sample().handbrake == 0 and control.driver.sample().brake == 255,"handbrake release preserves analog brake")
	var cancel := InputEventScreenTouch.new()
	cancel.index = 5
	cancel.canceled = true
	control._input(cancel)
	check(control.driver.sample().brake == 0 and control.driver.sample().steer == 127,"pedal cancellation preserves steering")
	control.hide()
	check(control.owners.is_empty() and control.touch_origins.is_empty() and control.driver.sample().steer == 0,"hidden controls release all origins and actions")
	press(control,9,steer.get_center())
	check(control.owners.is_empty(),"hidden controls cannot capture fingers")
	control.show()
	for notification: int in [Node.NOTIFICATION_APPLICATION_FOCUS_OUT,Node.NOTIFICATION_APPLICATION_PAUSED]:
		press(control,1,steer.get_center())
		drag(control,1,steer.get_center()-Vector2(100,0))
		control._notification(notification)
		check(control.owners.is_empty() and control.touch_origins.is_empty() and control.driver.sample().steer == 0,"focus/pause clears touch state")
	press(control,1,steer.get_center())
	control.layout = ControlLayout.preset()
	check(control.touch_origins.is_empty() and control.driver.sample().steer == 0,"layout replacement clears origins")
	press(control,2,control.touch_zones()[3].get_center())
	press(control,3,control.touch_zones()[2].get_center())
	check(control.driver.sample().throttle == 255 and control.driver.sample().brake == 255,"button scheme retains full press on separate pedals")
	control.enabled = false
	check(control.owners.is_empty() and control.touch_origins.is_empty() and control.driver.sample().throttle == 0 and control.driver.sample().brake == 0,"disable clears all buttons")
	control.enabled = true

func _capture_gameplay() -> void:
	var output: String = ProjectSettings.globalize_path("res://../build/analog-touch-2026-10-16/"+RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(output)
	var game: Node = load("res://core/game.tscn").instantiate()
	game.set("production_mode",true)
	root.add_child(game)
	game.set_physics_process(false)
	var control: TouchControls = game.get("hud").touch
	control.haptic_strength = 0.0
	for method: String in ["horizontal","joystick"]:
		control.layout = ControlLayout.preset()
		control.layout.steering_type = method
		control.queue_redraw()
		var steer: Rect2 = control.group_rects()[method]
		var pedal: Rect2 = control.group_rects().accelerator
		var origin: Vector2 = steer.get_center()-Vector2(18,0)
		var pedal_origin: Vector2 = pedal.get_center()
		press(control,1,origin)
		press(control,2,pedal_origin)
		await _save(output.path_join(method+"-neutral.png"))
		check(control.thumb.position == origin and control.pedal_thumb.position == pedal_origin,"native indicators start at actual first contact")
		drag(control,1,origin+Vector2(steer.size.x*0.25,90))
		drag(control,2,pedal_origin-Vector2(60,pedal.size.y*0.25))
		await _save(output.path_join(method+"-gas-right.png"))
		check(control.thumb.position.y == origin.y and control.pedal_thumb.position.x == pedal_origin.x,"native indicators only move along intended axes")
		var draws: int = control.draw_count
		for tick: int in range(12):
			drag(control,1,origin+Vector2(steer.size.x*0.25,sin(tick)*90))
			drag(control,2,pedal_origin+Vector2(sin(tick)*90,-pedal.size.y*0.25))
			await process_frame
		check(control.draw_count == draws,"analog motion retains prepared drawing commands")
		drag(control,1,origin-Vector2(steer.size.x*0.25,0))
		drag(control,2,pedal_origin+Vector2(0,pedal.size.y*0.25))
		press(control,3,(control.group_rects().handbrake as Rect2).get_center())
		await _save(output.path_join(method+"-brake-left-handbrake.png"))
		check(control.driver.sample().steer == -127 and control.driver.sample().brake == 255 and control.driver.sample().handbrake == 255,"native opposite axes and separate handbrake")
		control.release_all()
	game.queue_free()
	await process_frame

func _save(path: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(path) == OK,"native gameplay capture: "+path.get_file())
